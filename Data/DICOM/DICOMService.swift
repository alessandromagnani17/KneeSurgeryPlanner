import Foundation

/// Classe di servizio Swift che fornisce un'interfaccia per interagire con la libreria DCMTK
class DICOMService {
    
    /// Legge i metadati da un file DICOM
    /// - Parameter filePath: Percorso del file DICOM
    /// - Returns: Dizionario con i metadati estratti
    func readMetadata(from filePath: String) -> [String: Any] {
        return DCMTKBridge.readMetadata(fromFile: filePath) as? [String: Any] ?? [:]
    }
    
    /// Ottiene il valore di un tag DICOM specifico
    /// - Parameters:
    ///   - filePath: Percorso del file DICOM
    ///   - tagName: Nome del tag DICOM da leggere
    /// - Returns: Valore del tag come stringa
    func getTagValue(from filePath: String, tagName: String) -> String {
        return DCMTKBridge.getTagValue(filePath, tagName: tagName)
    }
    
    /// Ottiene i dati dei pixel e le informazioni sulle dimensioni
    /// - Parameter filePath: Percorso del file DICOM
    /// - Returns: Tupla contenente i dati dei pixel e le dimensioni dell'immagine
    func getPixelData(from filePath: String) -> (pixelData: Data, rows: Int, columns: Int, bitsAllocated: Int)? {
        var rows: Int32 = 0
        var columns: Int32 = 0
        var bitsAllocated: Int32 = 0
        
        guard let pixelData = DCMTKBridge.getPixelData(fromFile: filePath,
                                                      rows: &rows,
                                                      columns: &columns,
                                                      bitsAllocated: &bitsAllocated) else {
            return nil
        }
        
        return (pixelData, Int(rows), Int(columns), Int(bitsAllocated))
    }
    
    /// Stampa tutti i tag DICOM per il debug
    /// - Parameter filePath: Percorso del file DICOM
    func printAllTags(from filePath: String) {
        DCMTKBridge.printAllTags(fromFile: filePath)
    }
    
    /// Stampa i metadati chiave di un file DICOM per il debug
    /// - Parameter filePath: Percorso del file DICOM
    func printKeyMetadata(from filePath: String) {
        let metadata = self.readMetadata(from: filePath)
        
        print("======= DICOM METADATA DEBUG =======")
        print("File: \(filePath)")
        print("------------------------------------")
        
        // Metadati principali
        let keyTags = [
            "PatientName", "PatientID", "Modality", "SeriesDescription",
            "StudyDate", "SeriesInstanceUID", "SliceThickness", "PixelSpacing",
            "WindowCenter", "WindowWidth", "RescaleSlope", "RescaleIntercept",
            "ImagePositionPatient", "ImageOrientationPatient"
        ]
        
        print("Metadati principali:")
        for tag in keyTags {
            if let value = metadata[tag] {
                print("🔑 \(tag): \(value)")
            }
        }
        
        // Categorie di tag
        printTagCategory(from: metadata,
                         title: "Informazioni spaziali",
                         keywords: ["Position", "Orientation", "Spacing", "Location", "Thickness", "Slice"])
        
        printTagCategory(from: metadata,
                         title: "Parametri di visualizzazione",
                         keywords: ["Window", "Rescale", "Center", "Width", "Intercept", "Slope", "WL", "WW"])
        
        print("====================================")
    }
    
    /// Stampa una categoria di tag che contengono parole chiave specifiche
    /// - Parameters:
    ///   - metadata: Dizionario dei metadati
    ///   - title: Titolo della categoria
    ///   - keywords: Parole chiave per filtrare i tag
    private func printTagCategory(from metadata: [String: Any], title: String, keywords: [String]) {
        let matchingTags = metadata.keys.filter { key in
            keywords.contains { key.contains($0) }
        }
        
        if !matchingTags.isEmpty {
            print("\n\(title):")
            for tag in matchingTags.sorted() {
                print("  \(tag): \(metadata[tag] ?? "N/A")")
            }
        }
    }
}
