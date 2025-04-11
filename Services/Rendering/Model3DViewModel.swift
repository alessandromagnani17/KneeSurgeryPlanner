import SwiftUI
import SceneKit

/// ViewModel per la gestione dello stato e della logica di Model3DView
class Model3DViewModel: ObservableObject {
    // MARK: - Proprietà pubblicate
    @Published var scene = SCNScene()
    @Published var thresholdValue: Float = 600
    @Published var renderingMode: RenderingMode = .solid
    @Published var markerMode: MarkerMode = .view
    @Published var scnView: SCNView?
    @Published var markerManager: MarkerManager?
    @Published var activePlaneID: UUID?
    @Published var showAllPlanes: Bool = true
    @Published var showMarkerLimitAlert = false
    
    // MARK: - Proprietà private
    private let initialCameraPosition = SCNVector3(250, 250, 800)
    private let initialCameraEulerAngles = SCNVector3(0, 0, 0)
    private var cameraNode = SCNNode()
    private var isModelInitialized = false
    private var isExporting = false
    private var dicomManager: DICOMManager?
    private var sceneManager: SceneManager?
    
    // MARK: - Inizializzazione
    func initialize(dicomManager: DICOMManager) {
        self.dicomManager = dicomManager
        self.sceneManager = SceneManager(scene: scene)
        
        if !isModelInitialized {
            setupScene()
            updateModel()
            isModelInitialized = true
        }
        
        if markerManager == nil && !scene.rootNode.childNodes.isEmpty {
            // Inizializza il manager dei marker quando la scena è pronta
            markerManager = MarkerManager(scene: scene)
            // Set the active plane ID to the first available plane
            if let firstPlane = markerManager?.cuttingPlanes.first {
                activePlaneID = firstPlane.id
                markerManager?.setActivePlane(id: firstPlane.id)
            }
        }
    }
    
    // MARK: - Metodi pubblici
    
    /// Aggiorna il modello 3D
    func updateModel() {
        removeExistingModel()
        createNewModel()
    }
    
    /// Aggiorna la modalità di rendering
    func updateRenderingMode() {
        sceneManager?.updateRenderingMode(renderingMode)
    }
    
    /// Ripristina la posizione della camera
    func resetCamera() {
        guard let scnView = self.scnView else { return }
        
        SCNTransaction.begin()
        SCNTransaction.animationDuration = 0.5
        
        // Se scnView.pointOfView è nil, imposta la tua camera come pointOfView
        if scnView.pointOfView == nil {
            scnView.pointOfView = cameraNode
        }
        
        // Aggiorna la posizione e l'orientamento del pointOfView corrente
        scnView.pointOfView?.position = initialCameraPosition
        scnView.pointOfView?.eulerAngles = initialCameraEulerAngles
        
        SCNTransaction.commit()
    }
    
    /// Focalizza la camera su un marker specifico
    func focusCameraOnMarker(_ marker: Marker) {
        guard let markerManager = markerManager, let scnView = scnView else { return }
        
        // Imposta il piano attivo al piano del marker
        activePlaneID = marker.planeGroupID
        
        // Utilizza il MarkerManager per spostare la camera
        markerManager.focusCameraOnMarker(markerId: marker.id, scnView: scnView)
    }
    
    /// Aggiunge un nuovo piano di taglio
    func addNewPlane() {
        guard let markerManager = markerManager else { return }
        
        let planeCount = markerManager.cuttingPlanes.count
        
        // Create colors that are visually distinct
        let colors = [
            NSColor(calibratedRed: 0.2, green: 0.6, blue: 1.0, alpha: 0.3),  // Blue
            NSColor(calibratedRed: 1.0, green: 0.4, blue: 0.4, alpha: 0.3),  // Red
            NSColor(calibratedRed: 0.2, green: 0.8, blue: 0.2, alpha: 0.3),  // Green
            NSColor(calibratedRed: 0.8, green: 0.6, blue: 0.1, alpha: 0.3),  // Orange
            NSColor(calibratedRed: 0.6, green: 0.2, blue: 0.8, alpha: 0.3),  // Purple
            NSColor(calibratedRed: 0.8, green: 0.3, blue: 0.6, alpha: 0.3)   // Pink
        ]
        
        // Use modulo to cycle through colors for planes beyond our predefined set
        let colorIndex = planeCount % colors.count
        let color = colors[colorIndex]
        
        let newPlaneID = markerManager.addCuttingPlane(name: "Cutting Plane \(planeCount + 1)", color: color)
        activePlaneID = newPlaneID
    }
    
    /// Aggiorna il piano attivo
    func updateActivePlane(_ newID: UUID?) {
        if let markerManager = markerManager, let newID = newID {
            markerManager.setActivePlane(id: newID)
            updatePlaneVisibility()
        }
    }
    
    /// Aggiorna il piano di taglio
    func updatePlane() {
        if let activePlaneID = activePlaneID, let markerManager = markerManager {
            markerManager.updateCuttingPlane(planeID: activePlaneID)
        }
    }
    
    /// Rimuove tutti i marker dal piano attivo
    func clearMarkers() {
        if let activePlaneID = activePlaneID, let markerManager = markerManager {
            markerManager.removeAllMarkers(forPlane: activePlaneID)
        }
    }
    
    /// Aggiorna la visibilità dei piani di taglio
    func updatePlaneVisibility() {
        guard let markerManager = markerManager else { return }
        
        if showAllPlanes {
            // Show all planes
            markerManager.updateAllCuttingPlanes()
        } else {
            // Show only the active plane
            for plane in markerManager.cuttingPlanes {
                if plane.id == activePlaneID {
                    markerManager.updateCuttingPlane(planeID: plane.id)
                } else if let node = plane.node {
                    // Hide other planes
                    node.isHidden = true
                }
            }
        }
    }
    
    /// Esporta il modello 3D
    func exportModel() {
        ExportUtils.exportModel(scene: scene)
    }
    
    /// Esporta il modello 3D con marker
    func exportModelWithMarkers() {
        if let markerManager = markerManager {
            ExportUtils.exportModelWithMarkers(scene: scene, markerManager: markerManager)
        }
    }
    
    // MARK: - Metodi privati
    
    /// Configura la scena 3D e l'illuminazione
    private func setupScene() {
        scene.background.contents = NSColor.darkGray
        setupCamera()
        setupLighting()
        
        // Inizializza il manager dei marker
        markerManager = MarkerManager(scene: scene)
    }
    
    /// Configura la camera
    private func setupCamera() {
        let camera = SCNCamera()
        camera.zNear = 1
        camera.zFar = 3000
        camera.fieldOfView = 45
        cameraNode.camera = camera
        cameraNode.position = initialCameraPosition
        cameraNode.eulerAngles = initialCameraEulerAngles
        scene.rootNode.addChildNode(cameraNode)
    }
    
    /// Configura il sistema di illuminazione
    private func setupLighting() {
        // 1. Luce ambientale
        addLight(type: .ambient, intensity: 70,
                 color: NSColor(calibratedRed: 0.9, green: 0.9, blue: 1.0, alpha: 1.0))
        
        // 2. Luce principale direzionale
        let mainLight = addLight(type: .directional, intensity: 1000,
                                 color: NSColor(calibratedRed: 1.0, green: 0.95, blue: 0.9, alpha: 1.0),
                                 position: SCNVector3(100, 150, 100))
        mainLight.light?.castsShadow = true
        mainLight.light?.shadowRadius = 3
        mainLight.light?.shadowColor = NSColor(white: 0.0, alpha: 0.7)
        mainLight.look(at: SCNVector3(0, 0, 0))
        
        // 3. Luce di riempimento
        let fillLight = addLight(type: .directional, intensity: 400,
                                 color: NSColor(calibratedRed: 0.9, green: 0.95, blue: 1.0, alpha: 1.0),
                                 position: SCNVector3(-100, 50, -100))
        fillLight.look(at: SCNVector3(0, 0, 0))
        
        // 4. Luce per i contorni (rim light)
        let rimLight = addLight(type: .directional, intensity: 300,
                                color: NSColor(calibratedRed: 1.0, green: 1.0, blue: 0.9, alpha: 1.0),
                                position: SCNVector3(0, -100, -150))
        rimLight.look(at: SCNVector3(0, 0, 0))
    }
    
    /// Aggiunge una luce alla scena con le specifiche fornite
    private func addLight(type: SCNLight.LightType, intensity: CGFloat,
                         color: NSColor, position: SCNVector3 = SCNVector3(0, 0, 0)) -> SCNNode {
        let lightNode = SCNNode()
        lightNode.light = SCNLight()
        lightNode.light?.type = type
        lightNode.light?.intensity = intensity
        lightNode.light?.color = color
        lightNode.position = position
        scene.rootNode.addChildNode(lightNode)
        return lightNode
    }
    
    /// Rimuove il modello esistente dalla scena
    private func removeExistingModel() {
        let existingNodes = scene.rootNode.childNodes.filter {
            $0.name == "volumeMesh" || $0.name == "testBox" || $0.name == "wireframeMesh"
        }
        existingNodes.forEach { $0.removeFromParentNode() }
    }
    
    /// Crea un nuovo modello 3D
    private func createNewModel() {
        // Ottieni i dati DICOM correnti
        guard let dicomManager = dicomManager,
              let series = dicomManager.currentSeries,
              let volume = dicomManager.createVolumeFromSeries(series) else {
            return
        }
        
        // Stampa valori in diversi punti per capire la distribuzione
        print("=== VALORI CAMPIONE ===")
        let centerX = volume.dimensions.x / 2
        let centerY = volume.dimensions.y / 2
        let centerZ = volume.dimensions.z / 2
        
        print("Centro volume: \(VolumeUtils.getVoxelValue(volume, centerX, centerY, centerZ)) HU")
        
        // Campiona punti in una griglia 3x3x3 attorno al centro
        for z in [centerZ-30, centerZ, centerZ+30] {
            for y in [centerY-30, centerY, centerY+30] {
                for x in [centerX-30, centerX, centerX+30] {
                    if x >= 0 && x < volume.dimensions.x &&
                        y >= 0 && y < volume.dimensions.y &&
                        z >= 0 && z < volume.dimensions.z {
                        let value = VolumeUtils.getVoxelValue(volume, x, y, z)
                        print("[\(x),\(y),\(z)]: \(value) HU")
                    }
                }
            }
        }
        print("======================")
        
        // Stampa informazioni sull'orientamento del volume
        print("Orientamento volume:")
        print("Origin: \(volume.origin)")
        print("Matrice di trasformazione:")
        print(volume.volumeToWorldMatrix)
        
        // Genera la mesh con Marching Cubes
        let marchingCubes = MarchingCubes()
        var mesh = marchingCubes.generateMesh(from: volume, isovalue: thresholdValue)
        
        // Ottimizzazione della mesh
        MeshUtils.closeHolesInMesh(&mesh)
        MeshUtils.fixMeshNormals(&mesh)
        
        // Crea il nodo del modello
        let geometry = SCNGeometry(mesh: mesh)
        let meshNode = SCNNode(geometry: geometry)
        meshNode.name = "volumeMesh"
        scene.rootNode.addChildNode(meshNode)
        
        // Aggiungi miglioramento dei contorni
        addSilhouetteEnhancement(to: meshNode)
        
        // Applica la modalità di rendering scelta
        updateRenderingMode()
    }
    
    /// Aggiunge un effetto di contorno al modello
    private func addSilhouetteEnhancement(to node: SCNNode) {
        guard let geometry = node.geometry else { return }
        
        let outlineGeometry = geometry.copy() as! SCNGeometry
        
        let outlineMaterial = SCNMaterial()
        outlineMaterial.diffuse.contents = NSColor.black
        outlineMaterial.lightingModel = .constant
        outlineMaterial.writesToDepthBuffer = true
        outlineMaterial.readsFromDepthBuffer = true
        
        outlineGeometry.materials = [outlineMaterial]
        
        let outlineNode = SCNNode(geometry: outlineGeometry)
        outlineNode.scale = SCNVector3(1.02, 1.02, 1.02)
        outlineNode.name = "outlineNode"
        
        node.addChildNode(outlineNode)
    }
}
