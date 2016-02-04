//
//  MetalRenderer.swift
//
//  Created by Dustin on 1/23/16.
//  Copyright © 2016 none. All rights reserved.
//

import MetalKit


// Use for tripple buffering generated frames.
private let numInflightCommandBuffers = 3


class MetalRenderer {

    // Use unowned here since mtkView must always be non-nil in order to render.
    unowned var mtkView : MTKView
    
    var device : MTLDevice!                        = nil
    var commandQueue : MTLCommandQueue!            = nil
    var defaultShaderLibrary : MTLLibrary!         = nil
    var pipelineState : MTLRenderPipelineState!    = nil
    var depthStencilState : MTLDepthStencilState!  = nil
    
    var particleMesh : MTKMesh!                    = nil
    
    var instanceBuffer : MTLBuffer!                = nil
    var frameUniformBuffers = [MTLBuffer!](count: numInflightCommandBuffers, repeatedValue: nil)
    var resultBuffer : MTLBuffer!                  = nil
    
    var currentFrame : Int = 0
    
    var numParticles : Int = 0
    
    var inflightSemaphore = dispatch_semaphore_create(numInflightCommandBuffers)
    
    let particleRadius : Float = 0.06
    
//    var angle : Float = 0.0
//    let angleDelta: Float = 0.01
    
    
    //-----------------------------------------------------------------------------------
    init(withMTKView view:MTKView) {
        mtkView = view
        
        self.setupMetal()
        self.setupView()
        
        self.allocateUniformBuffers()
        self.setFrameUniforms()
        
        self.uploadInstanceData()
        
        let vertexDescriptor = self.initVertexDescriptor()
        self.uploadMeshVertexData(vertexDescriptor)
        
        self.preparePipelineState(vertexDescriptor)
        self.prepareDepthStencilState()
    }
    
    //-----------------------------------------------------------------------------------
    private func setupMetal() {
        device = MTLCreateSystemDefaultDevice()
        if device == nil {
            fatalError("Error creating default MTLDevice.")
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
        let scale = Float(particleRadius * 0.5)
        let scaleMatrix = matrix_from_scale(scale, scale, scale)
        
        let modelMatrix = scaleMatrix
        
        // Projection Matrix:
        let width = Float(self.mtkView.bounds.size.width)
        let height = Float(self.mtkView.bounds.size.height)
        let aspect = width / height
        let fovy = Float(50.0) * (Float(M_PI) / Float(180.0))
        let projectionMatrix = matrix_from_perspective_fov_aspectLH(fovy, aspect,
            Float(0.1), Float(100))
        
        let viewMatrix = matrix_from_translation(0.0, 0.0, 5.0)
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
    private func initVertexDescriptor() -> MTLVertexDescriptor {
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
        
        return vertexDescriptor
    }
    
    //-----------------------------------------------------------------------------------
    private func uploadMeshVertexData(vertexDescriptor: MTLVertexDescriptor) {
        guard let assetURL = NSBundle.mainBundle().URLForResource("sphere.obj", withExtension: nil) else {
            fatalError("Unable to locate asset: sphere.obj")
        }
        
        let modelIOVertexDescriptor = MTKModelIOVertexDescriptorFromMetal(vertexDescriptor)
        
        // Mark position attribute data with Position Model IO name type.
        let positionVertexAttribute =
            modelIOVertexDescriptor.attributes[PositionAttribute] as! MDLVertexAttribute
        positionVertexAttribute.name = MDLVertexAttributePosition
        
        // Mark normal attribute data with Normal Model IO name type.
        let normalVertexAttribute =
            modelIOVertexDescriptor.attributes[NormalAttribute] as! MDLVertexAttribute
        normalVertexAttribute.name = MDLVertexAttributeNormal
        
        
        let bufferAllocator = MTKMeshBufferAllocator(device: device)
        
        let asset = MDLAsset(
                URL: assetURL,
                vertexDescriptor: modelIOVertexDescriptor,
                bufferAllocator: bufferAllocator
        )
        
        
        var mtkMeshes = try! MTKMesh.newMeshesFromAsset(asset, device: device, sourceMeshes: nil)
        
        particleMesh = mtkMeshes[0]
    }
    
    //-----------------------------------------------------------------------------------
    private func uploadInstanceData() {
        
        //FIXME: once numParticles exceeds 64^2 = 4096 = 2^12, the particles no longer form a
        // rectangular grid.
        
        let x_count = 70
        let y_count = 70
        numParticles = x_count * y_count
       
        var instanceArray = [InstanceUniforms](
                count: numParticles,
                repeatedValue: InstanceUniforms()
        )
        
        
        let origin = float2(-Float(x_count)/2.0, -Float(y_count)/2.0) * particleRadius
        
        print("numPartices: \(numParticles)")
        print("origin: \(origin)")
        print("particleRadius: \(particleRadius)")
        print("sizeof(Int): \(sizeof(Int))")
        
        for var j = 0; j < y_count; ++j {
            for var i = 0; i < x_count; ++i {
                var pos = origin
                pos.x += Float(i) * particleRadius
                pos.y += Float(j) * particleRadius
                
                instanceArray[j*x_count + i].worldOffset = float4(pos.x, pos.y, 0.0, 0.0)
            }
        }
        
        instanceBuffer = device.newBufferWithBytes(
            instanceArray,
            length: instanceArray.count * strideof(InstanceUniforms),
            options: .CPUCacheModeDefaultCache
        )
        
        print("Buffer bytes: \(instanceBuffer.length)")
        
    }
    
    //-----------------------------------------------------------------------------------
    func reshape(size: CGSize) {
        
    }
    
    //-----------------------------------------------------------------------------------
    private func preparePipelineState(vertexDescriptor: MTLVertexDescriptor) {
        
        guard let vertexFunction = defaultShaderLibrary.newFunctionWithName("vertexFunction")
            else {
                fatalError("Error retrieving vertex function.")
        }
        
        guard let fragmentFunction = defaultShaderLibrary.newFunctionWithName("fragmentFunction")
            else {
                fatalError("Error retrieving fragment function.")
        }
        
        
        //-- Render Pipeline Descriptor:
        let pipelineDescriptor = MTLRenderPipelineDescriptor()
        pipelineDescriptor.label = "Render Pipeline"
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
        renderPassDescriptor.colorAttachments[0].clearColor = MTLClearColor(
                red:   0.3,
                green: 0.3,
                blue:  0.3,
                alpha: 1.0
        )
        renderPassDescriptor.depthAttachment.clearDepth = 1.0
        
        let renderEncoder =
            commandBuffer.renderCommandEncoderWithDescriptor(renderPassDescriptor)
        
        renderEncoder.pushDebugGroup("Particle Mesh")
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
        
        
        for vertexBuffer in particleMesh.vertexBuffers {
            renderEncoder.setVertexBuffer(
                vertexBuffer.buffer,
                offset: vertexBuffer.offset,
                atIndex: VertexBufferIndex
            )
        }
        
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
        
        for subMesh in particleMesh.submeshes {
            renderEncoder.drawIndexedPrimitives(.Triangle,
                indexCount: subMesh.indexCount,
                indexType: subMesh.indexType,
                indexBuffer: subMesh.indexBuffer.buffer,
                indexBufferOffset: subMesh.indexBuffer.offset,
                instanceCount: numParticles
            )
        }
        
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
