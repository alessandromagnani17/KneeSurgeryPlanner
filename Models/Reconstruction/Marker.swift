import Foundation
import SwiftUI
import SceneKit
import simd
import Combine

/// Represents a marker in the 3D scene
struct Marker: Identifiable {
    let id: UUID
    var position: SCNVector3
    var name: String
    var planeGroupID: UUID  // Add plane group identifier
    
    init(position: SCNVector3, name: String = "", planeGroupID: UUID) {
        self.id = UUID()
        self.position = position
        self.name = name.isEmpty ? "Marker \(UUID().uuidString.prefix(5))" : name
        self.planeGroupID = planeGroupID
    }
}

/// Represents a cutting plane defined by markers
struct CuttingPlane: Identifiable {
    let id: UUID
    var name: String
    var color: NSColor
    var node: SCNNode?
    
    init(id: UUID? = nil, name: String, color: NSColor) {
        self.id = id ?? UUID()
        self.name = name
        self.color = color
    }
}

/// Enumeration for marker interaction modes
enum MarkerMode {
    case view      // View only
    case add       // Add markers
    case edit      // Edit marker positions
    case delete    // Remove markers
}

/// Class to manage markers and cutting planes
class MarkerManager: ObservableObject {
    // Nomi delle notifiche
    static let markerAdded = NSNotification.Name("MarkerAdded")
    static let markerRemoved = NSNotification.Name("MarkerRemoved")
    static let markerUpdated = NSNotification.Name("MarkerUpdated")
    static let markersCleared = NSNotification.Name("MarkersCleared")
    
    // Collection of cutting planes
    @Published private(set) var cuttingPlanes: [CuttingPlane] = []
    
    // Collection of markers grouped by plane
    @Published private(set) var markers: [Marker] = []
    
    // Currently active plane group
    @Published private(set) var activePlaneID: UUID?
    
    // SceneKit nodes associated with markers
    private var markerNodes: [UUID: SCNNode] = [:]
    
    // Marker size in points
    private let markerSize: CGFloat = 10.0
    
    // Default colors
    var defaultMarkerColor: NSColor = .systemRed
    var selectedMarkerColor: NSColor = .systemYellow
    
    // Reference to the scene
    private weak var scene: SCNScene?
    
    // Currently selected marker
    @Published private(set) var selectedMarkerID: UUID?
    
    /// Initialize the manager with the scene
    init(scene: SCNScene) {
        self.scene = scene
        
        // Create two default cutting plane groups
        let plane1 = CuttingPlane(name: "Cutting Plane 1", color: NSColor(calibratedRed: 0.2, green: 0.6, blue: 1.0, alpha: 0.3))
        
        cuttingPlanes = [plane1]
        activePlaneID = plane1.id
    }
    
    /// Get markers belonging to a specific plane
    func markers(forPlane planeID: UUID) -> [Marker] {
        return markers.filter { $0.planeGroupID == planeID }
    }
    
    /// Set the active plane for adding new markers
    func setActivePlane(id: UUID) {
        activePlaneID = id
        selectedMarkerID = nil
    }
    
    /// Add a new cutting plane
    @discardableResult
    func addCuttingPlane(name: String, color: NSColor) -> UUID {
        let newPlane = CuttingPlane(name: name, color: color)
        cuttingPlanes.append(newPlane)
        NotificationCenter.default.post(name: MarkerManager.markerUpdated, object: self, userInfo: ["planeID": newPlane.id])
        return newPlane.id
    }
    
    /// Remove a cutting plane and its markers
    func removeCuttingPlane(id: UUID) {
        // Remove associated markers first
        let planeMarkers = markers(forPlane: id)
        for marker in planeMarkers {
            removeMarker(id: marker.id)
        }
        
        // Remove the plane node
        if let planeIndex = cuttingPlanes.firstIndex(where: { $0.id == id }) {
            if let node = cuttingPlanes[planeIndex].node {
                node.removeFromParentNode()
            }
            cuttingPlanes.remove(at: planeIndex)
        }
        
        // Update active plane if needed
        if activePlaneID == id {
            activePlaneID = cuttingPlanes.first?.id
        }
        
        NotificationCenter.default.post(name: MarkerManager.markerUpdated, object: self, userInfo: ["planeID": id])
    }
    
    /// Get the color associated with a plane
    func planeColor(id: UUID) -> NSColor {
        if let plane = cuttingPlanes.first(where: { $0.id == id }) {
            return plane.color
        }
        return defaultMarkerColor
    }
    
    /// Add a new marker to the active plane
    @discardableResult
    func addMarker(at position: SCNVector3, name: String = "") -> Marker? {
        guard let activePlaneID = activePlaneID else { return nil }
        
        // Verifica se abbiamo già 3 marker per questo piano
        let planeMarkers = markers(forPlane: activePlaneID)
        if planeMarkers.count >= 3 {
            // Già 3 marker, non aggiungerne altri
            return nil
        }
        
        let marker = Marker(position: position, name: name.isEmpty ? "Marker \(planeMarkers.count + 1)" : name, planeGroupID: activePlaneID)
        markers.append(marker)
        createMarkerNode(for: marker)
        updateCuttingPlane(planeID: activePlaneID)
        
        // Invia notifica
        NotificationCenter.default.post(name: MarkerManager.markerAdded, object: self, userInfo: ["marker": marker, "planeID": activePlaneID])
        
        // Forza un aggiornamento dell'interfaccia UI
        objectWillChange.send()
        
        return marker
    }
    
    /// Remove a marker
    func removeMarker(id: UUID) {
        if let index = markers.firstIndex(where: { $0.id == id }) {
            let planeID = markers[index].planeGroupID
            markers.remove(at: index)
            
            // Remove the node from the scene
            if let node = markerNodes[id] {
                node.removeFromParentNode()
                markerNodes.removeValue(forKey: id)
            }
            
            // If it was selected, deselect
            if selectedMarkerID == id {
                selectedMarkerID = nil
            }
            
            updateCuttingPlane(planeID: planeID)
            
            // Invia notifica
            NotificationCenter.default.post(name: MarkerManager.markerRemoved, object: self, userInfo: ["markerID": id, "planeID": planeID])
            
            // Forza un aggiornamento dell'interfaccia UI
            objectWillChange.send()
        }
    }
    
    /// Remove all markers for a specific plane
    func removeAllMarkers(forPlane planeID: UUID? = nil) {
        let planeIDToUse = planeID ?? activePlaneID
        
        if let specificPlaneID = planeIDToUse {
            // Remove markers for the specific plane
            let markersToRemove = markers.filter { $0.planeGroupID == specificPlaneID }
            for marker in markersToRemove {
                if let node = markerNodes[marker.id] {
                    node.removeFromParentNode()
                    markerNodes.removeValue(forKey: marker.id)
                }
            }
            
            // Remove the plane node
            if let planeIndex = cuttingPlanes.firstIndex(where: { $0.id == specificPlaneID }) {
                if let node = cuttingPlanes[planeIndex].node {
                    node.removeFromParentNode()
                    cuttingPlanes[planeIndex].node = nil
                }
            }
            
            // Filter out the markers
            markers = markers.filter { $0.planeGroupID != specificPlaneID }
            
            // Deselect if needed
            if let selectedID = selectedMarkerID,
               markersToRemove.contains(where: { $0.id == selectedID }) {
                selectedMarkerID = nil
            }
            
            // Invia notifica
            NotificationCenter.default.post(name: MarkerManager.markersCleared, object: self, userInfo: ["planeID": specificPlaneID])
        } else {
            // Remove all markers from all planes
            for (_, node) in markerNodes {
                node.removeFromParentNode()
            }
            
            // Remove all plane nodes
            for i in 0..<cuttingPlanes.count {
                if let node = cuttingPlanes[i].node {
                    node.removeFromParentNode()
                    cuttingPlanes[i].node = nil
                }
            }
            
            // Clear collections
            markers.removeAll()
            markerNodes.removeAll()
            selectedMarkerID = nil
            
            // Invia notifica
            NotificationCenter.default.post(name: MarkerManager.markersCleared, object: self, userInfo: nil)
        }
        
        // Forza un aggiornamento dell'interfaccia UI
        objectWillChange.send()
    }
    
    /// Update a marker's position
    func updateMarker(id: UUID, position: SCNVector3) {
        guard let index = markers.firstIndex(where: { $0.id == id }) else { return }
        
        // Update position in the model
        let planeID = markers[index].planeGroupID
        markers[index].position = position
        
        // Update node position
        if let node = markerNodes[id] {
            node.position = position
        }
        
        updateCuttingPlane(planeID: planeID)
        
        // Invia notifica
        NotificationCenter.default.post(name: MarkerManager.markerUpdated, object: self, userInfo: ["markerID": id, "planeID": planeID])
        
        // Forza un aggiornamento dell'interfaccia UI
        objectWillChange.send()
    }
    
    /// Select a marker
    func selectMarker(id: UUID?) {
        // Deselect current marker
        if let selectedID = selectedMarkerID, let node = markerNodes[selectedID] {
            if let sphere = node.geometry as? SCNSphere {
                let markerPlaneID = markers.first(where: { $0.id == selectedID })?.planeGroupID
                let color = markerPlaneID.map { planeColor(id: $0) } ?? defaultMarkerColor
                sphere.firstMaterial?.diffuse.contents = color.withAlphaComponent(1.0)  // Assicura alpha 1.0
            }
        }
        
        selectedMarkerID = id
        
        // Select new marker
        if let id = id, let node = markerNodes[id] {
            if let sphere = node.geometry as? SCNSphere {
                sphere.firstMaterial?.diffuse.contents = selectedMarkerColor
            }
        }
        
        // Forza un aggiornamento dell'interfaccia UI
        objectWillChange.send()
    }
    
    /// Find the nearest marker to a given position
    func findNearestMarker(to position: SCNVector3, maxDistance: Float = 10.0, planeID: UUID? = nil) -> UUID? {
        var nearestID: UUID? = nil
        var minDistance = Float.greatestFiniteMagnitude
        
        let filteredMarkers = planeID != nil ?
            markers.filter { $0.planeGroupID == planeID } : markers
        
        for marker in filteredMarkers {
            let distance = distanceBetween(marker.position, position)
            if distance < minDistance && distance < maxDistance {
                minDistance = distance
                nearestID = marker.id
            }
        }
        
        return nearestID
    }
    
    /// Sposta la camera per inquadrare un marker specifico
    /// - Parameters:
    ///   - markerId: ID del marker da inquadrare
    ///   - scnView: La vista SceneKit in cui si trova la scena
    ///   - duration: Durata dell'animazione in secondi
    func focusCameraOnMarker(markerId: UUID, scnView: SCNView?, duration: Double = 0.5) {
        guard let scnView = scnView else { return }
        
        // Trova il marker specifico
        guard let marker = markers.first(where: { $0.id == markerId }),
              let node = markerNodes[markerId] else { return }
        
        // Seleziona il marker
        selectMarker(id: markerId)
        
        // Ottieni la posizione attuale della camera
        let currentPosition = scnView.pointOfView?.position ?? SCNVector3Zero
        
        // Calcola una posizione leggermente distante dal marker in direzione della camera attuale
        // per inquadrarlo frontalmente
        let offset: Float = 100.0 // Distanza di offset dal marker
        
        // Calcola il vettore normalizzato dalla camera attuale al marker
        let dirToMarker = SCNVector3(
            marker.position.x - currentPosition.x,
            marker.position.y - currentPosition.y,
            marker.position.z - currentPosition.z
        )
        
        // Normalizza il vettore per ottenere la direzione
        let length = sqrt(
            Float(dirToMarker.x * dirToMarker.x) +
            Float(dirToMarker.y * dirToMarker.y) +
            Float(dirToMarker.z * dirToMarker.z)
        )
        
        guard length > 0.001 else { return } // Evita divisione per zero
        
        let normalizedDir = SCNVector3(
            dirToMarker.x / CGFloat(length),
            dirToMarker.y / CGFloat(length),
            dirToMarker.z / CGFloat(length)
        )
        
        // Calcola la nuova posizione della camera (marker - direzione normalizzata * offset)
        let newCameraPosition = SCNVector3(
            marker.position.x - normalizedDir.x * CGFloat(offset),
            marker.position.y - normalizedDir.y * CGFloat(offset),
            marker.position.z - normalizedDir.z * CGFloat(offset)
        )
        
        // Crea un'animazione per spostare la camera
        SCNTransaction.begin()
        SCNTransaction.animationDuration = duration
        SCNTransaction.animationTimingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        
        // Sposta la camera alla nuova posizione
        scnView.pointOfView?.position = newCameraPosition
        
        // Orienta la camera verso il marker
        let lookAtConstraint = SCNLookAtConstraint(target: node)
        lookAtConstraint.isGimbalLockEnabled = true
        scnView.pointOfView?.constraints = [lookAtConstraint]
        
        // Imposta il vincolo solo temporaneamente per l'animazione
        SCNTransaction.completionBlock = {
            // Rimuovi il vincolo dopo l'animazione per permettere di controllare la camera normalmente
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                scnView.pointOfView?.constraints = []
            }
        }
        
        SCNTransaction.commit()
    }
    
    
    // MARK: - Private methods for managing SceneKit nodes
    
    /// Create a visual node for a marker
    private func createMarkerNode(for marker: Marker) {
        guard let scene = scene else { return }
        
        // Create a sphere to represent the marker
        let sphere = SCNSphere(radius: markerSize / 2)
        sphere.firstMaterial?.diffuse.contents = planeColor(id: marker.planeGroupID).withAlphaComponent(1.0)
        sphere.firstMaterial?.lightingModel = .constant
        
        // Create the node
        let node = SCNNode(geometry: sphere)
        node.position = marker.position
        node.name = "Marker_\(marker.id.uuidString)"
        
        // Add a label with the marker name
        let textGeometry = SCNText(string: marker.name, extrusionDepth: 0)
        textGeometry.font = NSFont.systemFont(ofSize: 6)
        textGeometry.firstMaterial?.diffuse.contents = NSColor.white
        textGeometry.firstMaterial?.lightingModel = .constant
        
        let textNode = SCNNode(geometry: textGeometry)
        textNode.scale = SCNVector3(0.5, 0.5, 0.5)
        textNode.position = SCNVector3(Float(markerSize)/2, Float(markerSize)/2, 0)
        node.addChildNode(textNode)
        
        // Add to scene and map
        scene.rootNode.addChildNode(node)
        markerNodes[marker.id] = node
    }
    
    /// Update the cutting plane for a specific plane group
    func updateCuttingPlane(planeID: UUID) {
        // Get the cutting plane
        guard let planeIndex = cuttingPlanes.firstIndex(where: { $0.id == planeID }) else { return }
        
        // Remove existing plane node
        if let node = cuttingPlanes[planeIndex].node {
            node.removeFromParentNode()
            cuttingPlanes[planeIndex].node = nil
        }
        
        // Get markers for this plane
        let planeMarkers = markers(forPlane: planeID)
        
        // Need at least 3 markers to define a plane
        guard planeMarkers.count >= 3, let scene = scene else { return }
        
        // Calculate plane center (average of positions)
        var centerX: CGFloat = 0
        var centerY: CGFloat = 0
        var centerZ: CGFloat = 0
        
        for marker in planeMarkers {
            centerX += marker.position.x
            centerY += marker.position.y
            centerZ += marker.position.z
        }
        
        centerX /= CGFloat(planeMarkers.count)
        centerY /= CGFloat(planeMarkers.count)
        centerZ /= CGFloat(planeMarkers.count)
        
        let center = SCNVector3(centerX, centerY, centerZ)
        
        // Calculate normal vectors to the plane
        let points = planeMarkers.map { simd_float3(Float($0.position.x), Float($0.position.y), Float($0.position.z)) }
        guard let normalVector = calculatePlaneNormal(from: points) else { return }
        
        // Determine plane size based on distance between markers
        let maxDistance = findMaxDistance(between: planeMarkers.map { $0.position })
        let planeSize = CGFloat(maxDistance * 3)
        
        // Create the plane
        let plane = SCNPlane(width: planeSize, height: planeSize)
        plane.firstMaterial?.diffuse.contents = cuttingPlanes[planeIndex].color
        plane.firstMaterial?.isDoubleSided = true
        
        // Create the plane node
        let planeNode = SCNNode(geometry: plane)
        planeNode.position = center
        planeNode.name = "cuttingPlane_\(planeID.uuidString)"
        
        // Orient the plane perpendicular to the normal vector
        orientNodeToNormal(planeNode, normal: SCNVector3(normalVector.x, normalVector.y, normalVector.z))
        
        // Add to scene
        scene.rootNode.addChildNode(planeNode)
        cuttingPlanes[planeIndex].node = planeNode
    }
    
    /// Update all cutting planes
    func updateAllCuttingPlanes() {
        for plane in cuttingPlanes {
            updateCuttingPlane(planeID: plane.id)
        }
    }
    
    /// Orient a node to be perpendicular to a normal vector
    private func orientNodeToNormal(_ node: SCNNode, normal: SCNVector3) {
        // Reference vector (usually [0,0,1] for an SCNPlane)
        let planeNormal = SCNVector3(0, 0, 1)
        
        // Calculate rotation axis
        let rotationAxis = crossProduct(planeNormal, normal)
        
        if length(rotationAxis) > 0.001 {  // Avoid division by zero
            // Calculate angle between vectors
            let dotProduct = dotProduct(planeNormal, normal)
            let normalLength = length(normal)
            let angle = acos(dotProduct / normalLength)
            
            // Create rotation around axis
            node.rotation = SCNVector4(rotationAxis.x, rotationAxis.y, rotationAxis.z, CGFloat(angle))
        }
    }
    
    /// Calculate plane normal vector from points
    private func calculatePlaneNormal(from points: [simd_float3]) -> simd_float3? {
        guard points.count >= 3 else { return nil }
        
        // Use first three points to define two vectors on the plane
        let v1 = points[1] - points[0]
        let v2 = points[2] - points[0]
        
        // Cross product gives the normal vector
        let normal = simd_normalize(simd_cross(v1, v2))
        return normal
    }
    
    /// Find maximum distance between pairs of markers
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
    
    // MARK: - Vector calculation functions
    
    /// Calculate distance between two points
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
    
    /// Calculate vector length
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
    
    /// Calculate dot product between vectors
    private func dotProduct(_ v1: SCNVector3, _ v2: SCNVector3) -> Float {
        let xProduct = Float(v1.x) * Float(v2.x)
        let yProduct = Float(v1.y) * Float(v2.y)
        let zProduct = Float(v1.z) * Float(v2.z)
        
        return xProduct + yProduct + zProduct
    }
    
    /// Calculate cross product between vectors
    private func crossProduct(_ v1: SCNVector3, _ v2: SCNVector3) -> SCNVector3 {
        return SCNVector3(
            v1.y * v2.z - v1.z * v2.y,
            v1.z * v2.x - v1.x * v2.z,
            v1.x * v2.y - v1.y * v2.x
        )
    }
}
