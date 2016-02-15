//
//  MetalRenderer.swift
//
//  Created by Dustin on 1/23/16.
//  Copyright © 2016 none. All rights reserved.
//

import MetalKit


// Use for tripple buffering generated frames.
private let numInflightCommandBuffers = 10

private let desiredFramesPerSecond = 60


class MetalRenderer {

    // Use unowned here since mtkView must always be non-nil in order to render.
    unowned var mtkView : MTKView
    
    var device : MTLDevice! = nil
    var commandQueue : MTLCommandQueue! = nil
    var defaultShaderLibrary : MTLLibrary! = nil
    
    var depthStencilState_depthTestOn : MTLDepthStencilState!  = nil
    var depthStencilState_depthTestOff : MTLDepthStencilState!  = nil
    
    var instanceBuffer : MTLBuffer! = nil
    var frameUniformBuffers = [MTLBuffer!](count: numInflightCommandBuffers, repeatedValue: nil)
    
    var currentFrame : Int = 0
    
    var inflightSemaphore = dispatch_semaphore_create(numInflightCommandBuffers)
    
    
    //-- Particle Related
    var pipelineState_particles : MTLRenderPipelineState!  = nil
    let numParticles : Int
    let particleRadius : Float
    var particleMesh : MTKMesh! = nil
    
    //-- Grid Related
    var pipelineState_grid : MTLRenderPipelineState!  = nil
    var vertexBuffer_grid : MTLBuffer! = nil
    var numGridVertices : Int = 0
    
    
    //-----------------------------------------------------------------------------------
    init (
            withMTKView view : MTKView,
            numParticles : Int,
            particleRadius : Float
    ) {
        mtkView = view
        self.numParticles = numParticles
        self.particleRadius = particleRadius
        
        self.setupMetal()
        self.setupView()
        
        self.allocateUniformBuffers()
        self.allocateInstanceData()
        self.allocateVertexBufferForGrid()
        
        let vertexDescriptor_particles = self.initVertexDescriptorForParticles()
        self.uploadMeshVertexData(vertexDescriptor_particles)
        
        self.prepareParticlePipelineState(vertexDescriptor_particles)
        
        self.prepareGridPipelineState()
        
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
        mtkView.sampleCount = 1
        mtkView.colorPixelFormat = MTLPixelFormat.BGRA8Unorm_sRGB
        mtkView.depthStencilPixelFormat = MTLPixelFormat.Depth32Float_Stencil8
        mtkView.preferredFramesPerSecond = desiredFramesPerSecond
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
    private func allocateInstanceData() {
        instanceBuffer = device.newBufferWithLength (
            numParticles * strideof(InstanceUniforms),
            options: .CPUCacheModeDefaultCache
        )
    }
    
    //-----------------------------------------------------------------------------------
    private func allocateVertexBufferForGrid() {
        
        let maxGridVertices = numParticles * 4
        let bytesPerVec3 = sizeof(Float) * 3
        
        // Set an upper bound on the number of grid cells
        vertexBuffer_grid = device.newBufferWithLength (
            maxGridVertices * bytesPerVec3,
            options: .CPUCacheModeDefaultCache
        )
        
    }
    
    //-----------------------------------------------------------------------------------
    private func setPerFrameData (inout particleData: ParticleData) {
        
        uploadParticleDataToInstanceBuffer(&particleData)
        
        updateFrameUniformData()
    }
    
    //-----------------------------------------------------------------------------------
    private func uploadParticleDataToInstanceBuffer (inout particleData: ParticleData) {
        let numBytes = strideof(vector_float3) * Int(particleData.numParticles)
        memcpy(instanceBuffer.contents(), particleData.position, numBytes)
    }
    
    
    //-----------------------------------------------------------------------------------
    private func updateFrameUniformData() {
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
    }
    
    //-----------------------------------------------------------------------------------
    private func initVertexDescriptorForParticles() -> MTLVertexDescriptor {
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
        guard let assetURL = NSBundle.mainBundle().URLForResource("sphere_lowest_res.obj", withExtension: nil) else {
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
    func reshape(size: CGSize) {
        
    }
    
    //-----------------------------------------------------------------------------------
    private func prepareParticlePipelineState(vertexDescriptor: MTLVertexDescriptor) {
        
        guard let vertexFunction =
            defaultShaderLibrary.newFunctionWithName("particleVertexFunction")
            else {
                fatalError("Error retrieving vertex function.")
        }
        
        guard let fragmentFunction =
            defaultShaderLibrary.newFunctionWithName("particleFragmentFunction")
            else {
                fatalError("Error retrieving fragment function.")
        }
        
        
        //-- Render Pipeline Descriptor:
        let pipelineDescriptor = MTLRenderPipelineDescriptor()
        pipelineDescriptor.vertexFunction = vertexFunction
        pipelineDescriptor.fragmentFunction = fragmentFunction
        pipelineDescriptor.vertexDescriptor = vertexDescriptor
        pipelineDescriptor.sampleCount = mtkView.sampleCount
        pipelineDescriptor.colorAttachments[0].pixelFormat = mtkView.colorPixelFormat
        pipelineDescriptor.depthAttachmentPixelFormat = mtkView.depthStencilPixelFormat
        pipelineDescriptor.stencilAttachmentPixelFormat = mtkView.depthStencilPixelFormat
        
        // Create our render pipeline state for reuse
        pipelineState_particles = try! device.newRenderPipelineStateWithDescriptor(pipelineDescriptor)
    }
    
    //-----------------------------------------------------------------------------------
    private func prepareGridPipelineState() {
        
        // Create a vertex descriptor
        let vertexDescriptor = MTLVertexDescriptor()
        
        //-- Vertex Positions:
        vertexDescriptor.attributes[PositionAttribute].format = MTLVertexFormat.Float3
        vertexDescriptor.attributes[PositionAttribute].offset = 0
        vertexDescriptor.attributes[PositionAttribute].bufferIndex = VertexBufferIndex
        
        //-- VertexBuffer layout description:
        vertexDescriptor.layouts[VertexBufferIndex].stride = sizeof(Float32) * 3
        vertexDescriptor.layouts[VertexBufferIndex].stepRate = 1
        vertexDescriptor.layouts[VertexBufferIndex].stepFunction = .PerVertex
        
        
        guard let vertexFunction =
            defaultShaderLibrary.newFunctionWithName("gridVertexFunction")
        else {
            fatalError("Error retrieving vertex function.")
        }
        
        guard let fragmentFunction =
            defaultShaderLibrary.newFunctionWithName("gridFragmentFunction")
        else {
            fatalError("Error retrieving fragment function.")
        }
        
        
        //-- Render Pipeline Descriptor:
        let pipelineDescriptor = MTLRenderPipelineDescriptor()
        pipelineDescriptor.vertexFunction = vertexFunction
        pipelineDescriptor.fragmentFunction = fragmentFunction
        pipelineDescriptor.vertexDescriptor = vertexDescriptor
        pipelineDescriptor.sampleCount = mtkView.sampleCount
        pipelineDescriptor.colorAttachments[0].pixelFormat = mtkView.colorPixelFormat
        pipelineDescriptor.depthAttachmentPixelFormat = mtkView.depthStencilPixelFormat
        pipelineDescriptor.stencilAttachmentPixelFormat = mtkView.depthStencilPixelFormat
        
        // Create our render pipeline state for reuse
        pipelineState_grid = try! device.newRenderPipelineStateWithDescriptor(pipelineDescriptor)
    }
    
    //-----------------------------------------------------------------------------------
    private func prepareDepthStencilState() {
        // Depth Testing ON:
        do {
            let depthStencilDecriptor = MTLDepthStencilDescriptor()
            depthStencilDecriptor.depthCompareFunction = MTLCompareFunction.Less
            depthStencilDecriptor.depthWriteEnabled = true
            depthStencilState_depthTestOn = device.newDepthStencilStateWithDescriptor(depthStencilDecriptor)
        }
        
        // Depth Testing OFF:
        do {
            let depthStencilDecriptor = MTLDepthStencilDescriptor()
            depthStencilDecriptor.depthCompareFunction = MTLCompareFunction.Always
            depthStencilDecriptor.depthWriteEnabled = false
            depthStencilState_depthTestOff = device.newDepthStencilStateWithDescriptor(depthStencilDecriptor)
        }
    }
    
    //-----------------------------------------------------------------------------------
    private func uploadGridVertexData(inout grid: Grid) {
        let max = grid.max
        let min = grid.min
        let cellSize = grid.cellSize
        
        
        let numHorizontalCells = Int( round((max.x - min.x) / cellSize) + 1 )
        let numVerticalCells = Int( round((max.y - min.y) / cellSize) + 1)
        
        numGridVertices = Int(numHorizontalCells * numVerticalCells)
        
        
        var gridVertices = [Float32](
                count: numGridVertices * 3,
                repeatedValue: 0.0
        )
        
        for j in 0 ..< numVerticalCells {
            for i in 0 ..< numHorizontalCells {
                let pos = min + vector_float3(Float(i), Float(j), 0.0) * cellSize
                gridVertices[j*(numHorizontalCells*3) + i*3 + 0] = pos.x
                gridVertices[j*(numHorizontalCells*3) + i*3 + 1] = pos.y
                gridVertices[j*(numHorizontalCells*3) + i*3 + 2] = 0.0
            }
        }
        
        let numBytes = gridVertices.count * sizeof(Float32)
        memcpy(vertexBuffer_grid.contents(), gridVertices, numBytes)
    }
    
    //-----------------------------------------------------------------------------------
    private func encodeRenderCommandsForParticles (commandBuffer: MTLCommandBuffer) {
        // Get the current MTLRenderPassDescriptor and set it's color and depth
        // clear values:
        let renderPassDescriptor = mtkView.currentRenderPassDescriptor!
        
        renderPassDescriptor.colorAttachments[0].loadAction = MTLLoadAction.Clear
        renderPassDescriptor.colorAttachments[0].clearColor = MTLClearColor (
                red:   0.08,
                green: 0.08,
                blue:  0.08,
                alpha: 1.0
        )
        
        renderPassDescriptor.depthAttachment.loadAction = MTLLoadAction.Clear
        renderPassDescriptor.depthAttachment.clearDepth = 1.0
        
        let renderEncoder =
            commandBuffer.renderCommandEncoderWithDescriptor(renderPassDescriptor)
        
        renderEncoder.pushDebugGroup("Particle Rendering Pass")
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
        renderEncoder.setDepthStencilState(depthStencilState_depthTestOn)
        
        renderEncoder.setRenderPipelineState(pipelineState_particles)
        
        
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
    private func encodeRenderCommandsForGrid (commandBuffer: MTLCommandBuffer) {
        // Get the current MTLRenderPassDescriptor and set it's color and depth
        // clear values:
        let renderPassDescriptor = mtkView.currentRenderPassDescriptor!
        
        renderPassDescriptor.colorAttachments[0].loadAction = MTLLoadAction.Load
        renderPassDescriptor.depthAttachment.loadAction = MTLLoadAction.Load
        
        let renderEncoder =
            commandBuffer.renderCommandEncoderWithDescriptor(renderPassDescriptor)
        
        renderEncoder.pushDebugGroup("Grid Rendering Pass")
        renderEncoder.setViewport(
            MTLViewport(
                originX: 0,
                originY: 0,
                width: Double(mtkView.drawableSize.width),
                height: Double(mtkView.drawableSize.height),
                znear: 0,
                zfar: 1)
        )
        
        renderEncoder.setDepthStencilState(depthStencilState_depthTestOff)
        renderEncoder.setRenderPipelineState(pipelineState_grid)
        
        
        renderEncoder.setVertexBuffer(
                vertexBuffer_grid,
                offset: 0,
                atIndex: VertexBufferIndex
        )
        
        renderEncoder.setVertexBuffer(
                frameUniformBuffers[currentFrame],
                offset: 0,
                atIndex: FrameUniformBufferIndex
        )
        
        renderEncoder.drawPrimitives(
                .Point,
                vertexStart: 0,
                vertexCount: numGridVertices
        )
        
//            renderEncoder.drawIndexedPrimitives(.Triangle,
//                indexCount: subMesh.indexCount,
//                indexType: subMesh.indexType,
//                indexBuffer: subMesh.indexBuffer.buffer,
//                indexBufferOffset: subMesh.indexBuffer.offset,
//                instanceCount: numParticles
//            )
        
        renderEncoder.endEncoding()
        renderEncoder.popDebugGroup()
    }
    
    //-----------------------------------------------------------------------------------
    /// Main render method
    func render(
            inout particleData particleData: ParticleData,
            inout grid: Grid
    ) {
        for var i = 0; i < numInflightCommandBuffers; ++i {
            // Allow the renderer to preflight frames on the CPU (using a semapore as
            // a guard) and commit them to the GPU.  This semaphore will get signaled
            // once the GPU completes a frame's work via addCompletedHandler callback
            // below, signifying the CPU can go ahead and prepare another frame.
            dispatch_semaphore_wait(inflightSemaphore, DISPATCH_TIME_FOREVER);
            
            setPerFrameData(&particleData)
            
            uploadGridVertexData(&grid)
            
            let commandBuffer = commandQueue.commandBuffer()
            
            encodeRenderCommandsForParticles(commandBuffer)
            
            encodeRenderCommandsForGrid(commandBuffer)
            
            commandBuffer.presentDrawable(mtkView.currentDrawable!)
            
            
            // Once GPU has completed executing the commands wihin this buffer, signal
            // the semaphore and allow the CPU to proceed in constructing the next frame.
            commandBuffer.addCompletedHandler() { mtlCommandbuffer in
                dispatch_semaphore_signal(self.inflightSemaphore)
            }
            
            // Push command buffer to GPU for execution.
            commandBuffer.commit()
        
            currentFrame = (currentFrame + 1) % frameUniformBuffers.count
        }
    }
    
}
