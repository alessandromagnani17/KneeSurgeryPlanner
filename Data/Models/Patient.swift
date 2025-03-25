/*
 Struttura che rappresenta un paziente con informazioni anagrafiche e serie DICOM.

 Proprietà principali:
 - id, name, dateOfBirth, medicalRecordNumber, gender
 - studySeries (escluso dalla codifica)

 Funzionalità:
 - Calcola l'età del paziente.
 - Supporta la codifica/decodifica (senza studySeries).

 Scopo:
 Gestisce i dati di un paziente e le sue serie di immagini.
 */

import Foundation

struct Patient: Identifiable, Codable {
    let id: UUID
    var name: String
    var dateOfBirth: Date
    var medicalRecordNumber: String
    var gender: Gender
    
    // Rendi questa proprietà privata per la codifica, o escludila
    var studySeries: [DICOMSeries] = []
    
    enum Gender: String, Codable, CaseIterable {
        case male = "Male"
        case female = "Female"
        case other = "Other"
    }
    
    // Implementa CodingKeys per escludere studySeries dalla codifica
    enum CodingKeys: String, CodingKey {
        case id, name, dateOfBirth, medicalRecordNumber, gender
    }
    
    init(id: UUID = UUID(), name: String, dateOfBirth: Date, medicalRecordNumber: String, gender: Gender) {
        self.id = id
        self.name = name
        self.dateOfBirth = dateOfBirth
        self.medicalRecordNumber = medicalRecordNumber
        self.gender = gender
    }
    
    var age: Int {
        let calendar = Calendar.current
        let ageComponents = calendar.dateComponents([.year], from: dateOfBirth, to: Date())
        return ageComponents.year ?? 0
    }
}
