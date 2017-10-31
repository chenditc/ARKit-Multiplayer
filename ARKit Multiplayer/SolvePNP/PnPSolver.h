//
//  PnPSolver.h
//  ARKit Multiplayer
//
//  Created by Eugene Bokhan on 31.10.2017.
//  Copyright © 2017 Eugene Bokhan. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <simd/SIMD.h>

@interface PnPSolver : NSObject

@property (nonatomic, assign) float qw;
@property (nonatomic, assign) float qx;
@property (nonatomic, assign) float qy;
@property (nonatomic, assign) float qz;
@property (nonatomic, assign) float t0;
@property (nonatomic, assign) float t1;
@property (nonatomic, assign) float t2;

- (void)processCorners:(CGPoint)_c0 :(CGPoint)_c1 :(CGPoint)_c2 :(CGPoint)_c3 :(float)half_of_real_size :(float)f_x :(float)f_y :(float)c_x :(float)c_y;

@end
