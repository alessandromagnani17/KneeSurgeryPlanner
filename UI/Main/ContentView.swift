/*
 Interfaccia principale
 */

import SwiftUI

struct ContentView: View {
    // Istanziamo un oggetto di classe DICOMManager: Gestisce i dati DICOM e il loro caricamento
    @StateObject private var dicomManager = DICOMManager()
    
    // Tiene traccia della scheda selezionata
    @State private var selectedTabIndex = 0

    var body: some View {
        NavigationView {
            // Barra laterale per la navigazione dei file DICOM
            DICOMBrowserView(dicomManager: dicomManager)
                .frame(minWidth: 300, idealWidth: 350, maxWidth: 400)
            
            // Contenuto principale con 3 schede
            VStack {
                TabView(selection: $selectedTabIndex) {
                    // Visualizzatore immagini DICOM
                    DICOMViewerView(dicomManager: dicomManager)
                        .tabItem { Label("DICOM Viewer", systemImage: "rectangle.stack") }
                        .tag(0)
                    
                    // Vista multiplanare (MPR)
                    MultiplanarView(dicomManager: dicomManager)
                        .tabItem { Label("MPR View", systemImage: "square.grid.3x3") }
                        .tag(1)
                    
                    // Visualizzazione 3D dei dati DICOM
                    Model3DView(dicomManager: dicomManager)
                        .tabItem { Label("3D Model", systemImage: "cube") }
                        .tag(2)
                }
                .onChange(of: selectedTabIndex) { _, newValue in
                    // Stampa nella console quando cambia scheda
                    switch newValue {
                    case 0: print("ContentView: cliccato tab DICOM Viewer")
                    case 1: print("ContentView: cliccato tab MPR View")
                    case 2: print("ContentView: cliccato tab 3D Model")
                    default: break
                    }
                }
            }
        }
        .navigationTitle("Knee Surgery Planner") // Titolo della finestra principale
        .frame(minWidth: 1000, minHeight: 700) // Dimensioni minime della finestra
        .onAppear {
            setupNotifications() // Configura le notifiche per l'importazione DICOM
        }
    }

    
    // Gestisce l'importazione di file DICOM tramite notifica
    /*
     Questa funzione configura un listener per un evento chiamato "ImportDICOM". Quando questo evento viene ricevuto,
     si apre un selettore di cartelle (NSOpenPanel) per permettere all'utente di scegliere una directory contenente
     file DICOM. Dopo la selezione, la cartella viene inviata al dicomManager per l'importazione dei file.
     */
    private func setupNotifications() {
        NotificationCenter.default.addObserver(forName: Notification.Name("ImportDICOM"), object: nil, queue: .main) { _ in
            let panel = NSOpenPanel()
            panel.canChooseFiles = false
            panel.canChooseDirectories = true
            panel.allowsMultipleSelection = false
            panel.message = "Seleziona una cartella contenente file DICOM"
            
            panel.begin { response in
                if response == .OK, let url = panel.url {
                    Task {
                        do {
                            let _ = try await dicomManager.importDICOMFromDirectory(url)
                        } catch {
                            print("Errore nell'importazione DICOM: \(error.localizedDescription)")
                        }
                    }
                }
            }
        }
    }
}
