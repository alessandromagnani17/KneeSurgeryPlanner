import Foundation
import simd

/// Classe di utilità per la manipolazione e creazione di mesh 3D.
/// Contiene funzioni per il vertex management, smoothing e creazione di forme base.
class MeshUtility {
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
    
    /// Crea una mesh sferica semplificata (per fallback)
    static func createSphereMesh(radius: Float, segments: Int, vertices: inout [Vertex], triangles: inout [Triangle]) {
        print("🔵 Creazione sfera fallback con \(segments) segmenti")
        let pi = Float.pi
        
        // Genera i vertici
        for i in 0...segments {
            let phi = pi * Float(i) / Float(segments)
            let cosPhi = cos(phi)
            let sinPhi = sin(phi)
            
            for j in 0...segments {
                let theta = 2.0 * pi * Float(j) / Float(segments)
                let cosTheta = cos(theta)
                let sinTheta = sin(theta)
                
                let x = radius * sinPhi * cosTheta
                let y = radius * sinPhi * sinTheta
                let z = radius * cosPhi
                
                let position = SIMD3<Float>(x, y, z)
                let normal = normalize(position)
                
                vertices.append(Vertex(position: position, normal: normal))
            }
        }
        
        // Genera i triangoli
        for i in 0..<segments {
            for j in 0..<segments {
                let first = UInt32(i * (segments + 1) + j)
                let second = first + 1
                let third = first + UInt32(segments + 1)
                let fourth = third + 1
                
                triangles.append(Triangle(indices: (first, second, third)))
                triangles.append(Triangle(indices: (second, fourth, third)))
            }
        }
        
        print("🔵 Creata sfera con \(vertices.count) vertici e \(triangles.count) triangoli")
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
    
    /// NUOVO METODO: Rimuove componenti isolati dalla mesh
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
    
    /// NUOVO METODO: Ottimizza la mesh rimuovendo vertici non utilizzati
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
    
    /// NUOVO METODO: Limita i vertici al bounding box specificato
    static func clampMeshToBounds(_ mesh: Mesh, minBounds: SIMD3<Float>, maxBounds: SIMD3<Float>) -> Mesh {
        print("📏 Limitazione mesh al bounding box: \(minBounds) - \(maxBounds)")
        
        var clampedVertices = mesh.vertices
        
        for i in 0..<clampedVertices.count {
            clampedVertices[i].position.x = max(minBounds.x, min(maxBounds.x, clampedVertices[i].position.x))
            clampedVertices[i].position.y = max(minBounds.y, min(maxBounds.y, clampedVertices[i].position.y))
            clampedVertices[i].position.z = max(minBounds.z, min(maxBounds.z, clampedVertices[i].position.z))
        }
        
        return Mesh(vertices: clampedVertices, triangles: mesh.triangles)
    }
    
    /// NUOVO METODO: Calcola il bounding box di una mesh
    static func calculateBoundingBox(_ mesh: Mesh) -> (min: SIMD3<Float>, max: SIMD3<Float>) {
        guard !mesh.vertices.isEmpty else {
            return (SIMD3<Float>(0, 0, 0), SIMD3<Float>(0, 0, 0))
        }
        
        var minBounds = SIMD3<Float>(Float.greatestFiniteMagnitude, Float.greatestFiniteMagnitude, Float.greatestFiniteMagnitude)
        var maxBounds = SIMD3<Float>(-Float.greatestFiniteMagnitude, -Float.greatestFiniteMagnitude, -Float.greatestFiniteMagnitude)
        
        for vertex in mesh.vertices {
            minBounds.x = min(minBounds.x, vertex.position.x)
            minBounds.y = min(minBounds.y, vertex.position.y)
            minBounds.z = min(minBounds.z, vertex.position.z)
            
            maxBounds.x = max(maxBounds.x, vertex.position.x)
            maxBounds.y = max(maxBounds.y, vertex.position.y)
            maxBounds.z = max(maxBounds.z, vertex.position.z)
        }
        
        return (minBounds, maxBounds)
    }
}
