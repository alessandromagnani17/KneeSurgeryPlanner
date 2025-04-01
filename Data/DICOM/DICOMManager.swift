import Foundation

class DICOMManager: ObservableObject {
    
    // Liste e proprietà pubblicate
    @Published var patients: [Patient] = []
    @Published var currentPatient: Patient?
    @Published var currentSeries: DICOMSeries?
    
    // Servizio per interagire con i file DICOM
    private let dicomService = DICOMService()
    
    enum DICOMError: Error {
        case fileNotFound
        case invalidData
        case importFailed(String)
        case unsupportedFormat
    }
    
    func importDICOMFromDirectory(_ url: URL) async throws -> DICOMSeries {
        print("Importazione da: \(url.path)")
        
        // Verifica che il percorso esista e sia una cartella valida
        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory), isDirectory.boolValue else {
            throw DICOMError.fileNotFound
        }
        
        // Recupera tutti i file nella cartella
        let fileURLs = try FileManager.default.contentsOfDirectory(at: url, includingPropertiesForKeys: nil)
        
        // Filtra solo i file DICOM
        let dicomFiles = fileURLs.filter { $0.pathExtension.lowercased() == "dcm" }
        let sortedDicomFiles = dicomFiles.sorted { $0.lastPathComponent < $1.lastPathComponent }
        
        if sortedDicomFiles.isEmpty {
            throw DICOMError.fileNotFound
        }
        
        // Legge e processa i file DICOM
        return try await readDICOMFiles(from: sortedDicomFiles)
    }
    
    private func readDICOMFiles(from files: [URL]) async throws -> DICOMSeries {
        // Per il debug, stampa i metadati del primo file
        if let firstFile = files.first {
            print("Debug metadati DICOM del primo file:")
            dicomService.printAllTags(from: firstFile.path)
        }
        
        // Leggi i metadati della serie dal primo file
        guard let firstFile = files.first,
              let metadata = try? dicomService.readMetadata(from: firstFile.path) else {
            throw DICOMError.invalidData
        }
        
        dicomService.printKeyMetadata(from: firstFile.path)
        
        // Estrai le informazioni di serie
        let seriesInstanceUID = metadata["SeriesInstanceUID"] as? String ?? UUID().uuidString
        let seriesDescription = metadata["SeriesDescription"] as? String ?? "Imported DICOM Series"
        let modality = metadata["Modality"] as? String ?? "Unknown"
        // Converti data studio se presente
        var studyDate = Date()
        if let dateString = metadata["StudyDate"] as? String, dateString.count == 8 {
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyyMMdd"
            if let date = formatter.date(from: dateString) {
                studyDate = date
            }
        }
        
        // Estrai ID paziente o genera un nuovo UUID
        let patientIDString = metadata["PatientID"] as? String
        let patientID = UUID() // Per mantenere compatibilità con il tuo modello
        
        // Estrai informazioni dell'orientamento dell'immagine se disponibili
        var imageOrientation: [Double] = [1, 0, 0, 0, 1, 0] // Default
        if let orientationArray = metadata["ImageOrientation"] as? [NSNumber] {
            imageOrientation = orientationArray.map { $0.doubleValue }
        }
        
        // Estrai posizione dell'immagine se disponibile
        var imagePosition: [Double] = [0, 0, 0] // Default
        if let posX = (metadata["ImagePositionX"] as? String).flatMap(Double.init),
           let posY = (metadata["ImagePositionY"] as? String).flatMap(Double.init),
           let posZ = (metadata["ImagePositionZ"] as? String).flatMap(Double.init) {
            imagePosition = [posX, posY, posZ]
        }
        
        // Crea una nuova serie DICOM con i metadati estratti
        var series = DICOMSeries(
            id: UUID(),
            seriesInstanceUID: seriesInstanceUID,
            seriesDescription: seriesDescription,
            modality: modality,
            studyDate: studyDate,
            patientID: patientID,
            seriesNumber: 1, // Default
            institutionName: metadata["InstitutionName"] as? String ?? "Unknown",
            imageOrientation: imageOrientation,
            imagePosition: imagePosition
        )
        
        var images: [DICOMImage] = []
        
        // Itera su tutti i file DICOM trovati nella cartella
        for (i, fileURL) in files.enumerated() {
            do {
                // Leggi metadati specifici dell'immagine
                let imageMetadata = dicomService.readMetadata(from: fileURL.path)
                
                // Ottieni i dati dei pixel
                guard let pixelInfo = dicomService.getPixelData(from: fileURL.path) else {
                    print("Impossibile ottenere i dati dei pixel per \(fileURL.lastPathComponent)")
                    continue
                }
                
                // Estrai la spaziatura dei pixel (pixel spacing)
                let pixelSpacingX = (imageMetadata["PixelSpacingX"] as? String).flatMap(Double.init) ?? 1.0
                let pixelSpacingY = (imageMetadata["PixelSpacingY"] as? String).flatMap(Double.init) ?? 1.0
                
                // Estrai posizione della slice
                let sliceLocation = (imageMetadata["SliceLocation"] as? String).flatMap(Double.init) ?? Double(i) * 2.0
                
                // Estrai numero di istanza
                let instanceNumber = (imageMetadata["InstanceNumber"] as? String).flatMap(Int.init) ?? (i + 1)
                
                // Estrai valori di finestra (window center/width)
                let windowCenter = (imageMetadata["WindowCenter"] as? String).flatMap(Double.init) ?? 40
                let windowWidth = (imageMetadata["WindowWidth"] as? String).flatMap(Double.init) ?? 400
                
                // Crea un'istanza di immagine DICOM con i dati estratti
                let image = DICOMImage(
                    id: UUID(),
                    pixelData: pixelInfo.pixelData,
                    rows: pixelInfo.rows,
                    columns: pixelInfo.columns,
                    bitsAllocated: pixelInfo.bitsAllocated,
                    pixelSpacing: (pixelSpacingX, pixelSpacingY),
                    sliceLocation: sliceLocation,
                    instanceNumber: instanceNumber,
                    metadata: ["SeriesInstanceUID": seriesInstanceUID],
                    windowCenter: windowCenter,
                    windowWidth: windowWidth
                )
                
                // Aggiunge l'immagine alla serie
                images.append(image)
            } catch {
                print("Errore nella lettura di \(fileURL.lastPathComponent): \(error.localizedDescription)")
            }
        }
        
        // Se nessuna immagine è stata importata, restituisce errore
        if images.isEmpty {
            throw DICOMError.importFailed("Nessuna immagine DICOM valida trovata")
        }
        
        // Ordina le immagini in base alla posizione della slice
        images.sort { $0.instanceNumber < $1.instanceNumber }
        
        // Assegna le immagini alla serie
        series.images = images
        
        // Estrai il nome del paziente dai metadati
        let patientName = metadata["PatientName"] as? String ?? "Paziente Importato"
        
        // Estrai data di nascita se presente, altrimenti usa un valore predefinito
        var dateOfBirth = Calendar.current.date(byAdding: .year, value: -60, to: Date())!
        
        // Crea un paziente con i dati estratti
        let patient = Patient(
            name: patientName,
            dateOfBirth: dateOfBirth,
            medicalRecordNumber: patientIDString ?? "MRN12345",
            gender: .male  // Default, dovrebbe essere estratto dai metadati DICOM
        )
        
        // Aggiorna la UI con i nuovi dati DICOM
        let seriesCopy = series
        
        await MainActor.run {
            self.patients.append(patient)
            self.currentPatient = patient
            self.currentSeries = seriesCopy
        }
        
        return series
    }
    
    func createVolumeFromSeries(_ series: DICOMSeries) -> Volume? {
        return Volume(from: series)
    }
}
