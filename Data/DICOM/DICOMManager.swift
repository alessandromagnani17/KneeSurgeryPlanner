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

class DICOMManager: ObservableObject {
    @Published var patients: [Patient] = []
    @Published var currentPatient: Patient?
    @Published var currentSeries: DICOMSeries?

    enum DICOMError: Error {
        case fileNotFound
        case invalidData
        case importFailed(String)
        case unsupportedFormat
    }

    // Importa file DICOM da una directory
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

        print("Trovati \(dicomFiles.count) file DICOM")

        if dicomFiles.isEmpty {
            throw DICOMError.fileNotFound
        }

        // Leggi i file DICOM reali invece di creare dati simulati
        return try await readDICOMFiles(from: dicomFiles)
    }

    private func readDICOMFiles(from files: [URL]) async throws -> DICOMSeries {
        // Crea un ID paziente per la demo
        let patientID = UUID()

        // Crea la serie DICOM
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

        var images: [DICOMImage] = []

        // Leggi ogni file DICOM
        for (i, fileURL) in files.enumerated() {
            do {
                print("Lettura del file: \(fileURL.lastPathComponent)")

                // Leggi i dati del file
                let fileData = try Data(contentsOf: fileURL)

                // Qui dovresti estrarre i metadati e i dati dell'immagine dal fileData
                // Questa è una versione molto semplificata che assume una dimensione standard e formato RAW

                // Assumi che i dati dell'immagine inizino dopo 128 byte di header + 4 byte di prefisso DICOM
                // NOTA: Questo è un approccio estremamente semplificato e non funzionerà per molti file DICOM
                // È solo per dimostrare il concetto

                let headerSize = 132 // dimensione tipica dell'header DICOM (128 + 4 byte)
                guard fileData.count > headerSize else {
                    print("File troppo piccolo per essere un DICOM valido: \(fileURL.lastPathComponent)")
                    continue
                }

                // Estrai i dati dei pixel - questo è molto semplificato!
                // In un'implementazione reale, dovresti analizzare l'header DICOM per determinare
                // la dimensione dell'immagine, profondità di bit, ecc.
                let pixelData = fileData.dropFirst(headerSize)

                // Parametri di default - in realtà dovresti estrarli dai metadati DICOM
                let rows = 512
                let columns = 512
                let bitsAllocated = 16

                let image = DICOMImage(
                    id: UUID(),
                    pixelData: pixelData,
                    rows: rows,
                    columns: columns,
                    bitsAllocated: bitsAllocated,
                    pixelSpacing: (0.5, 0.5),
                    sliceLocation: Double(i) * 2.0,
                    instanceNumber: i + 1,
                    metadata: ["SeriesInstanceUID": series.seriesInstanceUID],
                    windowCenter: 40,
                    windowWidth: 400
                )

                images.append(image)
                print("Immagine \(i+1) caricata: \(rows)x\(columns)")

            } catch {
                print("Errore nella lettura del file \(fileURL.lastPathComponent): \(error.localizedDescription)")
            }
        }

        if images.isEmpty {
            throw DICOMError.importFailed("Nessuna immagine DICOM valida trovata")
        }

        series.images = images

        // Crea un paziente demo
        let patient = Patient(
            name: "Paziente Importato",
            dateOfBirth: Calendar.current.date(byAdding: .year, value: -60, to: Date())!,
            medicalRecordNumber: "MRN12345",
            gender: .male
        )

        // Aggiorna le proprietà pubblicate in modo asincrono
        await MainActor.run {
            self.patients.append(patient)
            self.currentPatient = patient
            self.currentSeries = series
        }

        return series
    }

    // Aggiungi questo metodo alla tua classe DICOMManager
    func createVolumeFromSeries(_ series: DICOMSeries) -> Volume? {
        return Volume(from: series)
    }
}
