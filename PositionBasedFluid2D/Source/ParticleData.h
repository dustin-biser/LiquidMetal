//
//  ParticleData.h
//  LiquidMetal
//
//  Created by Dustin on 2/4/16.
//  Copyright © 2016 none. All rights reserved.
//

#pragma once

#include <simd/vector_types.h>

// Store particle attribute data in aligned arrays.
struct ParticleData {
    vector_float3 * position;      // position at current time step
    vector_float3 * position_prev; // position at previous time step
    vector_float3 * velocity;      // velocity at current time step
    
    unsigned long numParticles;
    
    // Particle radius size.
    float size;
};
