/*
 Classe per gestire l'importazione di directory contenenti file DICOM.

 Metodo principale:
 - importDICOMDirectory(): Mostra un pannello di selezione per scegliere una cartella contenente file DICOM.

 Funzionalità:
 - Utilizza un NSOpenPanel per consentire la selezione di directory.
 - Supporta l'uso asincrono tramite `withCheckedThrowingContinuation`.
 - Gestisce l'annullamento dell'operazione con un errore personalizzato.

 Scopo:
 Fornire un'interfaccia asincrona per importare directory con file DICOM, facilitando l'integrazione con altre parti dell'app.
 */

import Foundation
import UniformTypeIdentifiers
import AppKit

class FileImporter {
    func importDICOMDirectory() async throws -> URL {
        return try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.main.async {
                let panel = NSOpenPanel()
                panel.canChooseFiles = false
                panel.canChooseDirectories = true
                panel.allowsMultipleSelection = false
                panel.message = "Seleziona una cartella contenente file DICOM"
                
                panel.begin { response in
                    if response == .OK, let url = panel.url {
                        continuation.resume(returning: url)
                    } else {
                        struct ImportCancelledError: Error {}
                        continuation.resume(throwing: ImportCancelledError())
                    }
                }
            }
        }
    }
}
