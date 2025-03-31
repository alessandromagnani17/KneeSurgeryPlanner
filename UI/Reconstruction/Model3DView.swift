import SwiftUI
import SceneKit

// Definizione delle modalità di disegno
enum DrawingMode {
    case draw
    case erase
    case none
}

// Struttura per memorizzare le linee disegnate
struct DrawingLine: Identifiable {
    let id = UUID()
    var nodes: [SCNNode]
    var color: NSColor
    var thickness: Float
}

struct Model3DView: View {
    // MARK: - Proprietà esistenti
    @ObservedObject var dicomManager: DICOMManager
    
    private let initialCameraPosition = SCNVector3(0, 0, 200)
    private let initialCameraEulerAngles = SCNVector3(0, 0, 0)
    
    @State private var scene = SCNScene()
    @State private var cameraNode = SCNNode()
    @State private var thresholdValue: Float = 400
    @State private var scnView: SCNView?
    @State private var renderingMode: RenderingMode = .solid
    
    // MARK: - Nuove proprietà per il painter
    @State private var drawingMode: DrawingMode = .none
    @State private var currentDrawingColor: NSColor = .red
    @State private var lineThickness: Float = 1.0
    @State private var drawingLines: [DrawingLine] = []
    @State private var isDrawing = false
    @State private var lastHitPosition: SCNVector3?
    @State private var currentLineNodes: [SCNNode] = []
    
    enum RenderingMode {
        case solid
        case wireframe
        case solidWithWireframe
    }
    
    // MARK: - UI
    var body: some View {
        VStack {
            // Barra dei controlli esistente + controlli del painter
            HStack {
                // Controlli esistenti
                Text("Threshold: \(Int(thresholdValue))")
                Slider(value: $thresholdValue, in: 0...1000)
                    .onChange(of: thresholdValue) { oldValue, newValue in
                        print("📊 DEBUG: Threshold cambiato da \(oldValue) a \(newValue)")
                        updateModel()
                    }
                
                Spacer()
                
                Picker("Rendering", selection: $renderingMode) {
                    Text("Solid").tag(RenderingMode.solid)
                    Text("Wireframe").tag(RenderingMode.wireframe)
                    Text("Solid+Wire").tag(RenderingMode.solidWithWireframe)
                }
                .pickerStyle(MenuPickerStyle())
                .frame(width: 120)
                .onChange(of: renderingMode) { oldValue, newValue in
                    print("🖌️ DEBUG: Modalità rendering cambiata da \(oldValue) a \(newValue)")
                    updateRenderingMode()
                }
                
                Button("Reset Camera") {
                    print("📷 DEBUG: Reset camera richiesto")
                    resetCamera()
                }
            }
            .padding()
            
            // Nuova barra per i controlli del painter
            HStack {
                // Selezione modalità
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
                
                // Pulsante per cancellare tutte le linee
                Button("Clear All") {
                    clearAllDrawings()
                }
                .disabled(drawingLines.isEmpty)
                
                // Pulsante per annullare l'ultima linea
                Button("Undo") {
                    undoLastDrawing()
                }
                .disabled(drawingLines.isEmpty)
            }
            .padding(.horizontal)
            
            // Area principale che mostra il modello 3D
            GeometryReader { geometry in
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
                        print("🖼️ DEBUG: SceneKit view creata con dimensioni \(view.bounds.width) x \(view.bounds.height)")
                    }
                )
                .onAppear {
                    print("🚀 DEBUG: Model3DView è apparsa")
                    setupScene()
                    updateModel()
                }
            }
        }
    }
    
    // MARK: - Metodi esistenti
    private func setupScene() {
        // Codice esistente per la configurazione della scena
        scene.background.contents = NSColor.darkGray
        
        let camera = SCNCamera()
        camera.zNear = 1
        camera.zFar = 1000
        camera.fieldOfView = 45
        cameraNode.camera = camera
        cameraNode.position = initialCameraPosition
        cameraNode.eulerAngles = initialCameraEulerAngles
        scene.rootNode.addChildNode(cameraNode)
        
        // Illuminazione
        let ambientLight = SCNNode()
        ambientLight.light = SCNLight()
        ambientLight.light?.type = .ambient
        ambientLight.light?.intensity = 70
        ambientLight.light?.color = NSColor(calibratedRed: 0.9, green: 0.9, blue: 1.0, alpha: 1.0)
        scene.rootNode.addChildNode(ambientLight)
        
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
        
        let fillLight = SCNNode()
        fillLight.light = SCNLight()
        fillLight.light?.type = .directional
        fillLight.light?.intensity = 400
        fillLight.light?.color = NSColor(calibratedRed: 0.9, green: 0.95, blue: 1.0, alpha: 1.0)
        fillLight.position = SCNVector3(-100, 50, -100)
        fillLight.look(at: SCNVector3(0, 0, 0))
        scene.rootNode.addChildNode(fillLight)
        
        let rimLight = SCNNode()
        rimLight.light = SCNLight()
        rimLight.light?.type = .directional
        rimLight.light?.intensity = 300
        rimLight.light?.color = NSColor(calibratedRed: 1.0, green: 1.0, blue: 0.9, alpha: 1.0)
        rimLight.position = SCNVector3(0, -100, -150)
        rimLight.look(at: SCNVector3(0, 0, 0))
        scene.rootNode.addChildNode(rimLight)
        
        print("✅ DEBUG: Illuminazione professionale a 4 punti configurata")
    }
    
    private func updateModel() {
        // Mantieni il codice esistente per l'aggiornamento del modello
        print("🔄 DEBUG: Aggiornamento modello 3D con threshold \(thresholdValue)")
        
        // Rimuovi i nodi esistenti
        let existingNodes = scene.rootNode.childNodes.filter { $0.name == "volumeMesh" || $0.name == "testBox" || $0.name == "wireframeMesh" }
        if !existingNodes.isEmpty {
            print("🗑️ DEBUG: Rimozione di \(existingNodes.count) nodi esistenti")
            existingNodes.forEach { $0.removeFromParentNode() }
        }
        
        guard let series = dicomManager.currentSeries,
              let volume = dicomManager.createVolumeFromSeries(series) else {
            print("⚠️ DEBUG: Nessun dato DICOM disponibile")
            return
        }
        
        print("📋 DEBUG: Volume creato - dimensioni: \(volume.dimensions.x)x\(volume.dimensions.y)x\(volume.dimensions.z)")
        
        // Usa l'algoritmo Marching Cubes per generare la mesh
        let marchingCubes = MarchingCubes()
        print("⚙️ DEBUG: Inizio generazione mesh con isovalue \(thresholdValue)")
        
        var mesh = marchingCubes.generateMesh(from: volume, isovalue: thresholdValue)
        
        // Tentativo di riparare potenziali buchi
        closeHolesInMesh(&mesh)
        
        // Assicura il corretto orientamento delle normali
        fixMeshNormals(&mesh)
        
        // Crea la geometria con impostazioni ottimizzate
        let geometry = SCNGeometry(mesh: mesh)
        
        // Crea il nodo per il modello
        let meshNode = SCNNode(geometry: geometry)
        meshNode.name = "volumeMesh"
        
        // Applica trasformazioni per migliorare la visualizzazione
        meshNode.scale = SCNVector3(1.0, 1.0, 1.0)
        
        // Aggiungi il nodo alla scena
        scene.rootNode.addChildNode(meshNode)
        print("✅ DEBUG: Modello aggiunto alla scena")
        
        // Aggiungi supporto debug visivo - una sfera al centro della scena come riferimento
        let sphere = SCNSphere(radius: 5)
        let sphereMaterial = SCNMaterial()
        sphereMaterial.diffuse.contents = NSColor.red
        sphere.materials = [sphereMaterial]
        
        let sphereNode = SCNNode(geometry: sphere)
        sphereNode.position = SCNVector3(0, 0, 0)
        sphereNode.name = "debugSphere"
        scene.rootNode.addChildNode(sphereNode)
        
        // Aggiungi visualizzazione dei contorni (silhouette enhancement)
        addSilhouetteEnhancement(to: meshNode)
        
        // Applica la modalità di rendering corrente
        updateRenderingMode()
    }
    
    private func addSilhouetteEnhancement(to node: SCNNode) {
        // Mantieni il codice esistente
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
        
        print("✅ DEBUG: Miglioramento silhouette aggiunto")
    }
    
    private func updateRenderingMode() {
        // Mantieni il codice esistente
        guard let meshNode = scene.rootNode.childNodes.first(where: { $0.name == "volumeMesh" }) else {
            print("⚠️ DEBUG: Nessun nodo mesh trovato per applicare il rendering mode")
            return
        }
        
        guard let geometry = meshNode.geometry else {
            print("⚠️ DEBUG: Il nodo non ha geometria")
            return
        }
        
        print("🎨 DEBUG: Applicazione modalità rendering: \(renderingMode)")
        
        // Rimuovi eventuali nodi wireframe esistenti
        if renderingMode != .solidWithWireframe {
            scene.rootNode.childNodes.filter { $0.name == "wireframeMesh" }.forEach { $0.removeFromParentNode() }
        }
        
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
        
        print("✅ DEBUG: Modalità rendering applicata")
    }
    
    private func resetCamera() {
        // Mantieni il codice esistente
        guard let scnView = self.scnView else {
            print("⚠️ DEBUG: View SceneKit non disponibile per reset camera")
            return
        }
        
        print("🔄 DEBUG: Reset camera - posizione iniziale: \(initialCameraPosition)")
        
        SCNTransaction.begin()
        SCNTransaction.animationDuration = 0.5
        
        scnView.pointOfView?.position = initialCameraPosition
        scnView.pointOfView?.orientation = SCNQuaternion(0, 0, 0, 1)
        
        SCNTransaction.commit()
        
        print("✅ DEBUG: Telecamera resettata alla posizione iniziale")
    }
    
    func fixMeshNormals(_ mesh: inout Mesh) {
        print("DEBUG: Correzione orientamento normali")
        
        // Controllo se le normali sono già orientate correttamente
        // Questo è un euristico semplificato per determinare se dobbiamo invertire le normali
        let sampleSize = min(100, mesh.vertices.count)
        var sumDotProducts: Float = 0
        
        for i in 0..<sampleSize {
            let normalizedPosition = SIMD3<Float>(
                mesh.vertices[i].position.x / 100,
                mesh.vertices[i].position.y / 100,
                mesh.vertices[i].position.z / 100
            )
            
            // Il prodotto scalare tra la posizione e la normale dovrebbe essere positivo
            // se la normale punta verso l'esterno per una forma convessa
            let dotProduct = dot(normalizedPosition, mesh.vertices[i].normal)
            sumDotProducts += dotProduct
        }
        
        let shouldInvertNormals = sumDotProducts < 0
        
        if shouldInvertNormals {
            print("DEBUG: Le normali sembrano puntare verso l'interno - inversione")
            for i in 0..<mesh.vertices.count {
                mesh.vertices[i].normal = -mesh.vertices[i].normal
            }
        } else {
            print("DEBUG: Le normali sembrano già orientate correttamente")
        }
        
        // Assicuriamoci che tutte le normali siano normalizzate
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
    
    func closeHolesInMesh(_ mesh: inout Mesh) {
        // Questa è una implementazione semplificata che potrebbe necessitare di adattamenti
        // per il tuo caso specifico
        
        // 1. Identifica i bordi (edges) della mesh - quelli che appartengono a un solo triangolo
        print("DEBUG: Tentativo di chiusura buchi nella mesh")
        
        // Struttura per tenere traccia delle occorrenze dei bordi
        struct Edge: Hashable {
            let v1: Int
            let v2: Int
            
            init(_ a: Int, _ b: Int) {
                // Ordiniamo per garantire che (a,b) e (b,a) siano considerati lo stesso edge
                if a < b {
                    v1 = a
                    v2 = b
                } else {
                    v1 = b
                    v2 = a
                }
            }
        }
        
        // Contiamo le occorrenze di ogni edge
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
        print("DEBUG: Trovati \(boundaryEdges.count) bordi di confine (potrebbero formare buchi)")
        
        // Se ci sono troppi bordi, potrebbe non essere pratico chiuderli tutti
        if boundaryEdges.count > 1000 {
            print("DEBUG: Troppi bordi da chiudere, l'operazione potrebbe essere costosa")
            return
        }
        
        // Chiusura di buchi semplici - nota: questa è una semplificazione
        // Un'implementazione completa richiederebbe algoritmi più sofisticati
        
        // Per semplicità, è meglio implementare questo in un progetto reale
        // con una libreria di mesh processing come CGAL o MeshLab
        print("DEBUG: Chiusura buchi omessa - richiede implementazione specifica")
    }
    
    // MARK: - Gestione delle linee di disegno
    
    // Cancella tutte le linee
    private func clearAllDrawings() {
        // Rimuovi tutti i nodi di disegno dalla scena
        for line in drawingLines {
            for node in line.nodes {
                node.removeFromParentNode()
            }
        }
        
        // Svuota l'array
        drawingLines.removeAll()
        
        print("🧹 DEBUG: Cancellati tutti i disegni")
    }
    
    // Annulla l'ultima linea disegnata
    private func undoLastDrawing() {
        guard !drawingLines.isEmpty else { return }
        
        // Rimuovi l'ultima linea
        let lastLine = drawingLines.removeLast()
        
        // Rimuovi tutti i nodi associati dalla scena
        for node in lastLine.nodes {
            node.removeFromParentNode()
        }
        
        print("↩️ DEBUG: Annullata ultima linea")
    }
}

// MARK: - View rappresentabile che gestisce SceneKit e i gesti di disegno
struct SceneKitDrawingView: NSViewRepresentable {
    let scene: SCNScene
    let allowsCameraControl: Bool
    let autoenablesDefaultLighting: Bool
    let drawingMode: DrawingMode
    let currentDrawingColor: NSColor
    let lineThickness: Float
    @Binding var drawingLines: [DrawingLine]
    let onSceneViewCreated: (SCNView) -> Void
    
    // Crea la view NSView (SCNView)
    func makeNSView(context: Context) -> SCNView {
        let view = SCNView()
        view.scene = scene
        view.allowsCameraControl = allowsCameraControl
        view.autoenablesDefaultLighting = autoenablesDefaultLighting
        view.backgroundColor = NSColor.darkGray
        view.showsStatistics = true
        
        // Impostazioni avanzate per migliorare il rendering
        view.antialiasingMode = .multisampling4X
        view.preferredFramesPerSecond = 60
        view.isJitteringEnabled = true
        view.isPlaying = true
        
        // Associa il delegate al context coordinator
        context.coordinator.scnView = view
        
        // Configura i gesture recognizer
        let panGesture = NSPanGestureRecognizer(target: context.coordinator, action: #selector(DrawingCoordinator.handlePanGesture(_:)))
        panGesture.buttonMask = 0x1 // Clic sinistro
        view.addGestureRecognizer(panGesture)
        
        // Callback alla view principale
        onSceneViewCreated(view)
        
        return view
    }
    
    // Aggiorna la view NSView quando cambiano i dati
    func updateNSView(_ nsView: SCNView, context: Context) {
        // Aggiorna la scena
        nsView.scene = scene
        
        // Aggiorna le proprietà del coordinatore
        context.coordinator.drawingMode = drawingMode
        context.coordinator.currentDrawingColor = currentDrawingColor
        context.coordinator.lineThickness = lineThickness
    }
    
    // Crea il coordinatore che gestirà interazioni e disegno
    func makeCoordinator() -> DrawingCoordinator {
        DrawingCoordinator(self)
    }
    
    // MARK: - Coordinatore per la gestione dei gesti
    class DrawingCoordinator: NSObject {
        var parent: SceneKitDrawingView
        var scnView: SCNView?
        
        // Stato di disegno
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
        
        // MARK: - Gestione gesture
        @objc func handlePanGesture(_ gestureRecognizer: NSPanGestureRecognizer) {
            guard let scnView = self.scnView, drawingMode != .none else { return }
            
            let location = gestureRecognizer.location(in: scnView)
            
            // Hit test per trovare dove l'utente sta puntando sul modello 3D
            let hitResults = scnView.hitTest(location, options: nil)
            
            // Filtra i risultati per considerare solo la mesh principale del volume
            let volumeHits = hitResults.filter { result in
                return result.node.name == "volumeMesh" || (result.node.parent?.name == "volumeMesh")
            }
            
            guard let hit = volumeHits.first else {
                // Se il gesto termina senza hit, salva la linea corrente se necessario
                if gestureRecognizer.state == .ended || gestureRecognizer.state == .cancelled {
                    finalizeCurrentDrawing()
                }
                return
            }
            
            // Ottieni la posizione 3D del punto colpito
            let hitPosition = hit.worldCoordinates
            
            switch gestureRecognizer.state {
            case .began:
                // Inizia una nuova linea
                if drawingMode == .draw {
                    beginDrawing(at: hitPosition)
                } else if drawingMode == .erase {
                    eraseAtPosition(hitPosition)
                }
                
            case .changed:
                // Continua la linea esistente o continua a cancellare
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
        
        // MARK: - Metodi per il disegno
        
        private func beginDrawing(at position: SCNVector3) {
            guard let scene = scnView?.scene else { return }
            
            print("🖌️ DEBUG: Inizio disegno in posizione \(position)")
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
        
        private func finalizeCurrentDrawing() {
            guard isDrawing, !currentLineNodes.isEmpty else { return }
            
            print("✅ DEBUG: Disegno completato")
            
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
        
        private func eraseAtPosition(_ position: SCNVector3) {
            guard let scene = scnView?.scene else { return }
            
            // Raggio di cancellazione - leggermente più grande dello spessore della linea
            let eraseRadius: Float = lineThickness * 1.5
            
            // Memorizziamo gli ID delle linee da rimuovere
            var linesToRemove = Set<UUID>()
            
            // Crea una copia locale dell'array di drawing lines per evitare problemi di thread
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
                    print("🗑️ DEBUG: Linea cancellata")
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
        
        // Metodo statico per calcolare la distanza
        static func distance(from point1: SCNVector3, to point2: SCNVector3) -> Float {
            let dx = point1.x - point2.x
            let dy = point1.y - point2.y
            let dz = point1.z - point2.z
            
            // Suddividi il calcolo in passaggi intermedi
            let dxSquared = dx * dx
            let dySquared = dy * dy
            let dzSquared = dz * dz
            
            let sumOfSquares = dxSquared + dySquared + dzSquared
            
            // Usa sqrt() specificando esplicitamente che vogliamo la versione per Float
            let result = Float(sqrt(Double(sumOfSquares)))
            
            return result
        }
        
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
            
            // 6. Calcola il prodotto scalare
            // Calcola il prodotto scalare in passaggi separati
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

            // Calcola il prodotto vettoriale componente per componente con tipi espliciti
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

// MARK: - Estensioni supporto

// Estensione che aggiunge un metodo per creare una geometria SceneKit da una mesh Marching Cubes
extension SCNGeometry {
    convenience init(mesh: Mesh) {
        // Array per memorizzare vertici e normali convertiti
        var vertices: [SCNVector3] = []
        var normals: [SCNVector3] = []
        
        // Converte ogni vertice della mesh nel formato richiesto da SceneKit
        for vertex in mesh.vertices {
            vertices.append(SCNVector3(vertex.position.x, vertex.position.y, vertex.position.z))
            
            // Utilizziamo normali calcolate in modo coerente
            let normal = vertex.normal
            // Garantiamo che tutte le normali siano orientate correttamente e normalizzate
            let length = sqrt(normal.x * normal.x + normal.y * normal.y + normal.z * normal.z)
            if length > 0 {
                // Normalizza la normale e assicura che abbia la direzione corretta
                normals.append(SCNVector3(normal.x / length, normal.y / length, normal.z / length))
            } else {
                // Fallback: usa una normale predefinita se la normale è un vettore nullo
                normals.append(SCNVector3(0, 1, 0))
            }
        }
        
        // Indici dei triangoli - assicuriamoci che abbiano l'orientamento corretto
        var indices: [Int32] = []
        
        // IMPORTANTE: Potrebbe essere necessario cambiare l'ordine degli indici
        // per invertire l'orientamento delle facce se necessario
        for triangle in mesh.triangles {
            // Ordine normale - senso orario (clockwise)
            indices.append(Int32(triangle.indices.0))
            indices.append(Int32(triangle.indices.1))
            indices.append(Int32(triangle.indices.2))
        }
        
        // Crea le sorgenti di dati per SceneKit
        let vertexSource = SCNGeometrySource(vertices: vertices)
        let normalSource = SCNGeometrySource(normals: normals)
        
        // Crea l'elemento geometrico che definisce come i vertici formano triangoli
        let element = SCNGeometryElement(indices: indices, primitiveType: .triangles)
        
        // Inizializza la geometria
        self.init(sources: [vertexSource, normalSource], elements: [element])
        
        // Crea un materiale ottimizzato per la visualizzazione
        let material = SCNMaterial()
        
        // Configurazioni di base per un materiale solido
        material.diffuse.contents = NSColor(calibratedRed: 0.85, green: 0.85, blue: 0.85, alpha: 1.0)
        material.specular.contents = NSColor.white
        material.shininess = 0.3
        
        // Usa Blinn per una migliore resa delle superfici curve
        material.lightingModel = .blinn
        material.fillMode = .fill
        
        // Disattiva double-sided per migliorare le performance
        material.isDoubleSided = false
        
        // Esegue il culling dei poligoni con normali che puntano via dalla telecamera
        material.cullMode = .back
        
        // Aggiunge riflettività per superfici più realistiche
        material.reflective.contents = NSColor(white: 0.15, alpha: 1.0)
        
        // Aggiunta di leggera ambient occlusion per migliorare la percezione di profondità
        material.ambient.contents = NSColor(white: 0.4, alpha: 1.0)
        
        self.materials = [material]
        
        print("DEBUG: SCNGeometry configurata con materiale solido ottimizzato")
    }
}

// Estensione per permettere il confronto tra serie DICOM
extension DICOMSeries: Equatable {
    static func == (lhs: DICOMSeries, rhs: DICOMSeries) -> Bool {
        return lhs.id == rhs.id  // Due serie sono uguali se hanno lo stesso ID
    }
}
