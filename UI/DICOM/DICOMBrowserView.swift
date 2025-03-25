/*
 Vista per la gestione e l'esplorazione dei dati DICOM.

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

struct DICOMBrowserView: View {
    @ObservedObject var dicomManager: DICOMManager
    @State private var isImporting = false

    var body: some View {
        VStack {
            HStack {
                Text("DICOM Browser")
                    .font(.headline)

                Spacer()

                Button(action: {
                    print("DICOMBrowserView: cliccato pulsante Import DICOM")
                    isImporting = true
                }) {
                    Label("Import DICOM", systemImage: "square.and.arrow.down")
                }
                .customFileImporter(
                    isPresented: $isImporting,
                    allowedContentTypes: [.folder],
                    allowsMultipleSelection: false
                ) { result in
                    switch result {
                    case .success(let urls):
                        if let url = urls.first {
                            importDICOM(from: url)
                        }
                    case .failure(let error):
                        print("Error importing DICOM: \(error.localizedDescription)")
                    }
                }
            }
            .padding()

            Divider()

            if dicomManager.patients.isEmpty {
                VStack {
                    Spacer()
                    Text("No DICOM data imported")
                        .foregroundColor(.secondary)
                    Text("Click 'Import DICOM' to start")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    Spacer()
                }
            } else {
                List {
                    ForEach(dicomManager.patients) { patient in
                        Section(header: Text("\(patient.name) - \(patient.medicalRecordNumber)")) {
                            ForEach(patient.studySeries) { series in
                                HStack {
                                    VStack(alignment: .leading) {
                                        Text(series.seriesDescription)
                                            .font(.headline)
                                        Text("\(series.modality) - \(series.images.count) images")
                                            .font(.subheadline)
                                            .foregroundColor(.secondary)
                                    }

                                    Spacer()

                                    if let firstImage = series.images.first,
                                       let cgImage = firstImage.image() {
                                        Image(cgImage, scale: 1.0, label: Text("Thumbnail"))
                                            .resizable()
                                            .aspectRatio(contentMode: .fit)
                                            .frame(width: 60, height: 60)
                                    }
                                }
                                .padding(.vertical, 4)
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    print("DICOMBrowserView: cliccato pulsante Seleziona Serie")
                                    dicomManager.currentSeries = series
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    private func importDICOM(from url: URL) {
        Task {
            do {
                let _ = try await dicomManager.importDICOMFromDirectory(url)
                // La serie è già stata aggiunta al manager nel metodo importDICOMFromDirectory
            } catch {
                print("Error: \(error.localizedDescription)")
                // Qui dovresti mostrare un errore all'utente
            }
        }
    }
}
