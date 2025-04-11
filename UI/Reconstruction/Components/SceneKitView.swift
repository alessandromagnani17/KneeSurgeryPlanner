import SwiftUI
import SceneKit

/// View SceneKit per la visualizzazione 3D
struct SceneKitView: NSViewRepresentable {
    // Proprietà
    let scene: SCNScene
    let allowsCameraControl: Bool
    let autoenablesDefaultLighting: Bool
    let onSceneViewCreated: (SCNView) -> Void
    
    // Crea la view SCNView
    func makeNSView(context: Context) -> SCNView {
        let view = SCNView()
        view.scene = scene
        
        view.allowsCameraControl = allowsCameraControl
        view.autoenablesDefaultLighting = autoenablesDefaultLighting
        view.backgroundColor = NSColor.darkGray
        
        // Impostazioni di rendering avanzate
        view.antialiasingMode = .multisampling4X
        view.preferredFramesPerSecond = 60
        view.isJitteringEnabled = true
        view.isPlaying = true
        view.showsStatistics = false
        
        // Callback alla view principale
        onSceneViewCreated(view)
        
        return view
    }
    
    // Aggiorna la view quando cambiano i parametri
    func updateNSView(_ nsView: SCNView, context: Context) {
        // Aggiorna la scena
        nsView.scene = scene
        
        // Aggiorna le proprietà di controllo camera
        nsView.allowsCameraControl = allowsCameraControl
    }
    
    // Crea il coordinatore (semplificato senza funzionalità di disegno)
    func makeCoordinator() -> Coordinator {
        Coordinator()
    }
    
    // Coordinatore base senza funzionalità di disegno
    class Coordinator: NSObject {
        var scnView: SCNView?
    }
}
