import SwiftUI

/// Vista per la visualizzazione della lista dei marker raggruppati per piano di taglio
struct MarkerListView: View {
    // MARK: - Proprietà
    @ObservedObject var markerManager: MarkerManager
    let activePlaneID: UUID?
    
    // MARK: - UI
    var body: some View {
        VStack {
            ForEach(markerManager.cuttingPlanes) { plane in
                let planeMarkers = markerManager.markers(forPlane: plane.id)
                if !planeMarkers.isEmpty {
                    VStack(alignment: .leading, spacing: 4) {
                        // Group header
                        HStack {
                            Circle()
                                .fill(Color(plane.color))
                                .frame(width: 8, height: 8)
                            Text(plane.name)
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(plane.id == activePlaneID ? .primary : .secondary)
                            
                            Text("(\(planeMarkers.count) markers)")
                                .font(.system(size: 10))
                                .foregroundColor(.secondary)
                        }
                        
                        // Marker list
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                ForEach(planeMarkers) { marker in
                                    HStack(spacing: 4) {
                                        Text(marker.name)
                                            .font(.system(size: 12))
                                    }
                                    .padding(.vertical, 4)
                                    .padding(.horizontal, 8)
                                    .background(Color(plane.color).opacity(0.15))
                                    .cornerRadius(16)
                                }
                            }
                            .padding(.horizontal, 2)
                        }
                        .frame(height: 30)
                    }
                    .padding(.vertical, 4)
                    .padding(.horizontal, 8)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color(plane.color).opacity(0.05))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color(plane.color).opacity(0.2), lineWidth: 1)
                    )
                    .id("\(plane.id)-\(planeMarkers.count)")
                }
            }
        }
        // Aggiunto un ID alla vista principale per forzare l'aggiornamento quando i marker cambiano
        .id("markerList-\(markerManager.markers.count)")
    }
}
