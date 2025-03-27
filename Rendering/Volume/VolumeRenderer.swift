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
    
    // OTTIMIZZAZIONE: Aggiunta di nuovi parametri per il controllo del rendering
    var renderingQuality: RenderingQuality = .medium
    var renderTimeLimit: TimeInterval = 20.0 // Limita tempo di rendering a 20 secondi
    private var renderStartTime: Date?
    private var meshGenerator: MarchingCubes?
    private var surfaceMesh: MarchingCubes.Mesh?
    
    // OTTIMIZZAZIONE: Parametri per la generazione di mesh
    private var isosurfaceValue: Float = 100 // Valore predefinito
    private var downsampleFactor: Int = 2    // Fattore di riduzione risoluzione
    
    // OTTIMIZZAZIONE: Modalità di rendering
    enum RenderingMode {
        case volumeRayCasting   // Rendering volumetrico diretto (originale)
        case isosurface         // Rendering di superficie (Marching Cubes)
        case preview            // Anteprima rapida e semplificata
    }
    var renderingMode: RenderingMode = .volumeRayCasting
    
    // OTTIMIZZAZIONE: Livelli di qualità del rendering
    enum RenderingQuality {
        case ultraFast  // Molto veloce, bassa qualità (downsampling 4x)
        case fast       // Veloce, qualità media (downsampling 3x)
        case medium     // Equilibrato (downsampling 2x)
        case high       // Alta qualità, più lento (downsampling 1.5x)
        case ultraHigh  // Massima qualità, potenzialmente molto lento (no downsampling)
        
        var downsampleFactor: Int {
            switch self {
            case .ultraFast: return 4
            case .fast: return 3
            case .medium: return 2
            case .high: return 1
            case .ultraHigh: return 1
            }
        }
        
        var maxSteps: Int {
            switch self {
            case .ultraFast: return 100
            case .fast: return 150
            case .medium: return 200
            case .high: return 300
            case .ultraHigh: return 400
            }
        }
    }
    
    init?(device: MTLDevice, volume: Volume) {
        print("📊 Inizializzazione VolumeRenderer con volume \(volume.dimensions.x)x\(volume.dimensions.y)x\(volume.dimensions.z)")
        self.device = device
        
        // OTTIMIZZAZIONE: Inizializza il generatore di mesh
        self.meshGenerator = MarchingCubes()
        
        // Crea la coda di comandi
        guard let queue = device.makeCommandQueue() else {
            print("❌ Impossibile creare command queue")
            return nil
        }
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
        
        guard let texture = device.makeTexture(descriptor: textureDescriptor) else {
            print("❌ Impossibile creare texture 3D")
            return nil
        }
        
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
        
        print("📊 Caricamento dati volume in texture: \(bytesPerRow) bytes per riga, \(bytesPerSlice) bytes per slice")
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
            print("❌ Impossibile trovare funzioni shader")
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
            print("❌ Errore creazione pipeline state: \(error)")
            return nil
        }
        
        // OTTIMIZZAZIONE: Determina automaticamente un buon valore di isosuperficie
        detectOptimalIsosurfaceValue(volume: volume)
    }
    
    // OTTIMIZZAZIONE: Funzione per rilevare automaticamente un buon valore di isosuperficie
    private func detectOptimalIsosurfaceValue(volume: Volume) {
        print("🔍 Rilevamento automatico valore isosuperficie ottimale...")
        
        // Campiona il volume per trovare un buon valore di isosuperficie
        let sampleRate = 10 // Campiona ogni 10 voxel per velocità
        var values: [Float] = []
        
        for z in stride(from: 0, to: volume.dimensions.z, by: sampleRate) {
            for y in stride(from: 0, to: volume.dimensions.y, by: sampleRate) {
                for x in stride(from: 0, to: volume.dimensions.x, by: sampleRate) {
                    if let value = volume.voxelValue(at: SIMD3<Int>(x, y, z)) {
                        values.append(Float(value))
                    }
                }
            }
        }
        
        guard !values.isEmpty else {
            print("⚠️ Impossibile determinare valore isosuperficie - nessun valore trovato")
            return
        }
        
        // Ordina i valori e trova percentili significativi
        values.sort()
        let p25 = values[Int(Float(values.count) * 0.25)]
        let p50 = values[Int(Float(values.count) * 0.5)]
        let p75 = values[Int(Float(values.count) * 0.75)]
        
        print("📊 Analisi volume - min: \(values.first!), max: \(values.last!)")
        print("📊 Percentili - P25: \(p25), P50: \(p50), P75: \(p75)")
        
        // Selezione euristica del valore di isosuperficie
        // Per CT, valori intorno a 400-600 sono tipicamente osso
        // Per MRI, dipende fortemente dalla sequenza
        if volume.type == .ct {
            // Per CT usiamo valori tipici per specifici tessuti
            if p75 > 400 {
                isosurfaceValue = 400  // Tipico valore per osso in CT
                print("🎯 CT rilevato: impostato valore isosuperficie a \(isosurfaceValue) (osso)")
            } else {
                isosurfaceValue = p50  // Uso mediana per altri casi
                print("🎯 CT rilevato: impostato valore isosuperficie a \(isosurfaceValue) (tessuti molli)")
            }
        } else {
            // Per MRI, la mediana è spesso un buon punto di partenza
            isosurfaceValue = p50
            print("🎯 MRI rilevato: impostato valore isosuperficie a \(isosurfaceValue)")
        }
    }
    
    // OTTIMIZZAZIONE: Nuova funzione per generare il modello 3D usando Marching Cubes
    func generateSurfaceModel(isovalue: Float? = nil, quality: RenderingQuality? = nil) {
        // Usa valori forniti o quelli di default
        let finalIsovalue = isovalue ?? self.isosurfaceValue
        let finalQuality = quality ?? self.renderingQuality
        
        print("🔨 Generazione modello superficie con valore \(finalIsovalue), qualità \(finalQuality)")
        
        // Imposta il fattore di downsampling in base alla qualità
        self.downsampleFactor = finalQuality.downsampleFactor
        
        // Inizia a misurare il tempo
        self.renderStartTime = Date()
        
        // Esegui in background per non bloccare l'UI
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self,
                  let volume = self.volumeToVolumeObject(),
                  let meshGenerator = self.meshGenerator else {
                print("❌ Errore: impossibile accedere a volume o mesh generator")
                return
            }
            
            // Genera la mesh
            self.surfaceMesh = meshGenerator.generateMesh(from: volume, isovalue: finalIsovalue)
            
            // Verifica il risultato
            if let mesh = self.surfaceMesh, !mesh.triangles.isEmpty {
                print("✅ Generata mesh con \(mesh.vertices.count) vertici e \(mesh.triangles.count) triangoli")
                self.renderingMode = .isosurface
            } else {
                print("⚠️ Generazione mesh fallita o nessun triangolo generato")
                self.renderingMode = .volumeRayCasting  // Fallback al metodo originale
            }
            
            // Calcola tempo impiegato
            if let startTime = self.renderStartTime {
                let elapsed = Date().timeIntervalSince(startTime)
                print("⏱️ Tempo di generazione: \(elapsed) secondi")
            }
        }
    }
    
    // OTTIMIZZAZIONE: Genera un'anteprima rapida
    func generateQuickPreview() {
        print("🚀 Generazione anteprima rapida...")
        self.renderingQuality = .ultraFast
        self.downsampleFactor = 4
        
        // Usa un timeout più breve per l'anteprima
        let previousTimeout = self.renderTimeLimit
        self.renderTimeLimit = 5.0
        
        // Genera il modello
        generateSurfaceModel(quality: .ultraFast)
        
        // Ripristina il timeout originale
        self.renderTimeLimit = previousTimeout
    }
    
    // Converte i dati interni in un oggetto Volume compatibile con MarchingCubes
    private func volumeToVolumeObject() -> Volume? {
        // Assume che abbiamo già i dati necessari
        // In un'implementazione reale, potrebbe essere necessario ricostruire l'oggetto Volume
        return nil // TODO: Implementare conversione se necessario
    }
    
    func updateViewport(size: CGSize) {
        // Aggiorna le impostazioni di viewport se necessario
        // Rimane invariato dall'implementazione originale
    }
    
    // OTTIMIZZAZIONE: Funzione di rendering modificata per supportare diverse modalità
    func render(commandBuffer: MTLCommandBuffer, renderPassDescriptor: MTLRenderPassDescriptor, drawable: CAMetalDrawable, windowCenter: Float, windowWidth: Float) {
        // Verifica timeout se stiamo generando la mesh
        if let startTime = renderStartTime, Date().timeIntervalSince(startTime) > renderTimeLimit {
            print("⚠️ Timeout: rendering fallback")
            renderingMode = .volumeRayCasting
            renderStartTime = nil
        }
        
        switch renderingMode {
        case .isosurface:
            renderSurfaceModel(commandBuffer: commandBuffer, renderPassDescriptor: renderPassDescriptor, drawable: drawable)
        case .preview:
            renderPreview(commandBuffer: commandBuffer, renderPassDescriptor: renderPassDescriptor, drawable: drawable)
        case .volumeRayCasting:
            renderVolumeRayCasting(commandBuffer: commandBuffer, renderPassDescriptor: renderPassDescriptor, drawable: drawable, windowCenter: windowCenter, windowWidth: windowWidth)
        }
    }
    
    // Rendering volumetrico originale (metodo esistente)
    private func renderVolumeRayCasting(commandBuffer: MTLCommandBuffer, renderPassDescriptor: MTLRenderPassDescriptor, drawable: CAMetalDrawable, windowCenter: Float, windowWidth: Float) {
        guard let encoder = commandBuffer.makeRenderCommandEncoder(descriptor: renderPassDescriptor) else {
            return
        }
        
        encoder.setRenderPipelineState(pipelineState)
        
        // Imposta la texture del volume
        if let volumeTexture = volumeTexture {
            encoder.setFragmentTexture(volumeTexture, index: 0)
        }
        
        // Imposta i parametri per il rendering
        var viewParams = SIMD4<Float>(windowCenter, windowWidth, Float(renderingQuality.maxSteps), 0)
        encoder.setFragmentBytes(&viewParams, length: MemoryLayout<SIMD4<Float>>.size, index: 0)
        
        var dimensions = volumeDimensions
        encoder.setFragmentBytes(&dimensions, length: MemoryLayout<SIMD3<UInt32>>.size, index: 1)
        
        var spacing = volumeSpacing
        encoder.setFragmentBytes(&spacing, length: MemoryLayout<SIMD3<Float>>.size, index: 2)
        
        // Disegna un quad che copre l'intera viewport
        encoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 6)
        encoder.endEncoding()
    }
    
    // OTTIMIZZAZIONE: Rendering della superficie isometrica
    private func renderSurfaceModel(commandBuffer: MTLCommandBuffer, renderPassDescriptor: MTLRenderPassDescriptor, drawable: CAMetalDrawable) {
        guard let mesh = surfaceMesh, !mesh.vertices.isEmpty, !mesh.triangles.isEmpty else {
            // Fallback al ray casting se non c'è una mesh valida
            renderVolumeRayCasting(commandBuffer: commandBuffer, renderPassDescriptor: renderPassDescriptor, drawable: drawable, windowCenter: 0, windowWidth: 1000)
            return
        }
        
        guard let encoder = commandBuffer.makeRenderCommandEncoder(descriptor: renderPassDescriptor) else {
            return
        }
        
        // Usa una pipeline diversa per il rendering della mesh
        // Nota: In un'implementazione completa, dovresti creare una pipeline separata
        // per il rendering di mesh con illuminazione in init()
        encoder.setRenderPipelineState(pipelineState)
        
        // TEMPORANEO: Qui dovresti configurare il renderer della mesh
        // In un'implementazione completa, dovresti:
        // 1. Creare buffer per vertici e indici
        // 2. Impostare stato di rendering per la mesh
        // 3. Disegnare la mesh
        
        print("⚠️ Rendering di mesh non completamente implementato - usa il fallback")
        
        // Per ora, fallback al ray casting
        encoder.endEncoding()
        renderVolumeRayCasting(commandBuffer: commandBuffer, renderPassDescriptor: renderPassDescriptor, drawable: drawable, windowCenter: 0, windowWidth: 1000)
    }
    
    // OTTIMIZZAZIONE: Rendering anteprima veloce
    private func renderPreview(commandBuffer: MTLCommandBuffer, renderPassDescriptor: MTLRenderPassDescriptor, drawable: CAMetalDrawable) {
        guard let encoder = commandBuffer.makeRenderCommandEncoder(descriptor: renderPassDescriptor) else {
            return
        }
        
        // Usa la pipeline standard ma con parametri semplificati
        encoder.setRenderPipelineState(pipelineState)
        
        // Imposta la texture del volume se disponibile
        if let volumeTexture = volumeTexture {
            encoder.setFragmentTexture(volumeTexture, index: 0)
        }
        
        // Imposta parametri semplificati per rendering veloce
        var viewParams = SIMD4<Float>(0, 1000, Float(100), 1.0) // L'ultimo valore indica modalità anteprima
        encoder.setFragmentBytes(&viewParams, length: MemoryLayout<SIMD4<Float>>.size, index: 0)
        
        var dimensions = volumeDimensions
        encoder.setFragmentBytes(&dimensions, length: MemoryLayout<SIMD3<UInt32>>.size, index: 1)
        
        var spacing = volumeSpacing
        encoder.setFragmentBytes(&spacing, length: MemoryLayout<SIMD3<Float>>.size, index: 2)
        
        // Disegna un quad che copre l'intera viewport
        encoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 6)
        encoder.endEncoding()
    }
    
    // OTTIMIZZAZIONE: Aggiunta di funzioni di utilità
    
    // Imposta la qualità del rendering
    func setRenderingQuality(_ quality: RenderingQuality) {
        self.renderingQuality = quality
        print("📊 Qualità rendering impostata a: \(quality)")
        
        // Se stiamo usando il ray casting, non serve rigenerare
        if renderingMode == .isosurface || renderingMode == .preview {
            // Rigenera il modello con la nuova qualità
            generateSurfaceModel(quality: quality)
        }
    }
    
    // Imposta il valore di isosuperficie e rigenera il modello
    func setIsosurfaceValue(_ value: Float) {
        self.isosurfaceValue = value
        print("🎯 Valore isosuperficie impostato a: \(value)")
        
        // Rigenera il modello con il nuovo valore
        generateSurfaceModel(isovalue: value)
    }
    
    // Passa da una modalità di rendering all'altra
    func switchRenderingMode(_ mode: RenderingMode) {
        print("🔄 Cambio modalità di rendering a: \(mode)")
        
        if mode == .isosurface && self.surfaceMesh == nil {
            // Se passiamo a isosurface ma non abbiamo ancora una mesh, generala
            generateSurfaceModel()
        } else if mode == .preview {
            // Se passiamo a anteprima, genera un'anteprima rapida
            generateQuickPreview()
        } else {
            // Altrimenti, imposta semplicemente la modalità
            self.renderingMode = mode
        }
    }
    
    private func correctVolumeOrientation(volume: Volume) -> Volume {
        print("🔄 Verifica orientamento volume...")
        
        // Verifica se l'orientamento sembra corretto
        let (width, height, depth) = (volume.dimensions.x, volume.dimensions.y, volume.dimensions.z)
        
        // Logga i dettagli del volume per il debug
        print("Dimensioni volume: \(width)x\(height)x\(depth)")
        print("Spacing: \(volume.spacing.x)x\(volume.spacing.y)x\(volume.spacing.z)")
        
        // Verifica se lo spacing è troppo irregolare (può causare deformazione)
        let maxSpacing = max(volume.spacing.x, max(volume.spacing.y, volume.spacing.z))
        let minSpacing = min(volume.spacing.x, min(volume.spacing.y, volume.spacing.z))
        let spacingRatio = maxSpacing / minSpacing
        
        if spacingRatio > 3.0 {
            print("Spacing molto irregolare (ratio: \(spacingRatio)). Potrebbe causare distorsioni.")
        }
        
        // Restituisci il volume originale per ora
        // In un'implementazione più avanzata, qui potresti riorientare il volume se necessario
        return volume
    }
    

    func generateBrainModel() {
        print("🧠 Iniziando generazione modello cervello...")
        
        // 1. Verifica e correggi l'orientamento del volume
        guard let volume = self.volumeToVolumeObject() else {
            print("❌ Errore: impossibile accedere al volume")
            return
        }
        let correctedVolume = correctVolumeOrientation(volume: volume)
        
        // 2. Rileva valori ottimali per tessuto cerebrale
        let brainIsovalues = IsosurfaceDetector.suggestBrainIsovalues(volume: correctedVolume)
        
        // 3. Usa il valore medio come default ma permetti all'utente di modificarlo via UI
        if !brainIsovalues.isEmpty {
            self.isosurfaceValue = brainIsovalues[brainIsovalues.count / 2]
        }
        
        // 4. Imposta parametri ottimizzati per il cervello
        self.renderingQuality = .medium     // Usa qualità media per bilanciare dettaglio/velocità
        self.downsampleFactor = 2           // Fattore di downsampling ridotto per il cervello
        
        // 5. Genera il modello
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self,
                  let volume = self.volumeToVolumeObject(),
                  let meshGenerator = self.meshGenerator else {
                print("❌ Errore: impossibile accedere a volume o mesh generator")
                return
            }
            
            self.renderStartTime = Date()
            
            // Genera la mesh con il valore di isosuperficie ottimizzato
            var brainMesh = meshGenerator.generateMesh(from: volume, isovalue: self.isosurfaceValue)
            
            // Applica lo smoothing per migliorare la qualità visiva
            if !brainMesh.triangles.isEmpty {
                print("🔄 Applicazione smoothing al modello cerebrale...")
                brainMesh = meshGenerator.smoothMesh(brainMesh, iterations: 2, factor: 0.5)
            }
            
            // Assegna la mesh e aggiorna la modalità di rendering
            self.surfaceMesh = brainMesh
            
            // Calcola tempo impiegato
            if let startTime = self.renderStartTime {
                let elapsed = Date().timeIntervalSince(startTime)
                print("⏱️ Modello cerebrale generato in \(elapsed) secondi")
                print("📊 Statistiche: \(brainMesh.vertices.count) vertici, \(brainMesh.triangles.count) triangoli")
            }
            
            // Cambia modalità di rendering
            DispatchQueue.main.async {
                self.renderingMode = .isosurface
            }
        }
    }
}
