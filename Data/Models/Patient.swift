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
    var medicalRecordNumber: String // Numero di cartella clinica
    var gender: Gender
    
    enum Gender: String, Codable, CaseIterable {
        case male = "Male"
        case female = "Female"
        case other = "Other"
    }
    
    // Definiamo le studySeries, array di DICOMSeries, per poi escluderle dalla codifica
    var studySeries: [DICOMSeries] = []
    
    /*
     Implementa CodingKeys per escludere studySeries dalla codifica: non vogliamo che i dati relativi alle serie DICOM
     vengano inclusi nell'oggetto Patient. Questo perchè le informazioni contenute nelle serie possono essere sensibili e
     non vogliamo che vengano salvate insieme ad altri dati del paziente (come nome, data di nascita, ecc.).
     */
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
