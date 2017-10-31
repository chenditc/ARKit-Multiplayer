//
//  PnPSolver.m
//  ARKit Multiplayer
//
//  Created by Eugene Bokhan on 31.10.2017.
//  Copyright © 2017 Eugene Bokhan. All rights reserved.
//

#import <opencv2/opencv.hpp>

#import "PnPSolver.h"

using namespace std;
using namespace cv;

@implementation PnPSolver

- (void)processCorners:(CGPoint)_c0 :(CGPoint)_c1 :(CGPoint)_c2 :(CGPoint)_c3 :(float)half_of_real_size :(float)f_x :(float)f_y :(float)c_x :(float)c_y
{
    std::vector<cv::Point2f> m_corners;
    // c0------c3
    // |        |
    // |        |
    // c1------c2
    Point2f c0 = Point2f(_c0.x, _c0.y);
    Point2f c1 = Point2f(_c1.x, _c1.y);
    Point2f c2 = Point2f(_c2.x, _c2.y);
    Point2f c3 = Point2f(_c3.x, _c3.y);
    
    m_corners.push_back(c0);
    m_corners.push_back(c1);
    m_corners.push_back(c2);
    m_corners.push_back(c3);
    
    Point3f corners_3d[] =
    {
        Point3f(-half_of_real_size, -half_of_real_size, 0),
        Point3f(-half_of_real_size,  half_of_real_size, 0),
        Point3f( half_of_real_size,  half_of_real_size, 0),
        Point3f( half_of_real_size, -half_of_real_size, 0)
    };
    
    float camera_intrisics_matrix[] =
    {
        f_x, 0.0f, c_x,
        0.0f, f_y, c_y,
        0.0f, 0.0f, 1.0f
    };
    
    float dist_coeff[] = {0.0f, 0.0f, 0.0f, 0.0f};
    
    vector<Point3f> m_corners_3d = vector<Point3f>(corners_3d, corners_3d + 4);
    Mat m_camera_matrix = Mat(3, 3, CV_32FC1, camera_intrisics_matrix).clone();
    Mat m_dist_coeff = Mat(1, 4, CV_32FC1, dist_coeff).clone();
    Mat rot_mat, tvec, rot_vec;
    
    bool res = solvePnP(m_corners_3d, m_corners, m_camera_matrix, m_dist_coeff, rot_vec, tvec);
    Rodrigues(rot_vec, rot_mat);
    
    self.qw = (sqrt(1.0 + rot_mat.at<double>(0,0) + rot_mat.at<double>(1,1) + rot_mat.at<double>(2,2)) / 2.0);
    self.qx = (rot_mat.at<double>(2,1) - rot_mat.at<double>(1,2)) / (4 * self.qw);
    self.qy = (rot_mat.at<double>(0,2) - rot_mat.at<double>(2,0)) / (4 * self.qw);
    self.qz = (rot_mat.at<double>(1,0) - rot_mat.at<double>(0,1)) / (4 * self.qw);
    self.t0 = tvec.at<double>(0);
    self.t1 = tvec.at<double>(1);
    self.t2 = tvec.at<double>(2);
}

@end

