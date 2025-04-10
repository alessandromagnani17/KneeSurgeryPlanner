import Foundation
import SceneKit
import simd

/// Rappresenta un marker fiduciale nella scena 3D
struct FiducialMarker: Identifiable {
    let id: UUID
    var position: SCNVector3
    var name: String
    
    init(position: SCNVector3, name: String = "") {
        self.id = UUID()
        self.position = position
        self.name = name.isEmpty ? "Marker \(UUID().uuidString.prefix(5))" : name
    }
}

/// Enumeration per le modalità di interazione con i marker fiduciali
enum MarkerMode {
    case view      // Solo visualizzazione
    case add       // Aggiungi marker
    case edit      // Modifica posizione marker
    case delete    // Rimuovi marker
}

/// Classe per gestire i marker fiduciali e il piano di taglio
class FiducialMarkerManager {
    // Collezione di marker fiduciali
    private(set) var markers: [FiducialMarker] = []
    
    // Nodi SceneKit associati
    private var markerNodes: [UUID: SCNNode] = [:]
    private var cuttingPlaneNode: SCNNode?
    
    // Dimensione marker in punti
    private let markerSize: CGFloat = 6.0
    
    // Colori configurabili
    var markerColor: NSColor = .systemRed
    var planeColor: NSColor = NSColor(calibratedRed: 0.2, green: 0.6, blue: 1.0, alpha: 0.3)
    var markerSelectedColor: NSColor = .systemYellow
    
    // Riferimento alla scena
    private weak var scene: SCNScene?
    
    // Marker attualmente selezionato
    private(set) var selectedMarkerID: UUID?
    
    /// Inizializza il manager con la scena
    init(scene: SCNScene) {
        self.scene = scene
    }
    
    /// Aggiunge un nuovo marker fiduciale
    @discardableResult
    func addMarker(at position: SCNVector3, name: String = "") -> FiducialMarker {
        let marker = FiducialMarker(position: position, name: name)
        markers.append(marker)
        createMarkerNode(for: marker)
        updateCuttingPlane()
        return marker
    }
    
    /// Rimuove un marker fiduciale
    func removeMarker(id: UUID) {
        if let index = markers.firstIndex(where: { $0.id == id }) {
            markers.remove(at: index)
            
            // Rimuovi il nodo dalla scena
            if let node = markerNodes[id] {
                node.removeFromParentNode()
                markerNodes.removeValue(forKey: id)
            }
            
            // Se era selezionato, deseleziona
            if selectedMarkerID == id {
                selectedMarkerID = nil
            }
            
            updateCuttingPlane()
        }
    }
    
    /// Rimuove tutti i marker
    func removeAllMarkers() {
        // Rimuovi tutti i nodi dalla scena
        for (_, node) in markerNodes {
            node.removeFromParentNode()
        }
        
        // Rimuovi il piano di taglio
        if let cuttingPlaneNode = cuttingPlaneNode {
            cuttingPlaneNode.removeFromParentNode()
            self.cuttingPlaneNode = nil
        }
        
        // Resetta le collezioni
        markers.removeAll()
        markerNodes.removeAll()
        selectedMarkerID = nil
    }
    
    /// Aggiorna la posizione di un marker
    func updateMarker(id: UUID, position: SCNVector3) {
        guard let index = markers.firstIndex(where: { $0.id == id }) else { return }
        
        // Aggiorna la posizione nel modello
        markers[index].position = position
        
        // Aggiorna la posizione del nodo
        if let node = markerNodes[id] {
            node.position = position
        }
        
        updateCuttingPlane()
    }
    
    /// Seleziona un marker
    func selectMarker(id: UUID?) {
        // Deseleziona il marker corrente
        if let selectedID = selectedMarkerID, let node = markerNodes[selectedID] {
            if let sphere = node.geometry as? SCNSphere {
                sphere.firstMaterial?.diffuse.contents = markerColor
            }
        }
        
        selectedMarkerID = id
        
        // Seleziona il nuovo marker
        if let id = id, let node = markerNodes[id] {
            if let sphere = node.geometry as? SCNSphere {
                sphere.firstMaterial?.diffuse.contents = markerSelectedColor
            }
        }
    }
    
    /// Trova il marker più vicino a una posizione data
    func findNearestMarker(to position: SCNVector3, maxDistance: Float = 10.0) -> UUID? {
        var nearestID: UUID? = nil
        var minDistance = Float.greatestFiniteMagnitude
        
        for marker in markers {
            let distance = distanceBetween(marker.position, position)
            if distance < minDistance && distance < maxDistance {
                minDistance = distance
                nearestID = marker.id
            }
        }
        
        return nearestID
    }
    
    // MARK: - Metodi privati per la gestione dei nodi SceneKit
    
    /// Crea un nodo visivo per un marker
    private func createMarkerNode(for marker: FiducialMarker) {
        guard let scene = scene else { return }
        
        // Crea una sfera per rappresentare il marker
        let sphere = SCNSphere(radius: markerSize / 2)
        sphere.firstMaterial?.diffuse.contents = markerColor
        sphere.firstMaterial?.lightingModel = .constant // Non influenzato dall'illuminazione
        
        // Crea il nodo
        let node = SCNNode(geometry: sphere)
        node.position = marker.position
        node.name = "fiducialMarker_\(marker.id.uuidString)"
        
        // Aggiungi un'etichetta con il nome del marker
        let textGeometry = SCNText(string: marker.name, extrusionDepth: 0)
        textGeometry.font = NSFont.systemFont(ofSize: 2)
        textGeometry.firstMaterial?.diffuse.contents = NSColor.white
        textGeometry.firstMaterial?.lightingModel = .constant
        
        let textNode = SCNNode(geometry: textGeometry)
        textNode.scale = SCNVector3(0.5, 0.5, 0.5)
        textNode.position = SCNVector3(Float(markerSize), Float(markerSize), 0)
        node.addChildNode(textNode)
        
        // Aggiungi alla scena e alla mappa
        scene.rootNode.addChildNode(node)
        markerNodes[marker.id] = node
    }
    
    /// Aggiorna il piano di taglio in base ai marker attuali
    func updateCuttingPlane() {
        // Rimuovi il piano esistente
        cuttingPlaneNode?.removeFromParentNode()
        cuttingPlaneNode = nil
        
        // Sono necessari almeno 3 marker per definire un piano
        guard markers.count >= 3, let scene = scene else { return }
        
        // Calcola il centro del piano (media delle posizioni)
        var centerX: CGFloat = 0
        var centerY: CGFloat = 0
        var centerZ: CGFloat = 0
        
        for marker in markers {
            centerX += marker.position.x
            centerY += marker.position.y
            centerZ += marker.position.z
        }
        
        centerX /= CGFloat(markers.count)
        centerY /= CGFloat(markers.count)
        centerZ /= CGFloat(markers.count)
        
        let center = SCNVector3(centerX, centerY, centerZ)
        
        // Calcola i vettori normali al piano
        let points = markers.map { simd_float3(Float($0.position.x), Float($0.position.y), Float($0.position.z)) }
        guard let normalVector = calculatePlaneNormal(from: points) else { return }
        
        // Determina la dimensione del piano in base alla distanza tra i marker
        let maxDistance = findMaxDistance(between: markers.map { $0.position })
        let planeSize = CGFloat(maxDistance * 1.5) // Piano leggermente più grande della regione dei marker
        
        // Crea il piano
        let plane = SCNPlane(width: planeSize, height: planeSize)
        plane.firstMaterial?.diffuse.contents = planeColor
        plane.firstMaterial?.isDoubleSided = true // Visibile da entrambi i lati
        
        // Crea il nodo del piano
        let planeNode = SCNNode(geometry: plane)
        planeNode.position = center
        planeNode.name = "cuttingPlane"
        
        // Orienta il piano perpendicolare al vettore normale
        orientNodeToNormal(planeNode, normal: SCNVector3(normalVector.x, normalVector.y, normalVector.z))
        
        // Aggiungi alla scena
        scene.rootNode.addChildNode(planeNode)
        cuttingPlaneNode = planeNode
    }
    
    /// Orienta un nodo in modo che sia perpendicolare a un vettore normale
    private func orientNodeToNormal(_ node: SCNNode, normal: SCNVector3) {
        // Vettore di riferimento (solitamente [0,0,1] per un piano SCNPlane)
        let planeNormal = SCNVector3(0, 0, 1)
        
        // Calcola l'asse di rotazione
        let rotationAxis = crossProduct(planeNormal, normal)
        
        if length(rotationAxis) > 0.001 {  // Evita la divisione per zero
            // Calcola l'angolo tra i vettori
            let dotProduct = dotProduct(planeNormal, normal)
            let normalLength = length(normal)
            let angle = acos(dotProduct / normalLength)
            
            // Crea una rotazione attorno all'asse
            node.rotation = SCNVector4(rotationAxis.x, rotationAxis.y, rotationAxis.z, CGFloat(angle))
        }
    }
    
    /// Calcola il vettore normale al piano definito dai punti
    private func calculatePlaneNormal(from points: [simd_float3]) -> simd_float3? {
        guard points.count >= 3 else { return nil }
        
        // Usa i primi tre punti per definire due vettori sul piano
        let v1 = points[1] - points[0]
        let v2 = points[2] - points[0]
        
        // Il prodotto vettoriale dà il vettore normale
        let normal = simd_normalize(simd_cross(v1, v2))
        return normal
    }
    
    /// Trova la distanza massima tra le coppie di marker
    private func findMaxDistance(between positions: [SCNVector3]) -> Float {
        var maxDist: Float = 0
        
        for i in 0..<positions.count {
            for j in (i+1)..<positions.count {
                let dist = distanceBetween(positions[i], positions[j])
                maxDist = max(maxDist, dist)
            }
        }
        
        return maxDist
    }
    
    // MARK: - Funzioni di calcolo vettoriale
    
    /// Calcola la distanza tra due punti
    private func distanceBetween(_ v1: SCNVector3, _ v2: SCNVector3) -> Float {
        let dx = Float(v2.x - v1.x)
        let dy = Float(v2.y - v1.y)
        let dz = Float(v2.z - v1.z)
        
        let dxSquare = dx * dx
        let dySquare = dy * dy
        let dzSquare = dz * dz
        
        let sumOfSquares = dxSquare + dySquare + dzSquare
        return sqrt(sumOfSquares)
    }
    
    /// Calcola la lunghezza di un vettore
    private func length(_ v: SCNVector3) -> Float {
        let xFloat = Float(v.x)
        let yFloat = Float(v.y)
        let zFloat = Float(v.z)
        
        let xSquare = xFloat * xFloat
        let ySquare = yFloat * yFloat
        let zSquare = zFloat * zFloat
        
        let sumOfSquares = xSquare + ySquare + zSquare
        return sqrt(sumOfSquares)
    }
    
    /// Calcola il prodotto scalare tra due vettori
    private func dotProduct(_ v1: SCNVector3, _ v2: SCNVector3) -> Float {
        let xProduct = Float(v1.x) * Float(v2.x)
        let yProduct = Float(v1.y) * Float(v2.y)
        let zProduct = Float(v1.z) * Float(v2.z)
        
        return xProduct + yProduct + zProduct
    }
    
    /// Calcola il prodotto vettoriale tra due vettori
    private func crossProduct(_ v1: SCNVector3, _ v2: SCNVector3) -> SCNVector3 {
        return SCNVector3(
            v1.y * v2.z - v1.z * v2.y,
            v1.z * v2.x - v1.x * v2.z,
            v1.x * v2.y - v1.y * v2.x
        )
    }
}
