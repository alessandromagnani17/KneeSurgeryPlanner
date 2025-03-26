/*
 Classe che gestisce l'importazione e la gestione di file DICOM.

 Proprietà principali:
 - patients, currentPatient, currentSeries

 Funzionalità:
 - Importa file DICOM da una directory.
 - Legge i dati e crea oggetti Patient, DICOMSeries, e DICOMImage.
 - Crea un volume 3D da una serie DICOM.

 Scopo:
 Centralizza la gestione dei dati DICOM e ne facilita l'uso nell'applicazione.
 */

import Foundation

// Classe che gestisce l'importazione e l'elaborazione di file DICOM (imaging medico)
// Implementa ObservableObject per l'integrazione con SwiftUI
class DICOMManager: ObservableObject {
    // Proprietà pubblicate che notificano automaticamente l'interfaccia quando cambiano
    @Published var patients: [Patient] = []          // Lista di pazienti
    @Published var currentPatient: Patient?          // Paziente attualmente selezionato
    @Published var currentSeries: DICOMSeries?       // Serie DICOM attualmente selezionata

    // Enum per definire i possibili errori che possono verificarsi durante l'importazione DICOM
    enum DICOMError: Error {
        case fileNotFound        // File non trovato
        case invalidData         // Dati non validi
        case importFailed(String) // Importazione fallita con messaggio di errore
        case unsupportedFormat   // Formato non supportato
    }

    // Importa file DICOM da una directory specificata tramite URL
    func importDICOMFromDirectory(_ url: URL) async throws -> DICOMSeries {
        print("Importazione da: \(url.path)")

        // Verifica che la directory esista
        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory),
              isDirectory.boolValue else {
            print("Path non è una directory: \(url.path)")
            throw DICOMError.fileNotFound
        }

        // Trova tutti i file nella directory
        let fileURLs = try FileManager.default.contentsOfDirectory(at: url, includingPropertiesForKeys: nil)

        // Filtra solo i file DICOM
        let dicomFiles = fileURLs.filter { $0.pathExtension.lowercased() == "dcm" }
        
        // Ordina i file per nome, che tipicamente corrisponde all'ordine visibile nella directory
        let sortedDicomFiles = dicomFiles.sorted { $0.lastPathComponent < $1.lastPathComponent }

        print("Trovati \(sortedDicomFiles.count) file DICOM")

        if sortedDicomFiles.isEmpty {
            throw DICOMError.fileNotFound
        }

        // Usa i file ordinati
        return try await readDICOMFiles(from: sortedDicomFiles)
    }

    // Elabora i file DICOM trovati e crea una serie
    private func readDICOMFiles(from files: [URL]) async throws -> DICOMSeries {
        // Crea un ID paziente univoco
        let patientID = UUID()

        // Inizializza una nuova serie DICOM con informazioni di base
        var series = DICOMSeries(
            id: UUID(),
            seriesInstanceUID: UUID().uuidString,
            seriesDescription: "Imported CT Series",
            modality: "CT",
            studyDate: Date(),
            patientID: patientID,
            seriesNumber: 1,
            institutionName: "Imported Hospital",
            imageOrientation: [1, 0, 0, 0, 1, 0],
            imagePosition: [0, 0, 0]
        )

        // Array per memorizzare le immagini elaborate
        var images: [DICOMImage] = []

        // Elabora ogni file DICOM trovato
        for (i, fileURL) in files.enumerated() {
            do {
                print("Lettura del file: \(fileURL.lastPathComponent)")

                // Legge i dati binari del file
                let fileData = try Data(contentsOf: fileURL)

                // Verifica che il file abbia almeno la dimensione dell'header DICOM
                let headerSize = 132 // dimensione tipica dell'header DICOM (128 + 4 byte)
                guard fileData.count > headerSize else {
                    print("File troppo piccolo per essere un DICOM valido: \(fileURL.lastPathComponent)")
                    continue
                }

                // Estrae i dati dei pixel (versione semplificata)
                // NOTA: In un'implementazione reale si dovrebbe analizzare l'header
                let pixelData = fileData.dropFirst(headerSize)

                // Parametri di default per l'immagine (in un'implementazione reale andrebbero estratti dai metadati)
                let rows = 512
                let columns = 512
                let bitsAllocated = 16

                // Crea un oggetto immagine DICOM con i dati estratti
                let image = DICOMImage(
                    id: UUID(),
                    pixelData: pixelData,
                    rows: rows,
                    columns: columns,
                    bitsAllocated: bitsAllocated,
                    pixelSpacing: (0.5, 0.5),
                    sliceLocation: Double(i) * 2.0,  // Posizione della slice incrementale
                    instanceNumber: i + 1,
                    metadata: ["SeriesInstanceUID": series.seriesInstanceUID],
                    windowCenter: 40,
                    windowWidth: 400
                )

                // Aggiunge l'immagine all'array
                images.append(image)
                print("Immagine \(i+1) caricata: \(rows)x\(columns)")

            } catch {
                // Gestisce gli errori per ogni file, permettendo di continuare con gli altri
                print("Errore nella lettura del file \(fileURL.lastPathComponent): \(error.localizedDescription)")
            }
        }

        // Verifica che sia stata elaborata almeno un'immagine
        if images.isEmpty {
            throw DICOMError.importFailed("Nessuna immagine DICOM valida trovata")
        }

        // Assegna le immagini alla serie
        series.images = images

        // Crea un paziente dimostrativo con dati fittizi
        let patient = Patient(
            name: "Paziente Importato",
            dateOfBirth: Calendar.current.date(byAdding: .year, value: -60, to: Date())!,
            medicalRecordNumber: "MRN12345",
            gender: .male
        )

        // Aggiorna le proprietà pubblicate sulla thread principale (UI)
        await MainActor.run {
            self.patients.append(patient)
            self.currentPatient = patient
            self.currentSeries = series
        }

        return series
    }

    // Crea un oggetto Volume 3D dalla serie di immagini DICOM
    func createVolumeFromSeries(_ series: DICOMSeries) -> Volume? {
        return Volume(from: series)
    }
}
