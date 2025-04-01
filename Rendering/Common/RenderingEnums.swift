import Foundation

/// Modalità di interazione con il disegno 3D
public enum DrawingMode {
    case draw   // Modalità disegno attiva
    case erase  // Modalità cancellazione attiva
    case none   // Interazione normale con il modello
}

/// Tipo di linea da disegnare
public enum LineStyle {
    case freehand     // Disegno a mano libera
    case straight     // Linea retta
}

/// Modalità di rendering del modello 3D
public enum RenderingMode {
    case solid              // Rendering solido standard
    case wireframe          // Solo wireframe
    case solidWithWireframe // Solido con overlay wireframe
}
