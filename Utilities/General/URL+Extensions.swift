/*
 Estensione di URL per verificare se un file è un file DICOM.

 Metodo principale:
 - isDICOMFile(): Restituisce un booleano che indica se il file è in formato DICOM.

 Funzionalità:
 - Controlla l'estensione del file confrontandola con un elenco di estensioni DICOM comuni.
 - Considera i file senza estensione come potenzialmente validi file DICOM.

 Scopo:
 Fornire un metodo semplice per identificare file DICOM tramite l'estensione o ulteriori controlli futuri.
*/

import Foundation

extension URL {
    func isDICOMFile() -> Bool {
        // Una verifica più accurata comporterebbe l'analisi dell'intestazione del file
        // Per ora, controlliamo solo l'estensione
        let dicomExtensions = ["dcm", "dicom", "dic"]
        
        // Se non c'è estensione, potrebbe essere un file DICOM senza estensione
        if self.pathExtension.isEmpty {
            // Qui potresti implementare una verifica del magic number del file
            return true
        }
        
        return dicomExtensions.contains(self.pathExtension.lowercased())
    }
}
