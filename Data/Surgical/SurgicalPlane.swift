import Foundation
import SceneKit
import simd

/// Tipo di piano chirurgico
enum SurgicalPlaneType: String, CaseIterable, Identifiable {
    case distal      // Piano distale del femore
    case posterior   // Piano posteriore del femore
    case anterior    // Piano anteriore del femore
    case chamfer     // Piano di smusso del femore
    case tibial      // Piano tibiale
    case custom      // Piano personalizzato
    
    var id: String { self.rawValue }
    
    var displayName: String {
        switch self {
        case .distal: return "Piano Distale"
        case .posterior: return "Piano Posteriore"
        case .anterior: return "Piano Anteriore"
        case .chamfer: return "Piano Smusso"
        case .tibial: return "Piano Tibiale"
        case .custom: return "Piano Personalizzato"
        }
    }
    
    var defaultColor: NSColor {
        switch self {
        case .distal: return .systemBlue
        case .posterior: return .systemGreen
        case .anterior: return .systemRed
        case .chamfer: return .systemOrange
        case .tibial: return .systemPurple
        case .custom: return .systemYellow
        }
    }
}

/// Modello dati per un piano chirurgico
class SurgicalPlane: Identifiable, ObservableObject {
    let id = UUID()
    
    // Proprietà osservabili
    @Published var name: String
    @Published var type: SurgicalPlaneType
    @Published var color: NSColor
    @Published var opacity: CGFloat = 0.7
    @Published var isVisible: Bool = true
    
    // Proprietà di posizionamento
    @Published var position: SCNVector3
    @Published var normal: SCNVector3
    @Published var width: Float = 100
    @Published var height: Float = 2
    @Published var length: Float = 100

    
    // Nodo SceneKit associato
    var sceneNode: SCNNode?
    
    init(name: String, type: SurgicalPlaneType, position: SCNVector3, normal: SCNVector3) {
        self.name = name
        self.type = type
        self.color = type.defaultColor
        self.position = position
        self.normal = normal
    }
    
    /// Crea un nodo SceneKit per rappresentare il piano
    func createSceneNode() -> SCNNode {
        // Crea la geometria del piano
        let plane = SCNBox(
                width: CGFloat(width),
                height: CGFloat(height),
                length: CGFloat(length),
                chamferRadius: 0
            )
        
        // Crea un materiale con la trasparenza
        let material = SCNMaterial()
        material.diffuse.contents = color.withAlphaComponent(opacity)
        material.isDoubleSided = true
        material.lightingModel = .constant // Non influenzato dall'illuminazione
        plane.materials = [material]
        
        // Crea il nodo con la geometria
        let node = SCNNode(geometry: plane)
        node.name = "surgicalPlane_\(id.uuidString)"
        node.position = position
        
        // Orienta il piano in base alla normale
        orientNodeToNormal(node)
        
        // Memorizza il riferimento al nodo
        self.sceneNode = node
        
        return node
    }
    
    /// Abilita l'interazione con il piano via mouse
    func enableDragInteraction(on view: SCNView, manager: SurgicalPlanningManager) {
        guard let node = sceneNode else { return }
        
        // Aggiungi un nome riconoscibile per l'hit testing
        node.name = "draggablePlane_\(id.uuidString)"
        
        // Crea un pan gesture recognizer
        let panGesture = NSPanGestureRecognizer(target: nil, action: nil)
        panGesture.buttonMask = 0x1 // Click sinistro
        
        // Aggiungi la funzione di gestione
        panGesture.target = DragPlaneGestureHandler(
            plane: self,
            planeNode: node,
            sceneView: view,
            planningManager: manager
        )
        panGesture.action = #selector(DragPlaneGestureHandler.handlePanGesture(_:))
        
        // Aggiungi il gesture recognizer alla vista
        view.addGestureRecognizer(panGesture)
    }
    
    /// Aggiorna il nodo SceneKit esistente
    func updateSceneNode() {
        guard let node = sceneNode, let plane = node.geometry as? SCNBox else { return }

        // Aggiorna la geometria
        plane.width = CGFloat(width)
        plane.height = CGFloat(height)
        plane.length = CGFloat(length)
        
        // Aggiorna il materiale
        if let material = plane.materials.first {
            material.diffuse.contents = color.withAlphaComponent(opacity)
        }
        
        // Aggiorna posizione e orientamento
        node.position = position
        orientNodeToNormal(node)
        
        // Aggiorna visibilità
        node.isHidden = !isVisible
    }
    
    /// Orienta il nodo in base alla normale
    /// Orienta il nodo in base alla normale
    private func orientNodeToNormal(_ node: SCNNode) {
        // Normalizza il vettore normale
        let normalLength = sqrt(normal.x * normal.x + normal.y * normal.y + normal.z * normal.z)
        if normalLength < 0.001 {
            // Se la normale è quasi zero, usa una direzione di default
            node.eulerAngles = SCNVector3(0, 0, 0)
            return
        }
        
        let normalizedNormal = SCNVector3(
            normal.x / normalLength,
            normal.y / normalLength,
            normal.z / normalLength
        )
        
        // Il piano è inizialmente orientato lungo l'asse Y, quindi ruotiamo in base alla normale
        if abs(normalizedNormal.y) > 0.999 {
            // Se la normale è parallela all'asse Y, non è necessaria alcuna rotazione speciale
            node.eulerAngles = SCNVector3(Float.pi/2 * (normalizedNormal.y > 0 ? 1 : -1), 0, 0)
        } else {
            // Altrimenti, calcoliamo la rotazione necessaria
            // Vettore up dell'asse Y
            let upVector = SCNVector3(0, 1, 0)
            
            // Calcola l'asse di rotazione (prodotto vettoriale)
            let crossProduct = SCNVector3(
                upVector.y * normalizedNormal.z - upVector.z * normalizedNormal.y,
                upVector.z * normalizedNormal.x - upVector.x * normalizedNormal.z,
                upVector.x * normalizedNormal.y - upVector.y * normalizedNormal.x
            )
            
            // Calcola l'angolo tra i vettori (prodotto scalare)
            let dotProduct = upVector.x * normalizedNormal.x +
                            upVector.y * normalizedNormal.y +
                            upVector.z * normalizedNormal.z
            
            let angle = acos(dotProduct)
            
            // Imposta la rotazione come quaternione
            let crossLength = sqrt(crossProduct.x * crossProduct.x +
                                   crossProduct.y * crossProduct.y +
                                   crossProduct.z * crossProduct.z)
            
            if crossLength > 0.001 {
                node.rotation = SCNVector4(
                    crossProduct.x / crossLength,
                    crossProduct.y / crossLength,
                    crossProduct.z / crossLength,
                    angle
                )
            }
        }
    }
    
    // Crea linee di intersezione con un piano DICOM (per la vista MPR)
    func createIntersectionLine(with plane: MPROrientation, at sliceIndex: Int, in volume: Volume) -> (startPoint: SIMD2<Float>, endPoint: SIMD2<Float>)? {
        // Implementazione dell'intersezione con i piani MPR
        // Questo verrà completato nella fase successiva dell'implementazione
        return nil
    }
}

/// Gestore per i piani chirurgici
class SurgicalPlanningManager: ObservableObject {
    @Published var planes: [SurgicalPlane] = []
    @Published var selectedPlaneId: UUID?
    
    /// Aggiunge un nuovo piano chirurgico
    func addPlane(type: SurgicalPlaneType, position: SCNVector3, normal: SCNVector3) -> SurgicalPlane {
        let name = "\(type.displayName) \(planes.filter { $0.type == type }.count + 1)"
        let plane = SurgicalPlane(name: name, type: type, position: position, normal: normal)
        planes.append(plane)
        return plane
    }
    
    /// Rimuove un piano chirurgico
    func removePlane(id: UUID) {
        planes.removeAll { $0.id == id }
        if selectedPlaneId == id {
            selectedPlaneId = nil
        }
    }
    
    /// Ottiene il piano selezionato
    var selectedPlane: SurgicalPlane? {
        guard let id = selectedPlaneId else { return nil }
        return planes.first { $0.id == id }
    }
    
    /// Seleziona un piano
    func selectPlane(id: UUID?) {
        selectedPlaneId = id
    }
    
    /// Aggiorna tutti i nodi SceneKit
    func updateAllSceneNodes() {
        for plane in planes {
            plane.updateSceneNode()
        }
    }
}

/// Classe per gestire il drag dei piani
class DragPlaneGestureHandler: NSObject {
    weak var plane: SurgicalPlane?
    weak var planeNode: SCNNode?
    weak var sceneView: SCNView?
    weak var planningManager: SurgicalPlanningManager?
    
    private var initialHitPosition: SCNVector3?
    private var initialPlanePosition: SCNVector3?
    
    init(plane: SurgicalPlane, planeNode: SCNNode, sceneView: SCNView, planningManager: SurgicalPlanningManager) {
        self.plane = plane
        self.planeNode = planeNode
        self.sceneView = sceneView
        self.planningManager = planningManager
        super.init()
    }
    
    @objc func handlePanGesture(_ gestureRecognizer: NSPanGestureRecognizer) {
        guard let planeNode = planeNode, let sceneView = sceneView, let plane = plane else { return }
        
        let location = gestureRecognizer.location(in: sceneView)
        
        switch gestureRecognizer.state {
        case .began:
            // Seleziona il piano quando inizia il drag
            planningManager?.selectPlane(id: plane.id)
            
            // Esegui un hit test per vedere se stiamo cliccando sul piano
            let hitResults = sceneView.hitTest(location, options: [.searchMode: SCNHitTestSearchMode.all.rawValue])
            
            // Trova il risultato che corrisponde al piano
            if let hitResult = hitResults.first(where: { $0.node === planeNode || $0.node.parent === planeNode }) {
                initialHitPosition = hitResult.worldCoordinates
                initialPlanePosition = planeNode.position
            }
            
        case .changed:
            guard let initialHitPosition = initialHitPosition,
                  let initialPlanePosition = initialPlanePosition else { return }
            
            // Calcola la nuova posizione con un punto di riferimento nel mondo
            let currentPoint = unprojectPoint(location, sceneView)
            
            // Muovi il piano solo lungo la sua normale
            let normal = plane.normal
            let normalizedNormal = normalize(normal)
            
            // Calcola lo spostamento lungo la normale
            let hitToCurrentVector = SCNVector3(
                currentPoint.x - initialHitPosition.x,
                currentPoint.y - initialHitPosition.y,
                currentPoint.z - initialHitPosition.z
            )
            
            // Proietta lo spostamento sulla normale
            let projectionLength = dot(hitToCurrentVector, normalizedNormal)
            
            // Calcola la nuova posizione
            let newPosition = SCNVector3(
                Float(initialPlanePosition.x) + Float(normalizedNormal.x) * Float(projectionLength),
                Float(initialPlanePosition.y) + Float(normalizedNormal.y) * Float(projectionLength),
                Float(initialPlanePosition.z) + Float(normalizedNormal.z) * Float(projectionLength)
            )
            
            // Aggiorna la posizione del piano
            planeNode.position = newPosition
            plane.position = newPosition
            
        case .ended, .cancelled:
            // Reset
            initialHitPosition = nil
            initialPlanePosition = nil
            
        default:
            break
        }
    }
    
    // Converte un punto 2D in 3D usando la direzione della camera
    private func unprojectPoint(_ point: CGPoint, _ sceneView: SCNView) -> SCNVector3 {
        let pointNear = SCNVector3(Float(point.x), Float(point.y), 0)
        let pointFar = SCNVector3(Float(point.x), Float(point.y), 1)
        
        let nearPoint = sceneView.unprojectPoint(pointNear)
        let farPoint = sceneView.unprojectPoint(pointFar)
        
        // Direzione dalla camera al punto
        let direction = SCNVector3(
            farPoint.x - nearPoint.x,
            farPoint.y - nearPoint.y,
            farPoint.z - nearPoint.z
        )
        
        return direction
    }
    
    // Calcola il prodotto scalare tra due vettori
    private func dot(_ v1: SCNVector3, _ v2: SCNVector3) -> Float {
        let xProduct = Float(v1.x) * Float(v2.x)
        let yProduct = Float(v1.y) * Float(v2.y)
        let zProduct = Float(v1.z) * Float(v2.z)
        return xProduct + yProduct + zProduct
    }
    
    // Normalizza un vettore
    private func normalize(_ v: SCNVector3) -> SCNVector3 {
        let length = sqrt(v.x * v.x + v.y * v.y + v.z * v.z)
        if length > 0 {
            return SCNVector3(v.x / length, v.y / length, v.z / length)
        }
        return SCNVector3(0, 0, 1)
    }
}
