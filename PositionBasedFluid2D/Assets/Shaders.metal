//
//  shaders.metal
//  MetalDemo
//
//  Created by Dustin on 12/27/15.
//  Copyright © 2015 none. All rights reserved.
//

#include <metal_stdlib>
#include <simd/simd.h>
#include "ShaderUniforms.h"
#include "ShaderResourceIndices.h"

using namespace metal;

// Variables in constant address space:
constant float3 light_position = float3(0.0, 0.0, -1.0);
constant half3 diffuse = half3(0.4, 0.4, 0.7);


// Input to the vertex shader.
struct VertexInput {
    float3 position [[ attribute(PositionAttribute) ]];
    float3 normal   [[ attribute(NormalAttribute) ]];
};

// Output from Vertex shader.
struct VertexOutput {
    float4 position [[position]];
    float3 eye_position; // Vertex position in eye-space.
    float3 eye_normal;   // Vertex normal in eye-space.
};


//---------------------------------------------------------------------------------------
// Vertex Function
vertex VertexOutput vertexFunction (
        VertexInput v_in [[ stage_in ]],
        device InstanceUniforms * instanceUniforms [[ buffer(InstanceUniformBufferIndex) ]],
        constant FrameUniforms & frameUniforms [[ buffer(FrameUniformBufferIndex) ]],
        uint iid [[ instance_id ]]
) {
    VertexOutput vOut;
    
    float4 pWorld = frameUniforms.modelMatrix * float4(v_in.position, 1.0);
    pWorld += instanceUniforms[iid].worldOffset;
    float4 pEye = frameUniforms.viewMatrix * pWorld;
    
    vOut.eye_position = pEye.xyz;
    vOut.position = frameUniforms.projectionMatrix * pEye;
    vOut.eye_normal = normalize(frameUniforms.normalMatrix * v_in.normal);
    
    return vOut;
}


//---------------------------------------------------------------------------------------
// Fragment Function
fragment half4 fragmentFunction (
        VertexOutput f_in [[ stage_in ]]
) {
    float3 l = normalize(light_position - f_in.eye_position);
    float n_dot_l = dot(f_in.eye_normal.rgb, l);
    n_dot_l = fmax(0.0, n_dot_l);
    
//    float r = clamp(distance(light_position, f_in.eye_position), 0.4, 1.2);
//    float fallOff = 1.0/r;
    
    return half4(diffuse * n_dot_l, 1.0);
}