import Foundation
import simd

/// Strutture dati di base per l'algoritmo Marching Cubes
/// e per la rappresentazione delle mesh 3D.

/// Rappresenta un vertice della mesh con posizione e normale
struct Vertex {
    var position: SIMD3<Float>
    var normal: SIMD3<Float>
    
    init(position: SIMD3<Float>, normal: SIMD3<Float> = SIMD3<Float>(0, 0, 0)) {
        self.position = position
        self.normal = normal
    }
}

/// Rappresenta un triangolo della mesh con indici ai tre vertici
struct Triangle {
    var indices: (UInt32, UInt32, UInt32)
}

/// Rappresenta una mesh 3D completa con vertici e triangoli
struct Mesh {
    var vertices: [Vertex]
    var triangles: [Triangle]
}
