/*
 View del modello 3D ricostruito da immagini DICOM.

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
    // Gestisce i dati DICOM e fornisce metodi per convertirli in formato 3D
    @ObservedObject var dicomManager: DICOMManager
    
    // Queste variabili di stato gestiscono la visualizzazione 3D
    @State private var scene = SCNScene()                 // La scena 3D che contiene il modello
    @State private var cameraNode = SCNNode()             // Il nodo della telecamera per la view 3D
    @State private var thresholdValue: Float = 100        // Valore di soglia per l'algoritmo Marching Cubes
    @State private var scnView: SCNView?                  // Riferimento alla view SceneKit attuale
    
    // La struttura dell'interfaccia utente
    var body: some View {
        VStack {
            // Barra superiore con controlli
            HStack {
                // Mostra il valore attuale della soglia e permette di modificarlo
                Text("Threshold: \(Int(thresholdValue))")
                Slider(value: $thresholdValue, in: 0...1000)
                    .onChange(of: thresholdValue) { oldValue, newValue in
                        // Quando la soglia cambia, aggiorna il modello 3D
                        updateModel()
                    }
                
                Spacer()
                
                // Pulsante per riportare la telecamera alla posizione iniziale
                Button("Reset Camera") {
                    print("Model3DView: cliccato pulsante Reset Camera")
                    resetCamera()
                }
            }
            .padding()
            
            // Area principale che mostra il modello 3D
            GeometryReader { geometry in
                // Wrapper di SceneKit per SwiftUI
                SceneKitView(
                    scene: scene,
                    options: [.allowsCameraControl, .autoenablesDefaultLighting], // Permette di ruotare il modello e attiva l'illuminazione automatica
                    onViewCreated: { view in
                        // Salva il riferimento alla view SceneKit
                        self.scnView = view
                    }
                )
                .onAppear {
                    // Quando la view appare, configura la scena e crea il modello iniziale
                    setupScene()
                    updateModel()
                }
            }
        }
    }
    
    // Configura la scena 3D, luci e telecamera
    private func setupScene() {
        // Imposta lo sfondo della scena in nero
        scene.background.contents = NSColor.black
        
        // Configura la telecamera per visualizzare il modello
        let camera = SCNCamera()
        camera.zNear = 1                      // Distanza minima visibile dalla telecamera
        camera.zFar = 1000                    // Distanza massima visibile dalla telecamera
        cameraNode.camera = camera
        cameraNode.position = SCNVector3(0, 0, 200)  // Posiziona la telecamera a distanza dal modello
        scene.rootNode.addChildNode(cameraNode)      // Aggiunge la telecamera alla scena
        
        // Aggiunge luce ambientale per illuminare uniformemente il modello
        let ambientLight = SCNNode()
        ambientLight.light = SCNLight()
        ambientLight.light?.type = .ambient           // Luce che illumina tutto uniformemente
        ambientLight.light?.intensity = 50            // Intensità bassa per non sovraesporre
        ambientLight.light?.color = NSColor.white
        scene.rootNode.addChildNode(ambientLight)
        
        // Aggiunge luce direzionale per creare ombre e dare profondità
        let directionalLight = SCNNode()
        directionalLight.light = SCNLight()
        directionalLight.light?.type = .directional   // Luce che proviene da una direzione
        directionalLight.light?.intensity = 800       // Intensità alta per illuminare bene il modello
        directionalLight.light?.color = NSColor.white
        directionalLight.position = SCNVector3(50, 50, 50)          // Posizione della luce
        directionalLight.eulerAngles = SCNVector3(-Float.pi/4, Float.pi/4, 0)  // Direzione della luce
        scene.rootNode.addChildNode(directionalLight)
    }
    
    // Genera o aggiorna il modello 3D in base al valore di soglia corrente
    private func updateModel() {
        // Rimuove eventuali modelli già presenti nella scena
        scene.rootNode.childNodes.filter { $0.name == "volumeMesh" }.forEach { $0.removeFromParentNode() }
        
        // Verifica che ci siano dati DICOM disponibili da visualizzare
        guard let series = dicomManager.currentSeries,
              let volume = dicomManager.createVolumeFromSeries(series) else {
            return  // Esce se non ci sono dati validi
        }
        
        // Crea una mesh 3D dai dati DICOM usando l'algoritmo Marching Cubes
        let marchingCubes = MarchingCubes()
        // Il valore di soglia determina quali parti del volume vengono incluse nel modello
        let mesh = marchingCubes.generateMesh(from: volume, isovalue: thresholdValue)
        
        // Converte la mesh generata in un formato compatibile con SceneKit
        let geometry = SCNGeometry(mesh: mesh)
        
        // Crea un nodo per visualizzare la mesh nella scena
        let meshNode = SCNNode(geometry: geometry)
        meshNode.name = "volumeMesh"  // Nome per identificare il nodo in futuro
        
        // Aggiunge il modello alla scena
        scene.rootNode.addChildNode(meshNode)
    }
    
    // Riporta la telecamera alla posizione e rotazione iniziale
    private func resetCamera() {
        guard let scnView = self.scnView else {
            print("View SceneKit non disponibile")
            return
        }
        
        // Utilizza SCNTransaction per animare il movimento della telecamera
        SCNTransaction.begin()
        SCNTransaction.animationDuration = 0.5 // Durata dell'animazione in secondi
        
        // Imposta la posizione e rotazione della telecamera di visualizzazione
        let defaultPosition = SCNVector3(0, 0, 200)
        let defaultOrientation = SCNQuaternion(0, 0, 0, 1) // Quaternione di identità (nessuna rotazione)
        
        scnView.pointOfView?.position = defaultPosition
        scnView.pointOfView?.orientation = defaultOrientation
        
        SCNTransaction.commit()
        
        print("Telecamera resettata alla posizione iniziale")
    }
}

// Estensione che aggiunge un metodo per creare una geometria SceneKit da una mesh Marching Cubes
extension SCNGeometry {
    convenience init(mesh: MarchingCubes.Mesh) {
        // Array per memorizzare vertici e normali convertiti
        var vertices: [SCNVector3] = []
        var normals: [SCNVector3] = []
        
        // Converte ogni vertice della mesh nel formato richiesto da SceneKit
        for vertex in mesh.vertices {
            vertices.append(SCNVector3(vertex.position.x, vertex.position.y, vertex.position.z))
            normals.append(SCNVector3(vertex.normal.x, vertex.normal.y, vertex.normal.z))
        }
        
        // Converte i triangoli della mesh in un array di indici
        var indices: [Int32] = []
        for triangle in mesh.triangles {
            indices.append(Int32(triangle.indices.0))  // Primo vertice del triangolo
            indices.append(Int32(triangle.indices.1))  // Secondo vertice del triangolo
            indices.append(Int32(triangle.indices.2))  // Terzo vertice del triangolo
        }
        
        // Crea le sorgenti di dati per SceneKit
        let vertexSource = SCNGeometrySource(vertices: vertices)  // Posizioni dei vertici
        let normalSource = SCNGeometrySource(normals: normals)    // Normali per l'illuminazione
        
        // Crea l'elemento geometrico che definisce come i vertici formano triangoli
        let element = SCNGeometryElement(indices: indices, primitiveType: .triangles)
        
        // Inizializza la geometria con vertici, normali e definizione dei triangoli
        self.init(sources: [vertexSource, normalSource], elements: [element])
        
        // Configura l'aspetto del modello
        let material = SCNMaterial()
        material.diffuse.contents = NSColor.systemBlue.withAlphaComponent(0.8)  // Colore blu semi-trasparente
        material.specular.contents = NSColor.white  // Riflessi bianchi per effetto lucido
        material.shininess = 0.5                    // Intensità dell'effetto lucido
        material.lightingModel = .phong             // Modello di illuminazione realistico
        
        self.materials = [material]  // Applica il materiale alla geometria
    }
}

// Componente che integra SceneKit con SwiftUI
struct SceneKitView: NSViewRepresentable {
    let scene: SCNScene                // La scena 3D da visualizzare
    let options: SCNView.Options       // Opzioni per la visualizzazione
    let onViewCreated: (SCNView) -> Void  // Callback per ottenere un riferimento alla view
    
    // Crea una view SceneKit quando SwiftUI lo richiede
    func makeNSView(context: Context) -> SCNView {
        let view = SCNView()
        view.scene = scene                                                  // Imposta la scena da visualizzare
        view.allowsCameraControl = options.contains(.allowsCameraControl)   // Abilita/disabilita controllo della telecamera
        view.autoenablesDefaultLighting = options.contains(.autoenablesDefaultLighting)  // Abilita/disabilita illuminazione automatica
        view.backgroundColor = NSColor.black                                // Sfondo nero
        view.showsStatistics = false                                        // Nasconde le statistiche di performance
        
        // Passa la view creata attraverso la callback
        onViewCreated(view)
        
        return view
    }
    
    // Aggiorna la view SceneKit quando SwiftUI lo richiede
    func updateNSView(_ nsView: SCNView, context: Context) {
        nsView.scene = scene  // Aggiorna la scena visualizzata
    }
}

// Definizione delle opzioni per la view SceneKit
extension SCNView {
    struct Options: OptionSet {
        let rawValue: Int
        
        static let allowsCameraControl = Options(rawValue: 1 << 0)          // Permette all'utente di ruotare/zoomare
        static let autoenablesDefaultLighting = Options(rawValue: 1 << 1)   // Aggiunge illuminazione automatica
    }
}

// Estensione per permettere il confronto tra serie DICOM
extension DICOMSeries: Equatable {
    static func == (lhs: DICOMSeries, rhs: DICOMSeries) -> Bool {
        return lhs.id == rhs.id  // Due serie sono uguali se hanno lo stesso ID
    }
}
