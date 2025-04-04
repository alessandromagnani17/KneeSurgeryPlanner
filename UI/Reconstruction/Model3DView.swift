import SwiftUI
import SceneKit
import ModelIO

/// Vista principale per la visualizzazione e interazione col modello 3D
struct Model3DView: View {
    // MARK: - Proprietà
    @ObservedObject var dicomManager: DICOMManager
    
    // Gestore per la pianificazione chirurgica
    @ObservedObject var planningManager: SurgicalPlanningManager
        
    // Configurazione camera
    private let initialCameraPosition = SCNVector3(250, 250, 800)
    private let initialCameraEulerAngles = SCNVector3(0, 0, 0)
    
    // Stato della scena 3D
    @State private var scene = SCNScene()
    @State private var cameraNode = SCNNode()
    @State private var thresholdValue: Float = 600
    @State private var scnView: SCNView?
    @State private var renderingMode: RenderingMode = .solid
    
    // Stato del painter 3D
    @State private var drawingMode: DrawingMode = .none
    @State private var lineStyle: LineStyle = .freehand
    @State private var currentDrawingColor: NSColor = .red
    @State private var lineThickness: Float = 1.0
    @State private var drawingLines: [DrawingLine] = []
    
    @State private var isModelInitialized = false
    @State private var isExporting = false
    
    // MARK: - Proprietà di pianificazione chirurgica
    @State private var isPlanningModeActive = false
    @State private var selectedPlaneType: SurgicalPlaneType = .distal
    
    // MARK: - UI
    var body: some View {
        VStack {
            renderingControlsView
            
            // Barra di controllo per la pianificazione o disegno
            if isPlanningModeActive {
                planningControlsView
            } else {
                drawingControlsView
            }
            
            modelView
        }
    }
    
    // MARK: - Viste componenti
    
    /// Controlli per il rendering del modello
    private var renderingControlsView: some View {
        HStack {
            Text("Threshold: \(Int(thresholdValue))")
            Slider(value: $thresholdValue, in: 0...1000)
                .onChange(of: thresholdValue) { _, _ in
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
            
            // Pulsante di esportazione
            Button("Export to Desktop") {
                exportModel()
            }
            
            // Pulsante per attivare/disattivare pianificazione
            Button(action: togglePlanningMode) {
                Text(isPlanningModeActive ? "Disegno" : "Pianificazione")
            }
            .buttonStyle(.bordered)
        }
        .padding()
    }
    
    private var planningControlsView: some View {
        planningControlsUI(
            isPlanningModeActive: isPlanningModeActive,
            selectedPlaneType: selectedPlaneType,
            onTogglePlanningMode: togglePlanningMode,
            onSelectPlaneType: { self.selectedPlaneType = $0 },
            onAddPlane: {
                self.addNewPlane(from: self.scnView, type: self.selectedPlaneType, scene: self.scene, planningManager: self.planningManager)
            },
            onRemovePlane: {
                if let selectedPlane = planningManager.selectedPlane {
                    // Rimuovi il nodo dalla scena
                    selectedPlane.sceneNode?.removeFromParentNode()
                    // Rimuovi il piano dal manager
                    planningManager.removePlane(id: selectedPlane.id)
                }
            },
            onRotatePlaneX: {
                self.rotatePlaneX(planningManager: self.planningManager)
            },
            onRotatePlaneY: {
                self.rotatePlaneY(planningManager: self.planningManager)
            }
        )
    }
    
    /// Controlli per il disegno sul modello
    private var drawingControlsView: some View {
        HStack {
            // Selezione modalità disegno
            Picker("Mode", selection: $drawingMode) {
                Text("View").tag(DrawingMode.none)
                Text("Draw").tag(DrawingMode.draw)
                Text("Erase").tag(DrawingMode.erase)
            }
            .pickerStyle(SegmentedPickerStyle())
            .frame(width: 200)
            
            Picker("Line Style", selection: $lineStyle) {
                        Text("Freehand").tag(LineStyle.freehand)
                        Text("Straight").tag(LineStyle.straight)
                    }
                    .pickerStyle(SegmentedPickerStyle())
                    .frame(width: 250)
                    .disabled(drawingMode != .draw)
            
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
    }
    
    /// Vista del modello 3D
    private var modelView: some View {
        GeometryReader { _ in
            SceneKitDrawingView(
                scene: scene,
                allowsCameraControl: isPlanningModeActive ? false : true,
                autoenablesDefaultLighting: false,
                drawingMode: drawingMode,
                lineStyle: lineStyle,
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
                    isModelInitialized = true
                }
            }
        }
    }
    
    // MARK: - Metodi per la configurazione della scena
    
    /// Configura la scena 3D e l'illuminazione
    private func setupScene() {
        scene.background.contents = NSColor.darkGray
        setupCamera()
        setupLighting()
    }
    
    /// Configura la camera
    private func setupCamera() {
        let camera = SCNCamera()
        camera.zNear = 1
        camera.zFar = 3000
        camera.fieldOfView = 45
        cameraNode.camera = camera
        cameraNode.position = initialCameraPosition
        cameraNode.eulerAngles = initialCameraEulerAngles
        scene.rootNode.addChildNode(cameraNode)
    }
    
    /// Configura il sistema di illuminazione
    private func setupLighting() {
        // 1. Luce ambientale
        addLight(type: .ambient, intensity: 70,
                 color: NSColor(calibratedRed: 0.9, green: 0.9, blue: 1.0, alpha: 1.0))
        
        // 2. Luce principale direzionale
        let mainLight = addLight(type: .directional, intensity: 1000,
                                 color: NSColor(calibratedRed: 1.0, green: 0.95, blue: 0.9, alpha: 1.0),
                                 position: SCNVector3(100, 150, 100))
        mainLight.light?.castsShadow = true
        mainLight.light?.shadowRadius = 3
        mainLight.light?.shadowColor = NSColor(white: 0.0, alpha: 0.7)
        mainLight.look(at: SCNVector3(0, 0, 0))
        
        // 3. Luce di riempimento
        let fillLight = addLight(type: .directional, intensity: 400,
                                 color: NSColor(calibratedRed: 0.9, green: 0.95, blue: 1.0, alpha: 1.0),
                                 position: SCNVector3(-100, 50, -100))
        fillLight.look(at: SCNVector3(0, 0, 0))
        
        // 4. Luce per i contorni (rim light)
        let rimLight = addLight(type: .directional, intensity: 300,
                                color: NSColor(calibratedRed: 1.0, green: 1.0, blue: 0.9, alpha: 1.0),
                                position: SCNVector3(0, -100, -150))
        rimLight.look(at: SCNVector3(0, 0, 0))
    }
    
    /// Aggiunge una luce alla scena con le specifiche fornite
    private func addLight(type: SCNLight.LightType, intensity: CGFloat,
                         color: NSColor, position: SCNVector3 = SCNVector3(0, 0, 0)) -> SCNNode {
        let lightNode = SCNNode()
        lightNode.light = SCNLight()
        lightNode.light?.type = type
        lightNode.light?.intensity = intensity
        lightNode.light?.color = color
        lightNode.position = position
        scene.rootNode.addChildNode(lightNode)
        return lightNode
    }
    
    // MARK: - Metodi per la gestione del modello
    
    /// Crea o aggiorna il modello 3D in base al valore di soglia
    private func updateModel() {
        removeExistingModel()
        createNewModel()
    }
    
    /// Rimuove il modello esistente dalla scena
    private func removeExistingModel() {
        let existingNodes = scene.rootNode.childNodes.filter {
            $0.name == "volumeMesh" || $0.name == "testBox" || $0.name == "wireframeMesh"
        }
        existingNodes.forEach { $0.removeFromParentNode() }
    }
    
    /// Crea un nuovo modello 3D
    private func createNewModel() {
        // Ottieni i dati DICOM correnti
        guard let series = dicomManager.currentSeries,
              let volume = dicomManager.createVolumeFromSeries(series) else {
            return
        }
        
        // Stampa valori in diversi punti per capire la distribuzione
        print("=== VALORI CAMPIONE ===")
        let centerX = volume.dimensions.x / 2
        let centerY = volume.dimensions.y / 2
        let centerZ = volume.dimensions.z / 2
        
        print("Centro volume: \(VolumeUtility.getVoxelValue(volume, centerX, centerY, centerZ)) HU")
        
        // Campiona punti in una griglia 3x3x3 attorno al centro
        for z in [centerZ-30, centerZ, centerZ+30] {
            for y in [centerY-30, centerY, centerY+30] {
                for x in [centerX-30, centerX, centerX+30] {
                    if x >= 0 && x < volume.dimensions.x &&
                       y >= 0 && y < volume.dimensions.y &&
                       z >= 0 && z < volume.dimensions.z {
                        let value = VolumeUtility.getVoxelValue(volume, x, y, z)
                        print("[\(x),\(y),\(z)]: \(value) HU")
                    }
                }
            }
        }
        print("======================")
        
        // Stampa informazioni sull'orientamento del volume
        print("Orientamento volume:")
        print("Origin: \(volume.origin)")
        print("Matrice di trasformazione:")
        print(volume.volumeToWorldMatrix)
        
        // Genera la mesh con Marching Cubes
        let marchingCubes = MarchingCubes()
        var mesh = marchingCubes.generateMesh(from: volume, isovalue: thresholdValue)
        
        // Ottimizzazione della mesh
        MeshUtility.closeHolesInMesh(&mesh)
        MeshUtility.fixMeshNormals(&mesh)
        
        // Crea il nodo del modello
        let geometry = SCNGeometry(mesh: mesh)
        let meshNode = SCNNode(geometry: geometry)
        meshNode.name = "volumeMesh"
        scene.rootNode.addChildNode(meshNode)
                
        // Aggiungi miglioramento dei contorni
        addSilhouetteEnhancement(to: meshNode)
        
        // Applica la modalità di rendering scelta
        updateRenderingMode()
        
        // Ripristina i piani chirurgici se necessario
        if isPlanningModeActive {
            // Rimuovi i nodi vecchi
            for plane in planningManager.planes {
                plane.sceneNode?.removeFromParentNode()
            }
            
            // Ricrea i nodi e aggiungili alla scena
            for plane in planningManager.planes {
                let planeNode = plane.createSceneNode()
                scene.rootNode.addChildNode(planeNode)
                
                if let scnView = self.scnView {
                    plane.enableDragInteraction(on: scnView, manager: planningManager)
                }
            }
        }
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
            applyMaterial(to: geometry.materials[i], forMode: renderingMode)
        }
        
        // Aggiungi overlay wireframe se necessario
        if renderingMode == .solidWithWireframe {
            addWireframeOverlay(for: geometry, parentNode: meshNode)
        }
    }
    
    /// Applica un materiale specifico in base alla modalità di rendering
    private func applyMaterial(to material: SCNMaterial, forMode mode: RenderingMode) {
        switch mode {
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
        }
    }
    
    /// Aggiunge un overlay wireframe al modello
    private func addWireframeOverlay(for geometry: SCNGeometry, parentNode: SCNNode) {
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
            wireframeNode.position = parentNode.position
            wireframeNode.scale = SCNVector3(1.001, 1.001, 1.001)
            scene.rootNode.addChildNode(wireframeNode)
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
    
    /// Esporta il modello 3D in formato SCN
    private func exportModel() {
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
                    alert.informativeText = "Il modello è stato salvato in formato SCN. Usa Reality Converter per convertirlo in USDZ se necessario."
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
    
    private func togglePlanningMode() {
        isPlanningModeActive.toggle()
        
        // Se disattiviamo la pianificazione, torniamo alla modalità di visualizzazione
        if !isPlanningModeActive {
            drawingMode = .none
        }
    }
}
