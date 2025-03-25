import SwiftUI

struct ContentView: View {
    @StateObject private var dicomManager = DICOMManager()
    @State private var selectedTabIndex = 0

    var body: some View {
        NavigationView {
            // Sidebar
            DICOMBrowserView(dicomManager: dicomManager)
            .frame(minWidth: 250, idealWidth: 300, maxWidth: 350)

            // Main Content
            VStack {
                TabView(selection: $selectedTabIndex) {
                    DICOMViewerView(dicomManager: dicomManager)
                        .tabItem {
                            Label("DICOM Viewer", systemImage: "rectangle.stack")
                        }
                        .tag(0)

                    MultiplanarView(dicomManager: dicomManager)
                        .tabItem {
                            Label("MPR View", systemImage: "square.grid.3x3")
                        }
                        .tag(1)

                    Model3DView(dicomManager: dicomManager)
                        .tabItem {
                            Label("3D Model", systemImage: "cube")
                        }
                        .tag(2)
                }
                .onChange(of: selectedTabIndex) { oldValue, newValue in
                    switch newValue {
                    case 0: print("ContentView: cliccato tab DICOM Viewer")
                    case 1: print("ContentView: cliccato tab MPR View")
                    case 2: print("ContentView: cliccato tab 3D Model")
                    default: break
                    }
                }
            }
        }
        .navigationTitle("Knee Surgery Planner")
        .frame(minWidth: 1000, minHeight: 700)
        .onAppear {
            // Configura le notifiche per gli eventi dell'applicazione
            setupNotifications()
        }
    }

    private func setupNotifications() {
        NotificationCenter.default.addObserver(forName: Notification.Name("ImportDICOM"), object: nil, queue: .main) { _ in
            // Mostra il file picker per importare DICOM
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
                            // Mostra un errore all'utente
                            print("Error importing DICOM: \(error.localizedDescription)")
                        }
                    }
                }
            }
        }
    }
}
