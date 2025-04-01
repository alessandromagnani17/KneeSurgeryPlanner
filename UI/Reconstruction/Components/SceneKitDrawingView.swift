import SwiftUI
import SceneKit

/// View SceneKit con supporto al disegno
struct SceneKitDrawingView: NSViewRepresentable {
    // Proprietà
    let scene: SCNScene
    let allowsCameraControl: Bool
    let autoenablesDefaultLighting: Bool
    let drawingMode: DrawingMode
    let lineStyle: LineStyle       
    let currentDrawingColor: NSColor
    let lineThickness: Float
    @Binding var drawingLines: [DrawingLine]
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
        
        // Associa il coordinatore per gestire gli eventi
        context.coordinator.scnView = view
        
        // Configura il gesture recognizer per il disegno
        let panGesture = NSPanGestureRecognizer(target: context.coordinator, action: #selector(DrawingCoordinator.handlePanGesture(_:)))
        panGesture.buttonMask = 0x1 // Clic sinistro
        panGesture.delegate = context.coordinator
        
        view.addGestureRecognizer(panGesture)
        
        // Callback alla view principale
        onSceneViewCreated(view)
        
        return view
    }
    
    // Aggiorna la view quando cambiano i parametri
    func updateNSView(_ nsView: SCNView, context: Context) {
        // Aggiorna la scena
        nsView.scene = scene
        
        // Aggiorna le proprietà del coordinatore
        context.coordinator.drawingMode = drawingMode
        context.coordinator.lineStyle = lineStyle    // Aggiorna anche lo stile della linea
        context.coordinator.currentDrawingColor = currentDrawingColor
        context.coordinator.lineThickness = lineThickness
        
        // Quando cambia la modalità, assicuriamoci che il controllo della camera funzioni correttamente
        nsView.allowsCameraControl = (drawingMode == .none)
    }
    
    // Crea il coordinatore per gestire gli eventi
    func makeCoordinator() -> DrawingCoordinator {
        DrawingCoordinator(self)
    }
}
