# ARKit-Multiplayer

This test project is based on [`Apple's ARKit framework`](https://developer.apple.com/arkit/), [`Vision framework`](https://developer.apple.com/documentation/vision) and [`OpenCV library`](http://opencv.org). It's able to track QR marker in the camera's videofeed and put SceneKit's node "above" that QR. Also it's possible to create a multiplayer ARKit session with the ability to see in camera view another device and interact with the 3D scene together in realtime.

<p align="center">
    <img src="/Media/ARKit Muliplayer.gif", width="480">
</p>

## QR marker detection

With the help of Apple's Vision now it's possible to recognize QR marker in camera's videofeed and track it while it is in the field of view. The framework provides us the coordinates of the QR marker square corners in the screen's coordinate system.

<p align="center">
    <img src="/Media/QR code detection.png", width="480">
</p>

## QR marker pose estimation

The next thing you probably want to do after detecting the QR markers is to obtain the camera pose from them.

To perform QR marker pose estimation you need to know the calibration parameters of your camera. This is the camera matrix and distortion coefficients. Each camera lens has unique parameters, such as focal length, principal point, and lens distortion model. The process of finding intrinsic camera parameters is called camera calibration. The camera calibration process is important for Augmented Reality applications because it describes the perspective transformation and lens distortion on an output image. To achieve the best user experience with Augmented Reality, visualization of an augmented object should be done using the same perspective projection.

At the end, what you get after the calibration is the camera matrix: a matrix of 3x3 elements with the focal distances and the camera center coordinates (a.k.a intrinsic parameters), and the distortion coefficients: a vector of 5 elements or more that models the distortion produced by your camera. The calibration parameters are pretty the same for most of iDevices.

With the precise location of marker corners, we can estimate a transformation between our camera and a marker in 3D space. This operation is known as pose estimation from 2D-3D correspondences. The pose estimation process finds an Euclidean transformation (that consists only of rotation and translation components) between the camera and the object.

<p align="center">
    <img src="/Media/QR marker pose estimation.png", width="480">
</p>

The C is used to denote the camera center. The P1-P4 points are 3D points in the world coordinate system and the p1-p4 points are their projections on the camera's image plane. Our goal is to find relative transformation between a known marker position in the 3D world (p1-p4) and the camera C using an intrinsic matrix and known point projections on image plane (P1-P4).

OpenCV functions are used to calculate the QR marker transformation in such a way that it minimizes the reprojection error, that is the sum of squared distances between the observed projection's imagePoints and the projected objectPoints. The estimated transformation is defined by rotation (rvec) and translation components (tvec). This is also known as Euclidean transformation or rigid transformation. At the end we get rotation quaternion and a translation matrix of the QR marker.

## Integration into Apple's ARKit

The final part is the integration of all the information about QR marker's pose into the 3D scene created by ARKit. ARKit uses Visual Inertial Odometry (VIO) to accurately track the world around it. VIO fuses camera sensor data with CoreMotion data. These two inputs allow the device to sense how it moves within a room with a high degree of accuracy, and without any additional calibration. All the rendering stuff is based on Apple's Metal and Apple's SceneKit above it.

In order to render SceneKit's node on our QR marker in a proper way we need to create a model matrix of our QR marker from the quaternion and translation matrix we've got from OpenCV. The next step is to multiply QR marker's model matrix by SceneKit scene virtual camera's transform matrix. As a result we can see a custom node (Axes node in our project) that repeats all the QR marker's movements in the real world while its in the filed of view of the iPhone's camera and if it is not - it stays on the last updated position so we can examine it around.

<p align="center">
    <img src="/Media/Integration into Apple's ARKit.gif", width="480">
</p>

## ARKit multiplayer session

If we run the same ARKit app on separate devices they won't be able to communicate with each other in one scene because each device sees the world from a different point of view and has its unique anchors in the real world so their 3D scenes can even cross each other but they will have separate coordinate systems. But if we provide them the only one anchor that will help us a lot. With the QR marker we can create new coordinate systems with the starting point near the marker in both of the iDevices. With the help of Apple's Bonjour protocol the iDevices can send each other the info about they pose in the new coordinate system so now we can create an ARKit multiplayer session.

##

To use this project you need to print a 10-sm QR. There's a small [`QR Generator`](https://github.com/eugenebokhan/QR-Generator) app that is going to help you with that.

<p align="center">
    <img src="/Media/QR Generator.png", width="480">
</p>

## 3. Licence

The source code is released under [GPLv3](http://www.gnu.org/licenses/) licence.


For commercial inqueries, please contact me.
