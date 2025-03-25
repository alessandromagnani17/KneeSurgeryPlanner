/*
 Gestisce il rendering volumetrico utilizzando Metal.

 Proprietà principali:
 - device: Dispositivo Metal utilizzato per l'elaborazione grafica.
 - commandQueue: Coda di comandi per inviare istruzioni alla GPU.
 - pipelineState: Stato della pipeline di rendering configurata con shader personalizzati.
 - volumeTexture: Texture 3D che rappresenta il volume DICOM.
 - volumeDimensions: Dimensioni del volume (larghezza, altezza, profondità).
 - volumeSpacing: Distanza tra i voxel per scalare correttamente lo spazio fisico.

 Funzionalità:
 - Inizializza e carica un volume DICOM in una texture 3D.
 - Configura e utilizza una pipeline di rendering per il ray casting volumetrico.
 - Fornisce un'interfaccia per aggiornare il viewport e i parametri di windowing.
 - Esegue il rendering di un quad fullscreen per visualizzare il volume.

 Scopo:
 Coordinare il flusso di rendering per la visualizzazione volumetrica 3D di immagini DICOM.
 */


import Metal
import MetalKit
import simd

class VolumeRenderer {
    let device: MTLDevice
    let commandQueue: MTLCommandQueue
    let pipelineState: MTLRenderPipelineState
    let volumeTexture: MTLTexture?
    let volumeDimensions: SIMD3<UInt32>
    let volumeSpacing: SIMD3<Float>
    
    init?(device: MTLDevice, volume: Volume) {
        self.device = device
        
        // Crea la coda di comandi
        guard let queue = device.makeCommandQueue() else { return nil }
        self.commandQueue = queue
        
        // Crea la texture 3D dal volume
        let textureDescriptor = MTLTextureDescriptor()
        textureDescriptor.textureType = .type3D
        textureDescriptor.width = volume.dimensions.x
        textureDescriptor.height = volume.dimensions.y
        textureDescriptor.depth = volume.dimensions.z
        textureDescriptor.pixelFormat = volume.bitsPerVoxel == 8 ? MTLPixelFormat.r8Uint : MTLPixelFormat.r16Uint
        textureDescriptor.mipmapLevelCount = 1
        textureDescriptor.usage = MTLTextureUsage.shaderRead
        textureDescriptor.storageMode = MTLStorageMode.shared
        
        guard let texture = device.makeTexture(descriptor: textureDescriptor) else { return nil }
        
        // Carica i dati del volume nella texture
        let bytesPerVoxel = volume.bitsPerVoxel / 8
        let bytesPerRow = volume.dimensions.x * bytesPerVoxel
        let bytesPerSlice = bytesPerRow * volume.dimensions.y
        
        let region = MTLRegion(
            origin: MTLOrigin(x: 0, y: 0, z: 0),
            size: MTLSize(
                width: volume.dimensions.x,
                height: volume.dimensions.y,
                depth: volume.dimensions.z
            )
        )
        
        texture.replace(
            region: region,
            mipmapLevel: 0,
            slice: 0,
            withBytes: [UInt8](volume.data),
            bytesPerRow: bytesPerRow,
            bytesPerImage: bytesPerSlice
        )
        
        self.volumeTexture = texture
        self.volumeDimensions = SIMD3<UInt32>(
            UInt32(volume.dimensions.x),
            UInt32(volume.dimensions.y),
            UInt32(volume.dimensions.z)
        )
        self.volumeSpacing = volume.spacing
        
        // Crea il render pipeline state
        let library = device.makeDefaultLibrary()
        guard let vertexFunction = library?.makeFunction(name: "vertexShader"),
              let fragmentFunction = library?.makeFunction(name: "fragmentShader") else {
            return nil
        }
        
        let pipelineDescriptor = MTLRenderPipelineDescriptor()
        pipelineDescriptor.vertexFunction = vertexFunction
        pipelineDescriptor.fragmentFunction = fragmentFunction
        pipelineDescriptor.colorAttachments[0].pixelFormat = .bgra8Unorm
        pipelineDescriptor.depthAttachmentPixelFormat = .depth32Float
        
        do {
            self.pipelineState = try device.makeRenderPipelineState(descriptor: pipelineDescriptor)
        } catch {
            print("Failed to create pipeline state: \(error)")
            return nil
        }
    }
    
    func updateViewport(size: CGSize) {
        // Aggiorna le impostazioni di viewport se necessario
    }
    
    func render(commandBuffer: MTLCommandBuffer, renderPassDescriptor: MTLRenderPassDescriptor, drawable: CAMetalDrawable, windowCenter: Float, windowWidth: Float) {
        guard let encoder = commandBuffer.makeRenderCommandEncoder(descriptor: renderPassDescriptor) else {
            return
        }
        
        encoder.setRenderPipelineState(pipelineState)
        
        // Imposta la texture del volume
        if let volumeTexture = volumeTexture {
            encoder.setFragmentTexture(volumeTexture, index: 0)
        }
        
        // Imposta i parametri per il rendering
        var viewParams = SIMD4<Float>(windowCenter, windowWidth, 0, 0)
        encoder.setFragmentBytes(&viewParams, length: MemoryLayout<SIMD4<Float>>.size, index: 0)
        
        var dimensions = volumeDimensions
        encoder.setFragmentBytes(&dimensions, length: MemoryLayout<SIMD3<UInt32>>.size, index: 1)
        
        var spacing = volumeSpacing
        encoder.setFragmentBytes(&spacing, length: MemoryLayout<SIMD3<Float>>.size, index: 2)
        
        // Disegna un quad che copre l'intera viewport
        encoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 6)
        encoder.endEncoding()
    }
}
