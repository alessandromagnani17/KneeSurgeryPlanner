import SwiftUI

/// Vista per i controlli dei marker
struct MarkerControlsView: View {
    // MARK: - Proprietà
    @ObservedObject var markerManager: MarkerManager
    @Binding var markerMode: MarkerMode
    @Binding var activePlaneID: UUID?
    @Binding var showAllPlanes: Bool
    
    // MARK: - Callback
    var onAddNewPlane: () -> Void
    var onUpdatePlane: () -> Void
    var onClearMarkers: () -> Void
    var onMarkerSelected: (Marker) -> Void  // Nuovo callback per la selezione del marker
    
    // MARK: - UI
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Section header
            Text("Fiducial Markers & Cutting Planes")
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(.secondary)
            
            VStack(spacing: 12) {
                HStack(spacing: 16) {
                    Text("Active Plane:")
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)
                    
                    // Plane picker with colored indicators
                    Picker("", selection: $activePlaneID) {
                        ForEach(markerManager.cuttingPlanes) { plane in
                            HStack {
                                Circle()
                                    .fill(Color(plane.color))
                                    .frame(width: 12, height: 12)
                                Text(plane.name)
                            }
                            .tag(plane.id as UUID?)
                        }
                    }
                    .pickerStyle(MenuPickerStyle())
                    .frame(width: 200)
                    
                    Button(action: onAddNewPlane) {
                        Label("Add Plane", systemImage: "plus")
                    }
                    .buttonStyle(.bordered)
                    
                    Spacer()
                    
                    // Show all planes toggle
                    Toggle(isOn: $showAllPlanes) {
                        Label("Show All Planes", systemImage: "eye")
                    }
                    .toggleStyle(.button)
                    .controlSize(.small)
                }
                
                // Controlli modalità marker
                HStack(spacing: 16) {
                    // Marker mode selector
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Marker Mode:")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                        
                        Picker("", selection: $markerMode) {
                            Label("View", systemImage: "eye").tag(MarkerMode.view)
                            Label("Add", systemImage: "plus.circle").tag(MarkerMode.add)
                            Label("Edit", systemImage: "arrow.up.and.down.and.arrow.left.and.right").tag(MarkerMode.edit)
                            Label("Delete", systemImage: "minus.circle").tag(MarkerMode.delete)
                        }
                        .pickerStyle(SegmentedPickerStyle())
                        .frame(width: 400)
                    }
                    
                    Spacer()
                    
                    // Marker action buttons
                    HStack(spacing: 10) {
                        Button(action: onClearMarkers) {
                            Label("Clear Markers", systemImage: "xmark.circle")
                                .frame(minWidth: 120)
                        }
                        .buttonStyle(.bordered)
                        .disabled(activePlaneID == nil ||
                                 (activePlaneID != nil && markerManager.markers(forPlane: activePlaneID!).isEmpty))
                    }
                }
                
                // Markers list raggruppati per piano
                MarkerListView(
                    markerManager: markerManager,
                    activePlaneID: activePlaneID,
                    onMarkerSelected: onMarkerSelected
                )
            }
        }
    }
}
