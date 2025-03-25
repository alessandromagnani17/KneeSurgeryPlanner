import SwiftUI
import AppKit
import simd

struct MultiplanarView: View {
    @ObservedObject var dicomManager: DICOMManager
    @State private var axialIndex: Int = 0
    @State private var coronalIndex: Int = 0
    @State private var sagittalIndex: Int = 0
    @State private var windowCenter: Double = 40
    @State private var windowWidth: Double = 400
    @State private var useCPURendering: Bool = true // Imposta su false per usare Metal

    // Per Metal Rendering
    @State private var mprRenderer: MPRRenderer?
    @State private var volumeLoaded: Bool = false

    var body: some View {
        VStack {
            if let series = dicomManager.currentSeries,
               let volume = Volume(from: series) {

                // Controlli per windowing
                HStack {
                    Text("Window Center: \(Int(windowCenter))")
                    Slider(value: $windowCenter, in: -1000...1000)
                        .frame(width: 150)

                    Text("Window Width: \(Int(windowWidth))")
                    Slider(value: $windowWidth, in: 1...2000)
                        .frame(width: 150)

                    // Toggle per CPU/GPU rendering
                    Toggle("CPU Rendering", isOn: $useCPURendering)
                        .onChange(of: useCPURendering) { newValue in
                            // Se passiamo da GPU a CPU o viceversa, resettiamo lo stato
                            volumeLoaded = false
                            if !newValue && mprRenderer == nil {
                                mprRenderer = MPRRenderer()
                            }
                        }

                    Spacer()
                }
                .padding()

                HStack {
                    // Vista assiale (top-down)
                    VStack {
                        Text("Axial")
                            .font(.headline)

                        GeometryReader { geometry in
                            ZStack {
                                Color.black

                                if axialIndex < volume.dimensions.z {
                                    if useCPURendering {
                                        if let image = renderSlice(
                                            from: volume,
                                            orientation: .axial,
                                            sliceIndex: axialIndex,
                                            windowCenter: windowCenter,
                                            windowWidth: windowWidth) {

                                            Image(nsImage: NSImage(cgImage: image, size: NSSize(width: image.width, height: image.height)))
                                                .resizable()
                                                .aspectRatio(contentMode: .fit)
                                        }
                                    } else {
                                        if let renderer = mprRenderer,
                                           let image = renderer.renderMPRSlice(
                                            orientation: .axial,
                                            sliceIndex: axialIndex,
                                            windowCenter: windowCenter,
                                            windowWidth: windowWidth) {

                                            Image(nsImage: NSImage(cgImage: image, size: NSSize(width: image.width, height: image.height)))
                                                .resizable()
                                                .aspectRatio(contentMode: .fit)
                                        }
                                    }
                                }
                            }
                        }

                        Slider(
                            value: Binding(
                                get: { Double(axialIndex) },
                                set: { axialIndex = Int($0) }
                            ),
                            in: 0...Double(max(0, volume.dimensions.z - 1)),
                            step: 1
                        )
                    }

                    // Vista coronale (front-back)
                    VStack {
                        Text("Coronal")
                            .font(.headline)

                        GeometryReader { geometry in
                            ZStack {
                                Color.black

                                if coronalIndex < volume.dimensions.y {
                                    if useCPURendering {
                                        if let image = renderSlice(
                                            from: volume,
                                            orientation: .coronal,
                                            sliceIndex: coronalIndex,
                                            windowCenter: windowCenter,
                                            windowWidth: windowWidth) {

                                            Image(nsImage: NSImage(cgImage: image, size: NSSize(width: image.width, height: image.height)))
                                                .resizable()
                                                .aspectRatio(contentMode: .fit)
                                        }
                                    } else {
                                        if let renderer = mprRenderer,
                                           let image = renderer.renderMPRSlice(
                                            orientation: .coronal,
                                            sliceIndex: coronalIndex,
                                            windowCenter: windowCenter,
                                            windowWidth: windowWidth) {

                                            Image(nsImage: NSImage(cgImage: image, size: NSSize(width: image.width, height: image.height)))
                                                .resizable()
                                                .aspectRatio(contentMode: .fit)
                                        }
                                    }
                                }
                            }
                        }

                        Slider(
                            value: Binding(
                                get: { Double(coronalIndex) },
                                set: { coronalIndex = Int($0) }
                            ),
                            in: 0...Double(max(0, volume.dimensions.y - 1)),
                            step: 1
                        )
                    }

                    // Vista sagittale (left-right)
                    VStack {
                        Text("Sagittal")
                            .font(.headline)

                        GeometryReader { geometry in
                            ZStack {
                                Color.black

                                if sagittalIndex < volume.dimensions.x {
                                    if useCPURendering {
                                        if let image = renderSlice(
                                            from: volume,
                                            orientation: .sagittal,
                                            sliceIndex: sagittalIndex,
                                            windowCenter: windowCenter,
                                            windowWidth: windowWidth) {

                                            Image(nsImage: NSImage(cgImage: image, size: NSSize(width: image.width, height: image.height)))
                                                .resizable()
                                                .aspectRatio(contentMode: .fit)
                                        }
                                    } else {
                                        if let renderer = mprRenderer,
                                           let image = renderer.renderMPRSlice(
                                            orientation: .sagittal,
                                            sliceIndex: sagittalIndex,
                                            windowCenter: windowCenter,
                                            windowWidth: windowWidth) {

                                            Image(nsImage: NSImage(cgImage: image, size: NSSize(width: image.width, height: image.height)))
                                                .resizable()
                                                .aspectRatio(contentMode: .fit)
                                        }
                                    }
                                }
                            }
                        }

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
                .onAppear {
                    // Inizializza il renderer Metal se necessario
                    if !useCPURendering {
                        if mprRenderer == nil {
                            mprRenderer = MPRRenderer()
                        }

                        if let renderer = mprRenderer, !volumeLoaded {
                            volumeLoaded = renderer.loadVolume(volume)
                        }
                    }
                }

            } else {
                VStack {
                    Spacer()
                    Text("No volume data available")
                        .foregroundColor(.secondary)
                    Spacer()
                }
            }
        }
    }

    // MARK: - Unified Rendering Function

    func renderSlice(from volume: Volume, orientation: MPROrientation, sliceIndex: Int,
                    windowCenter: Double, windowWidth: Double) -> CGImage? {
        // Dimensioni dell'output in base all'orientamento
        var width: Int = 0
        var height: Int = 0

        switch orientation {
        case .axial:
            width = volume.dimensions.x
            height = volume.dimensions.y
        case .coronal:
            width = volume.dimensions.x
            height = volume.dimensions.z
        case .sagittal:
            width = volume.dimensions.y
            height = volume.dimensions.z
        }

        // Controllo dei limiti
        let maxIndex: Int
        switch orientation {
        case .axial: maxIndex = volume.dimensions.z - 1
        case .coronal: maxIndex = volume.dimensions.y - 1
        case .sagittal: maxIndex = volume.dimensions.x - 1
        }

        guard sliceIndex >= 0 && sliceIndex <= maxIndex else { return nil }

        // Array per i dati elaborati
        var adjustedData = [UInt8](repeating: 0, count: width * height)

        // Limite inferiore per il windowing
        let lowerBound = windowCenter - (windowWidth / 2)

        // Accesso dei dati in base all'orientamento
        if volume.bitsPerVoxel == 16 {
            volume.data.withUnsafeBytes { rawBuffer in
                let int16Buffer = rawBuffer.bindMemory(to: Int16.self)

                switch orientation {
                case .axial:
                    // Axial slice: fixed Z coordinate
                    let sliceOffset = sliceIndex * width * height

                    for y in 0..<height {
                        for x in 0..<width {
                            let volumeIndex = sliceOffset + y * width + x

                            if volumeIndex < int16Buffer.count {
                                let value = Double(int16Buffer[volumeIndex])
                                let windowedValue = max(0, min(255, 255 * (value - lowerBound) / windowWidth))
                                adjustedData[y * width + x] = UInt8(windowedValue)
                            }
                        }
                    }

                case .coronal:
                    // Coronal slice: fixed Y coordinate
                    for z in 0..<volume.dimensions.z {
                        for x in 0..<volume.dimensions.x {
                            // Formula: z * (width * height) + sliceIndex * width + x
                            let volumeIndex = z * (volume.dimensions.x * volume.dimensions.y) +
                                            sliceIndex * volume.dimensions.x + x

                            if volumeIndex < int16Buffer.count {
                                let value = Double(int16Buffer[volumeIndex])
                                let windowedValue = max(0, min(255, 255 * (value - lowerBound) / windowWidth))

                                // Store in output array, z is now y in output image
                                adjustedData[z * width + x] = UInt8(windowedValue)
                            }
                        }
                    }

                case .sagittal:
                    // Sagittal slice: fixed X coordinate
                    for z in 0..<volume.dimensions.z {
                        for y in 0..<volume.dimensions.y {
                            // Formula: z * (width * height) + y * width + sliceIndex
                            let volumeIndex = z * (volume.dimensions.x * volume.dimensions.y) +
                                            y * volume.dimensions.x + sliceIndex

                            if volumeIndex < int16Buffer.count {
                                let value = Double(int16Buffer[volumeIndex])
                                let windowedValue = max(0, min(255, 255 * (value - lowerBound) / windowWidth))

                                // Store in output array
                                adjustedData[z * volume.dimensions.y + y] = UInt8(windowedValue)
                            }
                        }
                    }
                }
            }
        } else if volume.bitsPerVoxel == 8 {
            // Implementazione per dati a 8 bit
            volume.data.withUnsafeBytes { rawBuffer in
                let uint8Buffer = rawBuffer.bindMemory(to: UInt8.self)

                switch orientation {
                case .axial:
                    let sliceOffset = sliceIndex * width * height

                    for y in 0..<height {
                        for x in 0..<width {
                            let volumeIndex = sliceOffset + y * width + x

                            if volumeIndex < uint8Buffer.count {
                                let value = Double(uint8Buffer[volumeIndex])
                                let windowedValue = max(0, min(255, 255 * (value - lowerBound) / windowWidth))
                                adjustedData[y * width + x] = UInt8(windowedValue)
                            }
                        }
                    }

                case .coronal:
                    for z in 0..<volume.dimensions.z {
                        for x in 0..<volume.dimensions.x {
                            let volumeIndex = z * (volume.dimensions.x * volume.dimensions.y) +
                                            sliceIndex * volume.dimensions.x + x

                            if volumeIndex < uint8Buffer.count {
                                let value = Double(uint8Buffer[volumeIndex])
                                let windowedValue = max(0, min(255, 255 * (value - lowerBound) / windowWidth))
                                adjustedData[z * width + x] = UInt8(windowedValue)
                            }
                        }
                    }

                case .sagittal:
                    for z in 0..<volume.dimensions.z {
                        for y in 0..<volume.dimensions.y {
                            let volumeIndex = z * (volume.dimensions.x * volume.dimensions.y) +
                                            y * volume.dimensions.x + sliceIndex

                            if volumeIndex < uint8Buffer.count {
                                let value = Double(uint8Buffer[volumeIndex])
                                let windowedValue = max(0, min(255, 255 * (value - lowerBound) / windowWidth))
                                adjustedData[z * volume.dimensions.y + y] = UInt8(windowedValue)
                            }
                        }
                    }
                }
            }
        }

        // Create output image
        guard let provider = CGDataProvider(data: Data(adjustedData) as CFData) else { return nil }
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

// Enum per specificare l'orientamento MPR
enum MPROrientation: Int32 {
    case axial = 0
    case coronal = 1
    case sagittal = 2
}
