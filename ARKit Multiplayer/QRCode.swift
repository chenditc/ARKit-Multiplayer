//
//  QRCode.swift
//  ManifestUI
//
//  Created by Eugene Bokhan on 28.07.17.
//  Copyright © 2017 Alexander. All rights reserved.
//

import UIKit
import SceneKit

class QRCode: NSObject {
    
    struct corner {
        var name: String
        var screenPosition: CGPoint
        var worldPosition: SCNVector3
    }
    
    var topLeftCorner = corner(name: "Top Left", screenPosition: CGPoint(), worldPosition: SCNVector3())
    var topRightCorner = corner(name: "Top Right", screenPosition: CGPoint(), worldPosition: SCNVector3())
    var bottomRightCorner = corner(name: "Bottom Right", screenPosition: CGPoint(), worldPosition: SCNVector3())
    var bottomLeftCorner = corner(name: "Bottom Left", screenPosition: CGPoint(), worldPosition: SCNVector3())

}
