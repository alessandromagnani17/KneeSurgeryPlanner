import Foundation
import simd

// Classe principale che implementa l'algoritmo Marching Cubes per la creazione di mesh da volumi
class MarchingCubes {
    
    /*
     Genera una mesh dal volume
        - Parameters:
            - volume: I dati volumetrici di input (es. scansione CT)
            - isovalue: Il valore soglia che determina cosa è "dentro" e cosa è "fuori" la superficie
            - Returns: Una mesh 3D composta da vertici e triangoli
     */
    func generateMesh(from volume: Volume, isovalue: Float) -> Mesh {
        print("MarchingCubes: Inizio generazione mesh con isovalue=\(isovalue)")
        
        // OTTIMIZZAZIONE 1: Riduzione drastica della risoluzione del modello
        // Un valore più alto significa meno dettagli ma elaborazione più veloce
        let downsampleFactor = 3
        
        // Parametro di distanza massima per eliminare le linee che si proiettano
        //let maxEdgeLength: Float = 10.0 * volume.spacing.x
        
        // Aumenta la precisione per la fusione dei vertici (aiuta a creare una mesh più pulita)
        let precision: Float = 100.0  // Aumentato da 10.0
        
        // OTTIMIZZAZIONE 2: Limiti più severi per evitare sovraccarichi
        let maxTriangles = 20000000                     // Limite massimo di triangoli generabili
        let maxProcessingTime: TimeInterval = 5000.0     // Tempo massimo di elaborazione (in secondi)
        let startTime = Date()                          // Memorizza l'orario di inizio per monitorare il tempo di esecuzione
        var processedCubes = 0                          // Contatore dei cubi elaborati
        var triangleCount = 0                           // Contatore dei triangoli creati
        
        // Strutture dati per la costruzione della mesh
        var vertices: [Vertex] = []                     // Array per memorizzare i vertici unici
        var triangles: [Triangle] = []                  // Array per memorizzare i triangoli
        var vertexMap: [String: UInt32] = [:]           // Mappa per evitare duplicazione dei vertici
        
        // Estrazione delle dimensioni del volume
        let width = volume.dimensions.x
        let height = volume.dimensions.y
        let depth = volume.dimensions.z
        
        print("Dimensioni volume originale: \(width)x\(height)x\(depth)")
        print("Spacing: \(volume.spacing.x)x\(volume.spacing.y)x\(volume.spacing.z)")
        print("Fattore di downsample: \(downsampleFactor)")
        
        // Filtro per i dati prima del Marching Cubes
        // Applica una soglia dura per eliminare il rumore a bassa densità
        //let filteredVolume = volume.applyThresholdFilter(minValue: isovalue * 0.05)
        let filteredVolume = volume
        
        // OTTIMIZZAZIONE 3: Analisi preliminare dei valori nel volume per determinare range
        // Questo ci dà un'idea della distribuzione dei valori nel volume
        let (minValue, maxValue) = filteredVolume.calculateMinMaxValues()
        print("Range dei valori nel volume filtrato: \(minValue) - \(maxValue)")
        
        if minValue == maxValue {
            // Avviso in caso di volume omogeneo (problema potenziale)
            print("⚠️ Attenzione: min e max sono uguali! min=\(minValue), max=\(maxValue)")
        }
        
        // OTTIMIZZAZIONE 4: Riduzione dell'area di analisi
        // Possiamo scegliere di elaborare solo la parte centrale del volume per risparmiare tempo
        let regionOfInterest = true                    // Se true, elabora solo la parte centrale
        let padding = 50                               // Margine da mantenere attorno alla regione di interesse
        
        // Calcolo dei limiti dell'area di interesse
        let startX: Int
        let endX: Int
        let startY: Int
        let endY: Int
        let startZ: Int
        let endZ: Int
        
        if regionOfInterest {
            // Se regionOfInterest è attiva, elaboriamo solo la parte centrale
            startX = max(width / 4 - padding, 0)
            endX = min(width * 3 / 4 + padding, width - downsampleFactor)
            startY = max(height / 4 - padding, 0)
            endY = min(height * 3 / 4 + padding, height - downsampleFactor)
            startZ = max(depth / 4 - padding, 0)
            endZ = min(depth * 3 / 4 + padding, depth - downsampleFactor)
        } else {
            // Altrimenti elaboriamo tutto il volume
            startX = 0
            endX = width - downsampleFactor
            startY = 0
            endY = height - downsampleFactor
            startZ = 0
            endZ = depth - downsampleFactor
        }
        
        print("Area di analisi: [\(startX)-\(endX)] x [\(startY)-\(endY)] x [\(startZ)-\(endZ)]")
        
        // OTTIMIZZAZIONE 5: Calcolo parziale e semplificato delle normali
        /*
         Le normali sono vettori perpendicolari alla superficie, necessari per l'illuminazione
         Per mostrare il modello con luci e ombre realistiche, bisogna sapere in quale direzione "guarda"
         ogni parte della superficie. Le normali forniscono questa informazione cruciale.
         */
        let normals = VolumeUtility.calculatePreciseGradients(volume: filteredVolume, downsampleFactor: downsampleFactor)
        print("✅ Gradienti calcolati in \(Date().timeIntervalSince(startTime)) secondi")
        
        // Calcolo del centro del volume per controllo della distanza
        let center = SIMD3<Float>(
            Float(width/2) * volume.spacing.x,
            Float(height/2) * volume.spacing.y,
            Float(depth/2) * volume.spacing.z
        )
        
        // Calcolo della dimensione del bounding box per controllo outlier
        let boundingBox: Float = Float(max(width, max(height, depth))) * volume.spacing.x
        
        // OTTIMIZZAZIONE 6: Conteggio progressivo e aggiornamento frequente
        // Per monitorare l'avanzamento durante l'elaborazione
        var lastUpdateTime = startTime
        let updateInterval: TimeInterval = 1.0 // Aggiorna ogni secondo
        
        // Valore buffer per evitare valori ambigui vicino alla soglia
        let bufferValue: Float = 1.0
        
        // Itera attraverso il volume con il fattore di downsample
        for z in stride(from: startZ, to: endZ, by: downsampleFactor) {
            for y in stride(from: startY, to: endY, by: downsampleFactor) {
                for x in stride(from: startX, to: endX, by: downsampleFactor) {
                    // Verifica timeout più frequentemente
                    processedCubes += 1
                    if processedCubes % 100 == 0 {
                        // Ogni 100 cubi, verifichiamo se abbiamo superato il timeout
                        let currentTime = Date()
                        if currentTime.timeIntervalSince(startTime) > maxProcessingTime {
                            // Se abbiamo superato il tempo massimo, interrompiamo e restituiamo la mesh parziale
                            print("⚠️ Timeout raggiunto dopo \(processedCubes) cubi e \(currentTime.timeIntervalSince(startTime)) secondi")
                            print("⚠️ Generati \(triangles.count) triangoli prima del timeout")
                            
                            // Applica smoothing alla mesh parziale
                            let smoothedMesh = smoothMesh(Mesh(vertices: vertices, triangles: triangles), iterations: 2, factor: 0.3)
                            
                            // Rimuovi componenti disconnessi
                            let cleanedMesh = MeshUtility.removeDisconnectedComponents(mesh: smoothedMesh, minComponentSize: 100)
                            
                            return cleanedMesh
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
                    // Evita di accedere a indici fuori dai limiti del volume
                    if x + downsampleFactor >= width || y + downsampleFactor >= height || z + downsampleFactor >= depth {
                        continue
                    }
                    
                    // Estrai gli 8 valori di densità ai vertici del cubo corrente
                    // Questi 8 valori formano un cubo nel volume e sono i punti che l'algoritmo analizza
                    let cubeValues: [Float] = [
                        VolumeUtility.getVoxelValue(filteredVolume, x, y, z),                                                    // 0: Vertice in basso a sinistra davanti
                        VolumeUtility.getVoxelValue(filteredVolume, x+downsampleFactor, y, z),                                   // 1: Vertice in basso a destra davanti
                        VolumeUtility.getVoxelValue(filteredVolume, x+downsampleFactor, y+downsampleFactor, z),                  // 2: Vertice in alto a destra davanti
                        VolumeUtility.getVoxelValue(filteredVolume, x, y+downsampleFactor, z),                                   // 3: Vertice in alto a sinistra davanti
                        VolumeUtility.getVoxelValue(filteredVolume, x, y, z+downsampleFactor),                                   // 4: Vertice in basso a sinistra dietro
                        VolumeUtility.getVoxelValue(filteredVolume, x+downsampleFactor, y, z+downsampleFactor),                  // 5: Vertice in basso a destra dietro
                        VolumeUtility.getVoxelValue(filteredVolume, x+downsampleFactor, y+downsampleFactor, z+downsampleFactor), // 6: Vertice in alto a destra dietro
                        VolumeUtility.getVoxelValue(filteredVolume, x, y+downsampleFactor, z+downsampleFactor)                   // 7: Vertice in alto a sinistra dietro
                    ]
                    
                    
                    // OTTIMIZZAZIONE: Verifica rapida se il cubo può contenere l'isosuperficie
                    // Se tutti i valori sono sopra o sotto la soglia, il cubo non contiene l'isosuperficie
                    let minVal = cubeValues.min() ?? 0
                    let maxVal = cubeValues.max() ?? 0
                    
                    // Se tutti i valori sono sopra o sotto la soglia, salta questo cubo
                    if (minVal >= isovalue && maxVal >= isovalue) || (minVal < isovalue && maxVal < isovalue) {
                        continue
                    }
                    
                    // Determina quali vertici del cubo sono dentro l'isosuperficie
                    // Creiamo un indice binario dove ogni bit rappresenta un vertice (dentro = 1, fuori = 0)
                    var cubeIndex = 0
                    for i in 0..<8 {
                        // Usa una soglia con zona di sicurezza
                        if cubeValues[i] > (isovalue + bufferValue) && cubeValues[i] < 3000 {
                            cubeIndex |= (1 << i) // Imposta il bit i-esimo a 1
                        }
                    }
                    
                    // Controlla se il cubo è completamente fuori o dentro l'isosuperficie
                    // La edgeTable contiene informazioni sugli spigoli che intersecano l'isosuperficie
                    if MarchingCubesTables.edgeTable[cubeIndex] == 0 {
                        continue // Nessuna intersezione, passa al cubo successivo
                    }
                    
                    // Posizioni dei vertici del cubo corrente (spazio fisico)
                    // Convertiamo da indici di volume a coordinate reali usando lo spacing
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
                    // Definisce quali vertici formano ciascuno dei 12 spigoli del cubo
                    let edgeVerts: [(Int, Int)] = [
                        (0, 1), (1, 2), (2, 3), (3, 0),  // Spigoli faccia frontale (0-3)
                        (4, 5), (5, 6), (6, 7), (7, 4),  // Spigoli faccia posteriore (4-7)
                        (0, 4), (1, 5), (2, 6), (3, 7)   // Spigoli che collegano fronte e retro (8-11)
                    ]
                    
                    // Calcola i punti di intersezione lungo gli spigoli del cubo
                    // Per ciascuno dei 12 spigoli, calcoliamo dove l'isosuperficie lo interseca
                    var intersectionPoints: [SIMD3<Float>] = Array(repeating: SIMD3<Float>(0, 0, 0), count: 12)
                    var intersectionNormals: [SIMD3<Float>] = Array(repeating: SIMD3<Float>(0, 0, 0), count: 12)
                    
                    // Per ogni spigolo che la edgeTable dice intersecato...
                    for i in 0..<12 {
                        if (MarchingCubesTables.edgeTable[cubeIndex] & (1 << i)) != 0 {
                            // Questo spigolo interseca l'isosuperficie
                            let v1 = edgeVerts[i].0 // Primo vertice dello spigolo
                            let v2 = edgeVerts[i].1 // Secondo vertice dello spigolo
                            
                            // Interpola per trovare il punto di intersezione lungo lo spigolo
                            // Prevenzione di divisione per zero
                            let denominator = cubeValues[v2] - cubeValues[v1]
                            let t = denominator != 0 ? (isovalue - cubeValues[v1]) / denominator : 0.5
                            if t < 0.0 || t > 1.0 {
                                // Avviso per valori anomali (debug)
                                //print("⚠️ Valore t fuori range: \(t), v1=\(v1), v2=\(v2), cubeValues=\(cubeValues[v1]), \(cubeValues[v2])")
                            }
                            
                            // Limita t tra 0 e 1 per evitare punti fuori dal cubo
                            let clampedT = max(0.0, min(1.0, t))
                            // Interpolazione lineare tra le posizioni dei due vertici
                            let point = MeshUtility.mix(cubePositions[v1], cubePositions[v2], t: clampedT)
                            
                            // Controlla se il punto è troppo distante dal centro
                            let distFromCenter = distance(point, center)
                            if distFromCenter > boundingBox * 0.7 {
                                // Salta questo punto se è troppo lontano dal centro
                                continue
                            }
                            
                            // Assegna il punto calcolato
                            intersectionPoints[i] = point
                            
                            // Ottimizzazione: semplificazione calcolo normali
                            // Usiamo i valori precalcolati dal buffer di normali
                            
                            // Definizione degli offset degli indici
                            // Mappa i vertici del cubo agli indici nella griglia
                            let indexOffsets = [
                                (0, 0, 0), (1, 0, 0), (1, 1, 0), (0, 1, 0),
                                (0, 0, 1), (1, 0, 1), (1, 1, 1), (0, 1, 1)
                            ]
                            
                            // Estrazione delle normali per i vertici dello spigolo corrente
                            // Calcoliamo gli indici nei buffer delle normali
                            let normal1X = x + indexOffsets[v1].0 * downsampleFactor
                            let normal1Y = y + indexOffsets[v1].1 * downsampleFactor
                            let normal1Z = z + indexOffsets[v1].2 * downsampleFactor
                            
                            let normal2X = x + indexOffsets[v2].0 * downsampleFactor
                            let normal2Y = y + indexOffsets[v2].1 * downsampleFactor
                            let normal2Z = z + indexOffsets[v2].2 * downsampleFactor
                            
                            // Otteniamo le normali dai buffer precalcolati
                            let normal1 = VolumeUtility.getNormalPrecise(normals, normal1X, normal1Y, normal1Z, width, height, depth, downsampleFactor, filteredVolume)
                            let normal2 = VolumeUtility.getNormalPrecise(normals, normal2X, normal2Y, normal2Z, width, height, depth, downsampleFactor, filteredVolume)
                            
                            // Usa la normale solo se è diversa da zero
                            if length(normal1) > 0.0001 || length(normal2) > 0.0001 {
                                // Interpoliamo le normali e normalizzazione (vettore unitario)
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
                        // La triTable dice quali spigoli formano triangoli per questa configurazione di cubo
                        let triangleIndices = MarchingCubesTables.triTable[cubeIndex]
                        var i = 0
                        // Iteriamo per tripli (ogni triangolo è formato da 3 vertici)
                        while i < triangleIndices.count {
                            if i + 2 >= triangleIndices.count {
                                break
                            }
                            
                            // Otteniamo gli indici dei 3 spigoli che formano il triangolo
                            let a = triangleIndices[i]
                            let b = triangleIndices[i+1]
                            let c = triangleIndices[i+2]
                            
                            // Controlli di sicurezza sugli indici
                            if a < 0 || a >= 12 || b < 0 || b >= 12 || c < 0 || c >= 12 {
                                i += 3
                                continue
                            }
                            
                            // Verifica che i punti di intersezione siano validi (non zero)
                            if length(intersectionPoints[a]) < 0.0001 ||
                               length(intersectionPoints[b]) < 0.0001 ||
                               length(intersectionPoints[c]) < 0.0001 {
                                i += 3
                                continue
                            }
                            
                            // Aggiungi i vertici e crea il triangolo
                            // La funzione addVertex riutilizza i vertici esistenti quando possibile
                            let v1 = MeshUtility.addVertex(intersectionPoints[a], intersectionNormals[a], &vertices, &vertexMap, precision)
                            let v2 = MeshUtility.addVertex(intersectionPoints[b], intersectionNormals[b], &vertices, &vertexMap, precision)
                            let v3 = MeshUtility.addVertex(intersectionPoints[c], intersectionNormals[c], &vertices, &vertexMap, precision)
                            
                            // Aggiungiamo il triangolo alla mesh
                            triangles.append(Triangle(indices: (v1, v2, v3)))
                            
                            // Controllo del limite di triangoli
                            triangleCount += 1
                            if triangleCount > maxTriangles {
                                // Se abbiamo superato il limite, restituiamo la mesh parziale
                                print("⚠️ Limite massimo di triangoli raggiunto (\(maxTriangles))")
                                let cleanedMesh = MeshUtility.removeDisconnectedComponents(
                                    mesh: smoothMesh(Mesh(vertices: vertices, triangles: triangles), iterations: 2, factor: 0.3),
                                    minComponentSize: 500
                                )
                                return cleanedMesh
                            }
                            
                            i += 3 // Passiamo al prossimo triangolo
                        }
                    }
                }
            }
            
            // Feedback di avanzamento ogni certo numero di slice
            // Per monitorare il progresso dell'algoritmo
            if z % (10 * downsampleFactor) == 0 {
                let progress = Int((Float(z - startZ) / Float(endZ - startZ)) * 100)
                let elapsedTime = Date().timeIntervalSince(startTime)
                print("Slice \(z)/\(endZ): \(progress)% completato, \(triangles.count) triangoli, \(elapsedTime) secondi")
            }
        }
        
        // Statistiche finali
        let endTime = Date()
        let elapsedTime = endTime.timeIntervalSince(startTime)
        print("✅ Marching Cubes completato: \(vertices.count) vertici, \(triangles.count) triangoli in \(elapsedTime) secondi")
        if triangles.count < 1000 {
            // Avviso se la mesh è troppo semplice (potrebbe indicare problemi)
            print("⚠️ Pochi triangoli generati: \(triangles.count) → Mesh incompleta!")
        }

        print("📊 DEBUG: Vertici finali: \(vertices.count), Triangoli finali: \(triangles.count)")

        // Rimuovi componenti isolati e applica smoothing prima di restituire la mesh
        let cleanedMesh = MeshUtility.removeDisconnectedComponents(
            mesh: Mesh(vertices: vertices, triangles: triangles),
            minComponentSize: 100
        )
        let smoothedMesh = smoothMesh(cleanedMesh, iterations: 3, factor: 0.5)
        
        for i in 0..<vertices.count {
            // Se la normale è quasi zero, sostituiscila con una normale predefinita
            if length(vertices[i].normal) < 0.1 {
                vertices[i].normal = SIMD3<Float>(0, 0, 1)
            }
            // Assicurati che sia normalizzata
            vertices[i].normal = normalize(vertices[i].normal)
        }
        
        // Restituiamo la mesh finale
        return smoothedMesh
    }
    
    /*
     Applica smoothing alla mesh generata
        - Parameters:
            - mesh: La mesh di input da lisciare
            - iterations: Numero di passaggi di smoothing (più alto = più liscio ma può perdere dettagli)
            - factor: Intensità dello smoothing (0.0-1.0)
            - Returns: La mesh lisciata
     */
    func smoothMesh(_ mesh: Mesh, iterations: Int = 1, factor: Float = 0.5) -> Mesh {
        return MeshUtility.smoothMesh(mesh, iterations: iterations, factor: factor)
    }
}
