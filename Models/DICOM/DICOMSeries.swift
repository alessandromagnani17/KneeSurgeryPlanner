import Foundation

/*
 Struttura che rappresenta una serie di immagini DICOM.
 Una serie è un gruppo di immagini acquisite durante lo stesso esame.
 */
struct DICOMSeries: Identifiable {
    
    // - Proprietà di identificazione
    /* Id univoco della serie: creato localmente per ogni oggetto dell'applicazione, non ha alcun significato esterno.
     È utile per distinguere le serie all'interno della nostra applicazione, ma non viene usato per l'identificazione
     ufficiale dei dati nel contesto del sistema sanitario
     */
    let id: UUID
    
    // Id DICOM standard della serie: usato per identificare la serie a livello globale. Proviene dal sistema che ha acquisito le immagini
    let seriesInstanceUID: String
    
    /*
     Descrizione della serie: breve descrizione testuale, utile per identificare il tipo di esame o le
     caratteristiche specifiche della scansione (es. "TC Addome con mdc")
     */
    let seriesDescription: String
    
    // Modalità di acquisizione (es. "CT", "MR", "US" - se si tratta di una TAC, di una risonanza magnetica o di un'ecografia)
    let modality: String
    
    // Data dell'esame
    let studyDate: Date
    
    // Id del paziente
    let patientID: UUID
    
    /*
     Immagini DICOM della serie: array di oggetti DICOMImage che rappresentano tutte le immagini (slice) acquisite durante
     l'esame. Ogni immagine DICOM contiene pixel e metadati specifici.
     */
    var images: [DICOMImage] = []

    
    // - Metadati aggiuntivi
    /*
     Numero progressivo della serie nello studio: utile per ordinare o identificare diverse serie all'interno di un singolo studio o esame.
     Esempio: 1, se è la prima serie acquisita durante l'esame, oppure 2, se è la seconda serie.
     */
    let seriesNumber: Int
    
    // Nome dell'istituzione che ha eseguito l'esame
    let institutionName: String?

    
    // - Informazioni spaziali per ricostruzione 3D
    /*
     Orientamento delle immagini nello spazio 3D: È un vettore di 6 valori che descrive l'orientamento delle immagini nello
     spazio tridimensionale (X, Y, Z per la riga e X, Y, Z per la colonna). Serve per determinare come le immagini sono orientate
     rispetto allo spazio reale.
     
     Esempio: [1, 0, 0, 0, 1, 0], che significa che le immagini della serie sono allineate al piano XY (orizzontale), con
     le righe che si estendono lungo l'asse X e le colonne lungo l'asse Y.
     */
    var imageOrientation: [Double]?
    
    /*
     Posizione della prima immagine nello spazio 3D (coordinate x, y, z): È un array di 3 valori che descrive la posizione della
     prima immagine nello spazio 3D. Le coordinate sono espresse in millimetri (mm) e indicano la posizione iniziale rispetto a un
     sistema di coordinate (tipicamente l'origine del paziente).
     
     Esempio: [0, 0, 0], che significa che la prima immagine è collocata nell'origine dello spazio 3D (0, 0, 0)
     */
    var imagePosition: [Double]?


    
    // - Proprietà calcolate
    /*
     Restituisce le immagini ordinate in base alla posizione lungo l'asse Z.
     Questo è importante per la ricostruzione 3D.
     
     @return Immagini ordinate per posizione crescente
     */
    var orderedImages: [DICOMImage] {
        return images.sorted { $0.sliceLocation < $1.sliceLocation }
    }

    /*
     Calcola lo spessore della slice, ossia la distanza tra due slice consecutive.
     Questo è essenziale per la ricostruzione 3D accurata.
     
     @return Spessore della slice in mm, o nil se ci sono meno di 2 immagini
     */
    var sliceThickness: Double? {
        guard images.count > 1 else { return nil }
        let sortedImages = orderedImages
        return abs(sortedImages[1].sliceLocation - sortedImages[0].sliceLocation)
    }

    /*
     Calcola le dimensioni del volume 3D creato dalla serie di immagini.
     
     @return Tupla con:
        - rows: numero di righe per immagine
        - columns: numero di colonne per immagine
        - slices: numero di immagini (profondità del volume)
     */
    var volumeDimensions: (rows: Int, columns: Int, slices: Int) {
        if let firstImage = images.first {
            return (firstImage.rows, firstImage.columns, images.count)
        }
        return (0, 0, 0)
    }
}
