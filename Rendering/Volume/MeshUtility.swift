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
}
