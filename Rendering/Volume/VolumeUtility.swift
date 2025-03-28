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
    
    /// Calcola gradienti semplificati per il volume (usati per le normali)
    static func calculateSimplifiedGradients(volume: Volume, downsampleFactor: Int) -> [SIMD3<Float>] {
        let width = volume.dimensions.x
        let height = volume.dimensions.y
        let depth = volume.dimensions.z
        
        // Riduci il numero di normali da calcolare usando il fattore di downsample
        let sampledWidth = (width + downsampleFactor - 1) / downsampleFactor
        let sampledHeight = (height + downsampleFactor - 1) / downsampleFactor
        let sampledDepth = (depth + downsampleFactor - 1) / downsampleFactor
        
        print("📊 Dimensioni gradienti ridotte: \(sampledWidth)x\(sampledHeight)x\(sampledDepth)")
        
        var normals = [SIMD3<Float>](repeating: SIMD3<Float>(0, 0, 0),
                                     count: sampledWidth * sampledHeight * sampledDepth)
        
        // Utilizza un passo di campionamento ancora più grande per velocizzare ulteriormente
        let gradientStep = downsampleFactor * 2
        
        for z in stride(from: 0, to: depth, by: gradientStep) {
            for y in stride(from: 0, to: height, by: gradientStep) {
                for x in stride(from: 0, to: width, by: gradientStep) {
                    // Calcola il gradiente usando le differenze centrali con step più grandi
                    var gradient = SIMD3<Float>(0, 0, 0)
                    
                    // Calcola il gradiente in X
                    if x > gradientStep && x < width - gradientStep {
                        let leftValue = getVoxelValue(volume, x - gradientStep, y, z)
                        let rightValue = getVoxelValue(volume, x + gradientStep, y, z)
                        gradient.x = rightValue - leftValue
                    }
                    
                    // Calcola il gradiente in Y
                    if y > gradientStep && y < height - gradientStep {
                        let bottomValue = getVoxelValue(volume, x, y - gradientStep, z)
                        let topValue = getVoxelValue(volume, x, y + gradientStep, z)
                        gradient.y = topValue - bottomValue
                    }
                    
                    // Calcola il gradiente in Z
                    if z > gradientStep && z < depth - gradientStep {
                        let backValue = getVoxelValue(volume, x, y, z - gradientStep)
                        let frontValue = getVoxelValue(volume, x, y, z + gradientStep)
                        gradient.z = frontValue - backValue
                    }
                    
                    // Normalizza ed inverte il gradiente per avere normali che puntano verso l'esterno
                    if length(gradient) > 0.0001 {
                        gradient = normalize(gradient) * -1.0
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
        }
        
        return normals
    }
    
    /// Ottiene la normale precalcolata per la posizione specificata
    static func getNormalSimplified(_ normals: [SIMD3<Float>], _ x: Int, _ y: Int, _ z: Int,
                              _ width: Int, _ height: Int, _ depth: Int, _ downsampleFactor: Int) -> SIMD3<Float> {
        // Mappa le coordinate al buffer ridotto
        let sampledWidth = (width + downsampleFactor - 1) / downsampleFactor
        let sampledHeight = (height + downsampleFactor - 1) / downsampleFactor
        
        let nx = min(x / downsampleFactor, sampledWidth - 1)
        let ny = min(y / downsampleFactor, sampledHeight - 1)
        let nz = min(z / downsampleFactor, (depth / downsampleFactor) - 1)
        
        let index = nz * sampledWidth * sampledHeight + ny * sampledWidth + nx
        
        // Verifica dell'indice
        if index >= 0 && index < normals.count {
            return normals[index]
        }
        
        return SIMD3<Float>(0, 0, 1) // Normale predefinita
    }
}
