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
    
void pbfSolver2D (
    float dt,
    const struct ParticleData * particleData
);
    
#ifdef __cplusplus
}
#endif
