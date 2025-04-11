import SwiftUI

/// Vista per la visualizzazione della lista dei marker raggruppati per piano di taglio
struct MarkerListView: View {
    // MARK: - Proprietà
    @ObservedObject var markerManager: MarkerManager
    let activePlaneID: UUID?
    
    // Callback per quando un marker viene selezionato dalla lista
    var onMarkerSelected: (Marker) -> Void
    
    // Aggiungi uno state per tenere traccia del marker selezionato a livello di vista
    @State private var localSelectedMarkerID: UUID? = nil
    
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
                                    Button(action: {
                                        // Prima aggiorna lo stato locale della vista
                                        localSelectedMarkerID = marker.id
                                        
                                        // Poi aggiorna il modello
                                        markerManager.selectMarker(id: marker.id)
                                        
                                        // Infine chiama il callback
                                        onMarkerSelected(marker)
                                    }) {
                                        Text(marker.name)
                                            .font(.system(size: 12))
                                            .padding(.vertical, 4)
                                            .padding(.horizontal, 8)
                                            .background(Color(plane.color).opacity(0.15))
                                            .cornerRadius(16)
                                            .overlay(
                                                RoundedRectangle(cornerRadius: 16)
                                                    // Usa sia lo state locale che quello del model
                                                    .stroke(localSelectedMarkerID == marker.id ||
                                                            markerManager.selectedMarkerID == marker.id
                                                            ? Color.yellow : Color.clear, lineWidth: 2)
                                            )
                                    }
                                    .buttonStyle(PlainButtonStyle())
                                    // Aggiungi un ID molto specifico che cambia quando qualsiasi selezione cambia
                                    .id("marker-\(marker.id)-selected-\(localSelectedMarkerID == marker.id)-\(markerManager.selectedMarkerID == marker.id)")
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
        // Sincronizza lo state locale con il modello quando cambia la selezione nel modello
        .onChange(of: markerManager.selectedMarkerID) { _, newValue in
            localSelectedMarkerID = newValue
        }
        // Forza l'aggiornamento quando cambia lo stato locale
        .id("markerList-\(localSelectedMarkerID?.uuidString ?? "none")-\(markerManager.selectedMarkerID?.uuidString ?? "none")")
        // Inizializza lo stato locale con il valore attuale dal modello all'apparizione
        .onAppear {
            localSelectedMarkerID = markerManager.selectedMarkerID
        }
    }
}
