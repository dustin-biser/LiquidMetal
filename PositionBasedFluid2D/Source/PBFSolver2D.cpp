//
//  PBFSolver2D.cpp
//  LiquidMetal
//
//  Created by Dustin on 2/4/16.
//  Copyright © 2016 none. All rights reserved.
//

#include "PBFSolver2D.h"

#include <cassert>

#include <iostream>
using namespace std;

void pbfSolver2D (
    struct ParticleData * particleData,
    float dt,
    const vector_float3 * force_ext
) {
    
    assert(particleData);
    assert(force_ext);
    
    const vector_float3 & f_ext = *force_ext;
    
    for(auto i = 0; i < particleData->numParticles; ++i) {
        vector_float3 & vel = particleData->velocity[i];
        vector_float3 & pos = particleData->position[i];
        
        vel += dt * f_ext;
        
        pos +=  dt * vel;
    }
    
}