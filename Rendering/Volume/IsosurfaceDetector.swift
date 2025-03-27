import Foundation
import simd

class IsosurfaceDetector {
    // Rileva automaticamente i migliori valori di isosuperficie per un volume medicale
    static func detectOptimalIsovalues(volume: Volume, sampleCount: Int = 20, fullAnalysis: Bool = false) -> [Float] {
        print("🔍 Iniziando rilevamento isovalori ottimali...")
        let startTime = Date()
        
        // Dimensioni volume
        let width = volume.dimensions.x
        let height = volume.dimensions.y
        let depth = volume.dimensions.z
        
        // Usa un campionatore più sparso per velocizzare l'analisi
        let sampleRate = max(1, min(width, min(height, depth)) / sampleCount)
        
        print("📊 Analisi volume: dimensioni \(width)x\(height)x\(depth), campionamento ogni \(sampleRate) voxel")
        
        // Raccolta valori campionati
        var values: [Float] = []
        values.reserveCapacity(sampleCount * sampleCount * sampleCount)
        
        // Campiona il volume utilizzando più thread per velocizzare l'operazione
        DispatchQueue.concurrentPerform(iterations: depth / sampleRate) { zIndex in
            let z = zIndex * sampleRate
            if z >= depth { return }
            
            // Crea un array locale per ogni thread per evitare contese
            var localValues: [Float] = []
            localValues.reserveCapacity(width * height / (sampleRate * sampleRate))
            
            for y in stride(from: 0, to: height, by: sampleRate) {
                for x in stride(from: 0, to: width, by: sampleRate) {
                    if let value = volume.voxelValue(at: SIMD3<Int>(x, y, z)) {
                        localValues.append(Float(value))
                    }
                }
            }
            
            // Sincronizza l'accesso all'array globale
            DispatchQueue.main.sync {
                values.append(contentsOf: localValues)
            }
        }
        
        // Verifica se abbiamo raccolto abbastanza valori
        guard values.count > 100 else {
            print("⚠️ Campioni insufficienti per l'analisi (\(values.count))")
            return [0.0] // Valore di default
        }
        
        // Ordina i valori per calcolare i percentili
        values.sort()
        
        let min = values.first ?? 0
        let max = values.last ?? 0
        
        // Calcola i percentili chiave
        let p5 = percentile(values: values, percent: 5)
        let p25 = percentile(values: values, percent: 25)
        let p50 = percentile(values: values, percent: 50) // mediana
        let p75 = percentile(values: values, percent: 75)
        let p95 = percentile(values: values, percent: 95)
        
        print("📊 Statistiche volume:")
        print("  Range valori: \(min) - \(max)")
        print("  Percentili: P5=\(p5), P25=\(p25), P50=\(p50), P75=\(p75), P95=\(p95)")
        
        // Esegui un'analisi dell'istogramma per trovare i picchi significativi
        // Questa operazione è costosa, quindi la eseguiamo solo se fullAnalysis è true
        var additionalValues: [Float] = []
        
        if fullAnalysis && values.count > 1000 {
            print("📊 Esecuzione analisi avanzata dell'istogramma...")
            additionalValues = analyzeHistogram(values: values, bucketCount: 50)
        }
        
        // Determina valori di isosuperficie basati sul tipo di volume
        var isovalues: [Float] = []
        
        // Determina i valori suggeriti in base al tipo di volume
        if volume.type == .ct {
            // Per CT, usiamo valori specifici per diversi tessuti
            // Aria: -1000 HU
            // Grasso: -100 to -50 HU
            // Acqua: 0 HU
            // Tessuti molli: 20-80 HU
            // Osso: 400+ HU
            
            // Usa i valori più comuni per CT ma adattati al range trovato
            if min < -500 && max > 400 {
                // Range tipico di CT con aria e osso
                isovalues = [-600, -200, 30, 150, 400]
                print("🎯 Valori suggeriti per TC con range completo")
            } else if min < -100 && max > 100 {
                // Range parziale, probabilmente TC cerebrale o altro soft tissue
                isovalues = [-100, 0, 40, 80, 150]
                print("🎯 Valori suggeriti per TC con range soft tissue")
            } else {
                // Range atipico, usa i percentili
                isovalues = [p25, p50, p75]
                print("🎯 Valori suggeriti basati sui percentili (range CT atipico)")
            }
        } else {
            // Per MRI, usiamo principalmente i percentili
            isovalues = [p25, p50, p75]
            
            // Cerca di individuare il bordo tra sfondo e tessuto
            // (metodo euristico, potrebbe richiedere aggiustamenti)
            if p5 < p95 * 0.1 {
                // Probabilmente c'è un chiaro sfondo nero
                let backgroundThreshold = p5 + (p25 - p5) * 0.5
                isovalues.insert(backgroundThreshold, at: 0)
                print("🎯 Aggiunto valore di soglia per lo sfondo: \(backgroundThreshold)")
            }
            
            print("🎯 Valori suggeriti per MRI basati sui percentili")
        }
        
        // Aggiungi eventuali valori aggiuntivi trovati dall'analisi avanzata
        isovalues.append(contentsOf: additionalValues)
        
        print("✅ Rilevamento completato in \(Date().timeIntervalSince(startTime)) secondi")
        print("🎯 Isovalori suggeriti: \(isovalues)")
        
        return isovalues
    }
    
    // Calcola un percentile specifico da un array di valori ordinati
    private static func percentile(values: [Float], percent: Int) -> Float {
        let index = Int(Float(values.count) * Float(percent) / 100.0)
        return values[min(max(0, index), values.count - 1)]
    }
    
    // Analizza l'istogramma per trovare picchi significativi
    private static func analyzeHistogram(values: [Float], bucketCount: Int) -> [Float] {
        guard let minValue = values.first, let maxValue = values.last, minValue < maxValue else {
            return []
        }
        
        // Crea bucket per l'istogramma
        let range = maxValue - minValue
        let bucketSize = range / Float(bucketCount)
        var histogram = [Int](repeating: 0, count: bucketCount)
        
        // Popola l'istogramma
        for value in values {
            let bucketIndex = min(bucketCount - 1, Int((value - minValue) / bucketSize))
            histogram[bucketIndex] += 1
        }
        
        // Cerca i picchi locali (escludendo il primo e l'ultimo bucket)
        var peaks: [(index: Int, count: Int)] = []
        for i in 1..<(bucketCount-1) {
            if histogram[i] > histogram[i-1] && histogram[i] > histogram[i+1] &&
               histogram[i] > values.count / 50 {  // Escludi picchi insignificanti
                peaks.append((i, histogram[i]))
            }
        }
        
        // Ordina i picchi per grandezza e prendi i più significativi
        peaks.sort { $0.count > $1.count }
        let topPeaks = peaks.prefix(3)
        
        // Converte gli indici dei bucket nei valori corrispondenti
        return topPeaks.map { minValue + bucketSize * (Float($0.index) + 0.5) }
    }
    
    // Suggerisce un isovalue ottimale per un tipo specifico di tessuto
    static func suggestIsovalueForTissueType(volume: Volume, tissueType: TissueType) -> Float {
        let isovalues = detectOptimalIsovalues(volume: volume, fullAnalysis: false)
        
        switch tissueType {
        case .skin:
            return volume.type == .ct ? -200 : isovalues[0]
        case .bone:
            return volume.type == .ct ? 400 : isovalues.last ?? isovalues[0]
        case .brain:
            return volume.type == .ct ? 40 : isovalues[1]
        case .softTissue:
            return volume.type == .ct ? 100 : isovalues[1]
        case .auto:
            // Restituisce il valore più adatto in base al tipo di volume
            if volume.type == .ct {
                return 100  // Valore intermedio per soft tissue in CT
            } else {
                // Per MRI usa il percentile 50
                return isovalues.count > 1 ? isovalues[1] : isovalues[0]
            }
        }
    }
    
    static func suggestBrainIsovalues(volume: Volume) -> [Float] {
        print("🧠 Rilevamento valori ottimali per tessuto cerebrale...")
        
        // Campiona il volume per creare un istogramma
        let sampleRate = 8 // Campiona ogni 8 voxel per velocità
        var values: [Float] = []
        let width = volume.dimensions.x
        let height = volume.dimensions.y
        let depth = volume.dimensions.z
        
        // Campionamento più denso nella regione centrale (dove è più probabile ci sia il cervello)
        let centerX = width / 2
        let centerY = height / 2
        let centerZ = depth / 2
        let radius = min(width, min(height, depth)) / 3
        
        print("📊 Campionamento volume cerebrale...")
        
        for z in stride(from: 0, to: depth, by: sampleRate) {
            for y in stride(from: 0, to: height, by: sampleRate) {
                for x in stride(from: 0, to: width, by: sampleRate) {
                    // Calcola distanza dal centro
                    let dx = x - centerX
                    let dy = y - centerY
                    let dz = z - centerZ
                    let distanceSquared = dx*dx + dy*dy + dz*dz
                    
                    // Campiona più densamente vicino al centro
                    if distanceSquared <= radius*radius || Int.random(in: 0...10) == 0 {
                        if let value = volume.voxelValue(at: SIMD3<Int>(x, y, z)) {
                            values.append(Float(value))
                        }
                    }
                }
            }
        }
        
        guard !values.isEmpty else {
            print("⚠️ Nessun valore trovato nel campionamento")
            return [0.0]
        }
        
        // Ordina i valori e trova percentili significativi
        values.sort()
        
        let minVal = values.first!
        let maxVal = values.last!
        let p5 = values[Int(Float(values.count) * 0.05)]
        let p25 = values[Int(Float(values.count) * 0.25)]
        let p50 = values[Int(Float(values.count) * 0.5)]
        let p75 = values[Int(Float(values.count) * 0.75)]
        let p95 = values[Int(Float(values.count) * 0.95)]
        
        print("📊 Analisi valori cerebrali:")
        print("  Range: \(minVal) - \(maxVal)")
        print("  Percentili: P5=\(p5), P25=\(p25), P50=\(p50), P75=\(p75), P95=\(p95)")
        
        // Selezione valori specifici per il cervello basati sul tipo di scansione
        var brainIsovalues: [Float] = []
        
        if volume.type == .ct {
            // Per TC cerebrale:
            // ~0-20 HU: Liquido cerebrospinale
            // ~20-40 HU: Materia grigia
            // ~40-60 HU: Materia bianca
            // Solitamente usiamo valori tra 30-50 per il tessuto cerebrale in TC
            brainIsovalues = [30, 45, 60]
            print("🧠 TC cerebrale rilevata: valori suggeriti = \(brainIsovalues)")
        } else {
            // Per RM, i valori dipendono fortemente dalla sequenza
            // Usiamo un approccio basato sui percentili
            // Escludiamo valori bassi che sono spesso rumore di fondo
            let threshold = p25 + (p50 - p25) * 0.5
            brainIsovalues = [threshold, p50, p75]
            print("🧠 RM cerebrale rilevata: valori suggeriti = \(brainIsovalues)")
        }
        
        return brainIsovalues
    }
    
    // Tipi di tessuto che possono essere visualizzati
    enum TissueType {
        case skin
        case bone
        case brain
        case softTissue
        case auto
    }
}
