import SwiftUI
import SceneKit

/// Coordinatore per la gestione del disegno 3D
class DrawingCoordinator: NSObject, NSGestureRecognizerDelegate {
    var parent: SceneKitDrawingView
    var scnView: SCNView?
    
    // Stato disegno
    var drawingMode: DrawingMode
    var lineStyle: LineStyle
    var currentDrawingColor: NSColor
    var lineThickness: Float
    var isDrawing = false
    var lastHitPosition: SCNVector3?
    var currentLineNodes: [SCNNode] = []
    
    var straightLineStartPosition: SCNVector3?
    var previewLineNode: SCNNode?
    
    init(_ parent: SceneKitDrawingView) {
        self.parent = parent
        self.drawingMode = parent.drawingMode
        self.lineStyle = parent.lineStyle
        self.currentDrawingColor = parent.currentDrawingColor
        self.lineThickness = parent.lineThickness
        super.init()
    }
    
    // MARK: - Delegati NSGestureRecognizer
    
    func gestureRecognizerShouldBegin(_ gestureRecognizer: NSGestureRecognizer) -> Bool {
        // Attiva il gesture recognizer solo se siamo in modalità Draw o Erase
        return drawingMode != .none
    }
    
    func gestureRecognizer(_ gestureRecognizer: NSGestureRecognizer,
                           shouldRecognizeSimultaneouslyWith otherGestureRecognizer: NSGestureRecognizer) -> Bool {
        // Non permettere riconoscimenti simultanei quando siamo in modalità di disegno
        return drawingMode == .none
    }
    
    // MARK: - Gestione eventi
    
    /// Gestisce gli eventi di trascinamento per disegnare sul modello
    @objc func handlePanGesture(_ gestureRecognizer: NSPanGestureRecognizer) {
        guard let scnView = self.scnView, drawingMode != .none else { return }
        
        let location = gestureRecognizer.location(in: scnView)
        
        // Hit test per trovare dove l'utente sta puntando sul modello 3D
        let hitResults = scnView.hitTest(location, options: nil)
        
        // Filtra i risultati per considerare solo la mesh principale
        let volumeHits = hitResults.filter { result in
            return result.node.name == "volumeMesh" || (result.node.parent?.name == "volumeMesh")
        }
        
        guard let hit = volumeHits.first else {
            // Se il gesto termina senza hit, finalizza la linea
            if gestureRecognizer.state == .ended || gestureRecognizer.state == .cancelled {
                if drawingMode == .draw {
                    if lineStyle == .freehand {
                        finalizeCurrentDrawing()
                    } else if lineStyle == .straight {
                        finalizeStraightLine()
                    }
                }
            }
            return
        }
        
        // Ottieni la posizione 3D del punto colpito
        let hitPosition = hit.worldCoordinates
        
        switch gestureRecognizer.state {
        case .began:
            if drawingMode == .draw {
                if lineStyle == .freehand {
                    beginDrawing(at: hitPosition)
                } else if lineStyle == .straight {
                    beginStraightLine(at: hitPosition)
                }
            } else if drawingMode == .erase {
                eraseAtPosition(hitPosition)
            }
            
        case .changed:
            if drawingMode == .draw {
                if lineStyle == .freehand && isDrawing {
                    continueDrawing(to: hitPosition)
                } else if lineStyle == .straight {
                    updateStraightLinePreview(to: hitPosition)
                }
            } else if drawingMode == .erase {
                eraseAtPosition(hitPosition)
            }
            
        case .ended, .cancelled:
            if drawingMode == .draw {
                if lineStyle == .freehand {
                    finalizeCurrentDrawing()
                } else if lineStyle == .straight {
                    finalizeStraightLine(at: hitPosition)
                }
            }
            
        default:
            break
        }
    }
    // MARK: - Metodi di disegno
    
    /// Inizia a disegnare una nuova linea
    private func beginDrawing(at position: SCNVector3) {
        guard let scene = scnView?.scene else { return }
        
        isDrawing = true
        lastHitPosition = position
        currentLineNodes = []
        
        // Crea un nodo container per la nuova linea
        let lineContainerNode = SCNNode()
        lineContainerNode.name = "drawingLine"
        scene.rootNode.addChildNode(lineContainerNode)
        
        // Aggiungi una sfera al punto iniziale
        let startPoint = createSphereNode(at: position, color: currentDrawingColor, radius: CGFloat(lineThickness / 2))
        lineContainerNode.addChildNode(startPoint)
        currentLineNodes.append(lineContainerNode)
    }
    
    /// Continua a disegnare la linea corrente fino al nuovo punto
    private func continueDrawing(to newPosition: SCNVector3) {
        guard isDrawing, let lastPosition = lastHitPosition, let lineContainer = currentLineNodes.first else { return }
        
        // Calcola la distanza tra il punto precedente e quello nuovo
        let distance = Self.distance(from: lastPosition, to: newPosition)
        
        // Se la distanza è troppo piccola, ignora per evitare sovrapposizioni
        if distance < Float(lineThickness / 2) {
            return
        }
        
        // Crea un cilindro tra i due punti per rappresentare un segmento della linea
        let lineSegment = createCylinderLine(
            from: lastPosition,
            to: newPosition,
            color: currentDrawingColor,
            thickness: lineThickness
        )
        lineContainer.addChildNode(lineSegment)
        
        // Crea una sfera al nuovo punto per connettere i segmenti senza lacune
        let pointNode = createSphereNode(at: newPosition, color: currentDrawingColor, radius: CGFloat(lineThickness / 2))
        lineContainer.addChildNode(pointNode)

        // Aggiorna l'ultima posizione
        lastHitPosition = newPosition
    }
    
    /// Finalizza e salva la linea di disegno corrente
    private func finalizeCurrentDrawing() {
        guard isDrawing, !currentLineNodes.isEmpty else { return }
        
        // Salva la linea completata nell'array
        let newLine = DrawingLine(
            nodes: currentLineNodes,
            color: currentDrawingColor,
            thickness: lineThickness
        )
        
        // Aggiorna la binding
        DispatchQueue.main.async {
            self.parent.drawingLines.append(newLine)
        }
        
        // Resetta lo stato del disegno
        isDrawing = false
        lastHitPosition = nil
        currentLineNodes = []
    }
    
    /// Inizia una linea retta
    private func beginStraightLine(at position: SCNVector3) {
        guard let scene = scnView?.scene else { return }
        
        // Memorizza la posizione iniziale
        straightLineStartPosition = position
        
        // Crea un nodo container per l'anteprima
        let previewNode = SCNNode()
        previewNode.name = "previewLine"
        scene.rootNode.addChildNode(previewNode)
        
        // Aggiungi una sfera al punto iniziale
        let startPoint = createSphereNode(at: position, color: currentDrawingColor, radius: CGFloat(lineThickness / 2))
        previewNode.addChildNode(startPoint)
        
        // Salva il riferimento per la preview
        previewLineNode = previewNode
    }
    
    /// Aggiorna l'anteprima della linea retta mentre l'utente trascina
    private func updateStraightLinePreview(to position: SCNVector3) {
        guard let startPosition = straightLineStartPosition,
              let previewNode = previewLineNode else { return }
        
        // Rimuovi eventuali segmenti di anteprima precedenti
        for child in previewNode.childNodes {
            if child.name == "previewSegment" {
                child.removeFromParentNode()
            }
        }
        
        // Crea un nuovo segmento di linea per l'anteprima
        let lineSegment = createCylinderLine(
            from: startPosition,
            to: position,
            color: currentDrawingColor.withAlphaComponent(0.7),  // Semi-trasparente per l'anteprima
            thickness: lineThickness
        )
        lineSegment.name = "previewSegment"
        previewNode.addChildNode(lineSegment)
    }
    
    /// Finalizza la linea retta
    private func finalizeStraightLine(at endPosition: SCNVector3? = nil) {
        guard let startPosition = straightLineStartPosition,
              let scene = scnView?.scene else {
            // Rimuovi il nodo di anteprima
            previewLineNode?.removeFromParentNode()
            previewLineNode = nil
            return
        }
        
        // Rimuovi il nodo di anteprima
        previewLineNode?.removeFromParentNode()
        previewLineNode = nil
        
        // Se non abbiamo un punto finale valido, non creare la linea
        guard let finalEndPosition = endPosition else {
            straightLineStartPosition = nil
            return
        }
        
        // Crea un nuovo nodo container per la linea definitiva
        let lineContainerNode = SCNNode()
        lineContainerNode.name = "drawingLine"
        scene.rootNode.addChildNode(lineContainerNode)
        
        // Crea una sfera al punto iniziale
        let startPoint = createSphereNode(at: startPosition, color: currentDrawingColor, radius: CGFloat(lineThickness / 2))
        lineContainerNode.addChildNode(startPoint)
        
        // Crea il segmento di linea
        let lineSegment = createCylinderLine(
            from: startPosition,
            to: finalEndPosition,
            color: currentDrawingColor,
            thickness: lineThickness
        )
        lineContainerNode.addChildNode(lineSegment)
        
        // Crea una sfera al punto finale
        let endPoint = createSphereNode(at: finalEndPosition, color: currentDrawingColor, radius: CGFloat(lineThickness / 2))
        lineContainerNode.addChildNode(endPoint)
        
        // Salva la linea nell'array
        let newLine = DrawingLine(
            nodes: [lineContainerNode],
            color: currentDrawingColor,
            thickness: lineThickness
        )
        
        // Aggiorna la binding
        DispatchQueue.main.async {
            self.parent.drawingLines.append(newLine)
        }
        
        // Resetta lo stato
        straightLineStartPosition = nil
    }
    
    /// Cancella le linee alla posizione specificata
    private func eraseAtPosition(_ position: SCNVector3) {
        guard let scene = scnView?.scene else { return }
        
        // Raggio di cancellazione - leggermente più grande dello spessore della linea
        let eraseRadius: Float = lineThickness * 1.5
        
        // Memorizziamo gli ID delle linee da rimuovere
        var linesToRemove = Set<UUID>()
        
        // Crea una copia locale dell'array di drawing lines
        var localDrawingLines = parent.drawingLines
        
        // Verifica ogni linea disegnata
        for line in localDrawingLines {
            for node in line.nodes {
                for childNode in node.childNodes {
                    // Calcola la distanza tra la posizione di cancellazione e il nodo
                    let nodePosition = childNode.worldPosition
                    let distanceToNode = Self.distance(from: position, to: nodePosition)
                    
                    // Se il nodo è abbastanza vicino, segna la linea per la rimozione
                    if distanceToNode < eraseRadius {
                        linesToRemove.insert(line.id)
                        break
                    }
                }
            }
        }
        
        // Rimuovi le linee segnate
        for lineId in linesToRemove {
            if let index = localDrawingLines.firstIndex(where: { $0.id == lineId }) {
                // Rimuovi tutti i nodi dalla scena
                for node in localDrawingLines[index].nodes {
                    node.removeFromParentNode()
                }
                
                // Rimuovi la linea dall'array
                localDrawingLines.remove(at: index)
            }
        }
        
        // Aggiorna la binding se ci sono state modifiche
        if !linesToRemove.isEmpty {
            DispatchQueue.main.async {
                self.parent.drawingLines = localDrawingLines
            }
        }
    }
    
    // MARK: - Metodi di supporto per la creazione di nodi
    
    /// Crea un nodo sfera per i punti della linea
    private func createSphereNode(at position: SCNVector3, color: NSColor, radius: CGFloat) -> SCNNode {
        let sphere = SCNSphere(radius: radius)
        
        let material = SCNMaterial()
        material.diffuse.contents = color
        material.lightingModel = .blinn
        sphere.materials = [material]
        
        let node = SCNNode(geometry: sphere)
        node.position = position
        node.name = "linePoint"
        
        return node
    }
   
    /// Crea un cilindro tra due punti per un segmento di linea
    private func createCylinderLine(from startPoint: SCNVector3, to endPoint: SCNVector3,
                                  color: NSColor, thickness: Float) -> SCNNode {
        // Calcola la lunghezza del cilindro
        let distance = Self.distance(from: startPoint, to: endPoint)
        
        // Crea il cilindro
        let cylinder = SCNCylinder(radius: CGFloat(thickness / 2), height: CGFloat(distance))
        
        let material = SCNMaterial()
        material.diffuse.contents = color
        material.lightingModel = .blinn
        cylinder.materials = [material]
        
        // Posiziona il cilindro
        let node = SCNNode(geometry: cylinder)
        
        // Posizionamento geometrico del cilindro
        positionCylinderBetweenPoints(cylinder: node, from: startPoint, to: endPoint)
        
        node.name = "lineSegment"
        return node
    }
    
    /// Calcola la distanza tra due punti 3D
    static func distance(from point1: SCNVector3, to point2: SCNVector3) -> Float {
        let dx = point1.x - point2.x
        let dy = point1.y - point2.y
        let dz = point1.z - point2.z
        
        let dxSquared = dx * dx
        let dySquared = dy * dy
        let dzSquared = dz * dz
        
        let sumOfSquares = dxSquared + dySquared + dzSquared
        return Float(sqrt(Double(sumOfSquares)))
    }
    
    /// Orienta un cilindro tra due punti nello spazio 3D
    private func positionCylinderBetweenPoints(cylinder: SCNNode, from: SCNVector3, to: SCNVector3) {
        // 1. Posiziona al punto medio
        cylinder.position = SCNVector3(
            (from.x + to.x) / 2,
            (from.y + to.y) / 2,
            (from.z + to.z) / 2
        )
        
        // 2. Calcola la direzione e la lunghezza
        let direction = SCNVector3(to.x - from.x, to.y - from.y, to.z - from.z)
        let length = sqrt(
            direction.x * direction.x +
            direction.y * direction.y +
            direction.z * direction.z
        )
        
        // Evita divisione per zero
        if length < 0.0001 {
            return
        }
        
        // 3. Normalizza la direzione
        let normalizedDirection = SCNVector3(
            direction.x / length,
            direction.y / length,
            direction.z / length
        )
        
        // 4. Asse Y del cilindro (verticale per default)
        let yAxis = SCNVector3(0, 1, 0)
        
        // 5. Calcola il prodotto scalare
        let dotProduct = Float(
            yAxis.x * normalizedDirection.x +
            yAxis.y * normalizedDirection.y +
            yAxis.z * normalizedDirection.z
        )
        
        // 6. Gestione casi speciali (vettori paralleli o antiparalleli)
        if abs(abs(dotProduct) - 1) < 0.0001 {
            if dotProduct < 0 {
                // Antiparalleli - ruota di 180° attorno all'asse X
                cylinder.rotation = SCNVector4(1, 0, 0, Float.pi)
            }
            return
        }
        
        // 7. Calcola l'asse di rotazione (prodotto vettoriale)
        let rotationAxis = SCNVector3(
            yAxis.y * normalizedDirection.z - yAxis.z * normalizedDirection.y,
            yAxis.z * normalizedDirection.x - yAxis.x * normalizedDirection.z,
            yAxis.x * normalizedDirection.y - yAxis.y * normalizedDirection.x
        )
        
        // 8. Normalizza l'asse di rotazione
        let rotAxisLength = sqrt(
            rotationAxis.x * rotationAxis.x +
            rotationAxis.y * rotationAxis.y +
            rotationAxis.z * rotationAxis.z
        )
        
        if rotAxisLength < 0.0001 {
            return
        }
        
        let normalizedRotAxis = SCNVector3(
            rotationAxis.x / rotAxisLength,
            rotationAxis.y / rotAxisLength,
            rotationAxis.z / rotAxisLength
        )
        
        // 9. Calcola e applica la rotazione
        let angle = acos(dotProduct)
        cylinder.rotation = SCNVector4(
            normalizedRotAxis.x,
            normalizedRotAxis.y,
            normalizedRotAxis.z,
            CGFloat(angle)  
        )
    }
}
