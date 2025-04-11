import SwiftUI
import SceneKit

/// Vista principale per la visualizzazione e interazione col modello 3D
struct Model3DView: View {
    // MARK: - Proprietà
    @StateObject private var viewModel = Model3DViewModel()
    @ObservedObject var dicomManager: DICOMManager
    
    // MARK: - Inizializzazione
    init(dicomManager: DICOMManager) {
        self.dicomManager = dicomManager
    }
    
    // MARK: - UI
    var body: some View {
        VStack(spacing: 12) {
            // Control panels with consistent styling
            VStack(spacing: 8) {
                RenderingControlsView(
                    thresholdValue: $viewModel.thresholdValue,
                    renderingMode: $viewModel.renderingMode,
                    onModelUpdate: viewModel.updateModel,
                    onRenderingUpdate: viewModel.updateRenderingMode,
                    onResetCamera: viewModel.resetCamera,
                    onExportModel: viewModel.exportModel,
                    onExportModelWithMarkers: viewModel.exportModelWithMarkers
                )
                
                if let markerManager = viewModel.markerManager {
                    Divider()
                    MarkerControlsView(
                        markerManager: markerManager,
                        markerMode: $viewModel.markerMode,
                        activePlaneID: $viewModel.activePlaneID,
                        showAllPlanes: $viewModel.showAllPlanes,
                        onAddNewPlane: viewModel.addNewPlane,
                        onUpdatePlane: viewModel.updatePlane,
                        onClearMarkers: viewModel.clearMarkers
                    )
                    .id("markerControls-\(markerManager.markers.count)") // Force refresh when markers change
                }
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(.windowBackgroundColor).opacity(0.6))
                    .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
            )
            .padding(.horizontal)
            
            // 3D model view
            ModelViewContainer(
                scene: $viewModel.scene,
                scnView: $viewModel.scnView,
                markerMode: $viewModel.markerMode,
                markerManager: viewModel.markerManager
            )
            .cornerRadius(8)
            .shadow(color: .black.opacity(0.2), radius: 3, x: 0, y: 2)
            .padding([.horizontal, .bottom])
        }
        .onAppear {
            viewModel.initialize(dicomManager: dicomManager)
            setupNotifications()
        }
        .onChange(of: viewModel.showAllPlanes) { _, _ in
            viewModel.updatePlaneVisibility()
        }
        .onChange(of: viewModel.activePlaneID) { _, newID in
            viewModel.updateActivePlane(newID)
        }
        .alert("Marker Limit Reached", isPresented: $viewModel.showMarkerLimitAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text("Each cutting plane can have a maximum of 3 markers.")
        }
    }
    
    // MARK: - Setup
    private func setupNotifications() {
        // Notifica per limite di marker raggiunto
        NotificationCenter.default.addObserver(
            forName: NSNotification.Name("MarkerLimitReached"),
            object: nil,
            queue: .main) { _ in
                viewModel.showMarkerLimitAlert = true
            }
        
        // Notifiche per aggiornamenti dei marker
        NotificationCenter.default.addObserver(
            forName: MarkerManager.markerAdded,
            object: nil,
            queue: .main) { _ in
                // Forza aggiornamento della vista
                viewModel.objectWillChange.send()
            }
        
        NotificationCenter.default.addObserver(
            forName: MarkerManager.markerRemoved,
            object: nil,
            queue: .main) { _ in
                // Forza aggiornamento della vista
                viewModel.objectWillChange.send()
            }
        
        NotificationCenter.default.addObserver(
            forName: MarkerManager.markerUpdated,
            object: nil,
            queue: .main) { _ in
                // Forza aggiornamento della vista
                viewModel.objectWillChange.send()
            }
        
        NotificationCenter.default.addObserver(
            forName: MarkerManager.markersCleared,
            object: nil,
            queue: .main) { _ in
                // Forza aggiornamento della vista
                viewModel.objectWillChange.send()
            }
    }
}
