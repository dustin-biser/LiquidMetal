//
//  PBFSimulator2D.swift
//  LiquidMetal
//
//  Created by Dustin on 2/4/16.
//  Copyright © 2016 none. All rights reserved.
//

class PBFSimulator2D {
    
    let numParticles : Int = 10 * 10
    let particleRadius : Float = 0.06
    
    var particleData : [ParticleData]
    
    let dt : Float = 0.01
 
    
    //-----------------------------------------------------------------------------------
    init() {
        
        print("numPartices: \(numParticles)")
        
        particleData = [ParticleData](count: numParticles, repeatedValue: ParticleData())
        
        setInitialParticlePositions()
    }
    
    
    //-----------------------------------------------------------------------------------
    private func setInitialParticlePositions() {
        let x_count = Int( sqrtf(Float(numParticles)) )
        let y_count = x_count
        
        let origin = float2(-Float(x_count)/2.0, -Float(y_count)/2.0) * particleRadius
        
        for var j = 0; j < y_count; ++j {
            for var i = 0; i < x_count; ++i {
                var pos = origin
                pos.x += Float(i) * particleRadius
                pos.y += Float(j) * particleRadius
                
                particleData[j*x_count + i].position = float3(pos.x, pos.y, 0.0)
            }
        }
    }
    
    //-----------------------------------------------------------------------------------
    internal func update () {
        
    }
    
}