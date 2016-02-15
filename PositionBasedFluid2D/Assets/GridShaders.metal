//
//  GridShaders.metal
//  LiquidMetal
//
//  Created by Dustin on 2/10/16.
//  Copyright © 2016 none. All rights reserved.
//

#include <metal_stdlib>
using namespace metal;

#include <simd/simd.h>
#include "ShaderUniforms.h"
#include "ShaderResourceIndices.h"


struct VertexInput {
    float3 position [[ attribute(PositionAttribute) ]];
};

struct VertexOutput {
    float4 position [[ position ]];
    float pointSize [[ point_size ]];
};


//---------------------------------------------------------------------------------------
vertex VertexOutput gridVertexFunction (
        VertexInput v_in [[ stage_in ]],
        constant FrameUniforms & uniforms [[ buffer(FrameUniformBufferIndex) ]]
) {
    float4 pos = uniforms.viewMatrix * float4(v_in.position, 1.0);
    
    // Return clip-space coordinate
    pos = uniforms.projectionMatrix * pos;
    
    VertexOutput vOut;
    vOut.position = pos;
    vOut.pointSize = 2.0;
    
    return vOut;
}


//---------------------------------------------------------------------------------------
fragment half4 gridFragmentFunction (
        VertexOutput f_in [[ stage_in ]]
){
    return half4(1.0, 1.0, 1.0, 1.0);
}

