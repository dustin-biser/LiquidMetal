//
//  PBFSolver2D.h
//  LiquidMetal
//
//  Created by Dustin on 2/4/16.
//  Copyright © 2016 none. All rights reserved.
//

#pragma once

/*
   Declared functions require a C Interface in order to be called from Swift.
 */

#ifdef __cplusplus
extern "C" {
#endif
    
#include "ParticleData.h"
#include "Grid.h"
    
///Position Based Fluid solver for 2D simulation.
void pbfSolver2D (
    struct ParticleData * particleData,  /// Particle data, positions and velocities
    float dt,                            /// Time step
    const vector_float3 * force_ext,     /// External forces
    struct Grid * outGrid                /// Returned Grid
);
    
#ifdef __cplusplus
}
#endif
