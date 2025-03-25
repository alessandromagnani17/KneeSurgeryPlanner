/*
 Struttura che rappresenta una serie DICOM contenente più immagini.

 Proprietà principali:
 - id, seriesInstanceUID, seriesDescription, modality, studyDate
 - patientID, images, seriesNumber, institutionName

 Funzionalità:
 - Ordina le immagini in base alla posizione della slice.
 - Calcola lo spessore della slice.

 Scopo:
 Organizza e gestisce una raccolta di immagini DICOM per la ricostruzione 3D.
 */

import Foundation

struct DICOMSeries: Identifiable {
    let id: UUID
    let seriesInstanceUID: String
    let seriesDescription: String
    let modality: String
    let studyDate: Date
    let patientID: UUID
    var images: [DICOMImage] = []

    // Metadati aggiuntivi della serie
    let seriesNumber: Int
    let institutionName: String?

    // Informazioni spaziali per ricostruzione 3D
    var imageOrientation: [Double]? // Direzione delle immagini nello spazio 3D
    var imagePosition: [Double]?    // Posizione della prima immagine

    var orderedImages: [DICOMImage] {
        return images.sorted { $0.sliceLocation < $1.sliceLocation }
    }

    var sliceThickness: Double? {
        guard images.count > 1 else { return nil }
        let sortedImages = orderedImages
        return abs(sortedImages[1].sliceLocation - sortedImages[0].sliceLocation)
    }

    var volumeDimensions: (rows: Int, columns: Int, slices: Int) {
        if let firstImage = images.first {
            return (firstImage.rows, firstImage.columns, images.count)
        }
        return (0, 0, 0)
    }
}
