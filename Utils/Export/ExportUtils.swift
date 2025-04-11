import Foundation
import SceneKit
import AppKit

/// Classe di utilità per l'esportazione dei modelli 3D
class ExportUtils {
    
    /// Esporta il modello 3D base
    static func exportModel(scene: SCNScene) {
        // 1. Ottieni il nodo del modello
        guard let meshNode = scene.rootNode.childNode(withName: "volumeMesh", recursively: true),
              let _ = meshNode.geometry else {
            DispatchQueue.main.async {
                let alert = NSAlert()
                alert.messageText = "Errore"
                alert.informativeText = "Nessun modello 3D da esportare"
                alert.runModal()
            }
            return
        }
        
        DispatchQueue.main.async {
            // 2. Mostra un pannello e ottieni l'autorizzazione dell'utente
            let savePanel = NSSavePanel()
            savePanel.title = "Esporta modello 3D"
            savePanel.nameFieldStringValue = "brain_model.scn"
            savePanel.allowedFileTypes = ["scn"]
            savePanel.canCreateDirectories = true
            
            let response = savePanel.runModal()
            
            if response == .OK, let url = savePanel.url {
                // 3. Richiedi accesso esplicito alla risorsa selezionata
                let didStartAccessing = url.startAccessingSecurityScopedResource()
                print("Accesso alla risorsa avviato: \(didStartAccessing)")
                
                defer {
                    // Assicurati sempre di rilasciare l'accesso
                    if didStartAccessing {
                        url.stopAccessingSecurityScopedResource()
                        print("Accesso alla risorsa terminato")
                    }
                }
                
                // 4. Crea una scena temporanea e clona il nodo
                let exportScene = SCNScene()
                let clonedNode = meshNode.clone()
                
                // 5. Ottimizza materiali per l'esportazione (opzionale)
                if let geometry = clonedNode.geometry {
                    for material in geometry.materials {
                        // Imposta proprietà dei materiali compatibili con RealityKit
                        material.lightingModel = .physicallyBased
                        material.diffuse.contents = NSColor(calibratedRed: 0.9, green: 0.9, blue: 0.9, alpha: 1.0)
                        material.roughness.contents = 0.7
                        material.metalness.contents = 0.0
                    }
                }
                
                exportScene.rootNode.addChildNode(clonedNode)
                
                // 6. Aggiungi una luce per migliorare la visualizzazione
                let lightNode = SCNNode()
                lightNode.light = SCNLight()
                lightNode.light?.type = .directional
                lightNode.light?.intensity = 1000
                lightNode.position = SCNVector3(100, 100, 100)
                exportScene.rootNode.addChildNode(lightNode)
                
                // 7. Salva il modello
                let success = exportScene.write(to: url, options: nil, delegate: nil, progressHandler: nil)
                
                if success {
                    let alert = NSAlert()
                    alert.messageText = "Esportazione completata"
                    alert.informativeText = "Il modello 3D completo è stato salvato in formato SCN. Usa Reality Converter per convertirlo in USDZ se necessario."
                    alert.runModal()
                    
                    NSWorkspace.shared.selectFile(url.path, inFileViewerRootedAtPath: "")
                } else {
                    let alert = NSAlert()
                    alert.messageText = "Errore"
                    alert.informativeText = "Impossibile salvare il modello."
                    alert.runModal()
                }
            }
        }
    }
    
    /// Esporta il modello includendo i marker e il piano di taglio
    static func exportModelWithMarkers(scene: SCNScene, markerManager: MarkerManager) {
        // 1. Ottieni il nodo del modello
        guard let meshNode = scene.rootNode.childNode(withName: "volumeMesh", recursively: true),
              let _ = meshNode.geometry else {
            DispatchQueue.main.async {
                let alert = NSAlert()
                alert.messageText = "Errore"
                alert.informativeText = "Nessun modello 3D da esportare"
                alert.runModal()
            }
            return
        }
        
        DispatchQueue.main.async {
            // 2. Mostra un pannello e ottieni l'autorizzazione dell'utente
            let savePanel = NSSavePanel()
            savePanel.title = "Esporta modello 3D con marker"
            savePanel.nameFieldStringValue = "model_with_markers.scn"
            savePanel.allowedFileTypes = ["scn"]
            savePanel.canCreateDirectories = true
            
            let response = savePanel.runModal()
            
            if response == .OK, let url = savePanel.url {
                // 3. Richiedi accesso esplicito alla risorsa selezionata
                let didStartAccessing = url.startAccessingSecurityScopedResource()
                print("Accesso alla risorsa avviato: \(didStartAccessing)")
                
                defer {
                    // Assicurati sempre di rilasciare l'accesso
                    if didStartAccessing {
                        url.stopAccessingSecurityScopedResource()
                        print("Accesso alla risorsa terminato")
                    }
                }
                
                // 4. Crea una scena temporanea e clona il nodo
                let exportScene = SCNScene()
                let clonedNode = meshNode.clone()
                
                // 5. Ottimizza materiali per l'esportazione (opzionale)
                if let geometry = clonedNode.geometry {
                    for material in geometry.materials {
                        // Imposta proprietà dei materiali compatibili con RealityKit
                        material.lightingModel = .physicallyBased
                        material.diffuse.contents = NSColor(calibratedRed: 0.9, green: 0.9, blue: 0.9, alpha: 1.0)
                        material.roughness.contents = 0.7
                        material.metalness.contents = 0.0
                    }
                }
                
                exportScene.rootNode.addChildNode(clonedNode)
                
                // Aggiungi i marker
                for marker in markerManager.markers {
                    // Crea una sfera per ogni marker
                    let sphere = SCNSphere(radius: 3.0)
                    sphere.firstMaterial?.diffuse.contents = NSColor.red
                    
                    let markerNode = SCNNode(geometry: sphere)
                    markerNode.position = marker.position
                    markerNode.name = "Marker_\(marker.id.uuidString)"
                    
                    // Aggiungi un'etichetta con il nome del marker
                    let textGeometry = SCNText(string: marker.name, extrusionDepth: 0)
                    textGeometry.font = NSFont.systemFont(ofSize: 2)
                    textGeometry.firstMaterial?.diffuse.contents = NSColor.white
                    
                    let textNode = SCNNode(geometry: textGeometry)
                    textNode.scale = SCNVector3(0.5, 0.5, 0.5)
                    textNode.position = SCNVector3(3, 3, 0)
                    markerNode.addChildNode(textNode)
                    
                    exportScene.rootNode.addChildNode(markerNode)
                }
                
                // Aggiungi il piano di taglio se esiste
                for plane in markerManager.cuttingPlanes {
                    if let planeNode = plane.node?.clone() {
                        exportScene.rootNode.addChildNode(planeNode)
                    }
                }
                
                // 6. Aggiungi una luce per migliorare la visualizzazione
                let lightNode = SCNNode()
                lightNode.light = SCNLight()
                lightNode.light?.type = .directional
                lightNode.light?.intensity = 1000
                lightNode.position = SCNVector3(100, 100, 100)
                exportScene.rootNode.addChildNode(lightNode)
                
                // 7. Salva il modello
                let success = exportScene.write(to: url, options: nil, delegate: nil, progressHandler: nil)
                
                if success {
                    let alert = NSAlert()
                    alert.messageText = "Esportazione completata"
                    alert.informativeText = "Il modello 3D con i marker è stato salvato in formato SCN."
                    alert.runModal()
                    
                    NSWorkspace.shared.selectFile(url.path, inFileViewerRootedAtPath: "")
                } else {
                    let alert = NSAlert()
                    alert.messageText = "Errore"
                    alert.informativeText = "Impossibile salvare il modello."
                    alert.runModal()
                }
            }
        }
    }
}
