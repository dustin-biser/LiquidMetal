//
//  ViewController.swift
//  Instancing
//
//  Created by Dustin on 12/30/15.
//  Copyright © 2015 none. All rights reserved.
//

import AppKit
import MetalKit

class MetalViewController: NSViewController {
    
    @IBOutlet weak var mtkView: MetalView!
    
    var metalRenderer : MetalRenderer! = nil
    
    var pbfSimulator2D : PBFSimulator2D! = nil
    
    
    //-----------------------------------------------------------------------------------
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // self will handle rendering the view
        mtkView.delegate = self
        
        pbfSimulator2D = PBFSimulator2D()
        
        metalRenderer = MetalRenderer(
            withMTKView: mtkView,
            numParticles: Int(pbfSimulator2D.particleData.numParticles),
            particleRadius: pbfSimulator2D.particleData.size
        )
        
        
        //-- Add self to Responder Chain so it can handle key and mouse input events.
        // Responder Chain order:
        // MetalView -> ViewController -> Window -> WindowController
        mtkView.window?.initialFirstResponder = mtkView
        mtkView.nextResponder = self
        self.nextResponder = mtkView.window
        
        //-- Add mouse tracking to the MetalView:
        let trackingOptions : NSTrackingAreaOptions = [
            .InVisibleRect, .MouseMoved, .MouseEnteredAndExited, .ActiveInActiveApp
        ]
        mtkView.addTrackingArea(NSTrackingArea(
            rect: mtkView.visibleRect,
            options: trackingOptions,
            owner: self,
            userInfo: nil))
    
    }
    
    //-----------------------------------------------------------------------------------
    override func keyDown(theEvent: NSEvent) {
//        print("keydown event: \(theEvent)")
    }
    
    //-----------------------------------------------------------------------------------
    override func mouseEntered(theEvent: NSEvent) {
//        print("mouse entered view")
    }
    
    //-----------------------------------------------------------------------------------
    override func mouseExited(theEvent: NSEvent) {
//        print("mouse exited view")
    }
    
    //-----------------------------------------------------------------------------------
    override func mouseMoved(theEvent: NSEvent) {
//        print("mouse loc: \(theEvent.locationInWindow)")
    }
    
}


extension MetalViewController : MTKViewDelegate {

    //-----------------------------------------------------------------------------------
    // Called whenever the drawableSize of the view will change
    func mtkView(view: MTKView, drawableSizeWillChange size: CGSize) {
        metalRenderer.reshape(size)
    }

    //-----------------------------------------------------------------------------------
    // Called on the delegate when it is asked to render into the view
    func drawInMTKView(view: MTKView) {
        
        struct DoOnce {
            static var firstRun = true
        }
        
        if DoOnce.firstRun {
            
            pbfSimulator2D.update()
            
            autoreleasepool {
                metalRenderer.render(
                    particleData: &pbfSimulator2D.particleData,
                    grid: &pbfSimulator2D.grid
                )
            }
            
            DoOnce.firstRun = false
        }
    }

}

