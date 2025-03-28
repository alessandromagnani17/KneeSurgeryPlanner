import Foundation
import simd

class MarchingCubes {
    struct Vertex {
        var position: SIMD3<Float>
        var normal: SIMD3<Float>
        
        init(position: SIMD3<Float>, normal: SIMD3<Float> = SIMD3<Float>(0, 0, 0)) {
            self.position = position
            self.normal = normal
        }
    }
    
    struct Triangle {
        var indices: (UInt32, UInt32, UInt32)
    }
    
    struct Mesh {
        var vertices: [Vertex]
        var triangles: [Triangle]
    }
    
    // Tabella degli spigoli per Marching Cubes
    private let edgeTable: [Int] = [
                0x0  , 0x109, 0x203, 0x30a, 0x406, 0x50f, 0x605, 0x70c,
                0x80c, 0x905, 0xa0f, 0xb06, 0xc0a, 0xd03, 0xe09, 0xf00,
                0x190, 0x99 , 0x393, 0x29a, 0x596, 0x49f, 0x795, 0x69c,
                0x99c, 0x895, 0xb9f, 0xa96, 0xd9a, 0xc93, 0xf99, 0xe90,
                0x230, 0x339, 0x33 , 0x13a, 0x636, 0x73f, 0x435, 0x53c,
                0xa3c, 0xb35, 0x83f, 0x936, 0xe3a, 0xf33, 0xc39, 0xd30,
                0x3a0, 0x2a9, 0x1a3, 0xaa , 0x7a6, 0x6af, 0x5a5, 0x4ac,
                0xbac, 0xaa5, 0x9af, 0x8a6, 0xfaa, 0xea3, 0xda9, 0xca0,
                0x460, 0x569, 0x663, 0x76a, 0x66 , 0x16f, 0x265, 0x36c,
                0xc6c, 0xd65, 0xe6f, 0xf66, 0x86a, 0x963, 0xa69, 0xb60,
                0x5f0, 0x4f9, 0x7f3, 0x6fa, 0x1f6, 0xff , 0x3f5, 0x2fc,
                0xdfc, 0xcf5, 0xfff, 0xef6, 0x9fa, 0x8f3, 0xbf9, 0xaf0,
                0x650, 0x759, 0x453, 0x55a, 0x256, 0x35f, 0x55 , 0x15c,
                0xe5c, 0xf55, 0xc5f, 0xd56, 0xa5a, 0xb53, 0x859, 0x950,
                0x7c0, 0x6c9, 0x5c3, 0x4ca, 0x3c6, 0x2cf, 0x1c5, 0xcc ,
                0xfcc, 0xec5, 0xdcf, 0xcc6, 0xbca, 0xac3, 0x9c9, 0x8c0,
                0x8c0, 0x9c9, 0xac3, 0xbca, 0xcc6, 0xdcf, 0xec5, 0xfcc,
                0xcc , 0x1c5, 0x2cf, 0x3c6, 0x4ca, 0x5c3, 0x6c9, 0x7c0,
                0x950, 0x859, 0xb53, 0xa5a, 0xd56, 0xc5f, 0xf55, 0xe5c,
                0x15c, 0x55 , 0x35f, 0x256, 0x55a, 0x453, 0x759, 0x650,
                0xaf0, 0xbf9, 0x8f3, 0x9fa, 0xef6, 0xfff, 0xcf5, 0xdfc,
                0x2fc, 0x3f5, 0xff , 0x1f6, 0x6fa, 0x7f3, 0x4f9, 0x5f0,
                0xb60, 0xa69, 0x963, 0x86a, 0xf66, 0xe6f, 0xd65, 0xc6c,
                0x36c, 0x265, 0x16f, 0x66 , 0x76a, 0x663, 0x569, 0x460,
                0xca0, 0xda9, 0xea3, 0xfaa, 0x8a6, 0x9af, 0xaa5, 0xbac,
                0x4ac, 0x5a5, 0x6af, 0x7a6, 0xaa , 0x1a3, 0x2a9, 0x3a0,
                0xd30, 0xc39, 0xf33, 0xe3a, 0x936, 0x83f, 0xb35, 0xa3c,
                0x53c, 0x435, 0x73f, 0x636, 0x13a, 0x33 , 0x339, 0x230,
                0xe90, 0xf99, 0xc93, 0xd9a, 0xa96, 0xb9f, 0x895, 0x99c,
                0x69c, 0x795, 0x49f, 0x596, 0x29a, 0x393, 0x99 , 0x190,
                0xf00, 0xe09, 0xd03, 0xc0a, 0xb06, 0xa0f, 0x905, 0x80c,
                0x70c, 0x605, 0x50f, 0x406, 0x30a, 0x203, 0x109, 0x0
            ]
            
            // Tabella dei triangoli per Marching Cubes
            // Per ogni configurazione di vertici, questa tabella indica come costruire i triangoli
            // Tabella completa dei triangoli per Marching Cubes
            private let triTable: [[Int]] = [
                [],
                [0, 8, 3],
                [0, 1, 9],
                [1, 8, 3, 9, 8, 1],
                [1, 2, 10],
                [0, 8, 3, 1, 2, 10],
                [9, 2, 10, 0, 2, 9],
                [2, 8, 3, 2, 10, 8, 10, 9, 8],
                [3, 11, 2],
                [0, 11, 2, 8, 11, 0],
                [1, 9, 0, 2, 3, 11],
                [1, 11, 2, 1, 9, 11, 9, 8, 11],
                [3, 10, 1, 11, 10, 3],
                [0, 10, 1, 0, 8, 10, 8, 11, 10],
                [3, 9, 0, 3, 11, 9, 11, 10, 9],
                [9, 8, 10, 10, 8, 11],
                [4, 7, 8],
                [4, 3, 0, 7, 3, 4],
                [0, 1, 9, 8, 4, 7],
                [4, 1, 9, 4, 7, 1, 7, 3, 1],
                [1, 2, 10, 8, 4, 7],
                [3, 4, 7, 3, 0, 4, 1, 2, 10],
                [9, 2, 10, 9, 0, 2, 8, 4, 7],
                [2, 10, 9, 2, 9, 7, 2, 7, 3, 7, 9, 4],
                [8, 4, 7, 3, 11, 2],
                [11, 4, 7, 11, 2, 4, 2, 0, 4],
                [9, 0, 1, 8, 4, 7, 2, 3, 11],
                [4, 7, 11, 9, 4, 11, 9, 11, 2, 9, 2, 1],
                [3, 10, 1, 3, 11, 10, 7, 8, 4],
                [1, 11, 10, 1, 4, 11, 1, 0, 4, 7, 11, 4],
                [4, 7, 8, 9, 0, 11, 9, 11, 10, 11, 0, 3],
                [4, 7, 11, 4, 11, 9, 9, 11, 10],
                [9, 5, 4],
                [9, 5, 4, 0, 8, 3],
                [0, 5, 4, 1, 5, 0],
                [8, 5, 4, 8, 3, 5, 3, 1, 5],
                [1, 2, 10, 9, 5, 4],
                [3, 0, 8, 1, 2, 10, 4, 9, 5],
                [5, 2, 10, 5, 4, 2, 4, 0, 2],
                [2, 10, 5, 3, 2, 5, 3, 5, 4, 3, 4, 8],
                [9, 5, 4, 2, 3, 11],
                [0, 11, 2, 0, 8, 11, 4, 9, 5],
                [0, 5, 4, 0, 1, 5, 2, 3, 11],
                [2, 1, 5, 2, 5, 8, 2, 8, 11, 4, 8, 5],
                [10, 3, 11, 10, 1, 3, 9, 5, 4],
                [4, 9, 5, 0, 8, 1, 8, 10, 1, 8, 11, 10],
                [5, 4, 0, 5, 0, 11, 5, 11, 10, 11, 0, 3],
                [5, 4, 8, 5, 8, 10, 10, 8, 11],
                [9, 7, 8, 5, 7, 9],
                [9, 3, 0, 9, 5, 3, 5, 7, 3],
                [0, 7, 8, 0, 1, 7, 1, 5, 7],
                [1, 5, 3, 3, 5, 7],
                [9, 7, 8, 9, 5, 7, 10, 1, 2],
                [10, 1, 2, 9, 5, 0, 5, 3, 0, 5, 7, 3],
                [8, 0, 2, 8, 2, 5, 8, 5, 7, 10, 5, 2],
                [2, 10, 5, 2, 5, 3, 3, 5, 7],
                [7, 9, 5, 7, 8, 9, 3, 11, 2],
                [9, 5, 7, 9, 7, 2, 9, 2, 0, 2, 7, 11],
                [2, 3, 11, 0, 1, 8, 1, 7, 8, 1, 5, 7],
                [11, 2, 1, 11, 1, 7, 7, 1, 5],
                [9, 5, 8, 8, 5, 7, 10, 1, 3, 10, 3, 11],
                [5, 7, 0, 5, 0, 9, 7, 11, 0, 1, 0, 10, 11, 10, 0],
                [11, 10, 0, 11, 0, 3, 10, 5, 0, 8, 0, 7, 5, 7, 0],
                [11, 10, 5, 7, 11, 5],
                [10, 6, 5],
                [0, 8, 3, 5, 10, 6],
                [9, 0, 1, 5, 10, 6],
                [1, 8, 3, 1, 9, 8, 5, 10, 6],
                [1, 6, 5, 2, 6, 1],
                [1, 6, 5, 1, 2, 6, 3, 0, 8],
                [9, 6, 5, 9, 0, 6, 0, 2, 6],
                [5, 9, 8, 5, 8, 2, 5, 2, 6, 3, 2, 8],
                [2, 3, 11, 10, 6, 5],
                [11, 0, 8, 11, 2, 0, 10, 6, 5],
                [0, 1, 9, 2, 3, 11, 5, 10, 6],
                [5, 10, 6, 1, 9, 2, 9, 11, 2, 9, 8, 11],
                [6, 3, 11, 6, 5, 3, 5, 1, 3],
                [0, 8, 11, 0, 11, 5, 0, 5, 1, 5, 11, 6],
                [3, 11, 6, 0, 3, 6, 0, 6, 5, 0, 5, 9],
                [6, 5, 9, 6, 9, 11, 11, 9, 8],
                [5, 10, 6, 4, 7, 8],
                [4, 3, 0, 4, 7, 3, 6, 5, 10],
                [1, 9, 0, 5, 10, 6, 8, 4, 7],
                [10, 6, 5, 1, 9, 7, 1, 7, 3, 7, 9, 4],
                [6, 1, 2, 6, 5, 1, 4, 7, 8],
                [1, 2, 5, 5, 2, 6, 3, 0, 4, 3, 4, 7],
                [8, 4, 7, 9, 0, 5, 0, 6, 5, 0, 2, 6],
                [7, 3, 9, 7, 9, 4, 3, 2, 9, 5, 9, 6, 2, 6, 9],
                [3, 11, 2, 7, 8, 4, 10, 6, 5],
                [5, 10, 6, 4, 7, 2, 4, 2, 0, 2, 7, 11],
                [0, 1, 9, 4, 7, 8, 2, 3, 11, 5, 10, 6],
                [9, 2, 1, 9, 11, 2, 9, 4, 11, 7, 11, 4, 5, 10, 6],
                [8, 4, 7, 3, 11, 5, 3, 5, 1, 5, 11, 6],
                [5, 1, 11, 5, 11, 6, 1, 0, 11, 7, 11, 4, 0, 4, 11],
                [0, 5, 9, 0, 6, 5, 0, 3, 6, 11, 6, 3, 8, 4, 7],
                [6, 5, 9, 6, 9, 11, 4, 7, 9, 7, 11, 9],
                [10, 4, 9, 6, 4, 10],
                [4, 10, 6, 4, 9, 10, 0, 8, 3],
                [10, 0, 1, 10, 6, 0, 6, 4, 0],
                [8, 3, 1, 8, 1, 6, 8, 6, 4, 6, 1, 10],
                [1, 4, 9, 1, 2, 4, 2, 6, 4],
                [3, 0, 8, 1, 2, 9, 2, 4, 9, 2, 6, 4],
                [0, 2, 4, 4, 2, 6],
                [8, 3, 2, 8, 2, 4, 4, 2, 6],
                [10, 4, 9, 10, 6, 4, 11, 2, 3],
                [0, 8, 2, 2, 8, 11, 4, 9, 10, 4, 10, 6],
                [3, 11, 2, 0, 1, 6, 0, 6, 4, 6, 1, 10],
                [6, 4, 1, 6, 1, 10, 4, 8, 1, 2, 1, 11, 8, 11, 1],
                [9, 6, 4, 9, 3, 6, 9, 1, 3, 11, 6, 3],
                [8, 11, 1, 8, 1, 0, 11, 6, 1, 9, 1, 4, 6, 4, 1],
                [3, 11, 6, 3, 6, 0, 0, 6, 4],
                [6, 4, 8, 11, 6, 8],
                [7, 10, 6, 7, 8, 10, 8, 9, 10],
                [0, 7, 3, 0, 10, 7, 0, 9, 10, 6, 7, 10],
                [10, 6, 7, 1, 10, 7, 1, 7, 8, 1, 8, 0],
                [10, 6, 7, 10, 7, 1, 1, 7, 3],
                [1, 2, 6, 1, 6, 8, 1, 8, 9, 8, 6, 7],
                [2, 6, 9, 2, 9, 1, 6, 7, 9, 0, 9, 3, 7, 3, 9],
                [7, 8, 0, 7, 0, 6, 6, 0, 2],
                [7, 3, 2, 6, 7, 2],
                [2, 3, 11, 10, 6, 8, 10, 8, 9, 8, 6, 7],
                [2, 0, 7, 2, 7, 11, 0, 9, 7, 6, 7, 10, 9, 10, 7],
                [1, 8, 0, 1, 7, 8, 1, 10, 7, 6, 7, 10, 2, 3, 11],
                [11, 2, 1, 11, 1, 7, 10, 6, 1, 6, 7, 1],
                [8, 9, 6, 8, 6, 7, 9, 1, 6, 11, 6, 3, 1, 3, 6],
                [0, 9, 1, 11, 6, 7],
                [7, 8, 0, 7, 0, 6, 3, 11, 0, 11, 6, 0],
                [7, 11, 6],
                [7, 6, 11],
                [3, 0, 8, 11, 7, 6],
                [0, 1, 9, 11, 7, 6],
                [8, 1, 9, 8, 3, 1, 11, 7, 6],
                [10, 1, 2, 6, 11, 7],
                [1, 2, 10, 3, 0, 8, 6, 11, 7],
                [2, 9, 0, 2, 10, 9, 6, 11, 7],
                [6, 11, 7, 2, 10, 3, 10, 8, 3, 10, 9, 8],
                [7, 2, 3, 7, 6, 2],
                [7, 0, 8, 7, 6, 0, 6, 2, 0],
                [2, 7, 6, 2, 3, 7, 0, 1, 9],
                [1, 6, 2, 1, 8, 6, 1, 9, 8, 8, 7, 6],
                [10, 7, 6, 10, 1, 7, 1, 3, 7],
                [10, 7, 6, 1, 7, 10, 1, 8, 7, 1, 0, 8],
                [0, 3, 7, 0, 7, 10, 0, 10, 9, 6, 10, 7],
                [7, 6, 10, 7, 10, 8, 8, 10, 9],
                [6, 8, 4, 11, 8, 6],
                [3, 6, 11, 3, 0, 6, 0, 4, 6],
                [8, 6, 11, 8, 4, 6, 9, 0, 1],
                [9, 4, 6, 9, 6, 3, 9, 3, 1, 11, 3, 6],
                [6, 8, 4, 6, 11, 8, 2, 10, 1],
                [1, 2, 10, 3, 0, 11, 0, 6, 11, 0, 4, 6],
                [4, 11, 8, 4, 6, 11, 0, 2, 9, 2, 10, 9],
                [10, 9, 3, 10, 3, 2, 9, 4, 3, 11, 3, 6, 4, 6, 3],
                [8, 2, 3, 8, 4, 2, 4, 6, 2],
                [0, 4, 2, 4, 6, 2],
                [1, 9, 0, 2, 3, 4, 2, 4, 6, 4, 3, 8],
                [1, 9, 4, 1, 4, 2, 2, 4, 6],
                [8, 1, 3, 8, 6, 1, 8, 4, 6, 6, 10, 1],
                [10, 1, 0, 10, 0, 6, 6, 0, 4],
                [4, 6, 3, 4, 3, 8, 6, 10, 3, 0, 3, 9, 10, 9, 3],
                [10, 9, 4, 6, 10, 4],
                [4, 9, 5, 7, 6, 11],
                [0, 8, 3, 4, 9, 5, 11, 7, 6],
                [5, 0, 1, 5, 4, 0, 7, 6, 11],
                [11, 7, 6, 8, 3, 4, 3, 5, 4, 3, 1, 5],
                [9, 5, 4, 10, 1, 2, 7, 6, 11],
                [6, 11, 7, 1, 2, 10, 0, 8, 3, 4, 9, 5],
                [7, 6, 11, 5, 4, 10, 4, 2, 10, 4, 0, 2],
                [3, 4, 8, 3, 5, 4, 3, 2, 5, 10, 5, 2, 11, 7, 6],
                [7, 2, 3, 7, 6, 2, 5, 4, 9],
                [9, 5, 4, 0, 8, 6, 0, 6, 2, 6, 8, 7],
                [3, 6, 2, 3, 7, 6, 1, 5, 0, 5, 4, 0],
                [6, 2, 8, 6, 8, 7, 2, 1, 8, 4, 8, 5, 1, 5, 8],
                [9, 5, 4, 10, 1, 6, 1, 7, 6, 1, 3, 7],
                [1, 6, 10, 1, 7, 6, 1, 0, 7, 8, 7, 0, 9, 5, 4],
                [4, 0, 10, 4, 10, 5, 0, 3, 10, 6, 10, 7, 3, 7, 10],
                [7, 6, 10, 7, 10, 8, 5, 4, 10, 4, 8, 10],
                [6, 9, 5, 6, 11, 9, 11, 8, 9],
                [3, 6, 11, 0, 6, 3, 0, 5, 6, 0, 9, 5],
                [0, 11, 8, 0, 5, 11, 0, 1, 5, 5, 6, 11],
                [6, 11, 3, 6, 3, 5, 5, 3, 1],
                [1, 2, 10, 9, 5, 11, 9, 11, 8, 11, 5, 6],
                [0, 11, 3, 0, 6, 11, 0, 9, 6, 5, 6, 9, 1, 2, 10],
                [11, 8, 5, 11, 5, 6, 8, 0, 5, 10, 5, 2, 0, 2, 5],
                [6, 11, 3, 6, 3, 5, 2, 10, 3, 10, 5, 3],
                [5, 8, 9, 5, 2, 8, 5, 6, 2, 3, 8, 2],
                [9, 5, 6, 9, 6, 0, 0, 6, 2],
                [1, 5, 8, 1, 8, 0, 5, 6, 8, 3, 8, 2, 6, 2, 8],
                [1, 5, 6, 2, 1, 6],
                [1, 3, 6, 1, 6, 10, 3, 8, 6, 5, 6, 9, 8, 9, 6],
                [10, 1, 0, 10, 0, 6, 9, 5, 0, 5, 6, 0],
                [0, 3, 8, 5, 6, 10],
                [10, 5, 6],
                [11, 5, 10, 7, 5, 11],
                [5, 11, 7, 5, 10, 11, 1, 9, 0],
                [10, 7, 5, 10, 11, 7, 9, 8, 1, 8, 3, 1],
                [11, 1, 2, 11, 7, 1, 7, 5, 1],
                [0, 8, 3, 1, 2, 7, 1, 7, 5, 7, 2, 11],
                [9, 7, 5, 9, 2, 7, 9, 0, 2, 2, 11, 7],
                [7, 5, 2, 7, 2, 11, 5, 9, 2, 3, 2, 8, 9, 8, 2],
                [2, 5, 10, 2, 3, 5, 3, 7, 5],
                [8, 2, 0, 8, 5, 2, 8, 7, 5, 10, 2, 5],
                [9, 0, 1, 5, 10, 3, 5, 3, 7, 3, 10, 2],
                [9, 8, 2, 9, 2, 1, 8, 7, 2, 10, 2, 5, 7, 5, 2],
                [1, 3, 5, 3, 7, 5],
                [0, 8, 7, 0, 7, 1, 1, 7, 5],
                [9, 0, 3, 9, 3, 5, 5, 3, 7],
                [9, 8, 7, 5, 9, 7],
                [5, 8, 4, 5, 10, 8, 10, 11, 8],
                [5, 0, 4, 5, 11, 0, 5, 10, 11, 11, 3, 0],
                [0, 1, 9, 8, 4, 10, 8, 10, 11, 10, 4, 5],
                [10, 11, 4, 10, 4, 5, 11, 3, 4, 9, 4, 1, 3, 1, 4],
                [2, 5, 1, 2, 8, 5, 2, 11, 8, 4, 5, 8],
                [0, 4, 11, 0, 11, 3, 4, 5, 11, 2, 11, 1, 5, 1, 11],
                [0, 2, 5, 0, 5, 9, 2, 11, 5, 4, 5, 8, 11, 8, 5],
                [9, 4, 5, 2, 11, 3],
                [2, 5, 10, 3, 5, 2, 3, 4, 5, 3, 8, 4],
                [5, 10, 2, 5, 2, 4, 4, 2, 0],
                [3, 10, 2, 3, 5, 10, 3, 8, 5, 4, 5, 8, 0, 1, 9],
                [5, 10, 2, 5, 2, 4, 1, 9, 2, 9, 4, 2],
                [8, 4, 5, 8, 5, 3, 3, 5, 1],
                [0, 4, 5, 1, 0, 5],
                [8, 4, 5, 8, 5, 3, 9, 0, 5, 0, 3, 5],
                [9, 4, 5],
                [4, 11, 7, 4, 9, 11, 9, 10, 11],
                [0, 8, 3, 4, 9, 7, 9, 11, 7, 9, 10, 11],
                [1, 10, 11, 1, 11, 4, 1, 4, 0, 7, 4, 11],
                [3, 1, 4, 3, 4, 8, 1, 10, 4, 7, 4, 11, 10, 11, 4],
                [4, 11, 7, 9, 11, 4, 9, 2, 11, 9, 1, 2],
                [9, 7, 4, 9, 11, 7, 9, 1, 11, 2, 11, 1, 0, 8, 3],
                [11, 7, 4, 11, 4, 2, 2, 4, 0],
                [11, 7, 4, 11, 4, 2, 8, 3, 4, 3, 2, 4],
                [2, 9, 10, 2, 7, 9, 2, 3, 7, 7, 4, 9],
                [9, 10, 7, 9, 7, 4, 10, 2, 7, 8, 7, 0, 2, 0, 7],
                [3, 7, 10, 3, 10, 2, 7, 4, 10, 1, 10, 0, 4, 0, 10],
                [1, 10, 2, 8, 7, 4],
                [4, 9, 1, 4, 1, 7, 7, 1, 3],
                [4, 9, 1, 4, 1, 7, 0, 8, 1, 8, 7, 1],
                [4, 0, 3, 7, 4, 3],
                [4, 8, 7],
                [9, 10, 8, 10, 11, 8],
                [3, 0, 9, 3, 9, 11, 11, 9, 10],
                [0, 1, 10, 0, 10, 8, 8, 10, 11],
                [3, 1, 10, 11, 3, 10],
                [1, 2, 11, 1, 11, 9, 9, 11, 8],
                [3, 0, 9, 3, 9, 11, 1, 2, 9, 2, 11, 9],
                [0, 2, 11, 8, 0, 11],
                [3, 2, 11],
                [2, 3, 8, 2, 8, 10, 10, 8, 9],
                [9, 10, 2, 0, 9, 2],
                [2, 3, 8, 2, 8, 10, 0, 1, 8, 1, 10, 8],
                [1, 10, 2],
                [1, 3, 8, 9, 1, 8],
                [0, 9, 1],
                [0, 3, 8],
                []
            ]
    
    // Genera una mesh isosurface dal volume
    func generateMesh(from volume: Volume, isovalue: Float) -> Mesh {
        print("🔍 MarchingCubes: Inizio generazione mesh con isovalue=\(isovalue)")
        
        // OTTIMIZZAZIONE 1: Riduzione drastica della risoluzione del modello
        let downsampleFactor = 3  // Aumenta questo valore per ridurre ulteriormente la risoluzione
        
        // OTTIMIZZAZIONE 2: Limiti più severi
        let maxTriangles = 20000000 // Ridotto il limite di triangoli
        let maxProcessingTime: TimeInterval = 150.0 // Ridotto a 150 secondi
        let startTime = Date()
        var processedCubes = 0
        var triangleCount = 0
        
        var vertices: [Vertex] = []
        var triangles: [Triangle] = []
        var vertexMap: [String: UInt32] = [:]
        
        let width = volume.dimensions.x
        let height = volume.dimensions.y
        let depth = volume.dimensions.z
        
        print("📊 Dimensioni volume originale: \(width)x\(height)x\(depth)")
        print("📏 Spacing: \(volume.spacing.x)x\(volume.spacing.y)x\(volume.spacing.z)")
        print("🔍 Fattore di downsample: \(downsampleFactor)")

        
        // OTTIMIZZAZIONE 3: Analisi preliminare dei valori nel volume per determinare range
        var minValue: Float = Float.greatestFiniteMagnitude
        var maxValue: Float = -Float.greatestFiniteMagnitude
        let sampleRate = 20
        
        for z in stride(from: 0, to: depth, by: sampleRate) {
            for y in stride(from: 0, to: height, by: sampleRate) {
                for x in stride(from: 0, to: width, by: sampleRate) {
                    let value = getVoxelValue(volume, x, y, z)
                    if x < 10 && y < 10 && z < 10 {
                        print("Voxel[\(x), \(y), \(z)]: \(value)")
                    }

                    minValue = min(minValue, value)
                    maxValue = max(maxValue, value)
                }
            }
        }
        print("📊 Range dei valori nel volume: \(minValue) - \(maxValue)")
        if minValue == maxValue {
            print("⚠️ Attenzione: min e max sono uguali! min=\(minValue), max=\(maxValue)")
        }

        print("🎯 Isovalue usato: \(isovalue)")
        
        // OTTIMIZZAZIONE 4: Riduzione dell'area di analisi
        // Possiamo scegliere di elaborare solo la parte centrale del volume
        let regionOfInterest = false
        let padding = 5  // Margine da mantenere
        
        // Calcolo dei limiti dell'area di interesse
        let startX: Int
        let endX: Int
        let startY: Int
        let endY: Int
        let startZ: Int
        let endZ: Int
        
        if regionOfInterest {
            startX = max(width / 4 - padding, 0)
            endX = min(width * 3 / 4 + padding, width - downsampleFactor)
            startY = max(height / 4 - padding, 0)
            endY = min(height * 3 / 4 + padding, height - downsampleFactor)
            startZ = max(depth / 4 - padding, 0)
            endZ = min(depth * 3 / 4 + padding, depth - downsampleFactor)
        } else {
            startX = 0
            endX = width - downsampleFactor
            startY = 0
            endY = height - downsampleFactor
            startZ = 0
            endZ = depth - downsampleFactor
        }
        
        print("🔍 Area di analisi: [\(startX)-\(endX)] x [\(startY)-\(endY)] x [\(startZ)-\(endZ)]")
        
        // OTTIMIZZAZIONE 5: Calcolo parziale e semplificato delle normali
        print("⏱️ Inizio calcolo gradienti semplificato")
        let normals = calculateSimplifiedGradients(volume: volume, downsampleFactor: downsampleFactor)
        print("✅ Gradienti calcolati in \(Date().timeIntervalSince(startTime)) secondi")
        
        // OTTIMIZZAZIONE 6: Conteggio progressivo e aggiornamento frequente
        var lastUpdateTime = startTime
        let updateInterval: TimeInterval = 1.0 // Aggiorna ogni secondo
        
        // Itera attraverso il volume con il fattore di downsample
        for z in stride(from: startZ, to: endZ, by: downsampleFactor) {
            for y in stride(from: startY, to: endY, by: downsampleFactor) {
                for x in stride(from: startX, to: endX, by: downsampleFactor) {
                    // Verifica timeout più frequentemente
                    processedCubes += 1
                    if processedCubes % 100 == 0 {
                        let currentTime = Date()
                        if currentTime.timeIntervalSince(startTime) > maxProcessingTime {
                            print("⚠️ Timeout raggiunto dopo \(processedCubes) cubi e \(currentTime.timeIntervalSince(startTime)) secondi")
                            print("⚠️ Generati \(triangles.count) triangoli prima del timeout")
                            return Mesh(vertices: vertices, triangles: triangles)
                        }
                        
                        // Aggiorna il progresso ogni secondo
                        if currentTime.timeIntervalSince(lastUpdateTime) > updateInterval {
                            let elapsedTime = currentTime.timeIntervalSince(startTime)
                            
                            // Calcola il volume totale del cubo e la percentuale elaborata
                            let totalVolume = Double((endX - startX) * (endY - startY) * (endZ - startZ))
                            let processedVolume = Double(processedCubes * (downsampleFactor * downsampleFactor * downsampleFactor))
                            
                            // Evita divisione per zero
                            let progress = totalVolume > 0 ? min(100.0, processedVolume / totalVolume * 100.0) : 0
                            
                            print("⏱️ Progresso: \(Int(progress))%, \(triangles.count) triangoli, \(elapsedTime.rounded()) secondi trascorsi")
                            lastUpdateTime = currentTime
                        }
                    }
                    
                    // Verifica se x+downsampleFactor, y+downsampleFactor, z+downsampleFactor sono ancora nel volume
                    if x + downsampleFactor >= width || y + downsampleFactor >= height || z + downsampleFactor >= depth {
                        continue
                    }
                    
                    // Estrai gli 8 valori di densità ai vertici del cubo corrente
                    let cubeValues: [Float] = [
                        getVoxelValue(volume, x, y, z),
                        getVoxelValue(volume, x+downsampleFactor, y, z),
                        getVoxelValue(volume, x+downsampleFactor, y+downsampleFactor, z),
                        getVoxelValue(volume, x, y+downsampleFactor, z),
                        getVoxelValue(volume, x, y, z+downsampleFactor),
                        getVoxelValue(volume, x+downsampleFactor, y, z+downsampleFactor),
                        getVoxelValue(volume, x+downsampleFactor, y+downsampleFactor, z+downsampleFactor),
                        getVoxelValue(volume, x, y+downsampleFactor, z+downsampleFactor)
                    ]
                    
                    if x == 256 && y == 256 && z == 113 {
                        print("🔍 cubeValues al centro: \(cubeValues)")
                    }

                    
                    // OTTIMIZZAZIONE: Verifica rapida se il cubo può contenere l'isosuperficie
                    let minVal = cubeValues.min() ?? 0
                    let maxVal = cubeValues.max() ?? 0
                    
                    // Se tutti i valori sono sopra o sotto la soglia, salta questo cubo
                    if (minVal >= isovalue && maxVal >= isovalue) || (minVal < isovalue && maxVal < isovalue) {
                        continue
                    }
                    
                    // Determina quali vertici del cubo sono dentro l'isosuperficie
                    var cubeIndex = 0
                    for i in 0..<8 {
                        if cubeValues[i] < isovalue {
                            cubeIndex |= (1 << i)
                        }
                    }
                    
                    // Controlla se il cubo è completamente fuori o dentro l'isosuperficie
                    if edgeTable[cubeIndex] == 0 {
                        continue // Nessuna intersezione, passa al cubo successivo
                    }
                    
                    // Posizioni dei vertici del cubo corrente (spazio fisico)
                    // Qui dividiamo l'espressione che causava problemi al type-checker
                    let pos0 = SIMD3<Float>(Float(x) * volume.spacing.x, Float(y) * volume.spacing.y, Float(z) * volume.spacing.z)
                    let pos1 = SIMD3<Float>(Float(x+downsampleFactor) * volume.spacing.x, Float(y) * volume.spacing.y, Float(z) * volume.spacing.z)
                    let pos2 = SIMD3<Float>(Float(x+downsampleFactor) * volume.spacing.x, Float(y+downsampleFactor) * volume.spacing.y, Float(z) * volume.spacing.z)
                    let pos3 = SIMD3<Float>(Float(x) * volume.spacing.x, Float(y+downsampleFactor) * volume.spacing.y, Float(z) * volume.spacing.z)
                    let pos4 = SIMD3<Float>(Float(x) * volume.spacing.x, Float(y) * volume.spacing.y, Float(z+downsampleFactor) * volume.spacing.z)
                    let pos5 = SIMD3<Float>(Float(x+downsampleFactor) * volume.spacing.x, Float(y) * volume.spacing.y, Float(z+downsampleFactor) * volume.spacing.z)
                    let pos6 = SIMD3<Float>(Float(x+downsampleFactor) * volume.spacing.x, Float(y+downsampleFactor) * volume.spacing.y, Float(z+downsampleFactor) * volume.spacing.z)
                    let pos7 = SIMD3<Float>(Float(x) * volume.spacing.x, Float(y+downsampleFactor) * volume.spacing.y, Float(z+downsampleFactor) * volume.spacing.z)
                    
                    let cubePositions = [pos0, pos1, pos2, pos3, pos4, pos5, pos6, pos7]
                    
                    // Indici dei vertici per gli spigoli del cubo
                    let edgeVerts: [(Int, Int)] = [
                        (0, 1), (1, 2), (2, 3), (3, 0),
                        (4, 5), (5, 6), (6, 7), (7, 4),
                        (0, 4), (1, 5), (2, 6), (3, 7)
                    ]
                    
                    // Calcola i punti di intersezione lungo gli spigoli del cubo
                    var intersectionPoints: [SIMD3<Float>] = Array(repeating: SIMD3<Float>(0, 0, 0), count: 12)
                    var intersectionNormals: [SIMD3<Float>] = Array(repeating: SIMD3<Float>(0, 0, 0), count: 12)
                    
                    for i in 0..<12 {
                        if (edgeTable[cubeIndex] & (1 << i)) != 0 {
                            let v1 = edgeVerts[i].0
                            let v2 = edgeVerts[i].1
                            
                            // Interpola per trovare il punto di intersezione lungo lo spigolo
                            // Prevenzione di divisione per zero
                            let denominator = cubeValues[v2] - cubeValues[v1]
                            let t = denominator != 0 ? (isovalue - cubeValues[v1]) / denominator : 0.5
                            if t < 0.0 || t > 1.0 {
                                print("⚠️ Valore t fuori range: \(t), v1=\(v1), v2=\(v2), cubeValues=\(cubeValues[v1]), \(cubeValues[v2])")
                            }

                            
                            // Limita t tra 0 e 1 per evitare punti fuori dal cubo
                            let clampedT = max(0.0, min(1.0, t))
                            intersectionPoints[i] = mix(cubePositions[v1], cubePositions[v2], t: clampedT)
                            
                            // Ottimizzazione: semplificazione calcolo normali
                            // Usiamo i valori precalcolati dal buffer di normali
                            
                            // Definizione degli offset degli indici
                            let indexOffsets = [
                                (0, 0, 0), (1, 0, 0), (1, 1, 0), (0, 1, 0),
                                (0, 0, 1), (1, 0, 1), (1, 1, 1), (0, 1, 1)
                            ]
                            
                            // Estrazione delle normali per i vertici dello spigolo corrente
                            let normal1X = x + indexOffsets[v1].0 * downsampleFactor
                            let normal1Y = y + indexOffsets[v1].1 * downsampleFactor
                            let normal1Z = z + indexOffsets[v1].2 * downsampleFactor
                            
                            let normal2X = x + indexOffsets[v2].0 * downsampleFactor
                            let normal2Y = y + indexOffsets[v2].1 * downsampleFactor
                            let normal2Z = z + indexOffsets[v2].2 * downsampleFactor
                            
                            let normal1 = getNormalSimplified(normals, normal1X, normal1Y, normal1Z, width, height, depth, downsampleFactor)
                            let normal2 = getNormalSimplified(normals, normal2X, normal2Y, normal2Z, width, height, depth, downsampleFactor)
                            
                            // Usa la normale solo se è diversa da zero
                            if length(normal1) > 0.0001 || length(normal2) > 0.0001 {
                                intersectionNormals[i] = normalize(mix(normal1, normal2, t: clampedT))
                            } else {
                                // Normale di default se non riusciamo a calcolarla
                                intersectionNormals[i] = SIMD3<Float>(0, 0, 1)
                            }
                        }
                    }
                    
                    // Verifica più semplificata per l'indice del cubo
                    if cubeIndex >= 0 && cubeIndex < triTable.count {
                        // Crea i triangoli utilizzando la tabella
                        let triangleIndices = triTable[cubeIndex]
                        var i = 0
                        while i < triangleIndices.count {
                            if i + 2 >= triangleIndices.count {
                                break
                            }
                            
                            let a = triangleIndices[i]
                            let b = triangleIndices[i+1]
                            let c = triangleIndices[i+2]
                            
                            // Controlli di sicurezza sugli indici
                            if a < 0 || a >= 12 || b < 0 || b >= 12 || c < 0 || c >= 12 {
                                i += 3
                                continue
                            }
                            
                            // Riduzione della precisione per il vertice condiviso
                            let precision: Float = 10.0 // Ridotta da 100 a 10
                            
                            // Aggiungi i vertici e crea il triangolo
                            let v1 = addVertex(intersectionPoints[a], intersectionNormals[a], &vertices, &vertexMap, precision)
                            let v2 = addVertex(intersectionPoints[b], intersectionNormals[b], &vertices, &vertexMap, precision)
                            let v3 = addVertex(intersectionPoints[c], intersectionNormals[c], &vertices, &vertexMap, precision)
                            
                            triangles.append(Triangle(indices: (v1, v2, v3)))
                            
                            // Controllo del limite di triangoli
                            triangleCount += 1
                            if triangleCount > maxTriangles {
                                print("⚠️ Limite massimo di triangoli raggiunto (\(maxTriangles))")
                                return Mesh(vertices: vertices, triangles: triangles)
                            }
                            
                            i += 3
                        }
                    }
                }
            }
            
            // Feedback di avanzamento ogni certo numero di slice
            if z % (10 * downsampleFactor) == 0 {
                let progress = Int((Float(z - startZ) / Float(endZ - startZ)) * 100)
                let elapsedTime = Date().timeIntervalSince(startTime)
                print("📊 Slice \(z)/\(endZ): \(progress)% completato, \(triangles.count) triangoli, \(elapsedTime) secondi")
            }
        }
        
        // Se non abbiamo generato triangoli, crea una sfera di default
        if triangles.isEmpty {
            print("⚠️ Nessun triangolo generato con isovalue \(isovalue), creazione sfera di default")
            createSphereMesh(radius: 50, segments: 12, vertices: &vertices, triangles: &triangles)
        }
        
        let endTime = Date()
        let elapsedTime = endTime.timeIntervalSince(startTime)
        print("✅ Marching Cubes completato: \(vertices.count) vertici, \(triangles.count) triangoli in \(elapsedTime) secondi")
        if triangles.count < 1000 {
            print("⚠️ Pochi triangoli generati: \(triangles.count) → Mesh incompleta!")
        }

        print("📊 DEBUG: Vertici finali: \(vertices.count), Triangoli finali: \(triangles.count)")

        return Mesh(vertices: vertices, triangles: triangles)
    }
    

    // Funzione helper per estrarre il valore di un voxel
    private func getVoxelValue(_ volume: Volume, _ x: Int, _ y: Int, _ z: Int) -> Float {
        guard x >= 0 && x < volume.dimensions.x &&
              y >= 0 && y < volume.dimensions.y &&
              z >= 0 && z < volume.dimensions.z,
              let value = volume.voxelValue(at: SIMD3<Int>(x, y, z)) else {
            return 0.0
        }
        
        // Per TC, usa direttamente il valore Hounsfield se disponibile
        if volume.type == .ct {
            if let hounsfield = volume.hounsfieldValue(at: SIMD3<Int>(x, y, z)) {
                // Stampa di debug per i voxel centrali
                if x == 256 && y == 256 && z == 113 {
                    print("🔍 Voxel[\(x), \(y), \(z)]: \(hounsfield) HU (raw: \(value))")
                }
                return hounsfield
            }
            
            // Fallback se hounsfieldValue non è disponibile
            // Assicura che il valore sia nel range di UInt16 (0 - 65535)
            let clampedValue = UInt16(clamping: value)
            
            // Converti il valore da UInt16 a Int16 per gestire i voxel con segno (DICOM)
            let signedValue = Int16(bitPattern: clampedValue)
            
            // Applica la trasformazione usando RescaleSlope e RescaleIntercept dai metadati
            let rescaleSlope = Float(volume.rescaleSlope ?? 1.0)
            let rescaleIntercept = Float(volume.rescaleIntercept ?? -1024.0)
            
            let hounsfield = Float(signedValue) * rescaleSlope + rescaleIntercept
            
            // Stampa di debug per i voxel centrali
            if x == 256 && y == 256 && z == 113 {
                print("🔍 Voxel[\(x), \(y), \(z)]: \(hounsfield) HU (raw: \(value))")
            }
            
            return hounsfield
        } else {
            // Per MRI o altre modalità, restituisci il valore così com'è
            let clampedValue = UInt16(clamping: value)
            let signedValue = Float(Int16(bitPattern: clampedValue))
            
            // Stampa di debug per i voxel centrali
            if x == 256 && y == 256 && z == 113 {
                print("🔍 Voxel[\(x), \(y), \(z)]: \(signedValue) (raw: \(value))")
            }
            
            return signedValue
        }
    }

    
    
    // Funzione helper per aggiungere un vertice ed evitare duplicati
    private func addVertex(_ position: SIMD3<Float>, _ normal: SIMD3<Float>,
                          _ vertices: inout [Vertex], _ vertexMap: inout [String: UInt32], _ precision: Float = 100.0) -> UInt32 {
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
    
    // Calcolo dei gradienti semplificato e più veloce
    private func calculateSimplifiedGradients(volume: Volume, downsampleFactor: Int) -> [SIMD3<Float>] {
        let width = volume.dimensions.x
        let height = volume.dimensions.y
        let depth = volume.dimensions.z
        
        // Riduci il numero di normali da calcolare usando il fattore di downsample
        let sampledWidth = (width + downsampleFactor - 1) / downsampleFactor
        let sampledHeight = (height + downsampleFactor - 1) / downsampleFactor
        let sampledDepth = (depth + downsampleFactor - 1) / downsampleFactor
        
        print("📊 Dimensioni gradienti ridotte: \(sampledWidth)x\(sampledHeight)x\(sampledDepth)")
        
        var normals = [SIMD3<Float>](repeating: SIMD3<Float>(0, 0, 0),
                                     count: sampledWidth * sampledHeight * sampledDepth)
        
        // Utilizza un passo di campionamento ancora più grande per velocizzare ulteriormente
        let gradientStep = downsampleFactor * 2
        
        for z in stride(from: 0, to: depth, by: gradientStep) {
            for y in stride(from: 0, to: height, by: gradientStep) {
                for x in stride(from: 0, to: width, by: gradientStep) {
                    // Calcola il gradiente usando le differenze centrali con step più grandi
                    var gradient = SIMD3<Float>(0, 0, 0)
                    
                    // Calcola il gradiente in X
                    if x > gradientStep && x < width - gradientStep {
                        let leftValue = getVoxelValue(volume, x - gradientStep, y, z)
                        let rightValue = getVoxelValue(volume, x + gradientStep, y, z)
                        gradient.x = rightValue - leftValue
                    }
                    
                    // Calcola il gradiente in Y
                    if y > gradientStep && y < height - gradientStep {
                        let bottomValue = getVoxelValue(volume, x, y - gradientStep, z)
                        let topValue = getVoxelValue(volume, x, y + gradientStep, z)
                        gradient.y = topValue - bottomValue
                    }
                    
                    // Calcola il gradiente in Z
                    if z > gradientStep && z < depth - gradientStep {
                        let backValue = getVoxelValue(volume, x, y, z - gradientStep)
                        let frontValue = getVoxelValue(volume, x, y, z + gradientStep)
                        gradient.z = frontValue - backValue
                    }
                    
                    // Normalizza ed inverte il gradiente per avere normali che puntano verso l'esterno
                    if length(gradient) > 0.0001 {
                        gradient = normalize(gradient) * -1.0
                    }
                    
                    // Mappa le coordinate originali alle coordinate del buffer ridotto
                    let nx = x / downsampleFactor
                    let ny = y / downsampleFactor
                    let nz = z / downsampleFactor
                    
                    let index = nz * sampledWidth * sampledHeight + ny * sampledWidth + nx
                    if index < normals.count {
                        normals[index] = gradient
                    }
                }
            }
        }
        
        return normals
    }
    
    // Ottiene la normale precalcolata per la posizione specificata
    private func getNormalSimplified(_ normals: [SIMD3<Float>], _ x: Int, _ y: Int, _ z: Int,
                              _ width: Int, _ height: Int, _ depth: Int, _ downsampleFactor: Int) -> SIMD3<Float> {
        // Mappa le coordinate al buffer ridotto
        let sampledWidth = (width + downsampleFactor - 1) / downsampleFactor
        let sampledHeight = (height + downsampleFactor - 1) / downsampleFactor
        
        let nx = min(x / downsampleFactor, sampledWidth - 1)
        let ny = min(y / downsampleFactor, sampledHeight - 1)
        let nz = min(z / downsampleFactor, (depth / downsampleFactor) - 1)
        
        let index = nz * sampledWidth * sampledHeight + ny * sampledWidth + nx
        
        // Verifica dell'indice
        if index >= 0 && index < normals.count {
            return normals[index]
        }
        
        return SIMD3<Float>(0, 0, 1) // Normale predefinita
    }
    
    // Interpolazione lineare tra due vettori
    private func mix(_ a: SIMD3<Float>, _ b: SIMD3<Float>, t: Float) -> SIMD3<Float> {
        let clampedT = max(0.0, min(1.0, t))
        return a * (1 - clampedT) + b * clampedT
    }
    
    // Crea una mesh sferica semplificata (per fallback)
    private func createSphereMesh(radius: Float, segments: Int, vertices: inout [Vertex], triangles: inout [Triangle]) {
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
    

    func smoothMesh(_ mesh: Mesh, iterations: Int = 1, factor: Float = 0.5) -> Mesh {
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
