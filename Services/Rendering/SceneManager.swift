import SceneKit

/// Classe per la gestione della scena 3D e dei suoi elementi
class SceneManager {
    // MARK: - Proprietà
    private let scene: SCNScene
    
    // MARK: - Inizializzazione
    init(scene: SCNScene) {
        self.scene = scene
    }
    
    // MARK: - Gestione del rendering
    
    /// Aggiorna la modalità di rendering del modello
    func updateRenderingMode(_ renderingMode: RenderingMode) {
        guard let meshNode = scene.rootNode.childNodes.first(where: { $0.name == "volumeMesh" }),
              let geometry = meshNode.geometry else {
            return
        }
        
        // Rimuovi eventuali nodi wireframe esistenti se non necessari
        if renderingMode != .solidWithWireframe {
            scene.rootNode.childNodes.filter { $0.name == "wireframeMesh" }.forEach {
                $0.removeFromParentNode()
            }
        }
        
        // Applica il materiale in base alla modalità di rendering
        for i in 0..<geometry.materials.count {
            applyMaterial(to: geometry.materials[i], forMode: renderingMode)
        }
        
        // Aggiungi overlay wireframe se necessario
        if renderingMode == .solidWithWireframe {
            addWireframeOverlay(for: geometry, parentNode: meshNode)
        }
    }
    
    /// Applica un materiale specifico in base alla modalità di rendering
    private func applyMaterial(to material: SCNMaterial, forMode mode: RenderingMode) {
        switch mode {
        case .solid:
            material.fillMode = .fill
            material.isDoubleSided = false
            material.cullMode = .back
            material.diffuse.contents = NSColor(calibratedRed: 0.9, green: 0.9, blue: 0.9, alpha: 1.0)
            material.specular.contents = NSColor.white
            material.shininess = 0.3
            material.lightingModel = .phong
            material.ambient.contents = NSColor(white: 0.6, alpha: 1.0)
            
        case .wireframe:
            material.fillMode = .lines
            material.isDoubleSided = true
            material.diffuse.contents = NSColor.white
            material.lightingModel = .constant
            
        case .solidWithWireframe:
            material.fillMode = .fill
            material.isDoubleSided = false
            material.cullMode = .back
            material.diffuse.contents = NSColor(calibratedRed: 0.9, green: 0.9, blue: 0.9, alpha: 1.0)
            material.specular.contents = NSColor.white
            material.shininess = 0.3
            material.lightingModel = .phong
        }
    }
    
    /// Aggiunge un overlay wireframe al modello
    private func addWireframeOverlay(for geometry: SCNGeometry, parentNode: SCNNode) {
        if !scene.rootNode.childNodes.contains(where: { $0.name == "wireframeMesh" }) {
            let wireframeGeometry = geometry.copy() as! SCNGeometry
            let wireMaterial = SCNMaterial()
            wireMaterial.fillMode = .lines
            wireMaterial.diffuse.contents = NSColor.black
            wireMaterial.lightingModel = .constant
            wireMaterial.cullMode = .back
            
            wireframeGeometry.materials = [wireMaterial]
            
            let wireframeNode = SCNNode(geometry: wireframeGeometry)
            wireframeNode.name = "wireframeMesh"
            wireframeNode.position = parentNode.position
            wireframeNode.scale = SCNVector3(1.001, 1.001, 1.001)
            scene.rootNode.addChildNode(wireframeNode)
        }
    }
}
