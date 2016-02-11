//
//  BridgingHeader.h
//  MetalSwift
//
//  Created by Dustin on 12/31/15.
//  Copyright © 2015 none. All rights reserved.
//

/**
    Headers to C declarations to make available to Swift.
 
    C variable and function definitions must be placed in an implementation file to be
    compiled with the target, rather than included here.
 */
 

#import <semaphore.h>

#import "MatrixTransforms.h"
#import "ShaderResourceIndices.h"
#import "ShaderUniforms.h"
#import "PBFSolver2D.h"
#import "ParticleData.h"
#import "Grid.h"
