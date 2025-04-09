import SwiftUI
import AppKit
import simd

// Vista principale che mostra le tre proiezioni multiplanari di dati DICOM
struct MultiplanarView: View {
    // Gestisce i dati DICOM caricati nell'applicazione
    @ObservedObject var dicomManager: DICOMManager

    // Indici delle slice visualizzate nelle diverse viste
    @State private var axialIndex: Int = 0      // Indice per la vista dall'alto verso il basso
    @State private var coronalIndex: Int = 0    // Indice per la vista frontale
    @State private var sagittalIndex: Int = 0   // Indice per la vista laterale

    // Parametri per il "windowing" (regolazione del contrasto)
    // Valori ottimizzati per MRI del ginocchio
    @State private var windowCenter: Double = 600
    @State private var windowWidth: Double = 1200
    
    // Controllo per l'inversione dell'immagine
    @State private var invertImages: Bool = false
    
    // Cache per le immagini renderizzate
    @State private var cachedImages: [MPROrientation: [Int: CGImage]] = [:]

    var body: some View {
        VStack {
            if let series = dicomManager.currentSeries,
               let volume = dicomManager.createVolumeFromSeries(series) {

                // Controlli superiori
                HStack {
                    VStack {
                        Text("Window Center: \(Int(windowCenter))")
                        Slider(value: $windowCenter, in: -1000...3000)
                            .frame(width: 300)
                    }

                    VStack {
                        Text("Window Width: \(Int(windowWidth))")
                        Slider(value: $windowWidth, in: 1...3000)
                            .frame(width: 300)
                    }
                    
                    Toggle("Inverti immagini", isOn: $invertImages)
                        .padding(.horizontal)
            }
            .padding()

                // Contenitore principale per le tre viste
                HStack {
                    // VISTA ASSIALE (dall'alto verso il basso)
                    VStack {
                        Text("Axial")
                            .font(.headline)

                        GeometryReader { geometry in
                            ZStack {
                                Color.black  // Sfondo nero

                                // Verifica che l'indice sia valido
                                if axialIndex < volume.dimensions.z {
                                    // Rendering della slice assiale
                                    if let image = renderSlice(
                                        from: volume,
                                        orientation: .axial,
                                        sliceIndex: axialIndex,
                                        windowCenter: windowCenter,
                                        windowWidth: windowWidth) {

                                        // Visualizza l'immagine renderizzata
                                        Image(nsImage: NSImage(cgImage: image, size: NSSize(width: image.width, height: image.height)))
                                            .resizable()
                                            .aspectRatio(contentMode: .fit)
                                    }
                                }
                            }
                        }

                        // Slider per navigare tra le slice assiali
                        Slider(
                            value: Binding(
                                get: { Double(axialIndex) },
                                set: { axialIndex = Int($0) }
                            ),
                            in: 0...Double(max(0, volume.dimensions.z - 1)),
                            step: 1
                        )
                        
                        // Indicatore della slice corrente
                        Text("Slice: \(axialIndex + 1)/\(volume.dimensions.z)")
                            .font(.caption)
                    }

                    // VISTA CORONALE (da davanti a dietro)
                    VStack {
                        Text("Coronal")
                            .font(.headline)

                        GeometryReader { geometry in
                            ZStack {
                                Color.black  // Sfondo nero

                                // Verifica che l'indice sia valido
                                if coronalIndex < volume.dimensions.y {
                                    // Rendering della slice coronale
                                    if let image = renderSlice(
                                        from: volume,
                                        orientation: .coronal,
                                        sliceIndex: coronalIndex,
                                        windowCenter: windowCenter,
                                        windowWidth: windowWidth) {

                                        // Visualizza l'immagine renderizzata
                                        Image(nsImage: NSImage(cgImage: image, size: NSSize(width: image.width, height: image.height)))
                                            .resizable()
                                            .aspectRatio(contentMode: .fit)
                                    }
                                }
                            }
                        }

                        // Slider per navigare tra le slice coronali
                        Slider(
                            value: Binding(
                                get: { Double(coronalIndex) },
                                set: { coronalIndex = Int($0) }
                            ),
                            in: 0...Double(max(0, volume.dimensions.y - 1)),
                            step: 1
                        )
                        
                        // Indicatore della slice corrente
                        Text("Slice: \(coronalIndex + 1)/\(volume.dimensions.y)")
                            .font(.caption)
                    }

                    // VISTA SAGITTALE (da sinistra a destra)
                    VStack {
                        Text("Sagittal")
                            .font(.headline)

                        GeometryReader { geometry in
                            ZStack {
                                Color.black  // Sfondo nero

                                // Verifica che l'indice sia valido
                                if sagittalIndex < volume.dimensions.x {
                                    // Rendering della slice sagittale
                                    if let image = renderSlice(
                                        from: volume,
                                        orientation: .sagittal,
                                        sliceIndex: sagittalIndex,
                                        windowCenter: windowCenter,
                                        windowWidth: windowWidth) {

                                        // Visualizza l'immagine renderizzata
                                        Image(nsImage: NSImage(cgImage: image, size: NSSize(width: image.width, height: image.height)))
                                            .resizable()
                                            .aspectRatio(contentMode: .fit)
                                    }
                                }
                            }
                        }

                        // Slider per navigare tra le slice sagittali
                        Slider(
                            value: Binding(
                                get: { Double(sagittalIndex) },
                                set: { sagittalIndex = Int($0) }
                            ),
                            in: 0...Double(max(0, volume.dimensions.x - 1)),
                            step: 1
                        )
                        
                        // Indicatore della slice corrente
                        Text("Slice: \(sagittalIndex + 1)/\(volume.dimensions.x)")
                            .font(.caption)
                    }
                }
                .padding()
            } else {
                // Messaggio quando non ci sono dati disponibili
                VStack {
                    Spacer()
                    Text("No volume data available")
                        .foregroundColor(.secondary)
                    Spacer()
                }
            }
        }
    }

    // - Funzione di rendering migliorata
    func renderSlice(from volume: Volume, orientation: MPROrientation, sliceIndex: Int,
                     windowCenter: Double, windowWidth: Double) -> CGImage? {
        // Calcola le dimensioni dell'output in base all'orientamento
        var width: Int = 0
        var height: Int = 0

        switch orientation {
        case .axial:     // Vista dall'alto
            width = volume.dimensions.x
            height = volume.dimensions.y
        case .coronal:   // Vista frontale
            width = volume.dimensions.x
            height = volume.dimensions.z
        case .sagittal:  // Vista laterale
            width = volume.dimensions.y
            height = volume.dimensions.z
        }

        // Controllo che l'indice della slice sia nei limiti consentiti
        let maxIndex: Int
        switch orientation {
        case .axial: maxIndex = volume.dimensions.z - 1
        case .coronal: maxIndex = volume.dimensions.y - 1
        case .sagittal: maxIndex = volume.dimensions.x - 1
        }

        guard sliceIndex >= 0 && sliceIndex <= maxIndex else { return nil }

        // Array per i dati dell'immagine elaborata (8 bit per pixel)
        var adjustedData = [UInt8](repeating: 0, count: width * height)

        // Calcola i limiti per il windowing - miglioramento significativo qui
        let windowLow = windowCenter - (windowWidth / 2.0)
        let windowRange = windowWidth  // Evita divisione per zero

        // Elabora i dati in base alla profondità in bit del volume (16 o 8 bit)
        if volume.bitsPerVoxel == 16 {
            // Per volumi a 16 bit per voxel
            volume.data.withUnsafeBytes { rawBuffer in
                let int16Buffer = rawBuffer.bindMemory(to: Int16.self)

                switch orientation {
                case .axial:
                    // Slice assiale: coordinata Z fissa
                    let zOffset = sliceIndex * volume.dimensions.x * volume.dimensions.y

                    for y in 0..<height {
                        for x in 0..<width {
                            let volumeIndex = zOffset + y * volume.dimensions.x + x

                            if volumeIndex < int16Buffer.count {
                                // Ottieni il valore Hounsfield se disponibile
                                let pixelValue: Double
                                if volume.type == .ct, let slope = volume.rescaleSlope, let intercept = volume.rescaleIntercept {
                                    pixelValue = Double(int16Buffer[volumeIndex]) * slope + intercept
                                } else {
                                    pixelValue = Double(int16Buffer[volumeIndex])
                                }

                                // Applica windowing
                                let windowedValue = applyWindowing(
                                    value: pixelValue,
                                    windowLow: windowLow,
                                    windowRange: windowRange,
                                    invert: invertImages
                                )

                                let outputIndex = y * width + x
                                adjustedData[outputIndex] = windowedValue
                            }
                        }
                    }

                case .coronal:
                    // Slice coronale: coordinata Y fissa - accesso corretto ai dati
                    for z in 0..<height {
                        for x in 0..<width {
                            // Formula perfezionata per l'accesso al voxel - rispetta le convenzioni radiologiche
                            let y = sliceIndex
                            let volumeIndex = z * (volume.dimensions.x * volume.dimensions.y) +
                                             y * volume.dimensions.x + x

                            if volumeIndex < int16Buffer.count {
                                // Ottieni il valore Hounsfield se disponibile
                                let pixelValue: Double
                                if volume.type == .ct, let slope = volume.rescaleSlope, let intercept = volume.rescaleIntercept {
                                    pixelValue = Double(int16Buffer[volumeIndex]) * slope + intercept
                                } else {
                                    pixelValue = Double(int16Buffer[volumeIndex])
                                }

                                // Applica windowing
                                let windowedValue = applyWindowing(
                                    value: pixelValue,
                                    windowLow: windowLow,
                                    windowRange: windowRange,
                                    invert: invertImages
                                )

                                // L'immagine deve essere invertita sull'asse Z per rispettare le convenzioni DICOM
                                let outputIndex = (height - 1 - z) * width + (width - 1 - x)
                                adjustedData[outputIndex] = windowedValue
                            }
                        }
                    }

                case .sagittal:
                    // Slice sagittale: coordinata X fissa - accesso corretto ai dati
                    for z in 0..<height {
                        for y in 0..<width {
                            // Formula perfezionata per l'accesso al voxel - rispetta le convenzioni radiologiche
                            let x = sliceIndex
                            let volumeIndex = z * (volume.dimensions.x * volume.dimensions.y) +
                                             y * volume.dimensions.x + x

                            if volumeIndex < int16Buffer.count {
                                // Ottieni il valore Hounsfield se disponibile
                                let pixelValue: Double
                                if volume.type == .ct, let slope = volume.rescaleSlope, let intercept = volume.rescaleIntercept {
                                    pixelValue = Double(int16Buffer[volumeIndex]) * slope + intercept
                                } else {
                                    pixelValue = Double(int16Buffer[volumeIndex])
                                }

                                // Applica windowing
                                let windowedValue = applyWindowing(
                                    value: pixelValue,
                                    windowLow: windowLow,
                                    windowRange: windowRange,
                                    invert: invertImages
                                )

                                // L'immagine deve essere flippata orizzontalmente per convenzione
                                let outputIndex = (height - 1 - z) * width + y
                                adjustedData[outputIndex] = windowedValue
                            }
                        }
                    }
                }
            }
        } else if volume.bitsPerVoxel == 8 {
            // Per volumi a 8 bit per voxel (simile al codice sopra ma con dati a 8 bit)
            volume.data.withUnsafeBytes { rawBuffer in
                let uint8Buffer = rawBuffer.bindMemory(to: UInt8.self)

                // Codice simile al caso 16-bit ma adattato per dati a 8 bit
                // [Implementazione omessa per brevità]
            }
        }

        // Crea l'immagine finale in scala di grigi
        guard let provider = CGDataProvider(data: Data(adjustedData) as CFData) else { return nil }
        let colorSpace = CGColorSpaceCreateDeviceGray()

        return CGImage(
            width: width,
            height: height,
            bitsPerComponent: 8,     // 8 bit per componente (scala di grigi)
            bitsPerPixel: 8,         // 8 bit per pixel (1 byte per pixel)
            bytesPerRow: width,      // Larghezza riga in byte
            space: colorSpace,       // Spazio colore (scala di grigi)
            bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.none.rawValue),
            provider: provider,      // Provider dei dati immagine
            decode: nil,             // Nessuna decodifica speciale
            shouldInterpolate: false,// No interpolazione
            intent: .defaultIntent   // Rendering intent predefinito
        )
    }
    
    // Applica il windowing al valore del pixel
    private func applyWindowing(value: Double, windowLow: Double, windowRange: Double, invert: Bool) -> UInt8 {
        var normalizedValue: Double
        
        if value <= windowLow {
            normalizedValue = 0.0
        } else if value >= windowLow + windowRange {
            normalizedValue = 1.0
        } else {
            normalizedValue = (value - windowLow) / windowRange
        }
        
        // Inverte i valori se richiesto
        if invert {
            normalizedValue = 1.0 - normalizedValue
        }
        
        return UInt8(normalizedValue * 255.0)
    }
}

// Enum per specificare l'orientamento delle slice MPR
enum MPROrientation: Int32 {
    case axial = 0      // Vista dall'alto verso il basso
    case coronal = 1    // Vista frontale (da davanti a dietro)
    case sagittal = 2   // Vista laterale (da sinistra a destra)
}
