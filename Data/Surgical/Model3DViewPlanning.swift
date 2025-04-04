import SwiftUI
import SceneKit

/// Estensione di Model3DView per supportare la pianificazione chirurgica
extension Model3DView {
    
    // MARK: - Viste UI per pianificazione
    
    /// Vista per i controlli di pianificazione
    func planningControlsUI(
        isPlanningModeActive: Bool,
        selectedPlaneType: SurgicalPlaneType,
        onTogglePlanningMode: @escaping () -> Void,
        onSelectPlaneType: @escaping (SurgicalPlaneType) -> Void,
        onAddPlane: @escaping () -> Void,
        onRemovePlane: @escaping () -> Void,
        onRotatePlaneX: @escaping () -> Void,
        onRotatePlaneY: @escaping () -> Void
    ) -> some View {
        VStack(alignment: .leading) {
            HStack {
                Text("Pianificazione Chirurgica")
                    .font(.headline)
                
                Spacer()
                
                Button(action: onTogglePlanningMode) {
                    Text(isPlanningModeActive ? "Disattiva Pianificazione" : "Attiva Pianificazione")
                }
                .buttonStyle(.bordered)
            }
            
            if isPlanningModeActive {
                HStack(spacing: 16) {
                    // Menu di selezione del tipo di piano
                    Picker("Tipo", selection: Binding<SurgicalPlaneType>(
                        get: { selectedPlaneType },
                        set: { onSelectPlaneType($0) }
                    )) {
                        ForEach(SurgicalPlaneType.allCases) { type in
                            Text(type.displayName).tag(type)
                        }
                    }
                    .frame(width: 180)
                    
                    // Pulsanti di azione
                    Button(action: onAddPlane) {
                        Label("Aggiungi Piano", systemImage: "plus")
                    }
                    
                    if planningManager.selectedPlane != nil {
                        Button(action: onRemovePlane) {
                            Label("Rimuovi", systemImage: "trash")
                        }
                        
                        Button(action: onRotatePlaneX) {
                            Label("Ruota X", systemImage: "rotate.right")
                        }
                        
                        Button(action: onRotatePlaneY) {
                            Label("Ruota Y", systemImage: "rotate.left")
                        }
                    }
                    
                    Spacer()
                }
                .padding(.top, 4)
            }
        }
        .padding(.horizontal)
    }
    
    // MARK: - Azioni di pianificazione
    
    /// Aggiunge un nuovo piano chirurgico
    func addNewPlane(from view: SCNView?, type: SurgicalPlaneType, scene: SCNScene, planningManager: SurgicalPlanningManager) {
        guard let view = view else { return }
        
        // Ottieni la posizione della camera
        let cameraPosition = view.pointOfView?.position ?? SCNVector3(0, 0, 0)
        
        // Calcola un punto davanti alla camera
        let distance: Float = 200  // Distanza davanti alla camera
        var direction = SCNVector3(0, 0, -1)  // Direzione iniziale (guarda lungo -Z)
        
        // Applica la rotazione della camera alla direzione
        if let cameraRotation = view.pointOfView?.rotation {
            let rotationMatrix = SCNMatrix4MakeRotation(
                cameraRotation.w,
                cameraRotation.x,
                cameraRotation.y,
                cameraRotation.z
            )
            direction = SCNVector3Make(
                -rotationMatrix.m31,
                -rotationMatrix.m32,
                -rotationMatrix.m33
            )
        }
        
        // Normalizza la direzione
        let length = sqrt(direction.x * direction.x + direction.y * direction.y + direction.z * direction.z)
        if length > 0 {
            direction.x /= length
            direction.y /= length
            direction.z /= length
        }
        
        // Calcola la posizione davanti alla camera
        let position = SCNVector3(
            Float(cameraPosition.x) + Float(direction.x) * Float(distance),
            Float(cameraPosition.y) + Float(direction.y) * Float(distance),
            Float(cameraPosition.z) + Float(direction.z) * Float(distance)
        )
        
        // Crea un nuovo piano
        let plane = planningManager.addPlane(
            type: type,
            position: position,
            normal: direction
        )
        
        // Crea e aggiungi il nodo SceneKit
        let planeNode = plane.createSceneNode()
        scene.rootNode.addChildNode(planeNode)
        
        // Seleziona il piano appena aggiunto
        planningManager.selectPlane(id: plane.id)
    }
    
    /// Ruota il piano selezionato attorno all'asse X
    func rotatePlaneX(planningManager: SurgicalPlanningManager) {
        guard let selectedPlane = planningManager.selectedPlane else { return }
        
        // Ruota la normale del piano
        let angle: Float = Float.pi / 18.0  // 10 gradi
        
        // Crea la matrice di rotazione attorno all'asse X
        let rotationX = simd_float3x3(
            simd_float3(1, 0, 0),
            simd_float3(0, cos(angle), -sin(angle)),
            simd_float3(0, sin(angle), cos(angle))
        )
        
        // Converti SCNVector3 in simd_float3
        let normal = simd_float3(
            Float(selectedPlane.normal.x),
            Float(selectedPlane.normal.y),
            Float(selectedPlane.normal.z)
        )
        
        // Applica la rotazione
        let rotatedNormal = rotationX * normal
        
        // Aggiorna la normale del piano
        selectedPlane.normal = SCNVector3(rotatedNormal.x, rotatedNormal.y, rotatedNormal.z)
        
        // Aggiorna il nodo
        selectedPlane.updateSceneNode()
    }
    
    /// Ruota il piano selezionato attorno all'asse Y
    func rotatePlaneY(planningManager: SurgicalPlanningManager) {
        guard let selectedPlane = planningManager.selectedPlane else { return }
        
        // Ruota la normale del piano
        let angle: Float = Float.pi / 18.0  // 10 gradi
        
        // Crea la matrice di rotazione attorno all'asse Y
        let rotationY = simd_float3x3(
            simd_float3(cos(angle), 0, sin(angle)),
            simd_float3(0, 1, 0),
            simd_float3(-sin(angle), 0, cos(angle))
        )
        
        let normal = simd_float3(
            Float(selectedPlane.normal.x),
            Float(selectedPlane.normal.y),
            Float(selectedPlane.normal.z)
        )
        
        // Applica la rotazione
        let rotatedNormal = rotationY * normal
        
        // Aggiorna la normale del piano
        selectedPlane.normal = SCNVector3(rotatedNormal.x, rotatedNormal.y, rotatedNormal.z)
        
        // Aggiorna il nodo
        selectedPlane.updateSceneNode()
    }
}
