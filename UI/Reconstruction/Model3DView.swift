/*
 Vista SwiftUI che visualizza un modello 3D ricostruito da immagini DICOM.

 Proprietà principali:
 - dicomManager: Gestisce i dati DICOM.
 - thresholdValue: Controlla il livello di soglia per la generazione del modello.

 Funzionalità:
 - Visualizza il modello 3D con controllo interattivo della telecamera.
 - Aggiorna il modello al variare della soglia.
 - Reimposta la telecamera.

 Scopo:
 Fornire una visualizzazione interattiva del modello 3D per l'analisi medica.
 */

import SwiftUI
import SceneKit

struct Model3DView: View {
    @ObservedObject var dicomManager: DICOMManager
    @State private var sceneView = SCNView()
    @State private var scene = SCNScene()
    @State private var cameraNode = SCNNode()
    @State private var thresholdValue: Float = 300
    
    var body: some View {
        VStack {
            HStack {
                Text("Threshold: \(Int(thresholdValue))")
                Slider(value: $thresholdValue, in: 0...1000)
                    .onChange(of: thresholdValue) { oldValue, newValue in
                        updateModel()
                    }
                
                Spacer()
                
                Button("Reset Camera") {
                    print("Model3DView: cliccato pulsante Reset Camera")
                    resetCamera()
                }
            }
            .padding()
            
            GeometryReader { geometry in
                SceneKitView(
                    scene: scene,
                    options: [.allowsCameraControl, .autoenablesDefaultLighting]
                )
                .onAppear {
                    setupScene()
                    updateModel()
                }
            }
        }
        .onChange(of: thresholdValue) { oldValue, newValue in
            updateModel()
        }
    }
    
    private func setupScene() {
        // Configura la scena
        scene.background.contents = NSColor.black
        
        // Configura la telecamera
        let camera = SCNCamera()
        camera.zNear = 1
        camera.zFar = 1000
        cameraNode.camera = camera
        cameraNode.position = SCNVector3(0, 0, 200)
        scene.rootNode.addChildNode(cameraNode)
        
        // Aggiungi luci
        let ambientLight = SCNNode()
        ambientLight.light = SCNLight()
        ambientLight.light?.type = .ambient
        ambientLight.light?.intensity = 50
        ambientLight.light?.color = NSColor.white
        scene.rootNode.addChildNode(ambientLight)
        
        let directionalLight = SCNNode()
        directionalLight.light = SCNLight()
        directionalLight.light?.type = .directional
        directionalLight.light?.intensity = 800
        directionalLight.light?.color = NSColor.white
        directionalLight.position = SCNVector3(50, 50, 50)
        directionalLight.eulerAngles = SCNVector3(-Float.pi/4, Float.pi/4, 0)
        scene.rootNode.addChildNode(directionalLight)
    }
    
    private func updateModel() {
        // Rimuovi modelli esistenti
        scene.rootNode.childNodes.filter { $0.name == "volumeMesh" }.forEach { $0.removeFromParentNode() }
        
        // Controlla se abbiamo una serie DICOM valida
        guard let series = dicomManager.currentSeries,
              let volume = dicomManager.createVolumeFromSeries(series) else {
            return
        }
        
        // Crea una mesh dal volume usando Marching Cubes
        let marchingCubes = MarchingCubes()
        let mesh = marchingCubes.generateMesh(from: volume, isovalue: thresholdValue)
        
        // Crea una geometria SceneKit dalla mesh
        let geometry = SCNGeometry(mesh: mesh)
        
        // Crea un nodo per la mesh
        let meshNode = SCNNode(geometry: geometry)
        meshNode.name = "volumeMesh"
        
        // Aggiungi il nodo alla scena
        scene.rootNode.addChildNode(meshNode)
    }
    
    private func resetCamera() {
        cameraNode.position = SCNVector3(0, 0, 200)
        cameraNode.eulerAngles = SCNVector3(0, 0, 0)
    }
}

// Helper per creare una geometria SceneKit da una mesh di marching cubes
extension SCNGeometry {
    convenience init(mesh: MarchingCubes.Mesh) {
        // Converti i vertici in un formato utilizzabile da SceneKit
        var vertices: [SCNVector3] = []
        var normals: [SCNVector3] = []
        
        for vertex in mesh.vertices {
            vertices.append(SCNVector3(vertex.position.x, vertex.position.y, vertex.position.z))
            normals.append(SCNVector3(vertex.normal.x, vertex.normal.y, vertex.normal.z))
        }
        
        // Converti i triangoli in indici
        var indices: [Int32] = []
        for triangle in mesh.triangles {
            indices.append(Int32(triangle.indices.0))
            indices.append(Int32(triangle.indices.1))
            indices.append(Int32(triangle.indices.2))
        }
        
        // Crea le fonti di geometria
        let vertexSource = SCNGeometrySource(vertices: vertices)
        let normalSource = SCNGeometrySource(normals: normals)
        
        // Crea l'elemento della geometria
        let element = SCNGeometryElement(indices: indices, primitiveType: .triangles)
        
        // Inizializza la geometria con le fonti e l'elemento
        self.init(sources: [vertexSource, normalSource], elements: [element])
        
        // Imposta il materiale
        let material = SCNMaterial()
        material.diffuse.contents = NSColor.systemBlue.withAlphaComponent(0.8)
        material.specular.contents = NSColor.white
        material.shininess = 0.5
        material.lightingModel = .phong
        
        self.materials = [material]
    }
}

// Wrapper per SceneKit
struct SceneKitView: NSViewRepresentable {
    let scene: SCNScene
    let options: SCNView.Options
    
    func makeNSView(context: Context) -> SCNView {
        let view = SCNView()
        view.scene = scene
        view.allowsCameraControl = options.contains(.allowsCameraControl)
        view.autoenablesDefaultLighting = options.contains(.autoenablesDefaultLighting)
        view.backgroundColor = NSColor.black
        view.showsStatistics = false
        return view
    }
    
    func updateNSView(_ nsView: SCNView, context: Context) {
        nsView.scene = scene
    }
}

extension SCNView {
    struct Options: OptionSet {
        let rawValue: Int
        
        static let allowsCameraControl = Options(rawValue: 1 << 0)
        static let autoenablesDefaultLighting = Options(rawValue: 1 << 1)
    }
}

extension DICOMSeries: Equatable {
    static func == (lhs: DICOMSeries, rhs: DICOMSeries) -> Bool {
        return lhs.id == rhs.id
    }
}
