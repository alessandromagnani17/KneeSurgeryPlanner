import Foundation
import MetalKit
import CoreGraphics
import simd

class MPRRenderer {
    private var device: MTLDevice
    private var commandQueue: MTLCommandQueue
    private var pipelineState: MTLComputePipelineState
    private var volumeTexture: MTLTexture?

    // Buffer per i parametri di rendering
    private var renderParamsBuffer: MTLBuffer

    init?() {
        // Inizializza Metal
        guard let device = MTLCreateSystemDefaultDevice(),
              let commandQueue = device.makeCommandQueue() else {
            print("❌ Metal non è supportato su questo dispositivo")
            return nil
        }

        self.device = device
        self.commandQueue = commandQueue

        // Carica lo shader
        guard let library = device.makeDefaultLibrary(),
              let kernelFunction = library.makeFunction(name: "mprKernel") else {
            print("❌ Impossibile caricare lo shader MPR")
            return nil
        }

        // Crea lo stato della pipeline
        do {
            pipelineState = try device.makeComputePipelineState(function: kernelFunction)
        } catch {
            print("❌ Errore nella creazione della pipeline: \(error)")
            return nil
        }

        // Crea un buffer per i parametri di rendering
        var renderParams = RenderParameters()
        guard let buffer = device.makeBuffer(bytes: &renderParams,
                                             length: MemoryLayout<RenderParameters>.size,
                                             options: .storageModeShared) else {
            print("❌ Impossibile creare il buffer per i parametri")
            return nil
        }

        self.renderParamsBuffer = buffer
        print("✅ MPRRenderer inizializzato con successo")
    }

    // Carica il volume nella texture GPU
    func loadVolume(_ volume: Volume) -> Bool {
        // Crea il descrittore della texture 3D
        let textureDescriptor = MTLTextureDescriptor()
        textureDescriptor.textureType = .type3D
        textureDescriptor.pixelFormat = volume.bitsPerVoxel == 16 ? .r16Sint : .r8Unorm
        textureDescriptor.width = volume.dimensions.x
        textureDescriptor.height = volume.dimensions.y
        textureDescriptor.depth = volume.dimensions.z
        textureDescriptor.mipmapLevelCount = 1

        textureDescriptor.usage = [.shaderRead, .shaderWrite]
        textureDescriptor.storageMode = .shared

        guard let texture = device.makeTexture(descriptor: textureDescriptor) else {
            print("❌ Impossibile creare la texture per il volume")
            return false
        }

        // Copia i dati nella texture
        let region = MTLRegion(origin: MTLOrigin(x: 0, y: 0, z: 0),
                              size: MTLSize(width: volume.dimensions.x,
                                           height: volume.dimensions.y,
                                           depth: volume.dimensions.z))

        let bytesPerRow = volume.dimensions.x * (volume.bitsPerVoxel / 8)
        let bytesPerImage = bytesPerRow * volume.dimensions.y

        texture.replace(region: region,
                        mipmapLevel: 0,
                        slice: 0,
                        withBytes: [UInt8](volume.data),
                        bytesPerRow: bytesPerRow,
                        bytesPerImage: bytesPerImage)

        self.volumeTexture = texture
        print("✅ Volume caricato nella GPU con dimensioni: \(volume.dimensions)")
        return true
    }

    // Renderizza una slice MPR
    func renderMPRSlice(orientation: MPROrientation,
                        sliceIndex: Int,
                        windowCenter: Double,
                        windowWidth: Double) -> CGImage? {

        guard let volumeTexture = self.volumeTexture else {
            print("❌ Nessun volume caricato")
            return nil
        }

        // Configura i parametri di rendering
        var params = RenderParameters()
        params.orientation = orientation.rawValue
        params.sliceIndex = Int32(sliceIndex)
        params.windowCenter = Float(windowCenter)
        params.windowWidth = Float(windowWidth)

        // Dimensioni dell'output in base all'orientamento
        var width: Int = 0
        var height: Int = 0

        switch orientation {
        case .axial:
            width = volumeTexture.width
            height = volumeTexture.height
        case .coronal:
            width = volumeTexture.width
            height = volumeTexture.depth
        case .sagittal:
            width = volumeTexture.height
            height = volumeTexture.depth
        }

        params.outputWidth = Int32(width)
        params.outputHeight = Int32(height)

        // Debug output
        print("Rendering MPR slice: \(orientation) at index \(sliceIndex) with dimensions \(width)x\(height)")

        // Copia i parametri aggiornati nel buffer
        memcpy(renderParamsBuffer.contents(), &params, MemoryLayout<RenderParameters>.size)

        // Crea la texture di output
        let outputTextureDescriptor = MTLTextureDescriptor.texture2DDescriptor(
            pixelFormat: .r8Unorm,
            width: width,
            height: height,
            mipmapped: false
        )

        outputTextureDescriptor.usage = [.shaderWrite, .shaderRead]
        outputTextureDescriptor.storageMode = .shared

        guard let outputTexture = device.makeTexture(descriptor: outputTextureDescriptor) else {
            print("❌ Impossibile creare la texture di output")
            return nil
        }

        // Esegui il kernel shader
        guard let commandBuffer = commandQueue.makeCommandBuffer(),
              let computeEncoder = commandBuffer.makeComputeCommandEncoder() else {
            print("❌ Impossibile creare encoder per il compute shader")
            return nil
        }

        computeEncoder.setComputePipelineState(pipelineState)
        computeEncoder.setTexture(volumeTexture, index: 0)
        computeEncoder.setTexture(outputTexture, index: 1)
        computeEncoder.setBuffer(renderParamsBuffer, offset: 0, index: 0)

        // Calcola i threadgroup
        let threadGroupSize = MTLSize(width: 16, height: 16, depth: 1)
        let threadGroups = MTLSize(
            width: (width + threadGroupSize.width - 1) / threadGroupSize.width,
            height: (height + threadGroupSize.height - 1) / threadGroupSize.height,
            depth: 1
        )

        computeEncoder.dispatchThreadgroups(threadGroups, threadsPerThreadgroup: threadGroupSize)
        computeEncoder.endEncoding()

        // Esegui il comando
        commandBuffer.commit()
        commandBuffer.waitUntilCompleted()

        if let error = commandBuffer.error {
            print("❌ Errore nell'esecuzione del comando: \(error)")
            return nil
        }

        // Crea il CGImage dal risultato
        var outputBytes = [UInt8](repeating: 0, count: width * height)
        let region = MTLRegion(origin: MTLOrigin(x: 0, y: 0, z: 0),
                              size: MTLSize(width: width, height: height, depth: 1))

        outputTexture.getBytes(&outputBytes,
                               bytesPerRow: width,
                               from: region,
                               mipmapLevel: 0)

        // Crea un provider di dati per il CGImage
        guard let provider = CGDataProvider(data: Data(outputBytes) as CFData) else {
            print("❌ Impossibile creare il data provider")
            return nil
        }

        let colorSpace = CGColorSpaceCreateDeviceGray()
        return CGImage(
            width: width,
            height: height,
            bitsPerComponent: 8,
            bitsPerPixel: 8,
            bytesPerRow: width,
            space: colorSpace,
            bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.none.rawValue),
            provider: provider,
            decode: nil,
            shouldInterpolate: false,
            intent: .defaultIntent
        )
    }
}

// Struttura per i parametri di rendering (deve corrispondere a quella in MPRShader.metal)
struct RenderParameters {
    var orientation: Int32 = 0 // 0 = axial, 1 = coronal, 2 = sagittal
    var sliceIndex: Int32 = 0
    var windowCenter: Float = 40
    var windowWidth: Float = 400
    var outputWidth: Int32 = 0
    var outputHeight: Int32 = 0
}
