import SwiftUI
import SceneKit

/// Vista di SceneKit con supporto per l'aggiunta e modifica di marker fiduciali
struct SceneKitMarkerView: NSViewRepresentable {
    var scene: SCNScene
    var allowsCameraControl: Bool
    var autoenablesDefaultLighting: Bool
    var markerMode: MarkerMode
    var markerManager: FiducialMarkerManager
    var onSceneViewCreated: ((SCNView) -> Void)?
    
    private var hitTestOptions: [SCNHitTestOption: Any] {
        return [
            SCNHitTestOption.searchMode: SCNHitTestSearchMode.all.rawValue,
            SCNHitTestOption.ignoreHiddenNodes: false
        ]
    }
    
    init(scene: SCNScene,
         allowsCameraControl: Bool = true,
         autoenablesDefaultLighting: Bool = true,
         markerMode: MarkerMode = .view,
         markerManager: FiducialMarkerManager,
         onSceneViewCreated: ((SCNView) -> Void)? = nil) {
        
        self.scene = scene
        self.allowsCameraControl = allowsCameraControl
        self.autoenablesDefaultLighting = autoenablesDefaultLighting
        self.markerMode = markerMode
        self.markerManager = markerManager
        self.onSceneViewCreated = onSceneViewCreated
    }
    
    func makeNSView(context: Context) -> SCNView {
        let view = SCNView()
        view.scene = scene
        view.allowsCameraControl = allowsCameraControl
        view.autoenablesDefaultLighting = autoenablesDefaultLighting
        view.backgroundColor = NSColor.darkGray
        view.preferredFramesPerSecond = 60
        view.antialiasingMode = .multisampling4X
        view.delegate = context.coordinator
        
        // Aggiungi gestori di eventi
        let clickGesture = NSClickGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handleClick(_:)))
        view.addGestureRecognizer(clickGesture)
        
        onSceneViewCreated?(view)
        return view
    }
    
    func updateNSView(_ nsView: SCNView, context: Context) {
        // Aggiorna le proprietà se cambiano
        nsView.allowsCameraControl = allowsCameraControl
        context.coordinator.markerMode = markerMode
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, SCNSceneRendererDelegate {
        var parent: SceneKitMarkerView
        var markerMode: MarkerMode
        var isDragging = false
        var currentDragMarkerID: UUID?
        
        init(_ parent: SceneKitMarkerView) {
            self.parent = parent
            self.markerMode = parent.markerMode
        }
        
        @objc func handleClick(_ gesture: NSClickGestureRecognizer) {
            guard let scnView = gesture.view as? SCNView else { return }
            
            let location = gesture.location(in: scnView)
            let hitResults = scnView.hitTest(location, options: parent.hitTestOptions)
            
            // Filtra i risultati per includere solo il modello volumeMesh e escludere i marker esistenti
            let results = hitResults.filter { result in
                if markerMode == .add {
                    // Quando stiamo aggiungendo, ignora i nodi dei marker esistenti e i piani di taglio
                    // e permetti solo hit sul modello volumeMesh o il suo outline
                    let name = result.node.name ?? ""
                    let isMarker = name.starts(with: "fiducialMarker_")
                    let isPlane = name.starts(with: "cuttingPlane_")
                    let isModel = name == "volumeMesh" || name == "outlineNode" || result.node.parent?.name == "volumeMesh"
                    return !isMarker && !isPlane && isModel
                }
                return true
            }
            
            // Se non abbiamo un risultato valido, esci
            guard let result = results.first else { return }
            
            // Gestisci l'interazione in base alla modalità
            switch markerMode {
            case .add:
                let added = parent.markerManager.addMarker(at: result.worldCoordinates)
                if added == nil {
                    // Non è stato possibile aggiungere il marker (limite raggiunto)
                    DispatchQueue.main.async {
                        NotificationCenter.default.post(name: NSNotification.Name("MarkerLimitReached"), object: nil)
                    }
                }
                
            case .edit:
                // Verifica se abbiamo cliccato su un marker esistente
                if let nodeName = result.node.name, nodeName.starts(with: "fiducialMarker_") {
                    let markerIDString = String(nodeName.dropFirst("fiducialMarker_".count))
                    if let markerID = UUID(uuidString: markerIDString) {
                        parent.markerManager.selectMarker(id: markerID)
                        currentDragMarkerID = markerID
                        isDragging = true
                    }
                } else {
                    // Se abbiamo cliccato altrove, deseleziona
                    parent.markerManager.selectMarker(id: nil)
                }
                
            case .delete:
                // Rimuovi il marker se abbiamo cliccato su uno esistente
                if let nodeName = result.node.name, nodeName.starts(with: "fiducialMarker_") {
                    let markerIDString = String(nodeName.dropFirst("fiducialMarker_".count))
                    if let markerID = UUID(uuidString: markerIDString) {
                        parent.markerManager.removeMarker(id: markerID)
                    }
                }
                
            case .view:
                // In modalità visualizzazione, permette solo di selezionare un marker
                if let nodeName = result.node.name, nodeName.starts(with: "fiducialMarker_") {
                    let markerIDString = String(nodeName.dropFirst("fiducialMarker_".count))
                    if let markerID = UUID(uuidString: markerIDString) {
                        parent.markerManager.selectMarker(id: markerID)
                    }
                } else {
                    parent.markerManager.selectMarker(id: nil)
                }
            }
        }
        
        // Gestisce il movimento del mouse per spostare i marker in modalità edit
        func renderer(_ renderer: SCNSceneRenderer, updateAtTime time: TimeInterval) {
            guard markerMode == .edit, isDragging, let markerID = currentDragMarkerID else { return }
            
            guard let scnView = renderer as? SCNView else { return }
            
            // Ottiene la posizione attuale del mouse
            let mouseLocation = NSEvent.mouseLocation
            let windowPoint = scnView.window?.convertFromScreen(NSRect(x: mouseLocation.x, y: mouseLocation.y, width: 1, height: 1)).origin ?? .zero
            let viewPoint = scnView.convert(windowPoint, from: nil)
            
            // Esegue un hit test per trovare dove si trova il mouse nello spazio 3D
            let hitResults = scnView.hitTest(viewPoint, options: parent.hitTestOptions)
            
            // Filtra risultati per escludere marker e piani
            let results = hitResults.filter { result in
                let name = result.node.name ?? ""
                return !name.starts(with: "fiducialMarker_") && !name.starts(with: "cuttingPlane_")
            }
            
            // Aggiorna la posizione del marker se c'è un punto valido
            if let result = results.first {
                parent.markerManager.updateMarker(id: markerID, position: result.worldCoordinates)
            }
        }
    }
}
