import Foundation
import simd

/// Classe principale che implementa l'algoritmo Marching Cubes per la creazione di mesh
/// isosuperficiali da dati volumetrici, come immagini DICOM CT.
class MarchingCubes {
    
    /// Genera una mesh isosurface dal volume
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
                    let value = VolumeUtility.getVoxelValue(volume, x, y, z)
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
        let normals = VolumeUtility.calculateSimplifiedGradients(volume: volume, downsampleFactor: downsampleFactor)
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
                        VolumeUtility.getVoxelValue(volume, x, y, z),
                        VolumeUtility.getVoxelValue(volume, x+downsampleFactor, y, z),
                        VolumeUtility.getVoxelValue(volume, x+downsampleFactor, y+downsampleFactor, z),
                        VolumeUtility.getVoxelValue(volume, x, y+downsampleFactor, z),
                        VolumeUtility.getVoxelValue(volume, x, y, z+downsampleFactor),
                        VolumeUtility.getVoxelValue(volume, x+downsampleFactor, y, z+downsampleFactor),
                        VolumeUtility.getVoxelValue(volume, x+downsampleFactor, y+downsampleFactor, z+downsampleFactor),
                        VolumeUtility.getVoxelValue(volume, x, y+downsampleFactor, z+downsampleFactor)
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
                    if MarchingCubesTables.edgeTable[cubeIndex] == 0 {
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
                        if (MarchingCubesTables.edgeTable[cubeIndex] & (1 << i)) != 0 {
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
                            intersectionPoints[i] = MeshUtility.mix(cubePositions[v1], cubePositions[v2], t: clampedT)
                            
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
                            
                            let normal1 = VolumeUtility.getNormalSimplified(normals, normal1X, normal1Y, normal1Z, width, height, depth, downsampleFactor)
                            let normal2 = VolumeUtility.getNormalSimplified(normals, normal2X, normal2Y, normal2Z, width, height, depth, downsampleFactor)
                            
                            // Usa la normale solo se è diversa da zero
                            if length(normal1) > 0.0001 || length(normal2) > 0.0001 {
                                intersectionNormals[i] = normalize(MeshUtility.mix(normal1, normal2, t: clampedT))
                            } else {
                                // Normale di default se non riusciamo a calcolarla
                                intersectionNormals[i] = SIMD3<Float>(0, 0, 1)
                            }
                        }
                    }
                    
                    // Verifica più semplificata per l'indice del cubo
                    if cubeIndex >= 0 && cubeIndex < MarchingCubesTables.triTable.count {
                        // Crea i triangoli utilizzando la tabella
                        let triangleIndices = MarchingCubesTables.triTable[cubeIndex]
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
                            let v1 = MeshUtility.addVertex(intersectionPoints[a], intersectionNormals[a], &vertices, &vertexMap, precision)
                            let v2 = MeshUtility.addVertex(intersectionPoints[b], intersectionNormals[b], &vertices, &vertexMap, precision)
                            let v3 = MeshUtility.addVertex(intersectionPoints[c], intersectionNormals[c], &vertices, &vertexMap, precision)
                            
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
            MeshUtility.createSphereMesh(radius: 50, segments: 12, vertices: &vertices, triangles: &triangles)
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
    
    /// Applica smoothing alla mesh generata
    func smoothMesh(_ mesh: Mesh, iterations: Int = 1, factor: Float = 0.5) -> Mesh {
        return MeshUtility.smoothMesh(mesh, iterations: iterations, factor: factor)
    }
}
