import SwiftUI
import SceneKit

/// Vista di SceneKit con supporto per l'aggiunta e modifica di marker
struct SceneKitMarkerView: NSViewRepresentable {
    var scene: SCNScene
    var allowsCameraControl: Bool
    var autoenablesDefaultLighting: Bool
    var markerMode: MarkerMode
    var markerManager: MarkerManager
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
         markerManager: MarkerManager,
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
        
        DispatchQueue.global(qos: .userInteractive).async {
                    self.onSceneViewCreated?(view)
                }
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
        var selectedMarkerID: UUID? // Rinominato da currentDragMarkerID per chiarezza
        
        init(_ parent: SceneKitMarkerView) {
            self.parent = parent
            self.markerMode = parent.markerMode
            super.init()
        }
        
        @objc func handleClick(_ gesture: NSClickGestureRecognizer) {
            guard let scnView = gesture.view as? SCNView else {
                print("Non è stato possibile ottenere la SCNView")
                return
            }
            
            let location = gesture.location(in: scnView)
            let hitResults = scnView.hitTest(location, options: parent.hitTestOptions)
            
            // Filtra i risultati per escludere i piani di taglio
            let filteredResults = hitResults.filter { result in
                let nodeName = result.node.name ?? ""
                // Esclude i nodi che iniziano con "cuttingPlane_"
                return !nodeName.starts(with: "cuttingPlane_")
            }
            
            // Debug - stampa i risultati del hit test
            print("Hit test results (filtered): \(filteredResults.count)")
            for (index, result) in filteredResults.enumerated() {
                print("Result \(index): node name = \(result.node.name ?? "unnamed"), coordinates = \(result.worldCoordinates)")
            }
            
            // Se non abbiamo un risultato valido, esci
            guard let result = filteredResults.first else {
                print("Nessun risultato valido trovato")
                return
            }
            
            // Gestisci l'interazione in base alla modalità
            switch markerMode {
            case .add:
                print("Tentativo di aggiungere marker a \(result.worldCoordinates)")
                let added = parent.markerManager.addMarker(at: result.worldCoordinates)
                if added == nil {
                    print("Impossibile aggiungere il marker - limite raggiunto")
                    DispatchQueue.main.async(qos: .userInteractive) {
                        NotificationCenter.default.post(name: NSNotification.Name("MarkerLimitReached"), object: nil)
                    }
                } else {
                    print("Marker aggiunto con successo")
                }
                
            case .edit:
                let nodeName = result.node.name ?? ""
                
                // Se abbiamo già un marker selezionato
                if let markerID = selectedMarkerID {
                    // Riposiziona il marker alla posizione del click
                    print("Riposizionamento del marker \(markerID) alla posizione \(result.worldCoordinates)")
                    parent.markerManager.updateMarker(id: markerID, position: result.worldCoordinates)
                    
                    // Deseleziona il marker dopo averlo riposizionato
                    parent.markerManager.selectMarker(id: nil)
                    selectedMarkerID = nil
                }
                // Altrimenti verifica se abbiamo cliccato su un marker
                else if nodeName.starts(with: "Marker_") {
                    let markerIDString = String(nodeName.dropFirst("Marker_".count))
                    if let markerID = UUID(uuidString: markerIDString) {
                        print("Marker selezionato per modifica: \(markerID)")
                        parent.markerManager.selectMarker(id: markerID)
                        selectedMarkerID = markerID
                    }
                } else {
                    // Cliccato in un punto vuoto senza avere marker selezionati
                    print("Nessun marker selezionato per la modifica (node name: \(nodeName))")
                    parent.markerManager.selectMarker(id: nil)
                    selectedMarkerID = nil
                }
                
            case .delete:
                // Rimuovi il marker se abbiamo cliccato su uno esistente
                let nodeName = result.node.name ?? ""
                if nodeName.starts(with: "Marker_") {
                    let markerIDString = String(nodeName.dropFirst("Marker_".count))
                    if let markerID = UUID(uuidString: markerIDString) {
                        print("Tentativo di rimuovere marker: \(markerID)")
                        parent.markerManager.removeMarker(id: markerID)
                    }
                }
                
            case .view:
                // In modalità visualizzazione, permette solo di selezionare un marker
                let nodeName = result.node.name ?? ""
                if nodeName.starts(with: "Marker_") {
                    let markerIDString = String(nodeName.dropFirst("Marker_".count))
                    if let markerID = UUID(uuidString: markerIDString) {
                        print("Marker selezionato per visualizzazione: \(markerID)")
                        parent.markerManager.selectMarker(id: markerID)
                    }
                } else {
                    print("Nessun marker selezionato per la visualizzazione")
                    parent.markerManager.selectMarker(id: nil)
                }
            }
        }
        
        // Rimuoviamo completamente la funzionalità di trascinamento dal renderer
        func renderer(_ renderer: SCNSceneRenderer, updateAtTime time: TimeInterval) {
            // Non facciamo nulla - non vogliamo il trascinamento
        }
    }
}
