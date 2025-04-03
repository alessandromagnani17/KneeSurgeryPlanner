/*
 Estensione di View per aggiungere una funzionalità di importazione personalizzata di file.

 Metodo principale:
 - customFileImporter: Aggiunge un modificatore che presenta un pannello di selezione file.

 Strutture principali:
 - FileImporterViewModifier: Modificatore di vista che gestisce la presentazione e il risultato del pannello.

 Funzionalità:
 - Supporta la selezione di file e directory tramite NSOpenPanel.
 - Consente la selezione multipla o singola di file.
 - Filtra i tipi di contenuto consentiti utilizzando `UTType`.
 - Notifica il completamento tramite una closure `onCompletion`.

 Scopo:
 Espandere le viste SwiftUI per consentire l'importazione di file e cartelle, facilitando la gestione di contenuti DICOM.
 */

import SwiftUI
import UniformTypeIdentifiers
import AppKit

extension View {
    func customFileImporter(isPresented: Binding<Bool>, allowedContentTypes: [UTType], allowsMultipleSelection: Bool, onCompletion: @escaping (Result<[URL], Error>) -> Void) -> some View {
        self.modifier(FileImporterViewModifier(isPresented: isPresented, allowedContentTypes: allowedContentTypes, allowsMultipleSelection: allowsMultipleSelection, onCompletion: onCompletion))
    }
}

struct FileImporterViewModifier: ViewModifier {
    @Binding var isPresented: Bool
    let allowedContentTypes: [UTType]
    let allowsMultipleSelection: Bool
    let onCompletion: (Result<[URL], Error>) -> Void
    
    func body(content: Content) -> some View {
        content
            .onChange(of: isPresented) { _, isPresented in
                if isPresented {
                    let panel = NSOpenPanel()
                    panel.canChooseFiles = true
                    panel.canChooseDirectories = allowedContentTypes.contains(.folder)
                    panel.allowsMultipleSelection = allowsMultipleSelection
                    
                    // Filtra per tipi di contenuto
                    if !allowedContentTypes.contains(.folder) {
                        panel.allowedContentTypes = allowedContentTypes
                    }
                    
                    panel.begin { response in
                        defer { self.isPresented = false }
                        
                        if response == .OK {
                            onCompletion(.success(panel.urls))
                        } else {
                            struct CancelError: Error {}
                            onCompletion(.failure(CancelError()))
                        }
                    }
                }
            }
    }
}


/*
 Estensione di UTType per aggiungere il supporto personalizzato alle cartelle.

 Metodo principale:
 - customFolder: Fornisce un tipo UTType per rappresentare le cartelle.

 Funzionalità:
 - Compatibile con macOS 11.0 e versioni successive.
 - Fornisce un fallback per le versioni precedenti di macOS.

 Scopo:
 Estendere UTType per includere il supporto alle cartelle, garantendo la compatibilità con diverse versioni di macOS.
 */

// UTType estensione per supportare cartelle
import UniformTypeIdentifiers

extension UTType {
    static var customFolder: UTType {
        // In macOS 11+, usa il tipo incorporato
        if #available(macOS 11.0, *) {
            return UTType.folder  // Questo è il tipo incorporato di sistema, non la tua proprietà
        } else {
            // Fallback per versioni precedenti
            return UTType(filenameExtension: "public.folder")!
        }
    }
}
