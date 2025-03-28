/*
 Struttura che rappresenta un volume 3D generato da una serie DICOM.

 Proprietà principali:
 - dimensions: Dimensioni del volume (larghezza, altezza, profondità)
 - spacing: Spaziatura tra voxel in millimetri
 - origin: Origine del volume nello spazio 3D
 - data: Dati grezzi del volume (valori dei voxel)
 - bitsPerVoxel: Numero di bit per voxel (8, 16, 32 bit)
 - type: Tipo di volume (CT o MRI)
 - volumeToWorldMatrix: Matrice di trasformazione 3D (dal volume allo spazio del mondo)
 - windowCenter, windowWidth: Parametri di windowing per TC
 - rescaleSlope, rescaleIntercept: Parametri di trasformazione per TC

 Funzionalità:
 - Crea un volume 3D a partire da una serie di immagini DICOM
 - Permette di accedere ai valori dei voxel

 Scopo:
 Gestire e manipolare volumi 3D ricostruiti da immagini DICOM.
 */

import Foundation
import simd

// Struttura Volume per rappresentare un volume 3D
struct Volume {
    enum VolumeType {
        case ct
        case mri
    }
    
    // Proprietà del volume
    let dimensions: SIMD3<Int>          // Dimensioni del volume (width, height, depth)
    let spacing: SIMD3<Float>           // Spaziatura tra voxel in mm (x, y, z)
    let origin: SIMD3<Float>            // Origine del volume nello spazio 3D
    let data: Data                      // Dati grezzi del volume (voxel)
    let bitsPerVoxel: Int               // Numero di bit per voxel (8, 16, 32 bit)
    let type: VolumeType                // Tipo di volume (CT o MRI)
    
    // Matrice di trasformazione dal volume allo spazio del mondo
    var volumeToWorldMatrix: simd_float4x4
    
    // Parametri DICOM specifici
    let windowCenter: Double?          // Centro della finestra per TC
    let windowWidth: Double?           // Ampiezza della finestra per TC
    let rescaleSlope: Double?          // Pendenza di riscalaggio per TC
    let rescaleIntercept: Double?      // Intercetta di riscalaggio per TC
    
    // Inizializzatore per creare un volume a partire da una serie DICOM
    init?(from series: DICOMSeries) {
        guard !series.images.isEmpty, let firstImage = series.images.first else {
            print("La serie non contiene immagini")
            return nil
        }
        
        // Controlla che tutte le immagini abbiano le stesse dimensioni
        let rows = firstImage.rows
        let columns = firstImage.columns
        
        for image in series.images {
            if image.rows != rows || image.columns != columns {
                print("Dimensioni delle immagini inconsistenti nella serie")
                return nil
            }
        }
        
        let sortedImages = series.orderedImages
        let sliceCount = sortedImages.count
        
        // Verifica che ci siano abbastanza slice per formare un volume 3D significativo
        if sliceCount < 3 {
            print("Solo \(sliceCount) slice disponibili. Un volume 3D richiede almeno 3 slice.")
        }
        
        // Calcola la spaziatura tra i voxel (in pixel)
        let rowSpacing = firstImage.pixelSpacing.0
        let colSpacing = firstImage.pixelSpacing.1
        
        // Calcola la spaziatura tra le slice
        var sliceSpacing: Double
        if let thickness = series.sliceThickness {
            sliceSpacing = thickness
        } else if sliceCount > 1 {
            sliceSpacing = abs(sortedImages[1].sliceLocation - sortedImages[0].sliceLocation)
        } else {
            sliceSpacing = 1.0  // Default per una sola immagine
        }
        
        // Verifica consistenza dello spacing tra le slice
        if sliceCount > 2 {
            var spacingConsistent = true
            let expectedSpacing = sliceSpacing
            
            for i in 1..<sliceCount-1 {
                let actualSpacing = abs(sortedImages[i+1].sliceLocation - sortedImages[i].sliceLocation)
                let tolerance = expectedSpacing * 0.05  // Tolleranza del 5%
                
                if abs(actualSpacing - expectedSpacing) > tolerance {
                    print("Spaziatura inconsistente delle slice: attesa \(expectedSpacing), trovata \(actualSpacing) all'indice \(i)")
                    spacingConsistent = false
                }
            }
            
            if !spacingConsistent {
                print("Il volume ha spaziatura inconsistente delle slice.")
            }
        }
        
        // Calcola la dimensione totale del volume in byte
        let bytesPerVoxel = firstImage.bitsAllocated / 8
        let pixelsPerSlice = rows * columns
        let expectedVolumeSize = pixelsPerSlice * sliceCount * bytesPerVoxel
        
        // Crea un buffer per i dati del volume
        var volumeData = Data(capacity: expectedVolumeSize)
        
        // Copia i dati delle immagini nel buffer volume
        var totalDataSize = 0
        for image in sortedImages {
            let expectedSliceSize = pixelsPerSlice * bytesPerVoxel
            
            if image.pixelData.count < expectedSliceSize {
                // Padding con zeri se i dati sono più corti
                var paddedData = image.pixelData
                let paddingSize = expectedSliceSize - image.pixelData.count
                paddedData.append(Data(count: paddingSize))
                volumeData.append(paddedData)
            } else if image.pixelData.count > expectedSliceSize {
                // Tronca i dati in eccesso
                volumeData.append(image.pixelData.prefix(expectedSliceSize))
            } else {
                volumeData.append(image.pixelData)  // Dati corretti
            }
            
            totalDataSize += min(image.pixelData.count, expectedSliceSize)
        }
        
        // Usa i valori di WindowCenter e WindowWidth dai metadati
        self.windowCenter = firstImage.windowCenter
        self.windowWidth = firstImage.windowWidth
        
        // Parametri di scala per convertire in unità Hounsfield per TC
        self.rescaleSlope = firstImage.rescaleSlope
        self.rescaleIntercept = firstImage.rescaleIntercept
        
        // Inizializza le proprietà del volume
        self.dimensions = SIMD3<Int>(columns, rows, sliceCount)
        self.spacing = SIMD3<Float>(Float(colSpacing), Float(rowSpacing), Float(sliceSpacing))
        self.data = volumeData
        self.bitsPerVoxel = firstImage.bitsAllocated
        self.type = series.modality == "CT" ? .ct : .mri
        
        // Determina l'origine e l'orientamento del volume
        if let imagePosition = firstImage.imagePositionPatient,
           let imageOrientation = firstImage.imageOrientationPatient {
            // Estrai la posizione dell'immagine (punto in alto a sinistra della prima slice)
            let position = SIMD3<Float>(Float(imagePosition.0), Float(imagePosition.1), Float(imagePosition.2))
            
            // Estrai l'orientamento dell'immagine (prime due righe della matrice di orientamento)
            let rowDirectionCosines = SIMD3<Float>(Float(imageOrientation.0), Float(imageOrientation.1), Float(imageOrientation.2))
            let colDirectionCosines = SIMD3<Float>(Float(imageOrientation.3), Float(imageOrientation.4), Float(imageOrientation.5))
            
            // Calcola il vettore di direzione della slice come prodotto vettoriale normalizzato
            let sliceDirection = normalize(cross(rowDirectionCosines, colDirectionCosines))
            
            // Costruisci la matrice di orientamento
            var orientationMatrix = simd_float4x4(diagonal: SIMD4<Float>(1, 1, 1, 1))
            orientationMatrix.columns.0 = SIMD4<Float>(rowDirectionCosines * spacing.x, 0)
            orientationMatrix.columns.1 = SIMD4<Float>(colDirectionCosines * spacing.y, 0)
            orientationMatrix.columns.2 = SIMD4<Float>(sliceDirection * spacing.z, 0)
            orientationMatrix.columns.3 = SIMD4<Float>(position, 1)
            
            self.origin = position
            self.volumeToWorldMatrix = orientationMatrix
        } else {
            // Fallback se i metadati di orientamento non sono disponibili
            self.origin = SIMD3<Float>(0, 0, 0)
            self.volumeToWorldMatrix = simd_float4x4(diagonal: SIMD4<Float>(
                spacing.x, spacing.y, spacing.z, 1.0
            ))
        }
        
        // Debug: Analizza alcuni valori dal volume
        if self.bitsPerVoxel == 16 && !volumeData.isEmpty {
            self.data.withUnsafeBytes { rawBuffer in
                let int16Buffer = rawBuffer.bindMemory(to: Int16.self)
                
                // Stampa i primi valori per il debug
                let total = min(int16Buffer.count, 10)
                print("DEBUG: Primi \(total) valori nel volume:")
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
                    
                    // Per TC, mostra anche i valori in unità Hounsfield
                    if self.type == .ct && self.rescaleSlope != nil && self.rescaleIntercept != nil {
                        let minHU = Double(min) * (self.rescaleSlope ?? 1.0) + (self.rescaleIntercept ?? 0.0)
                        let maxHU = Double(max) * (self.rescaleSlope ?? 1.0) + (self.rescaleIntercept ?? 0.0)
                        print("ℹ️ Range Hounsfield stimato: \(minHU) HU - \(maxHU) HU")
                    }
                }
            }
        }
    }
    
    // Costruttore specifico per inizializzazione da metadati DICOM
    init?(columns: Int, rows: Int, slices: Int, bitsStored: Int,
          windowCenter: Double?, windowWidth: Double?,
          sliceLocation: Double, modality: String, spacing: SIMD3<Float>? = nil) {
        
        // Dimensioni del volume
        self.dimensions = SIMD3<Int>(columns, rows, slices)
        
        // Parametri di windowing
        self.windowCenter = windowCenter
        self.windowWidth = windowWidth
        
        // Usa valori di rescale tipici per TC se non forniti
        self.rescaleSlope = 1.0
        self.rescaleIntercept = -1024.0 // Valore tipico per TC
        
        // Determina il tipo di volume
        self.type = modality == "CT" ? .ct : .mri
        
        // Usa spacing fornito o valore di default
        if let providedSpacing = spacing {
            self.spacing = providedSpacing
        } else {
            // Valori di default se non specificati
            self.spacing = SIMD3<Float>(1.0, 1.0, 1.0)
        }
        
        // Crea un buffer vuoto per i dati
        self.bitsPerVoxel = bitsStored
        let bytesPerVoxel = bitsStored / 8
        let totalSize = columns * rows * slices * bytesPerVoxel
        self.data = Data(count: totalSize)
        
        // Posizione di default
        self.origin = SIMD3<Float>(0, 0, Float(sliceLocation))
        
        // Matrice di trasformazione di default
        self.volumeToWorldMatrix = simd_float4x4(diagonal: SIMD4<Float>(
            self.spacing.x, self.spacing.y, self.spacing.z, 1.0
        ))
    }
    
    // Accedi al valore di un voxel in una posizione specifica
    func voxelValue(at position: SIMD3<Int>) -> Int? {
        // Verifica che la posizione sia dentro i limiti
        guard position.x >= 0 && position.x < dimensions.x &&
              position.y >= 0 && position.y < dimensions.y &&
              position.z >= 0 && position.z < dimensions.z else {
            return nil  // Fuori dai limiti
        }
        
        // Calcola l'indice del voxel nel buffer
        let index = position.z * dimensions.x * dimensions.y + position.y * dimensions.x + position.x
        let bytesPerVoxel = bitsPerVoxel / 8
        let byteIndex = index * bytesPerVoxel
        
        // Verifica che l'indice sia valido
        guard byteIndex + bytesPerVoxel <= data.count else {
            return nil  // Indice non valido
        }
        
        // Restituisce il valore del voxel in base al formato dei bit per voxel
        if bitsPerVoxel == 8 {
            return Int(data[byteIndex])
        } else if bitsPerVoxel == 16 {
            let value = data[byteIndex..<(byteIndex + 2)].withUnsafeBytes { $0.load(as: UInt16.self) }
            return Int(value)
        } else {
            return nil  // Formato non supportato
        }
    }
    
    // Funzione per ottenere il valore del voxel in unità Hounsfield (per TC)
    func hounsfieldValue(at position: SIMD3<Int>) -> Float? {
        guard let rawValue = voxelValue(at: position) else {
            return nil
        }
        
        if type == .ct {
            // Converti in unità Hounsfield usando i parametri di rescale
            let slope = Float(rescaleSlope ?? 1.0)
            let intercept = Float(rescaleIntercept ?? -1024.0)
            return Float(rawValue) * slope + intercept
        } else {
            // Per MRI o altre modalità, restituisci il valore così com'è
            return Float(rawValue)
        }
    }
    
    // Funzione di debug per stampare informazioni sul volume
    func printDebugInfo() {
        print("\n--- DEBUG VOLUME INFO ---")
        print("Dimensions: \(dimensions.x) x \(dimensions.y) x \(dimensions.z)")
        print("Spacing: \(spacing.x) x \(spacing.y) x \(spacing.z)")
        print("Bits per voxel: \(bitsPerVoxel)")
        print("Volume data size: \(data.count) bytes")
        print("Expected data size: \(dimensions.x * dimensions.y * dimensions.z * (bitsPerVoxel / 8)) bytes")
        
        if let windowCenter = windowCenter, let windowWidth = windowWidth {
            print("Window settings: Center=\(windowCenter), Width=\(windowWidth)")
        }
        
        if let rescaleSlope = rescaleSlope, let rescaleIntercept = rescaleIntercept {
            print("Rescale: Slope=\(rescaleSlope), Intercept=\(rescaleIntercept)")
        }
        
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
                            let raw = int16Buffer[idx]
                            print("Center of slice \(z): \(raw)")
                            
                            if type == .ct && rescaleSlope != nil {
                                let hu = Double(raw) * (rescaleSlope ?? 1.0) + (rescaleIntercept ?? 0.0)
                                print("  HU value: \(hu)")
                            }
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
