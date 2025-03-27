/*
 View per la gestione e l'esplorazione dei dati DICOM.

 Proprietà principali:
 - dicomManager: Oggetto osservato che gestisce i dati DICOM.
 - isImporting: Stato per controllare la visualizzazione del pannello di importazione.

 Funzionalità:
 - Importa file DICOM da una cartella selezionata.
 - Mostra l'elenco dei pazienti e delle serie DICOM.
 - Consente di selezionare una serie per la visualizzazione dettagliata.

 Scopo:
 Fornire un'interfaccia per esplorare, importare e selezionare serie DICOM.
 */

import SwiftUI

// View principale per la gestione e l'esplorazione dei dati DICOM
struct DICOMBrowserView: View {
    @ObservedObject var dicomManager: DICOMManager  // Gestisce i dati DICOM
    @State private var isImporting = false  // Stato per controllare il pannello di importazione

    var body: some View {
        VStack {
            HStack {
                // Titolo della view
                Text("DICOM Browser")
                    .font(.headline)

                Spacer()

                // Pulsante per importare nuovi file DICOM
                Button(action: {
                    print("DICOMBrowserView: cliccato pulsante Import DICOM")
                    isImporting = true  // Mostra il pannello di importazione
                }) {
                    // Etichetta del pulsante con icona
                    Label("Import DICOM", systemImage: "square.and.arrow.down")
                }
                // Importa i file DICOM da una cartella selezionata
                .customFileImporter(
                    isPresented: $isImporting,  // Controlla la visualizzazione del pannello di importazione
                    allowedContentTypes: [.folder],  // Consente solo la selezione di cartelle
                    allowsMultipleSelection: false  // Non permette la selezione di più cartelle
                ) { result in
                    // Gestisce il risultato dell'importazione
                    switch result {
                    case .success(let urls):  // Se l'importazione è riuscita
                        if let url = urls.first {
                            importDICOM(from: url)  // Chiama la funzione per importare i dati DICOM dalla cartella
                        }
                    case .failure(let error):  // In caso di errore
                        print("Error importing DICOM: \(error.localizedDescription)")
                    }
                }
            }
            .padding()

            Divider()  // Separatore visivo

            // Se non ci sono pazienti importati, mostra un messaggio di avviso
            if dicomManager.patients.isEmpty {
                VStack {
                    Spacer()
                    Text("No DICOM data imported")  // Messaggio che avvisa l'utente
                        .foregroundColor(.secondary)
                    Text("Click 'Import DICOM' to start")  // Istruzione per l'utente
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    Spacer()
                }
            } else {
                // Se ci sono pazienti, mostra una lista delle serie DICOM
                List {
                    // Per ogni paziente, crea una sezione
                    ForEach(dicomManager.patients) { patient in
                        Section(header: Text("\(patient.name) - \(patient.medicalRecordNumber)")) {
                            // Per ogni serie di studio del paziente, mostra una riga
                            ForEach(patient.studySeries) { series in
                                HStack {
                                    VStack(alignment: .leading) {
                                        // Descrizione della serie (modality, numero di immagini)
                                        Text(series.seriesDescription)
                                            .font(.headline)
                                        Text("\(series.modality) - \(series.images.count) images")
                                            .font(.subheadline)
                                            .foregroundColor(.secondary)
                                    }

                                    Spacer()

                                    // Mostra l'immagine miniatura della prima immagine della serie (se disponibile)
                                    if let firstImage = series.images.first,
                                       let cgImage = firstImage.image() {
                                        Image(cgImage, scale: 1.0, label: Text("Thumbnail"))
                                            .resizable()
                                            .aspectRatio(contentMode: .fit)
                                            .frame(width: 60, height: 60)
                                    }
                                }
                                .padding(.vertical, 4)  // Aggiungi spazio verticale tra gli elementi
                                .contentShape(Rectangle())  // Rende l'intera riga cliccabile
                                .onTapGesture {
                                    // Gestisce il tap sulla serie DICOM per selezionarla
                                    print("DICOMBrowserView: cliccato pulsante Seleziona Serie")
                                    dicomManager.currentSeries = series  // Imposta la serie selezionata come corrente
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    // Funzione per importare i file DICOM dalla cartella selezionata
    private func importDICOM(from url: URL) {
        Task {
            do {
                // Chiama il metodo di importazione nel dicomManager
                let _ = try await dicomManager.importDICOMFromDirectory(url)
                // La serie è già stata aggiunta al manager nel metodo importDICOMFromDirectory
            } catch {
                // Gestisce eventuali errori durante l'importazione
                print("Error: \(error.localizedDescription)")
            }
        }
    }
}
