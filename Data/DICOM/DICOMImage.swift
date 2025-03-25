import Foundation
import CoreGraphics

struct DICOMImage: Identifiable {
    let id: UUID
    let pixelData: Data
    let rows: Int
    let columns: Int
    let bitsAllocated: Int
    let pixelSpacing: (Double, Double) // (row spacing, column spacing) in mm
    let sliceLocation: Double
    let instanceNumber: Int
    let metadata: [String: Any]

    // Valori Hounsfield per immagini TC
    let windowCenter: Double?
    let windowWidth: Double?

    func image() -> CGImage? {
        let bytesPerPixel = (bitsAllocated + 7) / 8
        let bytesPerRow = columns * bytesPerPixel
        let expectedLength = rows * bytesPerRow

        // Tolleranza dinamica per il padding (max 8192 bytes, tipico nei DICOM)
        let tolerance = max(2, expectedLength / 64)

        guard abs(pixelData.count - expectedLength) <= tolerance else {
            print("""
            ❌ Errore: Lunghezza dei pixel non valida
            - pixelData.count: \(pixelData.count)
            - rows: \(rows)
            - columns: \(columns)
            - bitsAllocated: \(bitsAllocated)
            - bytesPerPixel: \(bytesPerPixel)
            - expectedLength: \(expectedLength)
            - tolerance: \(tolerance)
            """)
            return nil
        }

        print("✅ Lunghezza pixel valida: \(pixelData.count)")

        // Crea lo spazio colore in scala di grigi
        let colorSpace = CGColorSpaceCreateDeviceGray()

        // Imposta il bitmapInfo in base a bitsAllocated
        let bitmapInfo: CGBitmapInfo = bitsAllocated == 16
            ? CGBitmapInfo(rawValue: CGImageAlphaInfo.none.rawValue | CGBitmapInfo.byteOrder16Little.rawValue)
            : CGBitmapInfo(rawValue: CGImageAlphaInfo.none.rawValue)

        // Ritaglia i dati se c'è un padding extra
        let croppedPixelData = pixelData.prefix(expectedLength)

        guard let provider = CGDataProvider(data: croppedPixelData as CFData) else {
            print("❌ Errore: Impossibile creare il CGDataProvider.")
            return nil
        }

        return CGImage(
            width: columns,
            height: rows,
            bitsPerComponent: bitsAllocated,
            bitsPerPixel: bitsAllocated,
            bytesPerRow: bytesPerRow,
            space: colorSpace,
            bitmapInfo: bitmapInfo,
            provider: provider,
            decode: nil,
            shouldInterpolate: false,
            intent: .defaultIntent
        )
    }

    // Metodo per applicare la finestra di visualizzazione (windowing)
    func applyWindowing(center: Double, width: Double) -> CGImage? {
        // Gestisce solo immagini a 16 bit
        guard bitsAllocated == 16 else {
            print("❌ Errore: Il windowing è supportato solo per immagini a 16 bit.")
            return nil
        }

        // Estrae il buffer di pixel
        guard let pixelBuffer = pixelData.withUnsafeBytes({ $0.bindMemory(to: Int16.self) }).baseAddress else {
            print("❌ Errore: Impossibile ottenere il buffer di pixel.")
            return nil
        }

        let length = rows * columns
        var adjustedPixels = [UInt8](repeating: 0, count: length)

        // Calcola i limiti per il windowing
        let lowerBound = center - (width / 2)
        let upperBound = center + (width / 2)

        for i in 0..<length {
            let value = Double(pixelBuffer[i])
            let windowedValue = max(0, min(255, 255 * (value - lowerBound) / width))
            adjustedPixels[i] = UInt8(windowedValue)
        }

        // Crea un provider per l'immagine con i pixel modificati
        guard let provider = CGDataProvider(data: Data(adjustedPixels) as CFData) else {
            print("❌ Errore: Impossibile creare il provider per il windowing.")
            return nil
        }

        let colorSpace = CGColorSpaceCreateDeviceGray()

        return CGImage(
            width: columns,
            height: rows,
            bitsPerComponent: 8,
            bitsPerPixel: 8,
            bytesPerRow: columns,
            space: colorSpace,
            bitmapInfo: .init(rawValue: CGImageAlphaInfo.none.rawValue),
            provider: provider,
            decode: nil,
            shouldInterpolate: false,
            intent: .defaultIntent
        )
    }
}
