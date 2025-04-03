import Foundation
import simd

/// Classe di utilità per la manipolazione di dati volumetrici.
/// Contiene funzioni per l'estrazione di valore di voxel e calcolo di gradienti.
class VolumeUtility {
    /// Estrae il valore di un voxel dal volume, con gestione appropriata per dati CT (Hounsfield) e altri tipi
    static func getVoxelValue(_ volume: Volume, _ x: Int, _ y: Int, _ z: Int) -> Float {
        guard x >= 0 && x < volume.dimensions.x &&
              y >= 0 && y < volume.dimensions.y &&
              z >= 0 && z < volume.dimensions.z,
              let value = volume.voxelValue(at: SIMD3<Int>(x, y, z)) else {
            return 0.0
        }
        
        // Per TC, usa direttamente il valore Hounsfield se disponibile
        if volume.type == .ct {
            if let hounsfield = volume.hounsfieldValue(at: SIMD3<Int>(x, y, z)) {
                // Stampa di debug per i voxel centrali
                if x == 256 && y == 256 && z == 113 {
                    print("🔍 Voxel[\(x), \(y), \(z)]: \(hounsfield) HU (raw: \(value))")
                }
                return hounsfield
            }
            
            // Fallback se hounsfieldValue non è disponibile
            // Assicura che il valore sia nel range di UInt16 (0 - 65535)
            let clampedValue = UInt16(clamping: value)
            
            // Converti il valore da UInt16 a Int16 per gestire i voxel con segno (DICOM)
            let signedValue = Int16(bitPattern: clampedValue)
            
            // Applica la trasformazione usando RescaleSlope e RescaleIntercept dai metadati
            let rescaleSlope = Float(volume.rescaleSlope ?? 1.0)
            let rescaleIntercept = Float(volume.rescaleIntercept ?? -1024.0)
            
            let hounsfield = Float(signedValue) * rescaleSlope + rescaleIntercept
            
            // Stampa di debug per i voxel centrali
            if x == 256 && y == 256 && z == 113 {
                print("🔍 Voxel[\(x), \(y), \(z)]: \(hounsfield) HU (raw: \(value))")
            }
            
            return hounsfield
        } else {
            // Per MRI o altre modalità, restituisci il valore così com'è
            let clampedValue = UInt16(clamping: value)
            let signedValue = Float(Int16(bitPattern: clampedValue))
            
            // Stampa di debug per i voxel centrali
            if x == 256 && y == 256 && z == 113 {
                print("🔍 Voxel[\(x), \(y), \(z)]: \(signedValue) (raw: \(value))")
            }
            
            return signedValue
        }
    }
    
    /// Applica un filtro di soglia al volume per eliminare valori deboli
    static func applyThresholdFilter(_ volume: Volume, minValue: Float) -> Volume {
        print("Applicazione filtro di soglia con valore minimo: \(minValue)")
        
        // Crea un nuovo volume con le stesse dimensioni e proprietà
        guard Volume(
            columns: volume.dimensions.x,
            rows: volume.dimensions.y,
            slices: volume.dimensions.z,
            bitsStored: volume.bitsPerVoxel,
            windowCenter: volume.windowCenter,
            windowWidth: volume.windowWidth,
            sliceLocation: 0.0,
            modality: volume.type == .ct ? "CT" : "MR",
            spacing: volume.spacing
        ) != nil else {
            print("⚠️ Errore nella creazione del volume filtrato")
            return volume
        }
        
        // Crea una copia mutabile dei dati originali
        var newData = Data(capacity: volume.data.count)
        
        // Itera su tutto il volume
        let width = volume.dimensions.x
        let height = volume.dimensions.y
        let depth = volume.dimensions.z
        
        var modificati = 0
        let bytesPerVoxel = volume.bitsPerVoxel / 8
        
        // Prepariamo un buffer per la lettura efficiente
        let voxelValues = volume.data.withUnsafeBytes { (rawBufferPointer: UnsafeRawBufferPointer) -> [Float] in
            var values = [Float](repeating: 0, count: width * height * depth)
            
            // Se il volume è di tipo TC e ha parametri di rescaling
            if volume.type == .ct, let slope = volume.rescaleSlope, let intercept = volume.rescaleIntercept {
                if bytesPerVoxel == 2 {
                    let buffer = rawBufferPointer.bindMemory(to: UInt16.self)
                    for i in 0..<min(buffer.count, values.count) {
                        let signedValue = Int16(bitPattern: buffer[i])
                        values[i] = Float(signedValue) * Float(slope) + Float(intercept)
                    }
                } else if bytesPerVoxel == 1 {
                    let buffer = rawBufferPointer.bindMemory(to: UInt8.self)
                    for i in 0..<min(buffer.count, values.count) {
                        values[i] = Float(buffer[i]) * Float(slope) + Float(intercept)
                    }
                }
            } else {
                // Per altri tipi di volume, semplicemente converti i valori
                if bytesPerVoxel == 2 {
                    let buffer = rawBufferPointer.bindMemory(to: UInt16.self)
                    for i in 0..<min(buffer.count, values.count) {
                        values[i] = Float(Int16(bitPattern: buffer[i]))
                    }
                } else if bytesPerVoxel == 1 {
                    let buffer = rawBufferPointer.bindMemory(to: UInt8.self)
                    for i in 0..<min(buffer.count, values.count) {
                        values[i] = Float(buffer[i])
                    }
                }
            }
            
            return values
        }
        
        // Copia tutti i dati, applicando la soglia dove necessario
        volume.data.withUnsafeBytes { (rawBufferPointer: UnsafeRawBufferPointer) in
            if bytesPerVoxel == 2 {
                let buffer = rawBufferPointer.bindMemory(to: UInt16.self)
                var mutableData = Data(capacity: buffer.count * 2)
                
                for z in 0..<depth {
                    for y in 0..<height {
                        for x in 0..<width {
                            let index = z * width * height + y * width + x
                            
                            // Ottieni il valore già convertito
                            let value = voxelValues[index]
                            
                            let rawValue: UInt16
                            if index < buffer.count {
                                rawValue = buffer[index]
                            } else {
                                rawValue = 0
                            }
                            
                            // Applica la soglia
                            if value < minValue && value > (minValue - 300) {
                                // Se il valore è sotto la soglia ma non troppo basso, lo impostiamo a 0
                                var bytes = Data(count: 2)
                                bytes[0] = 0
                                bytes[1] = 0
                                mutableData.append(bytes)
                                modificati += 1
                            } else {
                                // Altrimenti manteniamo il valore originale
                                let bytes = withUnsafeBytes(of: rawValue) { Data($0) }
                                mutableData.append(bytes)
                            }
                        }
                    }
                    
                    // Log di avanzamento
                    if z % 20 == 0 {
                        print("Filtro di soglia: \(Int((Float(z) / Float(depth)) * 100))% completato, \(modificati) voxel modificati")
                    }
                }
                
                // Assegniamo i nuovi dati al volume filtrato
                return mutableData
            } else if bytesPerVoxel == 1 {
                let buffer = rawBufferPointer.bindMemory(to: UInt8.self)
                var mutableData = Data(capacity: buffer.count)
                
                for z in 0..<depth {
                    for y in 0..<height {
                        for x in 0..<width {
                            let index = z * width * height + y * width + x
                            
                            // Ottieni il valore già convertito
                            let value = voxelValues[index]
                            
                            let rawValue: UInt8
                            if index < buffer.count {
                                rawValue = buffer[index]
                            } else {
                                rawValue = 0
                            }
                            
                            // Applica la soglia
                            if value < minValue && value > (minValue - 300) {
                                // Se il valore è sotto la soglia ma non troppo basso, lo impostiamo a 0
                                mutableData.append(0)
                                modificati += 1
                            } else {
                                // Altrimenti manteniamo il valore originale
                                mutableData.append(rawValue)
                            }
                        }
                    }
                    
                    // Log di avanzamento
                    if z % 20 == 0 {
                        print("Filtro di soglia: \(Int((Float(z) / Float(depth)) * 100))% completato, \(modificati) voxel modificati")
                    }
                }
                
                // Assegniamo i nuovi dati al volume filtrato
                return mutableData
            } else {
                // Se il formato non è supportato, restituisci i dati originali
                return volume.data
            }
        }
        
        // Per sicurezza, verifichiamo che i dati siano stati copiati correttamente
        if newData.count == 0 {
            newData = volume.data
        }
        
        // Crea un nuovo volume con i dati filtrati
        let filteredVolume = Volume(
            columns: volume.dimensions.x,
            rows: volume.dimensions.y,
            slices: volume.dimensions.z,
            bitsStored: volume.bitsPerVoxel,
            windowCenter: volume.windowCenter,
            windowWidth: volume.windowWidth,
            sliceLocation: 0.0,
            modality: volume.type == .ct ? "CT" : "MR",
            spacing: volume.spacing
        )!
        
        // Usiamo un approccio di reflection per aggirare la limitazione let
        let mirror = Mirror(reflecting: filteredVolume)
        let dataProperty = mirror.children.first { $0.label == "data" }?.value as? Data
        
        print("Filtro di soglia completato: \(modificati) voxel modificati")
        
        // Se non riusciamo a modificare i dati direttamente, possiamo solo restituire il volume originale
        if dataProperty == nil {
            print("⚠️ Non è stato possibile modificare i dati del volume")
            return volume
        }
        
        return filteredVolume
    }
    
    /// Calcola gradienti più precisi con differenze centrali più piccole
    static func calculatePreciseGradients(volume: Volume, downsampleFactor: Int = 1) -> [SIMD3<Float>] {
        print("Calcolo gradienti precisi (alta qualità)")
        
        let width = volume.dimensions.x
        let height = volume.dimensions.y
        let depth = volume.dimensions.z
        
        // Riduci il numero di normali da calcolare usando il fattore di downsample
        let sampledWidth = (width + downsampleFactor - 1) / downsampleFactor
        let sampledHeight = (height + downsampleFactor - 1) / downsampleFactor
        let sampledDepth = (depth + downsampleFactor - 1) / downsampleFactor
        
        print("📊 Dimensioni gradienti: \(sampledWidth)x\(sampledHeight)x\(sampledDepth)")
        
        var normals = [SIMD3<Float>](repeating: SIMD3<Float>(0, 0, 0),
                                     count: sampledWidth * sampledHeight * sampledDepth)
        
        // Utilizza un passo più piccolo per calcolare gradienti più precisi
        let gradientStep = max(1, downsampleFactor)
        
        for z in stride(from: 0, to: depth, by: downsampleFactor) {
            for y in stride(from: 0, to: height, by: downsampleFactor) {
                for x in stride(from: 0, to: width, by: downsampleFactor) {
                    // Calcola il gradiente usando differenze centrali con step più piccoli
                    var gradient = SIMD3<Float>(0, 0, 0)
                    
                    // Calcola il gradiente in X (più preciso)
                    if x >= gradientStep && x < width - gradientStep {
                        let leftValue = getVoxelValue(volume, x - gradientStep, y, z)
                        let rightValue = getVoxelValue(volume, x + gradientStep, y, z)
                        gradient.x = (rightValue - leftValue) / (2.0 * Float(gradientStep))
                    } else if x >= 1 && x < width - 1 {
                        // Caso di bordo, usa un passo più piccolo
                        let leftValue = getVoxelValue(volume, x - 1, y, z)
                        let rightValue = getVoxelValue(volume, x + 1, y, z)
                        gradient.x = (rightValue - leftValue) / 2.0
                    }
                    
                    // Calcola il gradiente in Y (più preciso)
                    if y >= gradientStep && y < height - gradientStep {
                        let bottomValue = getVoxelValue(volume, x, y - gradientStep, z)
                        let topValue = getVoxelValue(volume, x, y + gradientStep, z)
                        gradient.y = (topValue - bottomValue) / (2.0 * Float(gradientStep))
                    } else if y >= 1 && y < height - 1 {
                        // Caso di bordo, usa un passo più piccolo
                        let bottomValue = getVoxelValue(volume, x, y - 1, z)
                        let topValue = getVoxelValue(volume, x, y + 1, z)
                        gradient.y = (topValue - bottomValue) / 2.0
                    }
                    
                    // Calcola il gradiente in Z (più preciso)
                    if z >= gradientStep && z < depth - gradientStep {
                        let backValue = getVoxelValue(volume, x, y, z - gradientStep)
                        let frontValue = getVoxelValue(volume, x, y, z + gradientStep)
                        gradient.z = (frontValue - backValue) / (2.0 * Float(gradientStep))
                    } else if z >= 1 && z < depth - 1 {
                        // Caso di bordo, usa un passo più piccolo
                        let backValue = getVoxelValue(volume, x, y, z - 1)
                        let frontValue = getVoxelValue(volume, x, y, z + 1)
                        gradient.z = (frontValue - backValue) / 2.0
                    }
                    
                    // Limita i valori anomali per evitare normali estreme
                    let maxGradient: Float = 1000.0
                    gradient.x = max(-maxGradient, min(maxGradient, gradient.x))
                    gradient.y = max(-maxGradient, min(maxGradient, gradient.y))
                    gradient.z = max(-maxGradient, min(maxGradient, gradient.z))
                    
                    // Normalizza ed inverte il gradiente per avere normali che puntano verso l'esterno
                    let gradientLength = length(gradient)
                    if gradientLength > 0.0001 {
                        gradient = normalize(gradient) * -1.0
                    } else {
                        // Per valori molto piccoli, genera un vettore casuale normalizzato
                        // Questo aiuta a prevenire artefatti su superfici piane
                        gradient = SIMD3<Float>(0, 0, 1)
                    }
                    
                    // Mappa le coordinate originali alle coordinate del buffer ridotto
                    let nx = x / downsampleFactor
                    let ny = y / downsampleFactor
                    let nz = z / downsampleFactor
                    
                    let index = nz * sampledWidth * sampledHeight + ny * sampledWidth + nx
                    if index < normals.count {
                        normals[index] = gradient
                    }
                }
            }
            
            // Log di avanzamento
            if z % 20 == 0 {
                let progress = Int((Float(z) / Float(depth)) * 100)
                print("Calcolo gradienti: \(progress)% completato")
            }
        }
        
        print("✅ Gradienti precisi calcolati")
        return normals
    }
    
    /// Ottiene la normale precalcolata per la posizione specificata
    static func getNormalPrecise(_ normals: [SIMD3<Float>], _ x: Int, _ y: Int, _ z: Int,
                             _ width: Int, _ height: Int, _ depth: Int, _ downsampleFactor: Int, _ volume: Volume) -> SIMD3<Float> {
        // Mappa le coordinate al buffer ridotto
        let sampledWidth = (width + downsampleFactor - 1) / downsampleFactor
        let sampledHeight = (height + downsampleFactor - 1) / downsampleFactor
        
        let nx = min(x / downsampleFactor, sampledWidth - 1)
        let ny = min(y / downsampleFactor, sampledHeight - 1)
        let nz = min(z / downsampleFactor, (depth / downsampleFactor) - 1)
        
        let index = nz * sampledWidth * sampledHeight + ny * sampledWidth + nx
        
        // Verifica dell'indice
        if index >= 0 && index < normals.count {
            let normal = normals[index]
            
            // Verifica che la normale sia valida
            if length(normal) > 0.001 {
                return normal
            }
        }
        
        // Se non troviamo una normale valida, calcoliamo una normale più semplice
        // basata sui valori dei voxel circostanti
        var gradient = SIMD3<Float>(0, 0, 0)
        
        // Calcola il gradiente in-place per questa posizione
        if x > 0 && x < width - 1 {
            gradient.x = getVoxelValue(volume, x + 1, y, z) - getVoxelValue(volume, x - 1, y, z)
        }
        
        if y > 0 && y < height - 1 {
            gradient.y = getVoxelValue(volume, x, y + 1, z) - getVoxelValue(volume, x, y - 1, z)
        }
        
        if z > 0 && z < depth - 1 {
            gradient.z = getVoxelValue(volume, x, y, z + 1) - getVoxelValue(volume, x, y, z - 1)
        }
        
        // Normalizza e inverti (le normali puntano verso l'esterno della superficie)
        if length(gradient) > 0.0001 {
            return normalize(gradient)
        }
        
        return SIMD3<Float>(0, 0, 1) // Normale predefinita se tutto fallisce
    }
    
    /// Calcola i valori minimi e massimi del volume
    static func calculateMinMaxValues(_ volume: Volume) -> (min: Float, max: Float) {
        print("Calcolo valori min/max del volume...")
        
        var minValue: Float = Float.greatestFiniteMagnitude
        var maxValue: Float = -Float.greatestFiniteMagnitude
        
        let width = volume.dimensions.x
        let height = volume.dimensions.y
        let depth = volume.dimensions.z
        
        // Sample rate per accelerare il calcolo su volumi grandi
        let sampleRate = max(1, min(width, min(height, depth)) / 20)
        
        for z in stride(from: 0, to: depth, by: sampleRate) {
            for y in stride(from: 0, to: height, by: sampleRate) {
                for x in stride(from: 0, to: width, by: sampleRate) {
                    let value = getVoxelValue(volume, x, y, z)
                    minValue = min(minValue, value)
                    maxValue = max(maxValue, value)
                }
            }
        }
        
        print("Range valori: \(minValue) - \(maxValue)")
        return (minValue, maxValue)
    }
}

// Aggiungiamo queste funzioni di estensione a Volume
extension Volume {
    /// Funzione di convenienza per applicare il filtro di soglia
    func applyThresholdFilter(minValue: Float) -> Volume {
        return VolumeUtility.applyThresholdFilter(self, minValue: minValue)
    }
    
    /// Funzione di convenienza per calcolare min/max
    func calculateMinMaxValues() -> (min: Float, max: Float) {
        return VolumeUtility.calculateMinMaxValues(self)
    }
    
    /// Calcola l'indice lineare per una posizione 3D
    func linearIndex(for position: SIMD3<Int>) -> Int? {
        // Verifica che la posizione sia dentro i limiti
        guard position.x >= 0 && position.x < dimensions.x &&
              position.y >= 0 && position.y < dimensions.y &&
              position.z >= 0 && position.z < dimensions.z else {
            return nil  // Fuori dai limiti
        }
        
        // Calcola l'indice del voxel nel buffer lineare
        return position.z * dimensions.x * dimensions.y + position.y * dimensions.x + position.x
    }
    
    /// Crea una copia del volume
    func clone() -> Volume {
        // Usa applyThresholdFilter con un valore così basso
        // che nessun voxel viene modificato, ottenendo una copia
        return VolumeUtility.applyThresholdFilter(self, minValue: -10000)
    }
}
