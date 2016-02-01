//
//  MatrixTransforms.h
//  MetalSwift
//
//  Created by Dustin on 1/6/16.
//  Copyright © 2016 none. All rights reserved.
//

#pragma once

#include <simd/matrix_types.h>

matrix_float4x4 matrix_from_perspective_fov_aspectLH (
        const float fovY,
        const float aspect,
        const float nearZ,
        const float farZ
);

matrix_float4x4 matrix_from_translation (
        float x,
        float y,
        float z
);

matrix_float4x4 matrix_from_rotation (
        float radians,
        float x,
        float y,
        float z
);

matrix_float3x3 sub_matrix_float3x3 (
        const matrix_float4x4 * m
);
