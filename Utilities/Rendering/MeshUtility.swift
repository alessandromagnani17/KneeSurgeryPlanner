import Foundation
import simd

/// Classe di utilità per la manipolazione e creazione di mesh 3D.
/// Contiene funzioni per il vertex management, smoothing e creazione di forme base.
class MeshUtility {
    private struct Edge: Hashable {
        let v1: Int
        let v2: Int
        
        init(_ a: Int, _ b: Int) {
            // Ordina i vertici per garantire l'unicità dell'edge
            if a < b {
                v1 = a
                v2 = b
            } else {
                v1 = b
                v2 = a
            }
        }
    }
    
    /// Aggiunge un vertice alla mesh, evitando duplicati attraverso una mappa di vertici
    static func addVertex(_ position: SIMD3<Float>, _ normal: SIMD3<Float>,
                          _ vertices: inout [Vertex], _ vertexMap: inout [String: UInt32],
                          _ precision: Float = 100.0) -> UInt32 {
        // Usa una stringa hash come chiave per la mappa (approssimazione)
        let key = "\(Int(position.x * precision)),\(Int(position.y * precision)),\(Int(position.z * precision))"
        
        if let index = vertexMap[key] {
            // Il vertice esiste già
            return index
        } else {
            // Aggiungi un nuovo vertice
            let index = UInt32(vertices.count)
            vertices.append(Vertex(position: position, normal: normal))
            vertexMap[key] = index
            return index
        }
    }
    
    /// Interpolazione lineare tra due vettori
    static func mix(_ a: SIMD3<Float>, _ b: SIMD3<Float>, t: Float) -> SIMD3<Float> {
        let clampedT = max(0.0, min(1.0, t))
        return a * (1 - clampedT) + b * clampedT
    }
    
    /// Applica smoothing (lisciatura) alla mesh utilizzando l'algoritmo Laplaciano
    static func smoothMesh(_ mesh: Mesh, iterations: Int = 1, factor: Float = 0.5) -> Mesh {
        print("🔄 Smoothing mesh con \(iterations) iterazioni, fattore \(factor)...")
        
        guard iterations > 0 && factor > 0 else {
            return mesh
        }
        
        var smoothedVertices = mesh.vertices
        let triangles = mesh.triangles
        
        // Crea una mappa per trovare rapidamente i triangoli connessi a ogni vertice
        var vertexToTriangles: [Int: [Int]] = [:]
        
        for (triIndex, triangle) in triangles.enumerated() {
            let indices = [Int(triangle.indices.0), Int(triangle.indices.1), Int(triangle.indices.2)]
            for vIndex in indices {
                if vertexToTriangles[vIndex] == nil {
                    vertexToTriangles[vIndex] = []
                }
                vertexToTriangles[vIndex]?.append(triIndex)
            }
        }
        
        // Crea un set di vertici adiacenti per ogni vertice
        var vertexToNeighbors: [Int: Set<Int>] = [:]
        
        for (vIndex, triIndices) in vertexToTriangles {
            var neighbors = Set<Int>()
            
            for triIndex in triIndices {
                let triangle = triangles[triIndex]
                let indices = [Int(triangle.indices.0), Int(triangle.indices.1), Int(triangle.indices.2)]
                for neighborIndex in indices {
                    if neighborIndex != vIndex {
                        neighbors.insert(neighborIndex)
                    }
                }
            }
            
            vertexToNeighbors[vIndex] = neighbors
        }
        
        // Applica il Laplacian smoothing
        for _ in 0..<iterations {
            var newPositions: [SIMD3<Float>] = Array(repeating: SIMD3<Float>(0, 0, 0), count: smoothedVertices.count)
            
            for (vIndex, neighbors) in vertexToNeighbors {
                guard vIndex < smoothedVertices.count, !neighbors.isEmpty else { continue }
                
                // Calcola la posizione media dei vicini
                var avgPosition = SIMD3<Float>(0, 0, 0)
                for nIndex in neighbors {
                    guard nIndex < smoothedVertices.count else { continue }
                    avgPosition += smoothedVertices[nIndex].position
                }
                avgPosition /= Float(neighbors.count)
                
                // Interpola tra la posizione originale e la media
                let originalPos = smoothedVertices[vIndex].position
                newPositions[vIndex] = originalPos + (avgPosition - originalPos) * factor
            }
            
            // Aggiorna le posizioni
            for i in 0..<smoothedVertices.count {
                if length(newPositions[i]) > 0 {
                    smoothedVertices[i].position = newPositions[i]
                }
            }
        }
        
        // Ricalcola le normali dopo lo smoothing
        for i in 0..<triangles.count {
            let triangle = triangles[i]
            let v1 = Int(triangle.indices.0)
            let v2 = Int(triangle.indices.1)
            let v3 = Int(triangle.indices.2)
            
            guard v1 < smoothedVertices.count && v2 < smoothedVertices.count && v3 < smoothedVertices.count else {
                continue
            }
            
            let p1 = smoothedVertices[v1].position
            let p2 = smoothedVertices[v2].position
            let p3 = smoothedVertices[v3].position
            
            // Calcola la normale del triangolo
            let edge1 = p2 - p1
            let edge2 = p3 - p1
            let normal = normalize(cross(edge1, edge2))
            
            // Aggiorna le normali dei vertici
            smoothedVertices[v1].normal += normal
            smoothedVertices[v2].normal += normal
            smoothedVertices[v3].normal += normal
        }
        
        // Normalizza le normali dei vertici
        for i in 0..<smoothedVertices.count {
            if length(smoothedVertices[i].normal) > 0.0001 {
                smoothedVertices[i].normal = normalize(smoothedVertices[i].normal)
            } else {
                smoothedVertices[i].normal = SIMD3<Float>(0, 0, 1)
            }
        }
        
        print("✅ Smoothing completato: \(smoothedVertices.count) vertici elaborati")
        
        return Mesh(vertices: smoothedVertices, triangles: triangles)
    }
    
    /// Rimuove componenti isolati dalla mesh
    static func removeDisconnectedComponents(mesh: Mesh, minComponentSize: Int) -> Mesh {
        print("🧹 Rimozione componenti isolati con dimensione minima: \(minComponentSize)")
        
        // Se la mesh è vuota o troppo piccola, restituiscila senza modifiche
        if mesh.triangles.count <= 1 {
            return mesh
        }
        
        // Crea un grafo di adiacenza per i triangoli
        var adjacencyGraph: [Int: Set<Int>] = [:]
        for i in 0..<mesh.triangles.count {
            adjacencyGraph[i] = Set<Int>()
        }
        
        // Crea una mappa dai vertici ai triangoli che li contengono
        var vertexToTriangles: [UInt32: Set<Int>] = [:]
        for i in 0..<mesh.triangles.count {
            let triangle = mesh.triangles[i]
            
            // Aggiungi questo triangolo a tutti i suoi vertici
            for vertexIndex in [triangle.indices.0, triangle.indices.1, triangle.indices.2] {
                if vertexToTriangles[vertexIndex] == nil {
                    vertexToTriangles[vertexIndex] = Set<Int>()
                }
                vertexToTriangles[vertexIndex]?.insert(i)
            }
        }
        
        // Collega i triangoli nel grafo di adiacenza
        for i in 0..<mesh.triangles.count {
            let triangle = mesh.triangles[i]
            
            // Per ogni vertice del triangolo
            for vertexIndex in [triangle.indices.0, triangle.indices.1, triangle.indices.2] {
                // Aggiungi tutti i triangoli che condividono questo vertice come adiacenti
                if let trianglesWithVertex = vertexToTriangles[vertexIndex] {
                    for adjTriangle in trianglesWithVertex {
                        if adjTriangle != i {
                            adjacencyGraph[i]?.insert(adjTriangle)
                        }
                    }
                }
            }
        }
        
        // Trova i componenti connessi usando DFS
        var visited = Array(repeating: false, count: mesh.triangles.count)
        var components: [[Int]] = []
        
        for i in 0..<mesh.triangles.count {
            if !visited[i] {
                var component: [Int] = []
                var stack: [Int] = [i]
                visited[i] = true
                
                while !stack.isEmpty {
                    let current = stack.removeLast()
                    component.append(current)
                    
                    if let neighbors = adjacencyGraph[current] {
                        for neighbor in neighbors {
                            if !visited[neighbor] {
                                visited[neighbor] = true
                                stack.append(neighbor)
                            }
                        }
                    }
                }
                
                components.append(component)
            }
        }
        
        // Ordina i componenti per dimensione (numero di triangoli)
        components.sort { $0.count > $1.count }
        
        print("🔍 Trovati \(components.count) componenti separati")
        
        // Seleziona solo i componenti che soddisfano la dimensione minima
        var selectedTriangles = Set<Int>()
        var totalTriangles = 0
        
        for (index, component) in components.enumerated() {
            if component.count >= minComponentSize {
                selectedTriangles.formUnion(component)
                totalTriangles += component.count
                print("  ✅ Mantiene componente \(index): \(component.count) triangoli")
            } else {
                print("  ❌ Rimuove componente \(index): \(component.count) triangoli")
            }
        }
        
        // Se tutti i componenti sono stati rimossi, mantieni il componente principale
        if selectedTriangles.isEmpty && !components.isEmpty {
            let mainComponent = components[0]
            selectedTriangles.formUnion(mainComponent)
            totalTriangles = mainComponent.count
            print("⚠️ Tutti i componenti sono sotto la soglia minima. Mantiene il componente principale con \(mainComponent.count) triangoli")
        }
        
        // Costruisci la nuova mesh con solo i triangoli selezionati
        if selectedTriangles.count == mesh.triangles.count {
            print("✅ Nessun componente rimosso. Mesh invariata.")
            return mesh
        } else {
            print("✅ Rimossi \(mesh.triangles.count - selectedTriangles.count) triangoli isolati")
            
            // Crea una nuova mesh con solo i triangoli selezionati
            var newTriangles: [Triangle] = []
            
            for i in 0..<mesh.triangles.count {
                if selectedTriangles.contains(i) {
                    newTriangles.append(mesh.triangles[i])
                }
            }
            
            // Ottimizza la mesh rimuovendo i vertici non utilizzati e rinumerando
            return optimizeMesh(Mesh(vertices: mesh.vertices, triangles: newTriangles))
        }
    }
    
    /// Ottimizza la mesh rimuovendo vertici non utilizzati
    static func optimizeMesh(_ mesh: Mesh) -> Mesh {
        print("🔄 Ottimizzazione mesh: \(mesh.vertices.count) vertici, \(mesh.triangles.count) triangoli")
        
        // Trova tutti i vertici utilizzati
        var usedVertices = Set<UInt32>()
        for triangle in mesh.triangles {
            usedVertices.insert(triangle.indices.0)
            usedVertices.insert(triangle.indices.1)
            usedVertices.insert(triangle.indices.2)
        }
        
        // Crea una mappa dagli indici originali ai nuovi indici
        var vertexMap: [UInt32: UInt32] = [:]
        var newVertices: [Vertex] = []
        
        for i in 0..<mesh.vertices.count {
            let originalIndex = UInt32(i)
            if usedVertices.contains(originalIndex) {
                vertexMap[originalIndex] = UInt32(newVertices.count)
                newVertices.append(mesh.vertices[i])
            }
        }
        
        // Crea nuovi triangoli con indici aggiornati
        var newTriangles: [Triangle] = []
        for triangle in mesh.triangles {
            if let v1 = vertexMap[triangle.indices.0],
               let v2 = vertexMap[triangle.indices.1],
               let v3 = vertexMap[triangle.indices.2] {
                newTriangles.append(Triangle(indices: (v1, v2, v3)))
            }
        }
        
        print("✅ Ottimizzazione completata: \(newVertices.count) vertici, \(newTriangles.count) triangoli")
        return Mesh(vertices: newVertices, triangles: newTriangles)
    }
    
    /// Corregge l'orientamento delle normali nella mesh
    static func fixMeshNormals(_ mesh: inout Mesh) {
        print("🔄 Correzione normali della mesh...")
        
        // Verifica se le normali sono orientate correttamente
        // Campionando un sottoinsieme di vertici
        let sampleSize = min(100, mesh.vertices.count)
        var sumDotProducts: Float = 0
        
        for i in 0..<sampleSize {
            // Normalizza la posizione per ottenere una "direzione" dal centro
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
            print("⚠️ Rilevato orientamento delle normali invertito, correzione in corso...")
            // Inverte tutte le normali
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
        
        print("✅ Correzione normali completata")
    }
    
    /// Tenta di riparare buchi nella mesh identificando e collegando bordi aperti
    static func closeHolesInMesh(_ mesh: inout Mesh) {
        print("🔍 Analisi buchi nella mesh...")
        
        // Identifica i bordi della mesh
        var edgeCounts: [Edge: Int] = [:]
        
        // Conta l'occorrenza di ogni edge nella mesh
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
        
        // Gli edge che appaiono una sola volta sono bordi (non condivisi)
        let boundaryEdges = edgeCounts.filter { $0.value == 1 }.map { $0.key }
        
        // Se ci sono troppi bordi, potrebbe non essere pratico chiuderli tutti
        if boundaryEdges.count > 1000 {
            print("⚠️ Troppi bordi aperti nella mesh (\(boundaryEdges.count)), l'algoritmo di chiusura viene saltato")
            return
        }
        
        if boundaryEdges.isEmpty {
            print("✅ Nessun buco rilevato nella mesh")
            return
        }
        
        print("🛠 Tentativo di chiusura di \(boundaryEdges.count) bordi aperti nella mesh")
        
        // Organizza i bordi in cicli (loop)
        var boundaryLoops = findBoundaryLoops(from: boundaryEdges)
        
        // Tenta di chiudere i cicli più piccoli
        var newTriangles: [Triangle] = []
        
        for (index, loop) in boundaryLoops.enumerated() {
            if loop.count < 20 {  // Chiudi solo cicli piccoli per evitare creazione di facce non planari
                print("🔧 Chiusura ciclo \(index) con \(loop.count) vertici")
                closeLoop(loop, mesh: &mesh, newTriangles: &newTriangles)
            } else {
                print("⚠️ Ciclo \(index) troppo grande (\(loop.count) vertici), saltato")
            }
        }
        
        // Aggiungi i nuovi triangoli alla mesh
        if !newTriangles.isEmpty {
            print("✅ Aggiunti \(newTriangles.count) triangoli per chiudere i buchi")
            mesh.triangles.append(contentsOf: newTriangles)
        } else {
            print("ℹ️ Nessun triangolo aggiunto per la chiusura")
        }
    }
    
    /// Trova i cicli di bordi nella mesh
    private static func findBoundaryLoops(from boundaryEdges: [Edge]) -> [[Int]] {
        // Crea un dizionario che mappa ogni vertice con i suoi vertici adiacenti
        var adjacencyList: [Int: [Int]] = [:]
        
        for edge in boundaryEdges {
            adjacencyList[edge.v1, default: []].append(edge.v2)
            adjacencyList[edge.v2, default: []].append(edge.v1)
        }
        
        var loops: [[Int]] = []
        var visitedVertices = Set<Int>()
        
        // Per ogni vertice non ancora visitato nei bordi
        for edge in boundaryEdges {
            let startVertex = edge.v1
            
            if !visitedVertices.contains(startVertex) {
                var loop: [Int] = []
                var currentVertex = startVertex
                var previousVertex: Int? = nil
                
                // Segui il bordo fino a completare il ciclo
                while true {
                    loop.append(currentVertex)
                    visitedVertices.insert(currentVertex)
                    
                    guard let neighbors = adjacencyList[currentVertex] else { break }
                    
                    // Trova il prossimo vertice che non è quello da cui siamo arrivati
                    var nextVertex: Int? = nil
                    for neighbor in neighbors {
                        if neighbor != previousVertex {
                            nextVertex = neighbor
                            break
                        }
                    }
                    
                    if nextVertex == nil || nextVertex == startVertex {
                        // Ciclo completato o impossibile proseguire
                        break
                    }
                    
                    previousVertex = currentVertex
                    currentVertex = nextVertex!
                }
                
                if !loop.isEmpty {
                    loops.append(loop)
                }
            }
        }
        
        return loops
    }
    
    /// Chiude un ciclo creando triangoli che lo riempiono
    private static func closeLoop(_ loop: [Int], mesh: inout Mesh, newTriangles: inout [Triangle]) {
        guard loop.count >= 3 else { return }
        
        if loop.count == 3 {
            // Caso semplice: il ciclo è già un triangolo
            newTriangles.append(Triangle(indices: (UInt32(loop[0]), UInt32(loop[1]), UInt32(loop[2]))))
            return
        }
        
        // Per cicli più grandi, usiamo la triangolazione a ventaglio dal primo vertice
        // Non è ottimale ma è semplice
        let anchorVertex = loop[0]
        
        for i in 1..<(loop.count - 1) {
            newTriangles.append(Triangle(
                indices: (UInt32(anchorVertex), UInt32(loop[i]), UInt32(loop[i+1]))
            ))
        }
    }
}
