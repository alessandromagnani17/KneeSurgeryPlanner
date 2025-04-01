import Foundation

// Classe di servizio Swift per gestire l'interazione con DCMTK
class DICOMService {
    
    /**
     Legge i metadati da un file DICOM.
     - Parameter filePath: Percorso del file DICOM.
     - Returns: Dizionario con tutti i metadati estratti.
     */
    func readMetadata(from filePath: String) -> [String: Any] {
        return DCMTKBridge.readMetadata(fromFile: filePath) as? [String: Any] ?? [:]
    }
    
    /**
     Ottiene il valore di un tag specifico.
     - Parameters:
       - filePath: Percorso del file DICOM.
       - tagName: Nome del tag DICOM da leggere.
     - Returns: Valore del tag come stringa.
     */
    func getTagValue(from filePath: String, tagName: String) -> String {
        return DCMTKBridge.getTagValue(filePath, tagName: tagName)
    }
    
    /**
     Ottiene i dati dei pixel e le informazioni sulle dimensioni.
     - Parameter filePath: Percorso del file DICOM.
     - Returns: Tupla contenente i dati dei pixel e le dimensioni.
     */
    func getPixelData(from filePath: String) -> (pixelData: Data, rows: Int, columns: Int, bitsAllocated: Int)? {
        var rows: Int32 = 0
        var columns: Int32 = 0
        var bitsAllocated: Int32 = 0
        
        guard let pixelData = DCMTKBridge.getPixelData(fromFile: filePath, rows: &rows, columns: &columns, bitsAllocated: &bitsAllocated) else {
            return nil
        }
        
        return (pixelData, Int(rows), Int(columns), Int(bitsAllocated))
    }
    
    /**
     Stampa tutti i tag DICOM per il debug.
     - Parameter filePath: Percorso del file DICOM.
     */
    func printAllTags(from filePath: String) {
        DCMTKBridge.printAllTags(fromFile: filePath)
    }
    
    /**
     Stampa i metadati chiave di un file DICOM per il debug.
     - Parameter filePath: Percorso del file DICOM.
     */
    func printKeyMetadata(from filePath: String) {
        let metadata = self.readMetadata(from: filePath)
        
        print("======= DICOM METADATA DEBUG =======")
        print("File: \(filePath)")
        print("------------------------------------")
        
        // Stampa tutti i metadati disponibili
        print("Tutti i metadati disponibili:")
        for (key, value) in metadata {
            print("🔑 \(key): \(value)")
        }
        
        print("====================================")
        
        // Cerca possibili varianti dei tag importanti
        let possibleSpatialTags = metadata.keys.filter {
            $0.contains("Position") ||
            $0.contains("Orientation") ||
            $0.contains("Spacing") ||
            $0.contains("Location") ||
            $0.contains("Thickness") ||
            $0.contains("Image") ||
            $0.contains("Patient") ||
            $0.contains("Slice")
        }
        
        if !possibleSpatialTags.isEmpty {
            print("Possibili tag spaziali trovati:")
            for tag in possibleSpatialTags {
                print("🌐 \(tag): \(metadata[tag] ?? "N/A")")
            }
        }
        
        // Cerca possibili varianti dei tag di windowing
        let possibleWindowingTags = metadata.keys.filter {
            $0.contains("Window") ||
            $0.contains("Rescale") ||
            $0.contains("Center") ||
            $0.contains("Width") ||
            $0.contains("Intercept") ||
            $0.contains("Slope") ||
            $0.contains("WL") ||
            $0.contains("WW")
        }
        
        if !possibleWindowingTags.isEmpty {
            print("Possibili tag di windowing trovati:")
            for tag in possibleWindowingTags {
                print("�밍 \(tag): \(metadata[tag] ?? "N/A")")
            }
        }
        
        print("====================================")
    }
}
