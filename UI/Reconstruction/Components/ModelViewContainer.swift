import SwiftUI
import SceneKit

/// Vista container per il modello 3D che supporta sia la visualizzazione standard che quella con marker
struct ModelViewContainer: View {
    // MARK: - Proprietà
    @Binding var scene: SCNScene
    @Binding var scnView: SCNView?
    @Binding var markerMode: MarkerMode
    let markerManager: MarkerManager?
    
    // MARK: - UI
    var body: some View {
        GeometryReader { geometry in
            Group {
                if let manager = markerManager {
                    SceneKitMarkerView(
                        scene: scene,
                        // Sempre permettere controllo camera e gestire manualmente durante edit
                        allowsCameraControl: true,
                        autoenablesDefaultLighting: true,
                        markerMode: markerMode,
                        markerManager: manager,
                        onSceneViewCreated: { view in
                            DispatchQueue.main.async {
                                scnView = view
                                print("SceneKitMarkerView creata e assegnata")
                            }
                        }
                    )
                } else {
                    SceneKitView(
                        scene: scene,
                        allowsCameraControl: true,
                        autoenablesDefaultLighting: false,
                        onSceneViewCreated: { view in
                            DispatchQueue.main.async(qos: .userInteractive) {
                                scnView = view
                                print("SceneKitView creata e assegnata")
                            }
                        }
                    )
                }
            }
            .onChange(of: markerMode) { oldValue, newValue in
                // Quando si cambia modalità, assicurati che il controllo camera sia appropriato
                if newValue != .edit {
                    scnView?.allowsCameraControl = true
                }
            }
        }
    }
}
