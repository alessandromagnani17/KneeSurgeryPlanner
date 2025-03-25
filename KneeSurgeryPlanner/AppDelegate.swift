import Cocoa

class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Configurazione iniziale dell'applicazione
        setupMetalDevice()
        setupLogging()
    }
    
    private func setupMetalDevice() {
        // Configurare il dispositivo Metal per il rendering 3D
        guard MTLCreateSystemDefaultDevice() != nil else {
            print("Error: This device does not support Metal!")
            // Mostra un errore all'utente
            return
        }
    }
    
    private func setupLogging() {
        // Configurazione del sistema di logging
        let logPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("KneeSurgeryPlanner.log")
        freopen(logPath.path, "a+", stderr)
    }
}
