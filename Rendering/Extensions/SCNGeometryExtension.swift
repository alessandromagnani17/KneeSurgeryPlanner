import SceneKit

/// Estensione per creare geometria SceneKit da una mesh Marching Cubes
extension SCNGeometry {
    convenience init(mesh: Mesh) {
        // Prepara array per vertici e normali
        var vertices: [SCNVector3] = []
        var normals: [SCNVector3] = []
        
        // Converte ogni vertice della mesh nel formato SceneKit
        for vertex in mesh.vertices {
            vertices.append(SCNVector3(vertex.position.x, vertex.position.y, vertex.position.z))
            
            // Normalizza le normali
            let normal = vertex.normal
            let length = sqrt(normal.x * normal.x + normal.y * normal.y + normal.z * normal.z)
            if length > 0 {
                normals.append(SCNVector3(normal.x / length, normal.y / length, normal.z / length))
            } else {
                normals.append(SCNVector3(0, 1, 0))
            }
        }
        
        // Crea array di indici per i triangoli
        var indices: [Int32] = []
        
        for triangle in mesh.triangles {
            indices.append(Int32(triangle.indices.0))
            indices.append(Int32(triangle.indices.1))
            indices.append(Int32(triangle.indices.2))
        }
        
        // Crea le sorgenti di dati per SceneKit
        let vertexSource = SCNGeometrySource(vertices: vertices)
        let normalSource = SCNGeometrySource(normals: normals)
        
        // Crea l'elemento geometrico triangolare
        let element = SCNGeometryElement(indices: indices, primitiveType: .triangles)
        
        // Inizializza la geometria
        self.init(sources: [vertexSource, normalSource], elements: [element])
        
        // Applica materiale standard
        let material = SCNMaterial()
        material.diffuse.contents = NSColor(calibratedRed: 0.85, green: 0.85, blue: 0.85, alpha: 1.0)
        material.specular.contents = NSColor.white
        material.shininess = 0.3
        material.lightingModel = .blinn
        material.fillMode = .fill
        material.isDoubleSided = false
        material.cullMode = .back
        material.reflective.contents = NSColor(white: 0.15, alpha: 1.0)
        material.ambient.contents = NSColor(white: 0.4, alpha: 1.0)

        self.materials = [material]
    }
    
    /// Crea un materiale standard per il modello 3D
    private static func createDefaultMaterial() -> SCNMaterial {
        let material = SCNMaterial()
        
        // Impostazioni base
        material.diffuse.contents = NSColor(calibratedRed: 0.85, green: 0.85, blue: 0.85, alpha: 1.0)
        material.specular.contents = NSColor.white
        material.shininess = 0.3
        material.lightingModel = .blinn
        material.fillMode = .fill
        material.isDoubleSided = false
        material.cullMode = .back
        
        // Effetti avanzati
        material.reflective.contents = NSColor(white: 0.15, alpha: 1.0)
        material.ambient.contents = NSColor(white: 0.4, alpha: 1.0)
        
        return material
    }
}
