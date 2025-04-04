import SwiftUI
import AppKit
import simd

// View principale che mostra le tre proiezioni multiplanari di dati DICOM
struct MultiplanarView: View {
    // Gestisce i dati DICOM caricati nell'applicazione
    @ObservedObject var dicomManager: DICOMManager
    
    // Gestore dei piani chirurgici (passato dalla vista principale)
    @ObservedObject var planningManager: SurgicalPlanningManager
    
    // Indici delle slice visualizzate nelle diverse viste
    @State private var axialIndex: Int = 0      // Indice per la vista dall'alto verso il basso
    @State private var coronalIndex: Int = 0    // Indice per la vista frontale
    @State private var sagittalIndex: Int = 0   // Indice per la vista laterale
    
    // Parametri per il "windowing" (regolazione del contrasto)
    @State private var windowCenter: Double = 1100   // Centro della finestra (livello grigio medio)
    @State private var windowWidth: Double = 400   // Ampiezza della finestra (definisce il contrasto)
    
    // Controllo visualizzazione piani
    @State private var showPlanes: Bool = true
    
    var body: some View {
        VStack {
            // Verifica se esiste una serie DICOM e se è possibile creare un volume 3D
            if let series = dicomManager.currentSeries,
               let volume = dicomManager.createVolumeFromSeries(series) {

                // Controlli per la regolazione del windowing
                HStack {
                    // Slider per regolare il centro della finestra di visualizzazione
                    VStack {
                        Text("Window Center: \(Int(windowCenter))")
                            .frame(maxWidth: .infinity, alignment: .center) // Centra il testo orizzontalmente
                        Slider(value: $windowCenter, in: -1000...2000)
                            .frame(width: 300) // Imposta la larghezza dello slider
                    }

                    // Slider per regolare l'ampiezza della finestra di visualizzazione
                    VStack {
                        Text("Window Width: \(Int(windowWidth))")
                            .frame(maxWidth: .infinity, alignment: .center) // Centra il testo orizzontalmente
                        Slider(value: $windowWidth, in: 1...2000)
                            .frame(width: 300) // Imposta la larghezza dello slider
                    }
                    
                    // Toggle per mostrare/nascondere i piani chirurgici
                    Toggle("Mostra Piani", isOn: $showPlanes)
                        .frame(width: 150)
                    
                    Spacer()
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
                                    
                                    // Visualizza le intersezioni dei piani chirurgici se attivato
                                    if showPlanes {
                                        planeIntersectionsView(
                                            orientation: .axial,
                                            sliceIndex: axialIndex,
                                            volume: volume,
                                            planningManager: planningManager
                                        )
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
                                    // Visualizza le intersezioni dei piani chirurgici se attivato
                                    if showPlanes {
                                        planeIntersectionsView(
                                            orientation: .coronal,
                                            sliceIndex: coronalIndex,
                                            volume: volume,
                                            planningManager: planningManager
                                        )
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
                                    // Visualizza le intersezioni dei piani chirurgici se attivato
                                    if showPlanes {
                                        planeIntersectionsView(
                                            orientation: .sagittal,
                                            sliceIndex: sagittalIndex,
                                            volume: volume,
                                            planningManager: planningManager
                                        )
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

    // - Funzione di rendering
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

        // Calcola il limite inferiore per il windowing
        let lowerBound = windowCenter - (windowWidth / 2)

        // Elabora i dati in base alla profondità in bit del volume (16 o 8 bit)
        if volume.bitsPerVoxel == 16 {
            // Per volumi a 16 bit per voxel
            volume.data.withUnsafeBytes { rawBuffer in
                let int16Buffer = rawBuffer.bindMemory(to: Int16.self)

                switch orientation {
                case .axial:
                    // Slice assiale: coordinata Z fissa
                    let sliceOffset = sliceIndex * width * height
                    
                    for y in 0..<height {
                        for x in 0..<width {
                            let volumeIndex = sliceOffset + y * width + x
                            
                            if volumeIndex < int16Buffer.count {
                                // Applica il windowing per convertire da 16 bit a 8 bit
                                let value = Double(int16Buffer[volumeIndex])
                                let windowedValue = max(0, min(255, 255 * (value - lowerBound) / windowWidth))
                                adjustedData[y * width + x] = UInt8(windowedValue)
                            }
                        }
                    }
                    
                case .coronal:
                    // Slice coronale: coordinata Y fissa
                    for z in 0..<height {  // Usiamo height invece di volume.dimensions.z
                        for x in 0..<width {  // Usiamo width invece di volume.dimensions.x
                            // Formula corretta per accedere al voxel nel volume
                            let volumeIndex = z * (volume.dimensions.x * volume.dimensions.y) +
                            sliceIndex * volume.dimensions.x + x
                            
                            if volumeIndex < int16Buffer.count {
                                // Applica il windowing per convertire da 16 bit a 8 bit
                                let value = Double(int16Buffer[volumeIndex])
                                let windowedValue = max(0, min(255, 255 * (value - lowerBound) / windowWidth))
                                
                                // Invertiamo l'asse z per correggere l'orientamento verticale
                                let outputIndex = (height - 1 - z) * width + x
                                
                                // Verifica che l'indice sia all'interno dei limiti dell'array
                                if outputIndex >= 0 && outputIndex < adjustedData.count {
                                    adjustedData[outputIndex] = UInt8(windowedValue)
                                }
                            }
                        }
                    }
                    
                case .sagittal:
                    // Slice sagittale: coordinata X fissa
                    for z in 0..<height {  // Usiamo height invece di volume.dimensions.z
                        for y in 0..<width {  // Usiamo width invece di volume.dimensions.y
                            // Formula corretta per accedere al voxel nel volume
                            let volumeIndex = z * (volume.dimensions.x * volume.dimensions.y) +
                            y * volume.dimensions.x + sliceIndex
                            
                            if volumeIndex < int16Buffer.count {
                                // Applica il windowing per convertire da 16 bit a 8 bit
                                let value = Double(int16Buffer[volumeIndex])
                                let windowedValue = max(0, min(255, 255 * (value - lowerBound) / windowWidth))
                                
                                // Invertiamo l'asse z per correggere l'orientamento verticale
                                let outputIndex = (height - 1 - z) * width + y
                                
                                // Verifica che l'indice sia all'interno dei limiti dell'array
                                if outputIndex >= 0 && outputIndex < adjustedData.count {
                                    adjustedData[outputIndex] = UInt8(windowedValue)
                                }
                            }
                        }
                    }
                }
            }
        } else if volume.bitsPerVoxel == 8 {
            // Per volumi a 8 bit per voxel (simile al codice sopra ma con dati a 8 bit)
            volume.data.withUnsafeBytes { rawBuffer in
                let uint8Buffer = rawBuffer.bindMemory(to: UInt8.self)

                switch orientation {
                case .axial:
                    let sliceOffset = sliceIndex * width * height

                    for y in 0..<height {
                        for x in 0..<width {
                            let volumeIndex = sliceOffset + y * width + x

                            if volumeIndex < uint8Buffer.count {
                                // Applica il windowing sui dati a 8 bit
                                let value = Double(uint8Buffer[volumeIndex])
                                let windowedValue = max(0, min(255, 255 * (value - lowerBound) / windowWidth))
                                adjustedData[y * width + x] = UInt8(windowedValue)
                            }
                        }
                    }

                case .coronal:
                    for z in 0..<height {  // Usiamo height invece di volume.dimensions.z
                        for x in 0..<width {  // Usiamo width invece di volume.dimensions.x
                            let volumeIndex = z * (volume.dimensions.x * volume.dimensions.y) +
                                            sliceIndex * volume.dimensions.x + x

                            if volumeIndex < uint8Buffer.count {
                                // Applica il windowing sui dati a 8 bit
                                let value = Double(uint8Buffer[volumeIndex])
                                let windowedValue = max(0, min(255, 255 * (value - lowerBound) / windowWidth))
                                
                                // Invertiamo l'asse z per correggere l'orientamento verticale
                                let outputIndex = (height - 1 - z) * width + x
                                
                                if outputIndex >= 0 && outputIndex < adjustedData.count {
                                    adjustedData[outputIndex] = UInt8(windowedValue)
                                }
                            }
                        }
                    }

                case .sagittal:
                    for z in 0..<height {  // Usiamo height invece di volume.dimensions.z
                        for y in 0..<width {  // Usiamo width invece di volume.dimensions.y
                            let volumeIndex = z * (volume.dimensions.x * volume.dimensions.y) +
                                            y * volume.dimensions.x + sliceIndex

                            if volumeIndex < uint8Buffer.count {
                                // Applica il windowing sui dati a 8 bit
                                let value = Double(uint8Buffer[volumeIndex])
                                let windowedValue = max(0, min(255, 255 * (value - lowerBound) / windowWidth))
                                
                                // Invertiamo l'asse z per correggere l'orientamento verticale
                                let outputIndex = (height - 1 - z) * width + y
                                
                                if outputIndex >= 0 && outputIndex < adjustedData.count {
                                    adjustedData[outputIndex] = UInt8(windowedValue)
                                }
                            }
                        }
                    }
                }
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
}

// Enum per specificare l'orientamento delle slice MPR
enum MPROrientation: Int32 {
    case axial = 0      // Vista dall'alto verso il basso
    case coronal = 1    // Vista frontale (da davanti a dietro)
    case sagittal = 2   // Vista laterale (da sinistra a destra)
}
