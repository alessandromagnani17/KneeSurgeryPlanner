import Foundation
import simd

/// Rappresenta un vertice della mesh con posizione e normale
struct Vertex {
    var position: SIMD3<Float>
    var normal: SIMD3<Float>
    
    init(position: SIMD3<Float>, normal: SIMD3<Float> = SIMD3<Float>(0, 0, 0)) {
        self.position = position
        self.normal = normal
    }
}
