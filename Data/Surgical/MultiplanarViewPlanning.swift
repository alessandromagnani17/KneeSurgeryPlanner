import SwiftUI
import simd

/// Estensione di MultiplanarView per supportare la visualizzazione dei piani chirurgici
extension MultiplanarView {
    
    /// Vista per visualizzare le intersezioni dei piani chirurgici
    @ViewBuilder
    func planeIntersectionsView(orientation: MPROrientation, sliceIndex: Int, volume: Volume,
                               planningManager: SurgicalPlanningManager) -> some View {
        GeometryReader { geometry in
            ZStack {
                // Contenuto base
                Color.clear
                
                // Disegna le linee di intersezione per ogni piano
                ForEach(planningManager.planes) { plane in
                    if plane.isVisible, let intersection = calculatePlaneIntersection(
                        with: plane, orientation: orientation, sliceIndex: sliceIndex, volume: volume) {
                        PlaneIntersectionLineView(
                            start: intersection.start,
                            end: intersection.end,
                            color: Color(plane.color),
                            isSelected: planningManager.selectedPlaneId == plane.id,
                            width: plane.id == planningManager.selectedPlaneId ? 3.0 : 2.0
                        )
                    }
                }
            }
        }
    }
    
    /// Calcola l'intersezione tra un piano chirurgico e un piano MPR
    func calculatePlaneIntersection(with surgicalPlane: SurgicalPlane, orientation: MPROrientation,
                                   sliceIndex: Int, volume: Volume) -> (start: CGPoint, end: CGPoint)? {
        // Converti posizione e normale del piano chirurgico in coordinate SIMD
        let planePosition = simd_float3(
            Float(surgicalPlane.position.x),
            Float(surgicalPlane.position.y),
            Float(surgicalPlane.position.z)
        )
        
        let planeNormal = simd_float3(
            Float(surgicalPlane.normal.x),
            Float(surgicalPlane.normal.y),
            Float(surgicalPlane.normal.z)
        )
        
        // Normalizza la normale del piano
        let normalLength = sqrt(planeNormal.x * planeNormal.x + planeNormal.y * planeNormal.y + planeNormal.z * planeNormal.z)
        let normalizedPlaneNormal = normalLength > 0 ? planeNormal / normalLength : simd_float3(0, 0, 1)
        
        // Determina il piano MPR corrente
        let slicePos: Float
        let sliceNormal: simd_float3
        var viewDimension: (width: Int, height: Int) = (0, 0)
        
        switch orientation {
        case .axial:
            slicePos = Float(sliceIndex) * volume.spacing.z
            sliceNormal = simd_float3(0, 0, 1)
            viewDimension = (width: volume.dimensions.x, height: volume.dimensions.y)
            
        case .coronal:
            slicePos = Float(sliceIndex) * volume.spacing.y
            sliceNormal = simd_float3(0, 1, 0)
            viewDimension = (width: volume.dimensions.x, height: volume.dimensions.z)
            
        case .sagittal:
            slicePos = Float(sliceIndex) * volume.spacing.x
            sliceNormal = simd_float3(1, 0, 0)
            viewDimension = (width: volume.dimensions.y, height: volume.dimensions.z)
        }
        
        // Calcola il prodotto scalare tra le normali
        let dotProduct = dot(normalizedPlaneNormal, sliceNormal)
        
        // Se i piani sono quasi paralleli, non c'è intersezione
        if abs(dotProduct) > 0.999 {
            return nil
        }
        
        // Calcola l'intersezione tra i due piani
        // L'equazione di un piano è: dot(normal, point - position) = 0
        
        // Calcola il punto di intersezione tra il piano chirurgico e una linea nella direzione della normale MPR
        // dalla posizione del piano MPR
        let mprPlanePosition: simd_float3
        
        switch orientation {
        case .axial:
            mprPlanePosition = simd_float3(0, 0, slicePos)
        case .coronal:
            mprPlanePosition = simd_float3(0, slicePos, 0)
        case .sagittal:
            mprPlanePosition = simd_float3(slicePos, 0, 0)
        }
        
        // Calcola la distanza dal punto MPR al piano chirurgico
        let d = dot(normalizedPlaneNormal, planePosition - mprPlanePosition)
        
        // Calcola la direzione dell'intersezione (prodotto vettoriale delle normali)
        let intersectionDirection = cross(normalizedPlaneNormal, sliceNormal)
        let directionLength = sqrt(intersectionDirection.x * intersectionDirection.x +
                                intersectionDirection.y * intersectionDirection.y +
                                intersectionDirection.z * intersectionDirection.z)
        let lineDirection = directionLength > 0 ? intersectionDirection / directionLength : simd_float3(1, 0, 0)
        
        // Calcola un punto sulla linea di intersezione
        let intersectionPoint = mprPlanePosition + normalizedPlaneNormal * d
        
        // Estendi la linea in entrambe le direzioni
        let lineLength: Float = 1000.0  // Lunghezza sufficiente per attraversare la vista
        let lineStart = intersectionPoint - lineDirection * lineLength
        let lineEnd = intersectionPoint + lineDirection * lineLength
        
        // Converti in coordinate della vista
        var startPoint: CGPoint
        var endPoint: CGPoint
        
        switch orientation {
        case .axial:
            startPoint = CGPoint(x: CGFloat(lineStart.x), y: CGFloat(lineStart.y))
            endPoint = CGPoint(x: CGFloat(lineEnd.x), y: CGFloat(lineEnd.y))
            
        case .coronal:
            startPoint = CGPoint(x: CGFloat(lineStart.x), y: CGFloat(lineStart.z))
            endPoint = CGPoint(x: CGFloat(lineEnd.x), y: CGFloat(lineEnd.z))
            
        case .sagittal:
            startPoint = CGPoint(x: CGFloat(lineStart.y), y: CGFloat(lineStart.z))
            endPoint = CGPoint(x: CGFloat(lineEnd.y), y: CGFloat(lineEnd.z))
        }
        
        // Normalizza le coordinate in base alle dimensioni della vista
        let widthScale = CGFloat(viewDimension.width)
        let heightScale = CGFloat(viewDimension.height)
        
        startPoint = CGPoint(x: startPoint.x / widthScale, y: startPoint.y / heightScale)
        endPoint = CGPoint(x: endPoint.x / widthScale, y: endPoint.y / heightScale)
        
        return (startPoint, endPoint)
    }
}

/// Vista per rappresentare una linea di intersezione
/// Vista per rappresentare una linea di intersezione
struct PlaneIntersectionLineView: View {
    let start: CGPoint
    let end: CGPoint
    let color: Color
    let isSelected: Bool
    let width: CGFloat
    
    var body: some View {
        GeometryReader { geometry in
            Path { path in
                // Calcola i punti in coordinate assolute
                let startX = start.x * geometry.size.width
                let startY = start.y * geometry.size.height
                let endX = end.x * geometry.size.width
                let endY = end.y * geometry.size.height
                
                // Taglia la linea ai bordi della vista
                let (clippedStartX, clippedStartY, clippedEndX, clippedEndY) = clipLineToRect(
                    startX: startX, startY: startY, endX: endX, endY: endY,
                    minX: 0, minY: 0, maxX: geometry.size.width, maxY: geometry.size.height
                )
                
                // Disegna la linea tagliata
                path.move(to: CGPoint(x: clippedStartX, y: clippedStartY))
                path.addLine(to: CGPoint(x: clippedEndX, y: clippedEndY))
            }
            .stroke(style: StrokeStyle(
                lineWidth: width,
                lineCap: .round,
                lineJoin: .round,
                dash: isSelected ? [5, 3] : []
            ))
            .foregroundColor(color)
        }
    }
    
    // Funzione per tagliare una linea ai bordi di un rettangolo
    private func clipLineToRect(
        startX: CGFloat, startY: CGFloat, endX: CGFloat, endY: CGFloat,
        minX: CGFloat, minY: CGFloat, maxX: CGFloat, maxY: CGFloat
    ) -> (CGFloat, CGFloat, CGFloat, CGFloat) {
        // Implementazione dell'algoritmo di Cohen-Sutherland per il clipping delle linee
        
        // Definizione dei codici di regione
        let INSIDE = 0 // 0000
        let LEFT = 1   // 0001
        let RIGHT = 2  // 0010
        let BOTTOM = 4 // 0100
        let TOP = 8    // 1000
        
        // Calcola il codice di regione per un punto
        func computeCode(x: CGFloat, y: CGFloat) -> Int {
            var code = INSIDE
            
            if x < minX {
                code |= LEFT
            } else if x > maxX {
                code |= RIGHT
            }
            
            if y < minY {
                code |= BOTTOM
            } else if y > maxY {
                code |= TOP
            }
            
            return code
        }
        
        // Calcola i codici di regione per i punti di inizio e fine
        var code1 = computeCode(x: startX, y: startY)
        var code2 = computeCode(x: endX, y: endY)
        
        // Punti da restituire
        var x1 = startX
        var y1 = startY
        var x2 = endX
        var y2 = endY
        
        var accept = false
        
        while true {
            if (code1 | code2) == 0 {
                // La linea è completamente all'interno
                accept = true
                break
            } else if (code1 & code2) != 0 {
                // La linea è completamente all'esterno
                break
            } else {
                // La linea attraversa il bordo
                
                var x = 0.0 as CGFloat
                var y = 0.0 as CGFloat
                
                // Scegli un punto esterno
                let codeOut = (code1 != 0) ? code1 : code2
                
                // Trova l'intersezione
                if (codeOut & TOP) != 0 {
                    // Intersezione con il bordo superiore
                    x = x1 + (x2 - x1) * (maxY - y1) / (y2 - y1)
                    y = maxY
                } else if (codeOut & BOTTOM) != 0 {
                    // Intersezione con il bordo inferiore
                    x = x1 + (x2 - x1) * (minY - y1) / (y2 - y1)
                    y = minY
                } else if (codeOut & RIGHT) != 0 {
                    // Intersezione con il bordo destro
                    y = y1 + (y2 - y1) * (maxX - x1) / (x2 - x1)
                    x = maxX
                } else if (codeOut & LEFT) != 0 {
                    // Intersezione con il bordo sinistro
                    y = y1 + (y2 - y1) * (minX - x1) / (x2 - x1)
                    x = minX
                }
                
                // Sostituisci il punto esterno con il punto di intersezione
                if codeOut == code1 {
                    x1 = x
                    y1 = y
                    code1 = computeCode(x: x, y: y)
                } else {
                    x2 = x
                    y2 = y
                    code2 = computeCode(x: x, y: y)
                }
            }
        }
        
        if accept {
            return (x1, y1, x2, y2)
        } else {
            // Se la linea è completamente all'esterno, restituisci punti fuori dal campo visivo
            return (minX - 10, minY - 10, minX - 10, minY - 10)
        }
    }
}
