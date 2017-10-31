//
//  MathUtilities.swift
//  ARKit + QRMark
//
//  Created by Eugene Bokhan on 01.08.17.
//  Copyright © 2017 Eugene Bokhan. All rights reserved.
//

import Foundation
import simd

/// Builds a translation matrix that translates by the supplied vector
func matrix_float4x4_translation (t: vector_float3) -> matrix_float4x4 {
    let X = vector_float4(1, 0, 0, 0)
    let Y = vector_float4(0, 1, 0, 0)
    let Z = vector_float4(0, 0, 1, 0)
    let W = vector_float4(t.x, t.y, t.z, 1)
    
    let mat = matrix_float4x4(X, Y, Z, W)
    return mat
}

/// Builds a scale matrix that uniformly scales all axes by the supplied factor
func matrix_float4x4_uniform_scale (scale: Float) -> matrix_float4x4 {
    let X = vector_float4(scale, 0, 0, 0)
    let Y = vector_float4(0, scale, 0, 0)
    let Z = vector_float4(0, 0, scale, 0)
    let W = vector_float4(0, 0, 0, 1)
    
    let mat = matrix_float4x4(X, Y, Z, W)
    return mat
}

/// Builds a rotation matrix that rotates about the supplied axis by an
/// angle (given in radians). The axis should be normalized.
func matrix_float4x4_rotation (axis: vector_float3, angle: Float) -> matrix_float4x4 {
    
    let c: Float = cos(angle)
    let s: Float = sin(angle)
    
    var X = vector_float4()
    X.x = axis.x * axis.x + (1 - axis.x * axis.x) * c
    X.y = axis.x * axis.y * (1 - c) - axis.z * s
    X.z = axis.x * axis.z * (1 - c) + axis.y * s
    X.w = 0.0
    
    var Y = vector_float4()
    Y.x = axis.x * axis.y * (1 - c) + axis.z * s
    Y.y = axis.y * axis.y + (1 - axis.y * axis.y) * c
    Y.z = axis.y * axis.z * (1 - c) - axis.x * s
    Y.w = 0.0
    
    var Z = vector_float4()
    Z.x = axis.x * axis.z * (1 - c) - axis.y * s
    Z.y = axis.y * axis.z * (1 - c) + axis.x * s
    Z.z = axis.z * axis.z + (1 - axis.z * axis.z) * c
    Z.w = 0.0
    
    var W = vector_float4()
    W.x = 0.0
    W.y = 0.0
    W.z = 0.0
    W.w = 1.0
    
    let mat = matrix_float4x4(X, Y, Z, W)
    return mat
}

/// Builds a symmetric perspective projection matrix with the supplied aspect ratio,
/// vertical field of view (in radians), and near and far distances
func matrix_float4x4_perspective (aspect: Float, fovy: Float, near: Float, far: Float) -> matrix_float4x4 {
    let yScale: Float = 1 / tan(fovy * 0.5)
    let xScale: Float = yScale / aspect
    let zRange: Float = far - near
    let zScale: Float = -(far + near) / zRange
    let wzScale: Float = -2 * far * near / zRange
    
    let P = vector_float4(xScale, 0, 0, 0)
    let Q = vector_float4(0, yScale, 0, 0)
    let R = vector_float4(0, 0, zScale, -1)
    let S = vector_float4(0, 0, wzScale, 0)
    
    let mat = matrix_float4x4(P, Q, R, S)
    return mat
}

func matrix_float4x4_extract_linear (m: matrix_float4x4) -> matrix_float3x3 {
    let X = vector_float3(m.columns.0.x, m.columns.0.y, m.columns.0.z)
    let Y = vector_float3(m.columns.1.x, m.columns.1.y, m.columns.1.z)
    let Z = vector_float3(m.columns.2.x, m.columns.2.y, m.columns.2.z)
    let l = matrix_float3x3(X, Y, Z)
    return l
}
