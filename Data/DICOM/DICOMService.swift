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
}
