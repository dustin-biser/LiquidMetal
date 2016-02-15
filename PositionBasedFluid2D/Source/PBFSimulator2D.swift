//
//  PBFSimulator2D.swift
//  LiquidMetal
//
//  Created by Dustin on 2/4/16.
//  Copyright © 2016 none. All rights reserved.
//

class PBFSimulator2D {
    
    // Class instance will retain ownership of particle attribute data
    var positions  : [vector_float3]
    var velocities : [vector_float3]
    
    var particleData : ParticleData
    var grid : Grid
    
    let numParticles : Int = 10*10
    let particleSize : Float = 0.2
    let dt : Float = 0.01
    var gravity = vector_float3(0.0, -9.81, 0.0)
 
    
    //-----------------------------------------------------------------------------------
    init() {
        particleData = ParticleData()
        grid = Grid()
        
        particleData.numParticles = UInt(numParticles)
        particleData.size = particleSize
        
        // Positions:
        do {
            positions = [vector_float3] (
                    count: numParticles,
                    repeatedValue: vector_float3(0.0)
            )
            particleData.position = UnsafeMutablePointer<vector_float3>(positions)
        }
        
        
        // Velocities:
        do {
            velocities = [vector_float3] (
                    count: numParticles,
                    repeatedValue: vector_float3(0.0)
            )
            particleData.velocity = UnsafeMutablePointer<vector_float3>(velocities)
        }
        
        setInitialParticlePositions()
    }
    
    
    //-----------------------------------------------------------------------------------
    private func setInitialParticlePositions() {
        let x_count = Int( sqrtf(Float(particleData.numParticles)) )
        let y_count = x_count
        
        var origin = float2(-Float(x_count)/2.0, -Float(y_count)/2.0) * particleSize
        origin += float2(-Float(x_count)/2.0, Float(y_count)/3.0)*particleSize
        
        for var j = 0; j < y_count; ++j {
            for var i = 0; i < x_count; ++i {
                var pos = origin
                pos.x += Float(i) * particleSize
                pos.y += Float(j) * particleSize
                
                particleData.position[j*x_count + i] = float3(pos.x, pos.y, 0.0)
            }
        }
    }
    
    //-----------------------------------------------------------------------------------
    internal func update () {
        pbfSolver2D(&particleData, dt, &gravity, &grid)
    }
    
}