//
//  ViewController.swift
//  ARKit Multiplayer
//
//  Created by Eugene Bokhan on 31.10.2017.
//  Copyright © 2017 Eugene Bokhan. All rights reserved.
//

import ARKit
import UIKit
import Vision
import simd

class ViewController: UIViewController, ARSCNViewDelegate, MultiplayerConnectivityServiceDelegate {
    
    private let connectivityService = MultiplayerConnectivityService()
    private var requests = [VNRequest]()
    private var qrCode = QRCode()
    private var previousPoint: SCNVector3?
    private lazy var drawLayer: CAShapeLayer = {
        let drawLayer = CAShapeLayer()
        self.sceneView.layer.addSublayer(drawLayer)
        drawLayer.frame = self.sceneView.bounds
        drawLayer.strokeColor = UIColor.green.cgColor
        drawLayer.lineWidth = 3
        drawLayer.lineJoin = kCALineJoinMiter
        drawLayer.fillColor = UIColor.clear.cgColor
        return drawLayer
    }()
    
    private var pointGeom: SCNGeometry = {
        let geo = SCNSphere(radius: 0.01)
        let material = SCNMaterial()
        material.diffuse.contents = UIColor.blue
        material.locksAmbientWithDiffuse = true
        geo.firstMaterial = material
        return geo
    }()
    
    private var cameraNode: SCNNode = {
        var cameraNode = SCNScene(named:"art.scnassets/Camera.dae")?.rootNode
        cameraNode?.name = "cameraNode"
        return cameraNode!
    }()
    private var axesNode = createAxesNode(quiverLength: 0.06, quiverThickness: 1.0)
    private var sphereNode = SCNNode()
    private var nodes = [SCNNode]()
    
    private let bufferQueue = DispatchQueue(label: "com.evgeniybokhan.BufferQueue",
                                            qos: .userInteractive,
                                            attributes: .concurrent)
    
    private let pnpSolver = PnPSolver()
    
    
    @IBOutlet weak var connectionsLabel: UILabel!
    
    @IBAction func showButton(_ sender: UIButton) {
        addNode()
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        self.connectivityService.delegate = self
        setupScene()
        setupNotifications()
        setupVision()
        setupNodes()
    }
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        session.pause()
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        fixSceneViewPosition()
        // Prevent the screen from being dimmed after a while.
        UIApplication.shared.isIdleTimerDisabled = true
        
        // Start the ARSession.
        restartPlaneDetection()
    }
    
    // MARK: - ARKit / ARSCNView
    let session = ARSession()
    var sessionConfig: ARConfiguration = ARWorldTrackingConfiguration()
    @IBOutlet var sceneView: ARSCNView!
    var screenCenter: CGPoint?
    
    func setupNotifications() {
        NotificationCenter.default.addObserver(self, selector: #selector(fixSceneViewPosition), name: NSNotification.Name.UIApplicationDidChangeStatusBarOrientation, object: nil)
    }
    
    func setupScene() {
        // set up sceneView
        sceneView.delegate = self
        sceneView.session = session
        sceneView.antialiasingMode = .multisampling4X
        sceneView.automaticallyUpdatesLighting = false
        
        sceneView.preferredFramesPerSecond = 60
        sceneView.contentScaleFactor = 1.3
        
        fixSceneViewPosition()
        
        if let camera = sceneView.pointOfView?.camera {
            camera.wantsHDR = true
            camera.wantsExposureAdaptation = true
        }
    }
    
    func enableEnvironmentMapWithIntensity(_ intensity: CGFloat) {
        sceneView.scene.lightingEnvironment.intensity = intensity
    }
    
    func restartPlaneDetection() {
        // configure session
        if let worldSessionConfig = sessionConfig as? ARWorldTrackingConfiguration {
            worldSessionConfig.planeDetection = .horizontal
            session.run(worldSessionConfig, options: [.resetTracking, .removeExistingAnchors])
        }
    }
    
    // MARK: - SCNNodes
    
    func setupNodes() {
        //        sceneView.scene.rootNode.addChildNode(axesNode)
    }
    
    // MARK: - Vision
    
    func setupVision() {
        let barcodeRequest = VNDetectBarcodesRequest(completionHandler: barcodeDetectionHandler)
        barcodeRequest.symbologies = [.QR] // VNDetectBarcodesRequest.supportedSymbologies
        self.requests = [barcodeRequest]
    }
    
    func barcodeDetectionHandler(request: VNRequest, error: Error?) {
        guard let results = request.results else { return }
        
        DispatchQueue.main.async() {
            // Loop through the results found.
            let path = CGMutablePath()
            
            guard self.sceneView.session.currentFrame != nil else {
                return
            }
            
            for result in results {
                guard let barcode = result as? VNBarcodeObservation else { continue }
                self.qrCode.topLeftCorner.screenPosition = self.convert(point: barcode.topLeft)
                path.move(to: self.qrCode.topLeftCorner.screenPosition)
                self.qrCode.topRightCorner.screenPosition = self.convert(point: barcode.topRight)
                path.addLine(to: self.qrCode.topRightCorner.screenPosition)
                self.qrCode.bottomRightCorner.screenPosition = self.convert(point: barcode.bottomRight)
                path.addLine(to: self.qrCode.bottomRightCorner.screenPosition)
                self.qrCode.bottomLeftCorner.screenPosition = self.convert(point: barcode.bottomLeft)
                path.addLine(to: self.qrCode.bottomLeftCorner.screenPosition)
                path.addLine(to: self.qrCode.topLeftCorner.screenPosition)
                
                //    v0 --------------v3
                //    |             __/ |
                //    |          __/    |
                //    |       __/       |
                //    |    __/          |
                //    | __/             |
                //    v1 --------------v2
                
                switch UIApplication.shared.statusBarOrientation {
                case .portrait:
                    let imageResolution = self.session.currentFrame?.camera.imageResolution
                    let viewSize = self.sceneView.bounds.size
                    
                    let xCoef = (imageResolution?.width)! / viewSize.width
                    let yCoef = (imageResolution?.height)! / viewSize.height
                    
                    let _c0 = CGPoint(x: self.qrCode.bottomRightCorner.screenPosition.x * xCoef, y: self.qrCode.bottomRightCorner.screenPosition.y * yCoef)
                    let _c1 = CGPoint(x: self.qrCode.topRightCorner.screenPosition.x * xCoef, y: self.qrCode.topRightCorner.screenPosition.y * yCoef)
                    let _c2 = CGPoint(x: self.qrCode.topLeftCorner.screenPosition.x * xCoef, y: self.qrCode.topLeftCorner.screenPosition.y * yCoef)
                    let _c3 = CGPoint(x: self.qrCode.bottomLeftCorner.screenPosition.x * xCoef, y: self.qrCode.bottomLeftCorner.screenPosition.y * yCoef)
                    
                    let half_of_real_size: Float = 0.05 // 10sm / 2 = 0.05m
                    
                    let f_x = self.session.currentFrame?.camera.intrinsics.columns.0.x // Focal length in x axis
                    let f_y = self.session.currentFrame?.camera.intrinsics.columns.1.y // Focal length in y axis
                    let c_x = self.session.currentFrame?.camera.intrinsics.columns.2.x // Camera primary point x
                    let c_y = self.session.currentFrame?.camera.intrinsics.columns.2.y // Camera primary point y
                    
                    self.pnpSolver.processCorners(_c0, _c1, _c2, _c3, half_of_real_size, f_x!, f_y!, c_x!, c_y!)
                    
                    let qw = self.pnpSolver.qw
                    let qx = -self.pnpSolver.qx
                    let qy = -self.pnpSolver.qy
                    let qz = -self.pnpSolver.qz
                    let t0 = self.pnpSolver.t1
                    let t1 = self.pnpSolver.t0
                    let t2 = -self.pnpSolver.t2
                    
                    let r1 = vector_float4(x: 1 - 2*qy*qy - 2*qz*qz, y: (2*qx*qy + 2*qz*qw), z: (2*qx*qz - 2*qy*qw), w: 0)
                    let r2 = vector_float4(x: (2*qx*qy - 2*qz*qw), y: 1 - 2*qx*qx - 2*qz*qz, z: (2*qy*qz + 2*qx*qw), w: 0)
                    let r3 = vector_float4(x: (2*qx*qz + 2*qy*qw), y: (2*qy*qz - 2*qx*qw), z: 1 - 2*qx*qx - 2*qy*qy, w: 0)
                    let r4 = vector_float4(x: t0, y: t1, z: t2, w: 1)
                    
                    let modelMatrix = matrix_float4x4(r1, r2, r3, r4)
                    
                    let cameraTransform = self.session.currentFrame?.camera.transform
                    
                    let pose = SCNMatrix4(matrix_multiply(cameraTransform!, modelMatrix))
                    
                    self.axesNode.transform = pose
                    print()
                case .portraitUpsideDown:
                    break
                case .landscapeLeft:
                    let imageResolution = self.session.currentFrame?.camera.imageResolution
                    let viewSize = self.sceneView.bounds.size
                    
                    let xCoef = (imageResolution?.width)! / viewSize.width
                    let yCoef = (imageResolution?.height)! / viewSize.height
                    
                    let _c0 = CGPoint(x: self.qrCode.bottomRightCorner.screenPosition.x * xCoef, y: self.qrCode.bottomRightCorner.screenPosition.y * yCoef)
                    let _c1 = CGPoint(x: self.qrCode.topRightCorner.screenPosition.x * xCoef, y: self.qrCode.topRightCorner.screenPosition.y * yCoef)
                    let _c2 = CGPoint(x: self.qrCode.topLeftCorner.screenPosition.x * xCoef, y: self.qrCode.topLeftCorner.screenPosition.y * yCoef)
                    let _c3 = CGPoint(x: self.qrCode.bottomLeftCorner.screenPosition.x * xCoef, y: self.qrCode.bottomLeftCorner.screenPosition.y * yCoef)
                    
                    let half_of_real_size: Float = 0.05 // 10sm / 2 = 0.05m
                    
                    let f_x = self.session.currentFrame?.camera.intrinsics.columns.0.x // Focal length in x axis
                    let f_y = self.session.currentFrame?.camera.intrinsics.columns.1.y // Focal length in y axis
                    let c_x = self.session.currentFrame?.camera.intrinsics.columns.2.x // Camera primary point x
                    let c_y = self.session.currentFrame?.camera.intrinsics.columns.2.y // Camera primary point y
                    
                    self.pnpSolver.processCorners(_c0, _c1, _c2, _c3, half_of_real_size, f_x!, f_y!, c_x!, c_y!)
                    
                    let qw = self.pnpSolver.qw
                    let qx = -self.pnpSolver.qx
                    let qy = self.pnpSolver.qy
                    let qz = -self.pnpSolver.qz
                    let t0 = -self.pnpSolver.t0
                    let t1 = self.pnpSolver.t1
                    let t2 = -self.pnpSolver.t2
                    
                    let r1 = vector_float4(x: 1 - 2*qy*qy - 2*qz*qz, y: (2*qx*qy + 2*qz*qw), z: (2*qx*qz - 2*qy*qw), w: 0)
                    let r2 = vector_float4(x: (2*qx*qy - 2*qz*qw), y: 1 - 2*qx*qx - 2*qz*qz, z: (2*qy*qz + 2*qx*qw), w: 0)
                    let r3 = vector_float4(x: (2*qx*qz + 2*qy*qw), y: (2*qy*qz - 2*qx*qw), z: 1 - 2*qx*qx - 2*qy*qy, w: 0)
                    let r4 = vector_float4(x: t0, y: t1, z: t2, w: 1)
                    
                    let modelMatrix = matrix_float4x4(r1, r2, r3, r4)
                    
                    let cameraTransform = self.session.currentFrame?.camera.transform
                    
                    let pose = SCNMatrix4(matrix_multiply(cameraTransform!, modelMatrix))
                    
                    self.axesNode.transform = pose
                case .landscapeRight:
                    let imageResolution = self.session.currentFrame?.camera.imageResolution
                    let viewSize = self.sceneView.bounds.size
                    
                    let xCoef = (imageResolution?.width)! / viewSize.width
                    let yCoef = (imageResolution?.height)! / viewSize.height
                    
                    let _c0 = CGPoint(x: self.qrCode.topLeftCorner.screenPosition.x * xCoef, y: self.qrCode.topLeftCorner.screenPosition.y * yCoef)
                    let _c1 = CGPoint(x: self.qrCode.bottomLeftCorner.screenPosition.x * xCoef, y: self.qrCode.bottomLeftCorner.screenPosition.y * yCoef)
                    let _c2 = CGPoint(x: self.qrCode.bottomRightCorner.screenPosition.x * xCoef, y: self.qrCode.bottomRightCorner.screenPosition.y * yCoef)
                    let _c3 = CGPoint(x: self.qrCode.topRightCorner.screenPosition.x * xCoef, y: self.qrCode.topRightCorner.screenPosition.y * yCoef)
                    
                    let half_of_real_size: Float = 0.05 // 10sm / 2 = 0.05m
                    
                    let f_x = self.session.currentFrame?.camera.intrinsics.columns.0.x // Focal length in x axis
                    let f_y = self.session.currentFrame?.camera.intrinsics.columns.1.y // Focal length in y axis
                    let c_x = self.session.currentFrame?.camera.intrinsics.columns.2.x // Camera primary point x
                    let c_y = self.session.currentFrame?.camera.intrinsics.columns.2.y // Camera primary point y
                    
                    self.pnpSolver.processCorners(_c0, _c1, _c2, _c3, half_of_real_size, f_x!, f_y!, c_x!, c_y!)
                    
                    let qw = self.pnpSolver.qw
                    let qx = self.pnpSolver.qx
                    let qy = -self.pnpSolver.qy
                    let qz = -self.pnpSolver.qz
                    let t0 = self.pnpSolver.t0
                    let t1 = -self.pnpSolver.t1
                    let t2 = -self.pnpSolver.t2
                    
                    let r1 = vector_float4(x: 1 - 2*qy*qy - 2*qz*qz, y: (2*qx*qy + 2*qz*qw), z: (2*qx*qz - 2*qy*qw), w: 0)
                    let r2 = vector_float4(x: (2*qx*qy - 2*qz*qw), y: 1 - 2*qx*qx - 2*qz*qz, z: (2*qy*qz + 2*qx*qw), w: 0)
                    let r3 = vector_float4(x: (2*qx*qz + 2*qy*qw), y: (2*qy*qz - 2*qx*qw), z: 1 - 2*qx*qx - 2*qy*qy, w: 0)
                    let r4 = vector_float4(x: t0, y: t1, z: t2, w: 1)
                    
                    let modelMatrix = matrix_float4x4(r1, r2, r3, r4)
                    
                    let cameraTransform = self.session.currentFrame?.camera.transform
                    
                    let pose = SCNMatrix4(matrix_multiply(cameraTransform!, modelMatrix))
                    
                    self.axesNode.transform = pose
                case .unknown: break
                }
            }
            self.drawLayer.path = path
        }
    }
    
    private func convert(point: CGPoint) -> CGPoint {
        var convertedPoint = CGPoint()
        let height = sceneView.bounds.size.height
        let width = sceneView.bounds.size.width
        switch UIApplication.shared.statusBarOrientation {
        case .portrait:
            convertedPoint.x = point.x * width
            convertedPoint.y = (1 - point.y) * height
        case .portraitUpsideDown:
            convertedPoint.x = (1 - point.x) * width
            convertedPoint.y = point.y * height
        case .landscapeLeft:
            convertedPoint.x = point.y * width
            convertedPoint.y = point.x * height
        case .landscapeRight:
            convertedPoint.x = (1 - point.y) * width
            convertedPoint.y = (1 - point.x) * height
        case .unknown:
            convertedPoint.x = point.x * width
            convertedPoint.y = (1 - point.y) * height
        }
        return convertedPoint
    }
    
    // MARK: - Add nodes to SceneView
    
    @objc private func addNode() {
        let nodeCount = String(self.sceneView.scene.rootNode.childNodes.count)
        createNode(name: nodeCount)
        connectivityService.sendData(dataString: "addNode sphereNode \(nodeCount)")
        sendTransform(nodeName: "sphereNode \(nodeCount)")
    }
    
    private func createNode(name: String) {
        guard let pointOfView = sceneView.pointOfView else { return }
        let mat = pointOfView.transform
        let dir = SCNVector3(-1 * mat.m31, -1 * mat.m32, -1 * mat.m33)
        let currentPosition = pointOfView.position + (dir * 0.1)
        let sphereNode = SCNNode(geometry: pointGeom)
        sphereNode.name = "sphereNode \(name)"
        sphereNode.position = currentPosition
        sceneView.scene.rootNode.addChildNode(sphereNode)
    }
    
    // MARK: - Fix view on orientation change
    
    @objc func fixSceneViewPosition() {
        let viewWidth = self.view.bounds.width
        let viewHeight = self.view.bounds.height
        let sceneViewPortraitWidth = viewWidth
        let sceneViewPortraitHeight = viewWidth / 9 * 16
        let sceneViewLandscapeWidth = viewHeight / 9 * 16
        let sceneViewLandscapeHeight = viewHeight
        
        let landscapeWidthDifference = abs(viewWidth - sceneViewLandscapeWidth)
        let portraitHeightDifference = abs(viewHeight - sceneViewPortraitHeight)
        
        switch UIApplication.shared.statusBarOrientation {
        case .portrait:
            self.sceneView.bounds = CGRect(x: 0, y: -portraitHeightDifference / 2, width: sceneViewPortraitWidth, height: sceneViewPortraitHeight)
        case .portraitUpsideDown:
            self.sceneView.bounds = CGRect(x: 0, y: -portraitHeightDifference / 2, width: sceneViewPortraitWidth, height: sceneViewPortraitHeight)
        case .landscapeLeft:
            self.sceneView.bounds = CGRect(x: -landscapeWidthDifference / 2, y: 0, width: sceneViewLandscapeWidth, height: sceneViewLandscapeHeight)
        case .landscapeRight:
            self.sceneView.bounds = CGRect(x: -landscapeWidthDifference / 2, y: 0, width: sceneViewLandscapeWidth, height: sceneViewLandscapeHeight)
        case .unknown: break
        }
        self.sceneView.frame = self.sceneView.bounds
        drawLayer.frame = self.sceneView.frame
        self.screenCenter = self.sceneView.bounds.mid
    }
    
    // MARK: - Send information about camera transform relatively to axes node
    
    private func sendTransform(nodeName: String) {
        let nodeNameStringArray = nodeName.components(separatedBy: " ")
        
        if self.connectivityService.session.connectedPeers.count != 0 {
            var matrix = SCNMatrix4()
            var matrixString = String()
            
            if nodeNameStringArray[0] == "cameraNode" {
                if let cameraTransform = self.session.currentFrame?.camera.transform {
                    matrix = self.sceneView.scene.rootNode.convertTransform(SCNMatrix4(cameraTransform), to: self.axesNode) // Camera Matrix Relatively To Axes
                    matrixString = "\(matrix.m11) \(matrix.m12) \(matrix.m13) \(matrix.m14) \(matrix.m21) \(matrix.m22) \(matrix.m23) \(matrix.m24) \(matrix.m31) \(matrix.m32) \(matrix.m33) \(matrix.m34) \(matrix.m41) \(matrix.m42) \(matrix.m43) \(matrix.m44) cameraNode"
                }
            }
            
            if nodeNameStringArray[0] == "sphereNode" {
                let nodeTransform = self.sceneView.scene.rootNode.childNode(withName: nodeName, recursively: true)?.transform
                matrix = self.sceneView.scene.rootNode.convertTransform(nodeTransform!, to: self.axesNode) // Node Matrix Relatively To Axes
                matrixString = "\(matrix.m11) \(matrix.m12) \(matrix.m13) \(matrix.m14) \(matrix.m21) \(matrix.m22) \(matrix.m23) \(matrix.m24) \(matrix.m31) \(matrix.m32) \(matrix.m33) \(matrix.m34) \(matrix.m41) \(matrix.m42) \(matrix.m43) \(matrix.m44) sphereNode \(nodeNameStringArray[1])"
            }
            
            self.connectivityService.sendData(dataString : matrixString)
        }
    }
    
    // MARK: - ARSCNViewDelegate
    
    func renderer(_ renderer: SCNSceneRenderer, willRenderScene scene: SCNScene, atTime time: TimeInterval) {
        
    }
    
    func renderer(_ renderer: SCNSceneRenderer, updateAtTime time: TimeInterval) {
        //refreshFeaturePoints()
        
        DispatchQueue.main.async {
            guard let pixelBuffer = self.session.currentFrame?.capturedImage else { return }
            
            var requestOptions: [VNImageOption: Any] = [:]
            
            requestOptions = [.cameraIntrinsics: self.session.currentFrame?.camera.intrinsics as Any]
            
            
            let imageRequestHandler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, orientation: CGImagePropertyOrientation(rawValue: 6)!, options: requestOptions)
            
            do {
                try imageRequestHandler.perform(self.requests)
            } catch {
                print(error)
            }
            self.sendTransform(nodeName: "cameraNode")
        }
    }
}

extension ViewController {
    
    func connectedDevicesChanged(manager : MultiplayerConnectivityService, connectedDevices: [String]) {
        OperationQueue.main.addOperation {
            self.cameraNode.removeFromParentNode()
            self.sceneView.scene.rootNode.addChildNode(self.cameraNode)
            self.connectionsLabel.text = "Connections: \(connectedDevices)"
        }
    }
    
    func dataRecieved(manager : MultiplayerConnectivityService, data: String) {
        OperationQueue.main.addOperation {
            let dataArray = data.components(separatedBy: " ")
            
            if dataArray.count > 10 {
                let transform = SCNMatrix4(m11: Float(dataArray[0])!, m12: Float(dataArray[1])!, m13: Float(dataArray[2])!, m14: Float(dataArray[3])!, m21: Float(dataArray[4])!, m22: Float(dataArray[5])!, m23: Float(dataArray[6])!, m24: Float(dataArray[7])!, m31: Float(dataArray[8])!, m32: Float(dataArray[9])!, m33: Float(dataArray[10])!, m34: Float(dataArray[11])!, m41: Float(dataArray[12])!, m42: Float(dataArray[13])!, m43: Float(dataArray[14])!, m44: Float(dataArray[15])!)
                
                let relativeToAxesTransform = SCNMatrix4Mult(transform, self.axesNode.transform)
                
                if dataArray[16] == "cameraNode" {
                    self.cameraNode.transform = relativeToAxesTransform
                }
                
                if dataArray[16] == "sphereNode" {
                    self.sceneView.scene.rootNode.childNode(withName: "sphereNode \(dataArray[17])", recursively: true)?.transform = relativeToAxesTransform
                }
            }
            
            if dataArray[0] == "addNode" {
                if dataArray[1] == "sphereNode" {
                    self.createNode(name: dataArray[2])
                }
            }
            
        }
    }
}


