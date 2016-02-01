//
//  MetalRenderer.swift
//
//  Created by Dustin on 1/23/16.
//  Copyright © 2016 none. All rights reserved.
//

import MetalKit


private let kWidth  : Float32 = 0.5;
private let kHeight : Float32 = 0.5;
private let kDepth  : Float32 = 0.5;

private let CubeVertexData : [Float32] = [
//           Postions                  Normals
     kWidth, -kHeight,  kDepth,     0.0, -1.0,  0.0,
    -kWidth, -kHeight,  kDepth,     0.0, -1.0,  0.0,
    -kWidth, -kHeight, -kDepth,     0.0, -1.0,  0.0,
     kWidth, -kHeight, -kDepth,     0.0, -1.0,  0.0,
     kWidth, -kHeight,  kDepth,     0.0, -1.0,  0.0,
    -kWidth, -kHeight, -kDepth,     0.0, -1.0,  0.0,
    
     kWidth,  kHeight,  kDepth,     1.0,  0.0,  0.0,
     kWidth, -kHeight,  kDepth,     1.0,  0.0,  0.0,
     kWidth, -kHeight, -kDepth,     1.0,  0.0,  0.0,
     kWidth,  kHeight, -kDepth,     1.0,  0.0,  0.0,
     kWidth,  kHeight,  kDepth,     1.0,  0.0,  0.0,
     kWidth, -kHeight, -kDepth,     1.0,  0.0,  0.0,
    
    -kWidth,  kHeight,  kDepth,     0.0,  1.0,  0.0,
     kWidth,  kHeight,  kDepth,     0.0,  1.0,  0.0,
     kWidth,  kHeight, -kDepth,     0.0,  1.0,  0.0,
    -kWidth,  kHeight, -kDepth,     0.0,  1.0,  0.0,
    -kWidth,  kHeight,  kDepth,     0.0,  1.0,  0.0,
     kWidth,  kHeight, -kDepth,     0.0,  1.0,  0.0,
    
    -kWidth, -kHeight,  kDepth,    -1.0,  0.0,  0.0,
    -kWidth,  kHeight,  kDepth,    -1.0,  0.0,  0.0,
    -kWidth,  kHeight, -kDepth,    -1.0,  0.0,  0.0,
    -kWidth, -kHeight, -kDepth,    -1.0,  0.0,  0.0,
    -kWidth, -kHeight,  kDepth,    -1.0,  0.0,  0.0,
    -kWidth,  kHeight, -kDepth,    -1.0,  0.0,  0.0,
    
     kWidth,  kHeight,  kDepth,     0.0,  0.0,  1.0,
    -kWidth,  kHeight,  kDepth,     0.0,  0.0,  1.0,
    -kWidth, -kHeight,  kDepth,     0.0,  0.0,  1.0,
    -kWidth, -kHeight,  kDepth,     0.0,  0.0,  1.0,
     kWidth, -kHeight,  kDepth,     0.0,  0.0,  1.0,
     kWidth,  kHeight,  kDepth,     0.0,  0.0,  1.0,
    
     kWidth, -kHeight, -kDepth,     0.0,  0.0, -1.0,
    -kWidth, -kHeight, -kDepth,     0.0,  0.0, -1.0,
    -kWidth,  kHeight, -kDepth,     0.0,  0.0, -1.0,
     kWidth,  kHeight, -kDepth,     0.0,  0.0, -1.0,
     kWidth, -kHeight, -kDepth,     0.0,  0.0, -1.0,
    -kWidth,  kHeight, -kDepth,     0.0,  0.0, -1.0
]

private let numInflightCommandBuffers = 3



class MetalRenderer {

    // Use unowned here since mtkView must always be non-nil in order to render.
    unowned var mtkView : MTKView
    
    var device : MTLDevice!                        = nil
    var commandQueue : MTLCommandQueue!            = nil
    var defaultShaderLibrary : MTLLibrary!         = nil
    var pipelineState : MTLRenderPipelineState!    = nil
    var depthStencilState : MTLDepthStencilState!  = nil
    
    
    var inflightSemaphore = dispatch_semaphore_create(numInflightCommandBuffers)
    
    var vertexBuffer : MTLBuffer!                  = nil
    var instanceBuffer : MTLBuffer!               = nil
    var frameUniformBuffers = [MTLBuffer!](count: numInflightCommandBuffers, repeatedValue: nil)
    var currentFrame : Int = 0
    
    var rotationAngle : Float = 0.0
    let rotationDelta : Float = 0.01
    
    var numCubeInstances : Int = 4
    
    
    //-----------------------------------------------------------------------------------
    init(withMTKView view:MTKView) {
        mtkView = view
        
        self.setupMetal()
        self.setupView()
        
        self.prepareDepthStencilState()
        self.preparePipelineState()
        
        self.allocateUniformBuffers()
        self.setFrameUniforms()
        
        self.uploadInstanceData()
        self.uploadVertexBufferData()
    }
    
    //-----------------------------------------------------------------------------------
    private func setupMetal() {
        device = MTLCreateSystemDefaultDevice()
        if device == nil {
            fatalError("Error creating default MTLDevice.")
        } else {
            print("Metal Device: \(device)")
        }
        
        commandQueue = device.newCommandQueue()
        
        defaultShaderLibrary = device.newDefaultLibrary()
    }

    //-----------------------------------------------------------------------------------
    private func setupView() {
        mtkView.device = device
        mtkView.sampleCount = 4
        mtkView.colorPixelFormat = MTLPixelFormat.BGRA8Unorm
        mtkView.depthStencilPixelFormat = MTLPixelFormat.Depth32Float_Stencil8
        mtkView.preferredFramesPerSecond = 60
        mtkView.framebufferOnly = true
    }
    
    //-----------------------------------------------------------------------------------
    private func allocateUniformBuffers() {
        for index in frameUniformBuffers.indices {
            frameUniformBuffers[index] = device.newBufferWithLength (
                    strideof(FrameUniforms),
                    options: .CPUCacheModeDefaultCache
            )
        }
    }
    
    //-----------------------------------------------------------------------------------
    private func setFrameUniforms() {
        rotationAngle += rotationDelta
        var modelMatrix = matrix_from_rotation(rotationAngle, 1, 1, 0)
        modelMatrix = matrix_multiply(matrix_from_translation(0.0, 0.0, 2.0), modelMatrix)
        
        // Projection Matrix:
        let width = Float(self.mtkView.bounds.size.width)
        let height = Float(self.mtkView.bounds.size.height)
        let aspect = width / height
        let fovy = Float(65.0) * (Float(M_PI) / Float(180.0))
        let projectionMatrix = matrix_from_perspective_fov_aspectLH(fovy, aspect,
            Float(0.1), Float(100))
        
        let viewMatrix = matrix_from_translation(0.0, 0.0, 2.0)
        var modelView = matrix_multiply(viewMatrix, modelMatrix)
        let normalMatrix = sub_matrix_float3x3(&modelView)
        
        var frameUniforms = FrameUniforms()
        frameUniforms.modelMatrix = modelMatrix
        frameUniforms.viewMatrix = viewMatrix
        frameUniforms.projectionMatrix = projectionMatrix
        frameUniforms.normalMatrix = normalMatrix
        
        memcpy(frameUniformBuffers[currentFrame].contents(), &frameUniforms,
            strideof(FrameUniforms))
        
        currentFrame = (currentFrame + 1) % frameUniformBuffers.count
    }
    
    //-----------------------------------------------------------------------------------
    private func uploadVertexBufferData() {
        let numBytes = CubeVertexData.count * sizeof(Float32)
        vertexBuffer = device.newBufferWithBytes (
            CubeVertexData,
            length: numBytes,
            options: .OptionCPUCacheModeWriteCombined
        )
        vertexBuffer.label = "CubeVertexData"
    }
    
    //-----------------------------------------------------------------------------------
    private func uploadInstanceData() {
        var instanceData0 = InstanceUniforms()
        instanceData0.modelMatrix = matrix_from_translation(-1.0, -1.0, 0.0)
        
        var instanceData1 = InstanceUniforms()
        instanceData1.modelMatrix = matrix_from_translation(1.0, -1.0, 0.0)
        
        var instanceData2 = InstanceUniforms()
        instanceData2.modelMatrix = matrix_from_translation(-1.0, 1.0, 0.0)
        
        var instanceData3 = InstanceUniforms()
        instanceData3.modelMatrix = matrix_from_translation(1.0, 1.0, 0.0)
        
        
        let instanceData = [instanceData0, instanceData1, instanceData2, instanceData3]
        
        instanceBuffer = device.newBufferWithBytes(
            instanceData,
            length: strideof(InstanceUniforms) * numCubeInstances,
            options: .CPUCacheModeWriteCombined
        )
        
    }
    
    //-----------------------------------------------------------------------------------
    func reshape(size: CGSize) {
        
    }
    
    //-----------------------------------------------------------------------------------
    private func preparePipelineState() {
        
        guard let vertexFunction = defaultShaderLibrary.newFunctionWithName("vertexFunction")
            else {
                fatalError("Error retrieving vertex function.")
        }
        
        guard let fragmentFunction = defaultShaderLibrary.newFunctionWithName("fragmentFunction")
            else {
                fatalError("Error retrieving fragment function.")
        }
    
        // Create a vertex descriptor
        let vertexDescriptor = MTLVertexDescriptor()
        
        //-- Vertex Positions, attribute description:
        vertexDescriptor.attributes[PositionAttribute].format = MTLVertexFormat.Float3
        vertexDescriptor.attributes[PositionAttribute].offset = 0
        vertexDescriptor.attributes[PositionAttribute].bufferIndex = VertexBufferIndex
        
        //-- Vertex Normals, attribute description:
        vertexDescriptor.attributes[NormalAttribute].format = MTLVertexFormat.Float3
        vertexDescriptor.attributes[NormalAttribute].offset = sizeof(Float32) * 3
        vertexDescriptor.attributes[NormalAttribute].bufferIndex = VertexBufferIndex
        
        //-- VertexBuffer layout description:
        vertexDescriptor.layouts[VertexBufferIndex].stride = sizeof(Float32) * 6
        vertexDescriptor.layouts[VertexBufferIndex].stepRate = 1
        vertexDescriptor.layouts[VertexBufferIndex].stepFunction = .PerVertex
        
        
        //-- Render Pipeline Descriptor:
        let pipelineDescriptor = MTLRenderPipelineDescriptor()
        pipelineDescriptor.label = "Forward Render Pipeline"
        pipelineDescriptor.vertexFunction = vertexFunction
        pipelineDescriptor.fragmentFunction = fragmentFunction
        pipelineDescriptor.vertexDescriptor = vertexDescriptor
        pipelineDescriptor.sampleCount = mtkView.sampleCount
        pipelineDescriptor.colorAttachments[0].pixelFormat = mtkView.colorPixelFormat
        pipelineDescriptor.depthAttachmentPixelFormat = mtkView.depthStencilPixelFormat
        pipelineDescriptor.stencilAttachmentPixelFormat = mtkView.depthStencilPixelFormat
        
        // Create our render pipeline state for reuse
        pipelineState = try! device.newRenderPipelineStateWithDescriptor(pipelineDescriptor)
    }
    
    //-----------------------------------------------------------------------------------
    private func prepareDepthStencilState() {
        let depthStencilDecriptor = MTLDepthStencilDescriptor()
        depthStencilDecriptor.depthCompareFunction = MTLCompareFunction.Less
        depthStencilDecriptor.depthWriteEnabled = true
        depthStencilState = device.newDepthStencilStateWithDescriptor(depthStencilDecriptor)
    }
    
    //-----------------------------------------------------------------------------------
    private func encodeRenderCommandsInto (commandBuffer: MTLCommandBuffer) {
        // Get the current MTLRenderPassDescriptor and set it's color and depth
        // clear values:
        let renderPassDescriptor = mtkView.currentRenderPassDescriptor!
        renderPassDescriptor.colorAttachments[0].clearColor =
                MTLClearColor(red: 0.3, green: 0.3, blue: 0.3, alpha: 1.0)
        renderPassDescriptor.depthAttachment.clearDepth = 1.0
        
        let renderEncoder =
            commandBuffer.renderCommandEncoderWithDescriptor(renderPassDescriptor)
        
        renderEncoder.pushDebugGroup("Cube")
        renderEncoder.setViewport(
            MTLViewport(
                originX: 0,
                originY: 0,
                width: Double(mtkView.drawableSize.width),
                height: Double(mtkView.drawableSize.height),
                znear: 0,
                zfar: 1)
        )
        renderEncoder.setFrontFacingWinding(MTLWinding.Clockwise)
        renderEncoder.setCullMode(MTLCullMode.Back)
        renderEncoder.setDepthStencilState(depthStencilState)
        
        renderEncoder.setRenderPipelineState(pipelineState)
        
        renderEncoder.setVertexBuffer(
                vertexBuffer,
                offset: 0,
                atIndex: VertexBufferIndex
        )
        
        renderEncoder.setVertexBuffer(
                frameUniformBuffers[currentFrame],
                offset: 0,
                atIndex: FrameUniformBufferIndex
        )
        
        renderEncoder.setVertexBuffer(
                instanceBuffer,
                offset: 0,
                atIndex: InstanceUniformBufferIndex
        )
        
        renderEncoder.drawPrimitives( .Triangle,
            vertexStart: 0, vertexCount: 36, instanceCount: numCubeInstances)
        
        renderEncoder.endEncoding()
        renderEncoder.popDebugGroup()
    }
    
    //-----------------------------------------------------------------------------------
    /// Main render method
    func render() {
        for var i = 0; i < numInflightCommandBuffers; ++i {
            // Allow the renderer to preflight frames on the CPU (using a semapore as
            // a guard) and commit them to the GPU.  This semaphore will get signaled
            // once the GPU completes a frame's work via addCompletedHandler callback
            // below, signifying the CPU can go ahead and prepare another frame.
            dispatch_semaphore_wait(inflightSemaphore, DISPATCH_TIME_FOREVER);
            
            setFrameUniforms()
            
            let commandBuffer = commandQueue.commandBuffer()
            
            encodeRenderCommandsInto(commandBuffer)
            
            commandBuffer.presentDrawable(mtkView.currentDrawable!)
            
            
            // Once GPU has completed executing the commands wihin this buffer, signal
            // the semaphore and allow the CPU to proceed in constructing the next frame.
            commandBuffer.addCompletedHandler() { mtlCommandbuffer in
                dispatch_semaphore_signal(self.inflightSemaphore)
            }
            
            // Push command buffer to GPU for execution.
            commandBuffer.commit()
        }
    }
    
}
