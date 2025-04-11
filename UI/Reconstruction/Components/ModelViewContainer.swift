import SwiftUI
import SceneKit

/// Vista container per il modello 3D che supporta sia la visualizzazione standard che quella con marker
struct ModelViewContainer: View {
    // MARK: - Proprietà
    @Binding var scene: SCNScene
    @Binding var scnView: SCNView?
    @Binding var markerMode: MarkerMode
    let markerManager: FiducialMarkerManager?
    
    // Usiamo una variabile privata per tracciare quando la view è stata creata
    @State private var hasSetupSceneView = false
    
    // MARK: - UI
    var body: some View {
        GeometryReader { geometry in
            Group {
                if let manager = markerManager {
                    SceneKitMarkerView(
                        scene: scene,
                        allowsCameraControl: markerMode != .edit,
                        autoenablesDefaultLighting: true,
                        markerMode: markerMode,
                        markerManager: manager,
                        onSceneViewCreated: { view in
                            // Salviamo la view per usarla dopo
                            DispatchQueue.main.async {
                                if !hasSetupSceneView {
                                    scnView = view
                                    hasSetupSceneView = true
                                }
                            }
                        }
                    )
                } else {
                    SceneKitView(
                        scene: scene,
                        allowsCameraControl: true,
                        autoenablesDefaultLighting: false,
                        onSceneViewCreated: { view in
                            DispatchQueue.main.async {
                                if !hasSetupSceneView {
                                    scnView = view
                                    hasSetupSceneView = true
                                }
                            }
                        }
                    )
                }
            }
        }
    }
}
