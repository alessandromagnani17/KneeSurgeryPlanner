import Foundation
import SceneKit

/// Struttura per memorizzare le linee disegnate sul modello 3D
public struct DrawingLine: Identifiable {
    public let id = UUID()
    public var nodes: [SCNNode]      // Nodi SceneKit che compongono la linea
    public var color: NSColor        // Colore della linea
    public var thickness: Float      // Spessore della linea
}
