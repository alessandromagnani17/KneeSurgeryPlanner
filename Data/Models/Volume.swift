/*
 Struttura che rappresenta un volume 3D (CT o MRI) generato da una serie DICOM.

 Proprietà principali:
 - dimensions, spacing, origin, data, bitsPerVoxel, type
 - volumeToWorldMatrix: Matrice di trasformazione 3D

 Funzionalità:
 - Crea un volume da una serie DICOM.
 - Accede ai valori dei voxel.

 Scopo:
 Gestisce e manipola volumi 3D ricostruiti da immagini DICOM.
 */

import Foundation
import simd

struct Volume {
    enum VolumeType {
        case ct
        case mri
    }
    
    let dimensions: SIMD3<Int>          // Dimensioni del volume (width, height, depth)
    let spacing: SIMD3<Float>           // Spaziatura tra voxel in mm
    let origin: SIMD3<Float>            // Origine del volume nello spazio 3D
    let data: Data                      // Dati grezzi del volume
    let bitsPerVoxel: Int               // 8, 16, o 32 bit per voxel
    let type: VolumeType                // Tipo di volume (CT o MRI)
    
    // Matrice di trasformazione dal volume allo spazio del mondo
    var volumeToWorldMatrix: simd_float4x4
    
    // Crea un volume da una serie DICOM
    init?(from series: DICOMSeries) {
        guard !series.images.isEmpty,
              let firstImage = series.images.first else {
            print("❌ La serie non contiene immagini")
            return nil
        }
        
        // Controlla che tutte le immagini abbiano le stesse dimensioni
        let rows = firstImage.rows
        let columns = firstImage.columns
        
        for image in series.images {
            if image.rows != rows || image.columns != columns {
                print("❌ Dimensioni delle immagini inconsistenti nella serie")
                return nil
            }
        }
        
        let sortedImages = series.orderedImages
        let sliceCount = sortedImages.count
        
        // Verifica se abbiamo abbastanza slice per fare un volume 3D significativo
        if sliceCount < 3 {
            print("⚠️ Solo \(sliceCount) slice disponibili. Un volume 3D richiede almeno 3 slice per essere significativo.")
        }
        
        // Calcola la spaziatura
        let rowSpacing = firstImage.pixelSpacing.0
        let colSpacing = firstImage.pixelSpacing.1
        
        var sliceSpacing: Double
        if let thickness = series.sliceThickness {
            sliceSpacing = thickness
        } else if sliceCount > 1 {
            // Calcola la spaziatura tra slice se non è fornita direttamente
            sliceSpacing = abs(sortedImages[1].sliceLocation - sortedImages[0].sliceLocation)
        } else {
            // Default per serie con una sola immagine
            sliceSpacing = 1.0
        }
        
        print("ℹ️ Volume spacing: row=\(rowSpacing), col=\(colSpacing), slice=\(sliceSpacing)")
        
        // Verifica consistenza dello spacing tra slice
        if sliceCount > 2 {
            var spacingConsistent = true
            let expectedSpacing = sliceSpacing
            
            for i in 1..<sliceCount-1 {
                let actualSpacing = abs(sortedImages[i+1].sliceLocation - sortedImages[i].sliceLocation)
                let tolerance = expectedSpacing * 0.05  // Tolleranza del 5%
                
                if abs(actualSpacing - expectedSpacing) > tolerance {
                    print("⚠️ Spaziatura inconsistente delle slice: attesa \(expectedSpacing), trovata \(actualSpacing) all'indice \(i)")
                    spacingConsistent = false
                }
            }
            
            if !spacingConsistent {
                print("⚠️ Il volume ha spaziatura inconsistente delle slice. Il rendering potrebbe essere distorto.")
            }
        }
        
        // Calcola la dimensione totale del volume
        let bytesPerVoxel = firstImage.bitsAllocated / 8
        let pixelsPerSlice = rows * columns
        let expectedVolumeSize = pixelsPerSlice * sliceCount * bytesPerVoxel
        
        print("ℹ️ Creazione volume: \(columns)x\(rows)x\(sliceCount) pixels, \(bytesPerVoxel) bytes per voxel")
        print("ℹ️ Dimensione prevista volume: \(expectedVolumeSize) bytes")
        
        // Crea un buffer per i dati del volume
        var volumeData = Data(capacity: expectedVolumeSize)
        
        // Copia i dati delle immagini nel volume in ordine di posizione slice
        var totalDataSize = 0
        for image in sortedImages {
            // Verifica lunghezza dati
            let expectedSliceSize = pixelsPerSlice * bytesPerVoxel
            
            if image.pixelData.count < expectedSliceSize {
                print("⚠️ I dati della slice \(image.instanceNumber) sono più corti del previsto: \(image.pixelData.count) vs \(expectedSliceSize)")
                
                // Paddiamo con zeri se necessario
                var paddedData = image.pixelData
                let paddingSize = expectedSliceSize - image.pixelData.count
                paddedData.append(Data(count: paddingSize))
                volumeData.append(paddedData)
            } else if image.pixelData.count > expectedSliceSize {
                print("⚠️ I dati della slice \(image.instanceNumber) sono più lunghi del previsto: \(image.pixelData.count) vs \(expectedSliceSize)")
                
                // Tronchiamo i dati in eccesso
                volumeData.append(image.pixelData.prefix(expectedSliceSize))
            } else {
                // Dimensione corretta
                volumeData.append(image.pixelData)
            }
            
            totalDataSize += min(image.pixelData.count, expectedSliceSize)
        }
        
        print("ℹ️ Dimensione totale dei dati copiati: \(totalDataSize) bytes")
        print("ℹ️ Dimensione finale volumeData: \(volumeData.count) bytes")
        
        // Inizializza le proprietà del volume
        self.dimensions = SIMD3<Int>(columns, rows, sliceCount)
        self.spacing = SIMD3<Float>(Float(colSpacing), Float(rowSpacing), Float(sliceSpacing))
        self.origin = SIMD3<Float>(0, 0, 0) // Da calcolare in base ai metadati DICOM
        self.data = volumeData
        self.bitsPerVoxel = firstImage.bitsAllocated
        self.type = series.modality == "CT" ? .ct : .mri
        
        // Calcola la matrice di trasformazione dal volume allo spazio del mondo
        // Questa è una versione semplificata; la versione reale dovrebbe utilizzare
        // l'orientamento dell'immagine e la posizione dalle informazioni DICOM
        self.volumeToWorldMatrix = simd_float4x4(diagonal: SIMD4<Float>(
            spacing.x, spacing.y, spacing.z, 1.0
        ))
        
        // Debug: Analizza alcuni valori dal volume
        if self.bitsPerVoxel == 16 && !volumeData.isEmpty {
            self.data.withUnsafeBytes { rawBuffer in
                let int16Buffer = rawBuffer.bindMemory(to: Int16.self)
                
                let total = min(int16Buffer.count, 10)
                print("⚠️ DEBUG: Primi \(total) valori nel volume:")
                for i in 0..<total {
                    print("  [\(i)]: \(int16Buffer[i])")
                }
                
                // Analizza la prima slice
                if int16Buffer.count >= pixelsPerSlice {
                    var sum: Int = 0
                    var count: Int = 0
                    var min: Int16 = Int16.max
                    var max: Int16 = Int16.min
                    
                    for i in 0..<pixelsPerSlice {
                        let value = int16Buffer[i]
                        sum += Int(value)
                        count += 1
                        min = Swift.min(min, value)
                        max = Swift.max(max, value)
                    }
                    
                    let avg = count > 0 ? (sum / count) : 0
                    print("ℹ️ Statistiche prima slice - Min: \(min), Max: \(max), Avg: \(avg)")
                }
                
                // Verifica qualche valore dal centro del volume
                if sliceCount > 1 {
                    let middleSlice = sliceCount / 2
                    let middleOffset = middleSlice * pixelsPerSlice
                    let middleY = rows / 2
                    let middleX = columns / 2
                    
                    if int16Buffer.count >= middleOffset + middleY * columns + middleX {
                        let centerValue = int16Buffer[middleOffset + middleY * columns + middleX]
                        print("ℹ️ Valore centro volume [slice=\(middleSlice), x=\(middleX), y=\(middleY)]: \(centerValue)")
                    }
                }
            }
        }
    }
    
    // Accedi al valore di un voxel specifico
    func voxelValue(at position: SIMD3<Int>) -> Int? {
        guard position.x >= 0 && position.x < dimensions.x &&
              position.y >= 0 && position.y < dimensions.y &&
              position.z >= 0 && position.z < dimensions.z else {
            return nil  // Fuori dai limiti
        }
        
        let index = position.z * dimensions.x * dimensions.y + position.y * dimensions.x + position.x
        let bytesPerVoxel = bitsPerVoxel / 8
        let byteIndex = index * bytesPerVoxel
        
        guard byteIndex + bytesPerVoxel <= data.count else {
            return nil  // Indice non valido
        }
        
        if bitsPerVoxel == 8 {
            return Int(data[byteIndex])
        } else if bitsPerVoxel == 16 {
            let value = data[byteIndex..<(byteIndex + 2)].withUnsafeBytes { $0.load(as: UInt16.self) }
            return Int(value)
        } else {
            // Altri formati possono essere aggiunti secondo necessità
            return nil
        }
    }
    
    // Debugging: stampa valori campione dal volume
    func printDebugInfo() {
        print("\n--- DEBUG VOLUME INFO ---")
        print("Dimensions: \(dimensions.x) x \(dimensions.y) x \(dimensions.z)")
        print("Spacing: \(spacing.x) x \(spacing.y) x \(spacing.z)")
        print("Bits per voxel: \(bitsPerVoxel)")
        print("Volume data size: \(data.count) bytes")
        print("Expected data size: \(dimensions.x * dimensions.y * dimensions.z * (bitsPerVoxel / 8)) bytes")
        
        if bitsPerVoxel == 16 {
            data.withUnsafeBytes { rawBuffer in
                let int16Buffer = rawBuffer.bindMemory(to: Int16.self)
                
                // Campiona valori dal volume
                if int16Buffer.count > 0 {
                    print("\nSAMPLE VALUES:")
                    
                    // Centro di ciascuna slice
                    let centerX = dimensions.x / 2
                    let centerY = dimensions.y / 2
                    
                    for z in stride(from: 0, to: dimensions.z, by: max(1, dimensions.z / 5)) {
                        let idx = z * dimensions.x * dimensions.y + centerY * dimensions.x + centerX
                        if idx < int16Buffer.count {
                            print("Center of slice \(z): \(int16Buffer[idx])")
                        }
                    }
                    
                    // Valori lungo gli assi principali nella slice centrale
                    if dimensions.z > 0 {
                        let middleZ = dimensions.z / 2
                        let baseIdx = middleZ * dimensions.x * dimensions.y
                        
                        print("\nHORIZONTAL LINE (middle slice, middle row):")
                        for x in stride(from: 0, to: dimensions.x, by: max(1, dimensions.x / 10)) {
                            let idx = baseIdx + centerY * dimensions.x + x
                            if idx < int16Buffer.count {
                                print("[\(x),\(centerY),\(middleZ)] = \(int16Buffer[idx])")
                            }
                        }
                        
                        print("\nVERTICAL LINE (middle slice, middle column):")
                        for y in stride(from: 0, to: dimensions.y, by: max(1, dimensions.y / 10)) {
                            let idx = baseIdx + y * dimensions.x + centerX
                            if idx < int16Buffer.count {
                                print("[\(centerX),\(y),\(middleZ)] = \(int16Buffer[idx])")
                            }
                        }
                    }
                }
            }
        }
        
        print("--- END DEBUG INFO ---\n")
    }
}
