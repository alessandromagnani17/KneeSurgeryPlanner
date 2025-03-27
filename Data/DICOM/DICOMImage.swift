import Foundation
import CoreGraphics

/*
 Struttura che rappresenta un'immagine DICOM
 Gestisce i dati dell'immagine e fornisce metodi per la visualizzazione e l'elaborazione.
 */
struct DICOMImage: Identifiable {

    // - Proprietà
    /*
     Id univoco dell'immagine
     Ogni immagine DICOM avrà un ID univoco che non ha significato al di fuori del sistema in cui viene generato.
     */
    let id: UUID
    
    // Dati grezzi (raw) dei pixel dell'immagine: memorizzati in formato binario (Data), rappresentano l'intensità dei pixel
    let pixelData: Data
    
    // Numero di righe dell'immagine (altezza)
    let rows: Int
    
    // Numero di colonne dell'immagine (larghezza)
    let columns: Int
    
    // Numero di bit allocati per pixel (tipicamente 8 o 16): numero di bit usati per rappresentare ciascun pixel dell'immagine.
    // 8 bit possono rappresentare 256 livelli di intensità, mentre 16 bit ne rappresentano 65536.
    let bitsAllocated: Int
    
    // Spaziatura dei pixel in millimetri (row spacing, column spacing): indica la distanza fisica tra i pixel lungo le righe e le colonne.
    // Questa informazione è utile per ottenere una rappresentazione spaziale corretta delle immagini DICOM in 3D.
    let pixelSpacing: (Double, Double)
    
    
    /*
     Posizione della slice nell'asse Z (per immagini 3D come TC)
     La sliceLocation indica la distanza di ogni slice lungo l'asse Z (profondità). L'asse Z rappresenta la direzione
     in cui le slices vengono acquisite, come se fossero impilate una sopra l'altra.
     La sliceLocation può essere positiva o negativa, a seconda dell'orientamento della macchina.
     La distanza tra le fette è importante per la ricostruzione 3D dell'immagine.

     Esempio:
     - La prima slice (sliceLocation = 0) è considerata l'origine.
     - La seconda slice (sliceLocation = 1) è 1 mm più in basso rispetto all'origine.
     - La terza slice (sliceLocation = 2) è 2 mm più in basso, e così via.
    */
    let sliceLocation: Double

    
    // Numero di immagine all'interno della serie: indica la posizione dell'immagine nella serie
    let instanceNumber: Int
    
    /*
     Metadati aggiuntivi: dizionario contenente ulteriori informazioni sull'immagine, come parametri
     acquisitivi, data dell'acquisizione, ecc.
     */
    let metadata: [String: Any]

    /*
     Centro della finestra per la visualizzazione dei valori Hounsfield (TC): utile per l'elaborazione del contrasto.
     Determina quale densità di tessuti sarà il "centro" del nostro range di visualizzazione.
     
     Esempio: se lo impostiamo a 50, i valori Hounsfield intorno a 50 (ad esempio, da -50 a 150) verranno visualizzati con dettagli maggiori.
     I valori molto alti o molto bassi (ad esempio ossa o aria) saranno visibili meno dettagliatamente o non saranno visibili affatto.
     */
    let windowCenter: Double?
    
    /*
     Ampiezza della finestra per la visualizzazione dei valori Hounsfield (TC): determina il range di valori Hounsfield da visualizzare
     in un'immagine TC.
     
     Esempio: windowCenter = 50, windowWidth = 500
     In questo caso, i valori Hounsfield che vanno da 50 - 250 (cioè -200) fino a 50 + 250 (cioè 300) verranno visualizzati in modo dettagliato. I tessuti che rientrano in questo range (ad esempio i polmoni o altri tessuti molli) saranno più visibili, mentre valori molto bassi (come quelli dell'aria) o molto alti (come quelli delle ossa) potrebbero non essere visualizzati o apparire in modo sfocato.
     */
    let windowWidth: Double?

    
    // - Metodi
    // TODO: la funzione image non viene mai chiamata
    /*
     Converte i dati grezzi DICOM in un'immagine CGImage visualizzabile.
     
     Procedimento:
     1. Calcola i parametri necessari per l'immagine (bytes per pixel, bytes per riga).
     2. Verifica che la dimensione dei dati sia coerente con i parametri.
     3. Crea un provider di dati e genera l'immagine CGImage.
     
     @return Un'immagine CGImage o nil in caso di errore.
     */
    func image() -> CGImage? {
        // Calcola quanti bytes servono per rappresentare ogni pixel
        let bytesPerPixel = (bitsAllocated + 7) / 8
        
        // Calcola quanti bytes servono per rappresentare una riga completa
        let bytesPerRow = columns * bytesPerPixel
        
        // Calcola la lunghezza totale attesa dei dati dell'immagine
        let expectedLength = rows * bytesPerRow
        
        
        // Verifica se i dati sono più lunghi dell'atteso e stampa un warning
        if pixelData.count > expectedLength {
            //print("⚠️ I dati della slice \(instanceNumber) sono più lunghi del previsto: \(pixelData.count) vs \(expectedLength)")
        }
        
        print("Dati immagine: \(pixelData.count) bytes")
        print("Dimensione prevista: \(expectedLength) bytes")
        print("Righe: \(rows), Colonne: \(columns), Bits allocati: \(bitsAllocated)")


        // Troncamento dei dati DICOM se necessario
        let croppedPixelData = pixelData.prefix(expectedLength)

        // Crea uno spazio colore in scala di grigi per l'immagine
        let colorSpace = CGColorSpaceCreateDeviceGray()

        // Configura le informazioni del bitmap in base alla profondità di bit
        let bitmapInfo: CGBitmapInfo = bitsAllocated == 16
            ? CGBitmapInfo(rawValue: CGImageAlphaInfo.none.rawValue | CGBitmapInfo.byteOrder16Little.rawValue)
            : CGBitmapInfo(rawValue: CGImageAlphaInfo.none.rawValue)

        // Crea un provider di dati per l'immagine
        guard let provider = CGDataProvider(data: croppedPixelData as CFData) else {
            print("Errore: Impossibile creare il CGDataProvider.")
            return nil
        }

        // Crea e restituisce l'immagine CGImage con i parametri configurati
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

    /*
     Applica una finestra di visualizzazione (windowing) ai dati dell'immagine.
     Utile per visualizzare correttamente i diversi tessuti attraverso i valori Hounsfield.
     
     @param center Centro della finestra
     @param width Ampiezza della finestra
     @return Un'immagine CGImage con il windowing applicato o nil in caso di errore
     */
    func applyWindowing(center: Double, width: Double) -> CGImage? {
        
        // Verifica che l'immagine sia a 16 bit (tipico per TC con valori Hounsfield)
        guard bitsAllocated == 16 else {
            print("Errore: Il windowing è supportato solo per immagini a 16 bit.")
            return nil
        }

        // Ottiene il buffer dei pixel come array di Int16 (valori Hounsfield)
        guard let pixelBuffer = pixelData.prefix(rows * columns * 2).withUnsafeBytes({ $0.bindMemory(to: Int16.self) }).baseAddress else {
            print("Errore: Impossibile ottenere il buffer di pixel.")
            return nil
        }
        
        // Crea uno spazio colore in scala di grigi per l'immagine
        let colorSpace = CGColorSpaceCreateDeviceGray()

        // Calcola il numero totale di pixel
        let length = rows * columns
        
        // Crea un nuovo buffer per i pixel dopo l'applicazione del windowing
        var adjustedPixels = [UInt8](repeating: 0, count: length)

        // Calcola i limiti inferiore e superiore della finestra
        let lowerBound = center - (width / 2)

        // Applica la formula di windowing a ogni pixel
        for i in 0..<length {
            let value = Double(pixelBuffer[i])
            let windowedValue = max(0, min(255, 255 * (value - lowerBound) / width))
            adjustedPixels[i] = UInt8(windowedValue)
        }

        // Crea un provider di dati con i pixel modificati
        guard let provider = CGDataProvider(data: Data(adjustedPixels) as CFData) else {
            print("Errore: Impossibile creare il provider per il windowing.")
            return nil
        }

        // Crea e restituisce l'immagine CGImage con i valori modificati
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
