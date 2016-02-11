//
//  PBFSolver2D.cpp
//  LiquidMetal
//
//  Created by Dustin on 2/4/16.
//  Copyright © 2016 none. All rights reserved.
//

#include "PBFSolver2D.h"

#include <cassert>
#include <cfloat>
#include <cmath>

#include <iostream>
#include <vector>
using namespace std;


static vector<vector_float3> predicted_position;

static float h; // Kernel support radius


//---------------------------------------------------------------------------------------
// Function Declarations
//---------------------------------------------------------------------------------------
static void initSolver (
        const ParticleData * particleData
);
static void initPredictedPositions (
        const ParticleData * particleData
);

static void constructUniformGrid (
        Grid * outGrid,
        const vector<vector_float3> & predicted_position,
        float gridCellSize
);


//---------------------------------------------------------------------------------------
void pbfSolver2D (
        ParticleData * particleData,
        float dt,
        const vector_float3 * force_ext,
        Grid * outGrid
) {
    assert(particleData);
    assert(force_ext);
    assert(outGrid);
    
    initSolver(particleData);
    
    const vector_float3 & f_ext = *force_ext;
    
    for(auto i = 0; i < particleData->numParticles; ++i) {
        vector_float3 & vel = particleData->velocity[i];
        vector_float3 & pos = particleData->position[i];
        
        vel += dt * f_ext;
        predicted_position[i] = pos + dt * vel;
        
        
        // TODO: Remove this after testing:
        pos = predicted_position[i];
    }
    
    constructUniformGrid(outGrid, predicted_position, h);
}

//---------------------------------------------------------------------------------------
static void initSolver(
        const ParticleData * particleData
) {
    // Arbitrarily setting kernel radius to 5 times particle radius.
    // TODO: figure out how h relates to rest density rho_0.
    h = particleData->size * 5.0f;
    
    initPredictedPositions(particleData);
}

//---------------------------------------------------------------------------------------
static void initPredictedPositions(
        const ParticleData * particleData
) {
    // Number of predicted positions should match number of particles.
    // If the number of particles in particleData changed since last solver run,
    // then update predicted_position array to match number of current particles.
    unsigned long numParticles = particleData->numParticles;
    if(numParticles != predicted_position.size()) {
        predicted_position.resize(numParticles, vector_float3(0.0));
    }
}

//---------------------------------------------------------------------------------------
// Modifies inputs a and b equally so that:
// (a.x - b.x) / divisor is an integer, and
// (a.y - b.y) / divisor is an integer.
static void expandToMultipleOf (
        vector_float3 & a,
        vector_float3 & b,
        float divisor
) {
    float x = (a.x - b.x) / divisor;
    float margin = (ceil(x) - x) * 0.5f;
    a.x += margin;
    b.x -= margin;
    
    float y = (a.y - b.y) / divisor;
    margin = (ceil(y) - y) * 0.5f;
    a.y += margin;
    b.y -= margin;
}

//---------------------------------------------------------------------------------------
// Construct uniform grid from predicted particle positions.
static void constructUniformGrid (
        Grid * outGrid,
        const vector<vector_float3> & predicted_position,
        float gridCellSize
) {
    vector_float3 min = vector_float3(FLT_MAX);
    vector_float3 max = vector_float3(-FLT_MAX);
    
    for(const vector_float3 & pos : predicted_position) {
        min.x = (pos.x < min.x) ? pos.x : min.x;
        min.y = (pos.y < min.y) ? pos.y : min.y;
        min.z = (pos.z < min.z) ? pos.z : min.z;
        
        max.x = (pos.x > max.x) ? pos.x : max.x;
        max.y = (pos.y > max.y) ? pos.y : max.y;
        max.z = (pos.z > max.z) ? pos.z : max.z;
    }
    
    expandToMultipleOf(max, min, gridCellSize);
    
    outGrid->min = min;
    outGrid->max = max;
}
