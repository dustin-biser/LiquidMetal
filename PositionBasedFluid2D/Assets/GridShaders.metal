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


// Input to the vertex shader.
struct VertexInput {
    float3 position [[ attribute(PositionAttribute) ]];
};


//---------------------------------------------------------------------------------------
vertex float4 gridVertexFunction (
        VertexInput v_in [[ stage_in ]],
        constant FrameUniforms & uniforms [[ buffer(FrameUniformBufferIndex) ]]
) {
    float4 pos = uniforms.modelMatrix * float4(v_in.position, 1.0);
    pos = uniforms.viewMatrix * pos;
    
    // Return clip space coordinate
    return uniforms.projectionMatrix * pos;
}


//---------------------------------------------------------------------------------------
fragment half4 gridFragmentFunction ()
{
    return half4(1.0, 1.0, 1.0, 1.0);
}

