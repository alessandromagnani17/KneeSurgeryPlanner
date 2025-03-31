import SwiftUI
import SceneKit

// MARK: - Enumerazioni e Strutture di Supporto

/// Modalità di interazione con il disegno 3D
enum DrawingMode {
    case draw   // Modalità disegno attiva
    case erase  // Modalità cancellazione attiva
    case none   // Interazione normale con il modello
}

/// Struttura per memorizzare le linee disegnate sul modello 3D
struct DrawingLine: Identifiable {
    let id = UUID()
    var nodes: [SCNNode]      // Nodi SceneKit che compongono la linea
    var color: NSColor        // Colore della linea
    var thickness: Float      // Spessore della linea
}

/// Modalità di rendering del modello 3D
enum RenderingMode {
    case solid              // Rendering solido standard
    case wireframe          // Solo wireframe
    case solidWithWireframe // Solido con overlay wireframe
}

// MARK: - Vista Principale
struct Model3DView: View {
    // MARK: - Proprietà
    @ObservedObject var dicomManager: DICOMManager
    
    // Configurazione camera
    private let initialCameraPosition = SCNVector3(0, 0, 200)
    private let initialCameraEulerAngles = SCNVector3(0, 0, 0)
    
    // Stato della scena 3D
    @State private var scene = SCNScene()
    @State private var cameraNode = SCNNode()
    @State private var thresholdValue: Float = 400
    @State private var scnView: SCNView?
    @State private var renderingMode: RenderingMode = .solid
    
    // Stato del painter 3D
    @State private var drawingMode: DrawingMode = .none
    @State private var currentDrawingColor: NSColor = .red
    @State private var lineThickness: Float = 1.0
    @State private var drawingLines: [DrawingLine] = []
    
    @State private var isModelInitialized = false
    
    // MARK: - UI
    var body: some View {
        VStack {
            // Controlli per il modello 3D
            HStack {
                Text("Threshold: \(Int(thresholdValue))")
                Slider(value: $thresholdValue, in: 0...1000)
                    .onChange(of: thresholdValue) { oldValue, newValue in
                        updateModel()
                    }
                
                Spacer()
                
                Picker("Rendering", selection: $renderingMode) {
                    Text("Solid").tag(RenderingMode.solid)
                    Text("Wireframe").tag(RenderingMode.wireframe)
                    Text("Solid+Wire").tag(RenderingMode.solidWithWireframe)
                }
                .pickerStyle(MenuPickerStyle())
                .frame(width: 200)
                .onChange(of: renderingMode) { _, _ in
                    updateRenderingMode()
                }
                
                Button("Reset Camera") {
                    resetCamera()
                }
            }
            .padding()
            
            // Controlli per il painter 3D
            HStack {
                // Selezione modalità disegno
                Picker("Mode", selection: $drawingMode) {
                    Text("View").tag(DrawingMode.none)
                    Text("Draw").tag(DrawingMode.draw)
                    Text("Erase").tag(DrawingMode.erase)
                }
                .pickerStyle(SegmentedPickerStyle())
                .frame(width: 200)
                
                // Selezione colore
                ColorPicker("Line Color", selection: Binding(
                    get: { Color(self.currentDrawingColor) },
                    set: { self.currentDrawingColor = NSColor($0) }
                ))
                .disabled(drawingMode != .draw)
                
                // Controllo spessore linea
                Text("Thickness:")
                Slider(value: $lineThickness, in: 0.5...10.0)
                    .frame(width: 120)
                    .disabled(drawingMode != .draw)
                
                // Pulsanti di controllo disegno
                Button("Clear All") {
                    clearAllDrawings()
                }
                .disabled(drawingLines.isEmpty)
                
                Button("Undo") {
                    undoLastDrawing()
                }
                .disabled(drawingLines.isEmpty)
            }
            .padding(.horizontal)
            
            // Area principale che mostra il modello 3D
            GeometryReader { _ in
                SceneKitDrawingView(
                    scene: scene,
                    allowsCameraControl: true,
                    autoenablesDefaultLighting: false,
                    drawingMode: drawingMode,
                    currentDrawingColor: currentDrawingColor,
                    lineThickness: lineThickness,
                    drawingLines: $drawingLines,
                    onSceneViewCreated: { view in
                        self.scnView = view
                    }
                )
                .onAppear {
                    if !isModelInitialized {
                        setupScene()
                        updateModel()
                        // Imposta la flag a true dopo l'inizializzazione
                        isModelInitialized = true
                    }
                }
            }
        }
    }
    
    // MARK: - Metodi
    
    /// Configura la scena 3D e l'illuminazione
    private func setupScene() {
        scene.background.contents = NSColor.darkGray
        
        // Configurazione camera
        let camera = SCNCamera()
        camera.zNear = 1
        camera.zFar = 1000
        camera.fieldOfView = 45
        cameraNode.camera = camera
        cameraNode.position = initialCameraPosition
        cameraNode.eulerAngles = initialCameraEulerAngles
        scene.rootNode.addChildNode(cameraNode)
        
        // Sistema di illuminazione a 4 punti
        // 1. Luce ambientale
        let ambientLight = SCNNode()
        ambientLight.light = SCNLight()
        ambientLight.light?.type = .ambient
        ambientLight.light?.intensity = 70
        ambientLight.light?.color = NSColor(calibratedRed: 0.9, green: 0.9, blue: 1.0, alpha: 1.0)
        scene.rootNode.addChildNode(ambientLight)
        
        // 2. Luce principale direzionale
        let mainLight = SCNNode()
        mainLight.light = SCNLight()
        mainLight.light?.type = .directional
        mainLight.light?.intensity = 1000
        mainLight.light?.color = NSColor(calibratedRed: 1.0, green: 0.95, blue: 0.9, alpha: 1.0)
        mainLight.light?.castsShadow = true
        mainLight.light?.shadowRadius = 3
        mainLight.light?.shadowColor = NSColor(white: 0.0, alpha: 0.7)
        mainLight.position = SCNVector3(100, 150, 100)
        mainLight.look(at: SCNVector3(0, 0, 0))
        scene.rootNode.addChildNode(mainLight)
        
        // 3. Luce di riempimento
        let fillLight = SCNNode()
        fillLight.light = SCNLight()
        fillLight.light?.type = .directional
        fillLight.light?.intensity = 400
        fillLight.light?.color = NSColor(calibratedRed: 0.9, green: 0.95, blue: 1.0, alpha: 1.0)
        fillLight.position = SCNVector3(-100, 50, -100)
        fillLight.look(at: SCNVector3(0, 0, 0))
        scene.rootNode.addChildNode(fillLight)
        
        // 4. Luce per i contorni (rim light)
        let rimLight = SCNNode()
        rimLight.light = SCNLight()
        rimLight.light?.type = .directional
        rimLight.light?.intensity = 300
        rimLight.light?.color = NSColor(calibratedRed: 1.0, green: 1.0, blue: 0.9, alpha: 1.0)
        rimLight.position = SCNVector3(0, -100, -150)
        rimLight.look(at: SCNVector3(0, 0, 0))
        scene.rootNode.addChildNode(rimLight)
    }
    
    /// Crea o aggiorna il modello 3D in base al valore di soglia
    private func updateModel() {
        // Rimuovi i nodi esistenti prima di ricreare il modello
        let existingNodes = scene.rootNode.childNodes.filter {
            $0.name == "volumeMesh" || $0.name == "testBox" || $0.name == "wireframeMesh"
        }
        
        existingNodes.forEach { $0.removeFromParentNode() }
        
        // Ottieni i dati DICOM correnti
        guard let series = dicomManager.currentSeries,
              let volume = dicomManager.createVolumeFromSeries(series) else {
            return
        }
        
        // Genera la mesh con Marching Cubes
        let marchingCubes = MarchingCubes()
        var mesh = marchingCubes.generateMesh(from: volume, isovalue: thresholdValue)
        
        // Ottimizzazione della mesh
        closeHolesInMesh(&mesh)
        fixMeshNormals(&mesh)
        
        // Crea il nodo del modello
        let geometry = SCNGeometry(mesh: mesh)
        let meshNode = SCNNode(geometry: geometry)
        meshNode.name = "volumeMesh"
        scene.rootNode.addChildNode(meshNode)
        
        // Aggiungi miglioramento dei contorni
        addSilhouetteEnhancement(to: meshNode)
        
        // Applica la modalità di rendering scelta
        updateRenderingMode()
    }
    
    /// Aggiunge un effetto di contorno al modello
    private func addSilhouetteEnhancement(to node: SCNNode) {
        guard let geometry = node.geometry else { return }
        
        let outlineGeometry = geometry.copy() as! SCNGeometry
        
        let outlineMaterial = SCNMaterial()
        outlineMaterial.diffuse.contents = NSColor.black
        outlineMaterial.lightingModel = .constant
        outlineMaterial.writesToDepthBuffer = true
        outlineMaterial.readsFromDepthBuffer = true
        
        outlineGeometry.materials = [outlineMaterial]
        
        let outlineNode = SCNNode(geometry: outlineGeometry)
        outlineNode.scale = SCNVector3(1.02, 1.02, 1.02)
        outlineNode.name = "outlineNode"
        
        node.addChildNode(outlineNode)
    }
    
    /// Aggiorna la modalità di visualizzazione del modello
    private func updateRenderingMode() {
        guard let meshNode = scene.rootNode.childNodes.first(where: { $0.name == "volumeMesh" }),
              let geometry = meshNode.geometry else {
            return
        }
        
        // Rimuovi eventuali nodi wireframe esistenti se non necessari
        if renderingMode != .solidWithWireframe {
            scene.rootNode.childNodes.filter { $0.name == "wireframeMesh" }.forEach {
                $0.removeFromParentNode()
            }
        }
        
        // Applica il materiale in base alla modalità di rendering
        for i in 0..<geometry.materials.count {
            let material = geometry.materials[i]
            
            switch renderingMode {
            case .solid:
                material.fillMode = .fill
                material.isDoubleSided = false
                material.cullMode = .back
                material.diffuse.contents = NSColor(calibratedRed: 0.9, green: 0.9, blue: 0.9, alpha: 1.0)
                material.specular.contents = NSColor.white
                material.shininess = 0.3
                material.lightingModel = .phong
                material.ambient.contents = NSColor(white: 0.6, alpha: 1.0)
                
            case .wireframe:
                material.fillMode = .lines
                material.isDoubleSided = true
                material.diffuse.contents = NSColor.white
                material.lightingModel = .constant
                
            case .solidWithWireframe:
                material.fillMode = .fill
                material.isDoubleSided = false
                material.cullMode = .back
                material.diffuse.contents = NSColor(calibratedRed: 0.9, green: 0.9, blue: 0.9, alpha: 1.0)
                material.specular.contents = NSColor.white
                material.shininess = 0.3
                material.lightingModel = .phong
                
                // Aggiungi un overlay wireframe se necessario
                if !scene.rootNode.childNodes.contains(where: { $0.name == "wireframeMesh" }) {
                    let wireframeGeometry = geometry.copy() as! SCNGeometry
                    let wireMaterial = SCNMaterial()
                    wireMaterial.fillMode = .lines
                    wireMaterial.diffuse.contents = NSColor.black
                    wireMaterial.lightingModel = .constant
                    wireMaterial.cullMode = .back
                    
                    wireframeGeometry.materials = [wireMaterial]
                    
                    let wireframeNode = SCNNode(geometry: wireframeGeometry)
                    wireframeNode.name = "wireframeMesh"
                    wireframeNode.position = meshNode.position
                    wireframeNode.scale = SCNVector3(1.001, 1.001, 1.001)
                    scene.rootNode.addChildNode(wireframeNode)
                }
            }
        }
    }
    
    /// Ripristina la posizione della camera alla vista iniziale
    private func resetCamera() {
        guard let scnView = self.scnView else { return }
        
        SCNTransaction.begin()
        SCNTransaction.animationDuration = 0.5
        
        scnView.pointOfView?.position = initialCameraPosition
        scnView.pointOfView?.orientation = SCNQuaternion(0, 0, 0, 1)
        
        SCNTransaction.commit()
    }
    
    /// Corregge l'orientamento delle normali nella mesh
    func fixMeshNormals(_ mesh: inout Mesh) {
        // Verifica se le normali sono orientate correttamente
        let sampleSize = min(100, mesh.vertices.count)
        var sumDotProducts: Float = 0
        
        for i in 0..<sampleSize {
            let normalizedPosition = SIMD3<Float>(
                mesh.vertices[i].position.x / 100,
                mesh.vertices[i].position.y / 100,
                mesh.vertices[i].position.z / 100
            )
            
            // Il prodotto scalare positivo indica normali verso l'esterno
            let dotProduct = dot(normalizedPosition, mesh.vertices[i].normal)
            sumDotProducts += dotProduct
        }
        
        // Inverti le normali se sembrano puntare verso l'interno
        let shouldInvertNormals = sumDotProducts < 0
        
        if shouldInvertNormals {
            for i in 0..<mesh.vertices.count {
                mesh.vertices[i].normal = -mesh.vertices[i].normal
            }
        }
        
        // Normalizza tutte le normali
        for i in 0..<mesh.vertices.count {
            let normal = mesh.vertices[i].normal
            let length = sqrt(normal.x * normal.x + normal.y * normal.y + normal.z * normal.z)
            if length > 0 {
                mesh.vertices[i].normal = normal / length
            } else {
                // Fallback per normali nulle
                mesh.vertices[i].normal = SIMD3<Float>(0, 1, 0)
            }
        }
    }
    
    /// Tenta di riparare buchi nella mesh (semplificato)
    func closeHolesInMesh(_ mesh: inout Mesh) {
        struct Edge: Hashable {
            let v1: Int
            let v2: Int
            
            init(_ a: Int, _ b: Int) {
                if a < b {
                    v1 = a
                    v2 = b
                } else {
                    v1 = b
                    v2 = a
                }
            }
        }
        
        // Identifica i bordi della mesh
        var edgeCounts: [Edge: Int] = [:]
        
        for triangle in mesh.triangles {
            let i0 = Int(triangle.indices.0)
            let i1 = Int(triangle.indices.1)
            let i2 = Int(triangle.indices.2)
            
            let edges = [
                Edge(i0, i1),
                Edge(i1, i2),
                Edge(i2, i0)
            ]
            
            for edge in edges {
                edgeCounts[edge, default: 0] += 1
            }
        }
        
        // Gli edge che appaiono una sola volta sono bordi
        let boundaryEdges = edgeCounts.filter { $0.value == 1 }.map { $0.key }
        
        // Se ci sono troppi bordi, potrebbe non essere pratico chiuderli tutti
        if boundaryEdges.count > 1000 {
            return
        }
        
        // TODO: l'implementazione completa richiederebbe algoritmi più sofisticati
    }
    
    // MARK: - Gestione del Disegno 3D
    
    /// Cancella tutte le linee disegnate
    private func clearAllDrawings() {
        // Rimuovi tutti i nodi di disegno dalla scena
        for line in drawingLines {
            for node in line.nodes {
                node.removeFromParentNode()
            }
        }
        
        // Svuota l'array
        drawingLines.removeAll()
    }
    
    /// Annulla l'ultima linea disegnata
    private func undoLastDrawing() {
        guard !drawingLines.isEmpty else { return }
        
        // Rimuovi l'ultima linea
        let lastLine = drawingLines.removeLast()
        
        // Rimuovi tutti i nodi associati dalla scena
        for node in lastLine.nodes {
            node.removeFromParentNode()
        }
    }
}

// MARK: - View SceneKit con supporto al disegno
struct SceneKitDrawingView: NSViewRepresentable {
    // Proprietà
    let scene: SCNScene
    let allowsCameraControl: Bool
    let autoenablesDefaultLighting: Bool
    let drawingMode: DrawingMode
    let currentDrawingColor: NSColor
    let lineThickness: Float
    @Binding var drawingLines: [DrawingLine]
    let onSceneViewCreated: (SCNView) -> Void
    
    // Crea la view SCNView
    func makeNSView(context: Context) -> SCNView {
        let view = SCNView()
        view.scene = scene
        view.allowsCameraControl = allowsCameraControl  // Assicuriamo che questa proprietà sia impostata
        view.autoenablesDefaultLighting = autoenablesDefaultLighting
        view.backgroundColor = NSColor.darkGray
        
        // Impostazioni di rendering avanzate
        view.antialiasingMode = .multisampling4X
        view.preferredFramesPerSecond = 60
        view.isJitteringEnabled = true
        view.isPlaying = true
        view.showsStatistics = false  // Disattiva le statistiche di performance
        
        // Associa il coordinatore per gestire gli eventi
        context.coordinator.scnView = view
        
        // Configura il gesture recognizer per il disegno
        let panGesture = NSPanGestureRecognizer(target: context.coordinator, action: #selector(DrawingCoordinator.handlePanGesture(_:)))
        panGesture.buttonMask = 0x1 // Clic sinistro
        
        // Importante: il gesture recognizer NON deve interferire con il controllo della camera
        // quando siamo in modalità View
        panGesture.delegate = context.coordinator
        
        view.addGestureRecognizer(panGesture)
        
        // Callback alla view principale
        onSceneViewCreated(view)
        
        return view
    }
    
    // Aggiorna la view quando cambiano i parametri
    func updateNSView(_ nsView: SCNView, context: Context) {
        // Aggiorna la scena
        nsView.scene = scene
        
        // Aggiorna le proprietà del coordinatore
        context.coordinator.drawingMode = drawingMode
        context.coordinator.currentDrawingColor = currentDrawingColor
        context.coordinator.lineThickness = lineThickness
        
        // Quando cambia la modalità, assicuriamoci che il controllo della camera funzioni correttamente
        if drawingMode == .none {
            // In modalità View, deve essere possibile ruotare il modello
            nsView.allowsCameraControl = true
        } else {
            // In modalità Draw/Erase, disattiviamo il controllo della camera per evitare conflitti
            nsView.allowsCameraControl = false
        }
    }
    
    // Crea il coordinatore per gestire gli eventi
    func makeCoordinator() -> DrawingCoordinator {
        DrawingCoordinator(self)
    }
    
    // MARK: - Coordinatore per la gestione dei gesti
    class DrawingCoordinator: NSObject, NSGestureRecognizerDelegate {
        var parent: SceneKitDrawingView
        var scnView: SCNView?
        
        // Stato disegno
        var drawingMode: DrawingMode
        var currentDrawingColor: NSColor
        var lineThickness: Float
        var isDrawing = false
        var lastHitPosition: SCNVector3?
        var currentLineNodes: [SCNNode] = []
        
        init(_ parent: SceneKitDrawingView) {
            self.parent = parent
            self.drawingMode = parent.drawingMode
            self.currentDrawingColor = parent.currentDrawingColor
            self.lineThickness = parent.lineThickness
            super.init()
        }
        
        // Implementa il metodo delegato per controllare se il gesture recognizer dovrebbe essere attivato
        func gestureRecognizerShouldBegin(_ gestureRecognizer: NSGestureRecognizer) -> Bool {
            // Attiva il gesture recognizer solo se siamo in modalità Draw o Erase
            return drawingMode != .none
        }
        
        // Implementa questo metodo per assicurarsi che il gesture recognizer non interferisca con altri
        func gestureRecognizer(_ gestureRecognizer: NSGestureRecognizer,
                               shouldRecognizeSimultaneouslyWith otherGestureRecognizer: NSGestureRecognizer) -> Bool {
            // Non permettere riconoscimenti simultanei quando siamo in modalità di disegno
            return drawingMode == .none
        }
        
        // MARK: - Gestione eventi touch
        
        /// Gestisce gli eventi di trascinamento per disegnare sul modello
        @objc func handlePanGesture(_ gestureRecognizer: NSPanGestureRecognizer) {
            // Aggiunta di un controllo extra per assicurarci di non interferire con la modalità View
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
                    finalizeCurrentDrawing()
                }
                return
            }
            
            // Ottieni la posizione 3D del punto colpito
            let hitPosition = hit.worldCoordinates
            
            switch gestureRecognizer.state {
            case .began:
                // Inizia una nuova linea o cancella
                if drawingMode == .draw {
                    beginDrawing(at: hitPosition)
                } else if drawingMode == .erase {
                    eraseAtPosition(hitPosition)
                }
                
            case .changed:
                // Continua a disegnare o cancellare
                if drawingMode == .draw && isDrawing {
                    continueDrawing(to: hitPosition)
                } else if drawingMode == .erase {
                    eraseAtPosition(hitPosition)
                }
                
            case .ended, .cancelled:
                // Finalizza la linea corrente
                if drawingMode == .draw {
                    finalizeCurrentDrawing()
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
            
            do {
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
        
        // MARK: - Metodi di supporto
        
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
            
            // Suddividi il calcolo in passaggi intermedi per aiutare il compilatore
            let dxSquared = dx * dx
            let dySquared = dy * dy
            let dzSquared = dz * dz
            
            let sumOfSquares = dxSquared + dySquared + dzSquared
            
            // Usa esplicitamente Float per evitare errori di conversione
            let result = Float(sqrt(Double(sumOfSquares)))
            
            return result
        }
        
        /// Orienta un cilindro tra due punti nello spazio 3D
        private func positionCylinderBetweenPoints(cylinder: SCNNode, from: SCNVector3, to: SCNVector3) {
            // 1. Posiziona al punto medio
            let midX = (from.x + to.x) / 2
            let midY = (from.y + to.y) / 2
            let midZ = (from.z + to.z) / 2
            
            cylinder.position = SCNVector3(midX, midY, midZ)
            
            // 2. Calcola la direzione
            let dirX = to.x - from.x
            let dirY = to.y - from.y
            let dirZ = to.z - from.z
            
            // 3. Calcola la lunghezza del vettore direzione
            let length = sqrt(dirX * dirX + dirY * dirY + dirZ * dirZ)
            
            // Evita divisione per zero
            if length < 0.0001 {
                return
            }
            
            // 4. Normalizza la direzione
            let normDirX = dirX / length
            let normDirY = dirY / length
            let normDirZ = dirZ / length
            
            // 5. L'asse Y del cilindro deve essere allineato con la direzione
            let yAxisX: Float = 0
            let yAxisY: Float = 1
            let yAxisZ: Float = 0
            
            // 6. Calcola il prodotto scalare in passaggi separati
            let product1 = Float(yAxisX) * Float(normDirX)
            let product2 = Float(yAxisY) * Float(normDirY)
            let product3 = Float(yAxisZ) * Float(normDirZ)

            let sum1 = product1 + product2
            let dotProduct = sum1 + product3
            
            // 7. Gestione di casi speciali - vettori paralleli o antiparalleli
            if abs(abs(dotProduct) - 1) < 0.0001 {
                // Vettori paralleli (dotProduct ≈ 1) o antiparalleli (dotProduct ≈ -1)
                if dotProduct < 0 {
                    // Antiparalleli - ruota di 180° attorno all'asse X
                    cylinder.rotation = SCNVector4(1, 0, 0, Float.pi)
                }
                return
            }
            
            // 8. Calcola l'asse di rotazione (prodotto vettoriale)
            let normDirX_float: Float = Float(normDirX)
            let normDirY_float: Float = Float(normDirY)
            let normDirZ_float: Float = Float(normDirZ)

            // Calcola il prodotto vettoriale in componenti
            let rotAxisX: Float = yAxisY * normDirZ_float - yAxisZ * normDirY_float
            let rotAxisY: Float = yAxisZ * normDirX_float - yAxisX * normDirZ_float
            let rotAxisZ: Float = yAxisX * normDirY_float - yAxisY * normDirX_float
            
            // 9. Normalizza l'asse di rotazione
            let rotAxisLength = sqrt(rotAxisX * rotAxisX + rotAxisY * rotAxisY + rotAxisZ * rotAxisZ)
            
            // 10. Evita divisione per zero
            if rotAxisLength < 0.0001 {
                return
            }
            
            let normRotAxisX = rotAxisX / rotAxisLength
            let normRotAxisY = rotAxisY / rotAxisLength
            let normRotAxisZ = rotAxisZ / rotAxisLength
            
            // 11. Calcola l'angolo di rotazione
            let angle = acos(dotProduct)
            
            // 12. Applica la rotazione
            cylinder.rotation = SCNVector4(normRotAxisX, normRotAxisY, normRotAxisZ, angle)
        }
    }
}

// MARK: - Estensioni

/// Estensione per creare geometria SceneKit da una mesh Marching Cubes
extension SCNGeometry {
    convenience init(mesh: Mesh) {
        // Prepara array per vertici e normali
        var vertices: [SCNVector3] = []
        var normals: [SCNVector3] = []
        
        // Converte ogni vertice della mesh nel formato SceneKit
        for vertex in mesh.vertices {
            vertices.append(SCNVector3(vertex.position.x, vertex.position.y, vertex.position.z))
            
            // Normalizza le normali
            let normal = vertex.normal
            let length = sqrt(normal.x * normal.x + normal.y * normal.y + normal.z * normal.z)
            if length > 0 {
                normals.append(SCNVector3(normal.x / length, normal.y / length, normal.z / length))
            } else {
                normals.append(SCNVector3(0, 1, 0))
            }
        }
        
        // Crea array di indici per i triangoli
        var indices: [Int32] = []
        
        for triangle in mesh.triangles {
            indices.append(Int32(triangle.indices.0))
            indices.append(Int32(triangle.indices.1))
            indices.append(Int32(triangle.indices.2))
        }
        
        // Crea le sorgenti di dati per SceneKit
        let vertexSource = SCNGeometrySource(vertices: vertices)
        let normalSource = SCNGeometrySource(normals: normals)
        
        // Crea l'elemento geometrico triangolare
        let element = SCNGeometryElement(indices: indices, primitiveType: .triangles)
        
        // Inizializza la geometria
        self.init(sources: [vertexSource, normalSource], elements: [element])
        
        // Crea un materiale ottimizzato per la visualizzazione
        let material = SCNMaterial()
        
        // Impostazioni base
        material.diffuse.contents = NSColor(calibratedRed: 0.85, green: 0.85, blue: 0.85, alpha: 1.0)
        material.specular.contents = NSColor.white
        material.shininess = 0.3
        material.lightingModel = .blinn
        material.fillMode = .fill
        material.isDoubleSided = false
        material.cullMode = .back
        
        // Effetti avanzati
        material.reflective.contents = NSColor(white: 0.15, alpha: 1.0)
        material.ambient.contents = NSColor(white: 0.4, alpha: 1.0)
        
        self.materials = [material]
    }
}

/// Estensione per permettere il confronto tra serie DICOM
extension DICOMSeries: Equatable {
    static func == (lhs: DICOMSeries, rhs: DICOMSeries) -> Bool {
        return lhs.id == rhs.id
    }
}
