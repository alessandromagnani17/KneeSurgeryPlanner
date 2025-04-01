import SwiftUI
import SceneKit

/// Vista principale per la visualizzazione e interazione col modello 3D
struct Model3DView: View {
    // MARK: - Proprietà
    @ObservedObject var dicomManager: DICOMManager
    
    // Configurazione camera
    private let initialCameraPosition = SCNVector3(0, 0, 200)
    private let initialCameraEulerAngles = SCNVector3(0, 0, 0)
    
    // Stato della scena 3D
    @State private var scene = SCNScene()
    @State private var cameraNode = SCNNode()
    @State private var thresholdValue: Float = 350
    @State private var scnView: SCNView?
    @State private var renderingMode: RenderingMode = .solid
    
    // Stato del painter 3D
    @State private var drawingMode: DrawingMode = .none
    @State private var lineStyle: LineStyle = .freehand
    @State private var currentDrawingColor: NSColor = .red
    @State private var lineThickness: Float = 1.0
    @State private var drawingLines: [DrawingLine] = []
    
    @State private var isModelInitialized = false
    
    // MARK: - UI
    var body: some View {
        VStack {
            renderingControlsView
            drawingControlsView
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
        }
        .padding()
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
                allowsCameraControl: true,
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
        camera.zFar = 1000
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
        
        printSimpleHistogram(volume: volume)
        
        // Aggiungi miglioramento dei contorni
        addSilhouetteEnhancement(to: meshNode)
        
        // Applica la modalità di rendering scelta
        updateRenderingMode()
    }
    
    /// Crea un istogramma semplificato dei valori del volume
    private func printSimpleHistogram(volume: Volume) {
        var ranges: [String: Int] = [
            "<= -1000": 0,       // Aria
            "-999 - 0": 0,       // Grasso
            "1 - 400": 0,        // Tessuti molli
            "401 - 1000": 0,     // Osso trabecolare
            "1001 - 2000": 0,    // Osso compatto
            "> 2000": 0          // Metallo/artefatti
        ]
        
        // Campiona 1 voxel ogni 100 per velocità
        let sampleRate = 50
        var sampledCount = 0
        
        for z in stride(from: 0, to: volume.dimensions.z, by: sampleRate) {
            for y in stride(from: 0, to: volume.dimensions.y, by: sampleRate) {
                for x in stride(from: 0, to: volume.dimensions.x, by: sampleRate) {
                    let value = VolumeUtility.getVoxelValue(volume, x, y, z)
                    sampledCount += 1
                    
                    if value <= -1000 {
                        ranges["<= -1000"]! += 1
                    } else if value <= 0 {
                        ranges["-999 - 0"]! += 1
                    } else if value <= 400 {
                        ranges["1 - 400"]! += 1
                    } else if value <= 1000 {
                        ranges["401 - 1000"]! += 1
                    } else if value <= 2000 {
                        ranges["1001 - 2000"]! += 1
                    } else {
                        ranges["> 2000"]! += 1
                    }
                }
            }
        }
        
        print("\n=== DISTRIBUZIONE VALORI ===")
        print("Campione di \(sampledCount) voxel su \(volume.dimensions.x * volume.dimensions.y * volume.dimensions.z)")
        for (range, count) in ranges {
            let percentage = Float(count) / Float(sampledCount) * 100
            print("\(range): \(count) voxel (\(percentage.rounded())%)")
        }
        print("============================")
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

/// Estensione per permettere il confronto tra serie DICOM
extension DICOMSeries: Equatable {
    static func == (lhs: DICOMSeries, rhs: DICOMSeries) -> Bool {
        return lhs.id == rhs.id
    }
}
