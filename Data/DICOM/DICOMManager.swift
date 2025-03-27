import Foundation

/*
 Classe che gestisce l'importazione e l'elaborazione di file DICOM.
 Si occupa di leggere i file, estrarre i dati e aggiornare l'interfaccia.
 */
class DICOMManager: ObservableObject {
    
    // Lista di pazienti importati
    @Published var patients: [Patient] = []
    // Paziente attualmente selezionato
    @Published var currentPatient: Patient?
    // Serie DICOM attualmente visualizzata
    @Published var currentSeries: DICOMSeries?
    
    // Definizione degli errori possibili durante l'importazione dei file DICOM
    enum DICOMError: Error {
        case fileNotFound       // Il file o la cartella non esistono
        case invalidData        // Dati corrotti o file non valido
        case importFailed(String) // Errore generico con messaggio
        case unsupportedFormat  // Formato DICOM non supportato
    }
    
    /*
     Importa file DICOM da una cartella selezionata dall'utente.
     @param url Percorso della cartella contenente i file DICOM
     @return Restituisce la serie DICOM importata
     */
    func importDICOMFromDirectory(_ url: URL) async throws -> DICOMSeries {
        print("Importazione da: \(url.path)")
        
        // Verifica che il percorso esista e sia una cartella valida
        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory), isDirectory.boolValue else {
            throw DICOMError.fileNotFound
        }
        
        // Recupera tutti i file presenti nella cartella
        let fileURLs = try FileManager.default.contentsOfDirectory(at: url, includingPropertiesForKeys: nil)
        
        // Filtra solo i file con estensione .dcm (DICOM)
        let dicomFiles = fileURLs.filter { $0.pathExtension.lowercased() == "dcm" }
        let sortedDicomFiles = dicomFiles.sorted { $0.lastPathComponent < $1.lastPathComponent }
        
        // Se non ci sono file DICOM validi, restituisce un errore
        if sortedDicomFiles.isEmpty {
            throw DICOMError.fileNotFound
        }
        
        // Legge e processa i file DICOM
        return try await readDICOMFiles(from: sortedDicomFiles)
    }
    
    /*
     Legge e analizza i file DICOM, creando una serie con le immagini estratte.
     @param files Array di URL dei file DICOM
     @return Serie DICOM contenente le immagini elaborate
     */
    private func readDICOMFiles(from files: [URL]) async throws -> DICOMSeries {
        
        // Crea un nuovo identificatore per il paziente
        let patientID = UUID()
        
        // Inizializza una nuova serie DICOM con dati di base (TODO: )
        var series = DICOMSeries(
            id: UUID(),
            seriesInstanceUID: UUID().uuidString,
            seriesDescription: "Imported CT Series",
            modality: "CT",
            studyDate: Date(),
            patientID: patientID,
            seriesNumber: 1,
            institutionName: "Imported Hospital",
            imageOrientation: [1, 0, 0, 0, 1, 0], // Direzione standard
            imagePosition: [0, 0, 0] // Posizione iniziale
        )
        
        var images: [DICOMImage] = []
        
        // Itera su tutti i file DICOM trovati nella cartella
        for (i, fileURL) in files.enumerated() {
            do {
                // Carica i dati binari del file DICOM
                let fileData = try Data(contentsOf: fileURL)
                
                // Verifica che il file abbia almeno 132 byte per contenere un header DICOM (i metadati)
                let headerSize = 132
                guard fileData.count > headerSize else { continue }
                
                // Estrae i dati dei pixel (TODO: semplificato, in un'app reale servirebbe una libreria DICOM)
                let pixelData = fileData.dropFirst(headerSize)
                
                // TODO: Crea un'istanza di immagine DICOM con dati di base
                let image = DICOMImage(
                    id: UUID(),
                    pixelData: pixelData,
                    rows: 512, // Dimensioni predefinite dell'immagine
                    columns: 512,
                    bitsAllocated: 16, // Profondità dei bit
                    pixelSpacing: (0.5, 0.5), // Spaziatura tra pixel
                    sliceLocation: Double(i) * 2.0, // Posizione della slice lungo l'asse Z
                    instanceNumber: i + 1, // Numero progressivo dell'immagine
                    metadata: ["SeriesInstanceUID": series.seriesInstanceUID],
                    windowCenter: 40, // Valori di finestra per il contrasto
                    windowWidth: 400
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
        
        // Assegna le immagini alla serie
        series.images = images
        
        // Crea un paziente di esempio (TODO: in un'app reale, i dati verrebbero estratti dai file DICOM)
        let patient = Patient(
            name: "Paziente Importato",
            dateOfBirth: Calendar.current.date(byAdding: .year, value: -60, to: Date())!, // Paziente fittizio 60 anni
            medicalRecordNumber: "MRN12345",
            gender: .male
        )
        
        // Aggiorna la UI con i nuovi dati DICOM
        let seriesCopy = series // Crea una copia di `series`

        await MainActor.run {
            self.patients.append(patient)
            self.currentPatient = patient
            self.currentSeries = seriesCopy // Usa la copia invece della variabile originale (perchè l'accesso a variabili in contesti concorrenti è diventato più restrittivo)
        }
        
        return series
    }
    
    /*
     Genera una rappresentazione 3D della serie DICOM.
     @param series La serie DICOM da trasformare in modello 3D
     @return Un oggetto Volume opzionale
     */
    func createVolumeFromSeries(_ series: DICOMSeries) -> Volume? {
        return Volume(from: series)
    }
}
