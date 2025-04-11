import SwiftUI
import SceneKit

/// Vista container per il modello 3D che supporta sia la visualizzazione standard che quella con marker
struct ModelViewContainer: View {
    // MARK: - Proprietà
    @Binding var scene: SCNScene
    @Binding var scnView: SCNView?
    @Binding var markerMode: MarkerMode
    let markerManager: FiducialMarkerManager?
    
    // MARK: - UI
    var body: some View {
        GeometryReader { geometry in
            Group {
                if let manager = markerManager {
                    SceneKitMarkerView(
                        scene: scene,
                        allowsCameraControl: markerMode != .edit, // Disabilita controllo camera durante l'editing
                        autoenablesDefaultLighting: true,
                        markerMode: markerMode,
                        markerManager: manager,
                        onSceneViewCreated: { view in
                            self.scnView = view
                        }
                    )
                } else {
                    // Fallback alla vista normale se il manager non è stato inizializzato
                    SceneKitView(
                        scene: scene,
                        allowsCameraControl: true,
                        autoenablesDefaultLighting: false,
                        onSceneViewCreated: { view in
                            self.scnView = view
                        }
                    )
                }
            }
        }
    }
}
