//
//  ParticleGrid.h
//  LiquidMetal
//
//  Created by Dustin on 2/10/16.
//  Copyright © 2016 none. All rights reserved.
//

#pragma once

#include <simd/vector_types.h>
    
struct Grid {
    // Minimum and maximum coordinates of grid.
    vector_float3 min;
    vector_float3 max;
    
    float cellSize;
};

struct GridCell {
    vector_float3 * particlePosition;
    unsigned long numParticles;
};
    
