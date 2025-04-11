import SwiftUI

/// Vista per i controlli di rendering del modello 3D
struct RenderingControlsView: View {
    // MARK: - Proprietà
    @Binding var thresholdValue: Float
    @Binding var renderingMode: RenderingMode
    
    // MARK: - Callback
    var onModelUpdate: () -> Void
    var onRenderingUpdate: () -> Void
    var onResetCamera: () -> Void
    var onExportModel: () -> Void
    var onExportModelWithMarkers: () -> Void
    
    // MARK: - UI
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Section header
            Text("Rendering Options")
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(.secondary)
            
            HStack(spacing: 15) {
                // Threshold control with label
                VStack(alignment: .leading, spacing: 4) {
                    Text("Threshold: \(Int(thresholdValue))")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                    
                    Slider(value: $thresholdValue, in: 0...1000)
                        .frame(width: 200)
                        .onChange(of: thresholdValue) { _, _ in
                            onModelUpdate()
                        }
                }
                
                Spacer()
                
                // Rendering mode picker
                HStack {
                    Text("Style:")
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)
                    
                    Picker("", selection: $renderingMode) {
                        Text("Solid").tag(RenderingMode.solid)
                        Text("Wireframe").tag(RenderingMode.wireframe)
                        Text("Solid+Wire").tag(RenderingMode.solidWithWireframe)
                    }
                    .pickerStyle(SegmentedPickerStyle())
                    .frame(width: 220)
                    .onChange(of: renderingMode) { _, _ in
                        onRenderingUpdate()
                    }
                }
                
                // Action buttons
                HStack(spacing: 10) {
                    Button(action: onResetCamera) {
                        HStack {
                            Image(systemName: "camera.viewfinder")
                            Text("Reset View")
                        }
                        .frame(minWidth: 100)
                    }
                    .buttonStyle(.bordered)
                    
                    // Export menu
                    Menu {
                        Button("Base Model") {
                            onExportModel()
                        }
                        
                        Button("Model with Markers") {
                            // Note: This would need to be called from Model3DView since we need markerManager
                        }
                    } label: {
                        HStack {
                            Image(systemName: "square.and.arrow.up")
                            Text("Export")
                        }
                        .frame(minWidth: 100)
                    }
                    .menuStyle(BorderlessButtonMenuStyle())
                    .buttonStyle(.bordered)
                }
            }
        }
    }
}
