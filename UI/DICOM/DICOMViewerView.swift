/*
 View per visualizzare le immagini DICOM di una singola serie.

 Proprietà principali:
 - dicomManager: Oggetto osservato per accedere alla serie DICOM corrente.
 - selectedImageIndex: Indice dell'immagine attualmente visualizzata.
 - windowCenter, windowWidth: Parametri per il controllo del windowing.
 - zoom: Fattore di ingrandimento per l'immagine.

 Funzionalità:
 - Visualizza le immagini DICOM con supporto per lo zoom e il windowing.
 - Consente di navigare tra le slice tramite slider e pulsanti.
 - Gestisce l'aggiornamento dell'immagine in base ai parametri di visualizzazione.

 Scopo:
 Fornire un visualizzatore DICOM interattivo con strumenti per l'esplorazione dettagliata.
 */

import SwiftUI

struct DICOMViewerView: View {
    // Oggetto osservato per accedere alla serie DICOM corrente
    @ObservedObject var dicomManager: DICOMManager
    
    // Indice dell'immagine attualmente selezionata
    @State private var selectedImageIndex = 0
    
    // Parametri per il controllo del windowing (modifica la visualizzazione dell'intensità)
    @State private var windowCenter: Double = 40
    @State private var windowWidth: Double = 400
    
    // Fattore di zoom per l'immagine
    @State private var zoom: CGFloat = 1.0

    var body: some View {
        VStack {
            // Verifica che ci sia una serie DICOM selezionata e non sia vuota
            if let series = dicomManager.currentSeries, !series.images.isEmpty {
                VStack {
                    // Barra degli strumenti per controllare il windowing e lo zoom
                    HStack {
                        // Controllo per la regolazione del centro del windowing
                        VStack {
                            Text("Window Center: \(Int(windowCenter))")
                                .frame(maxWidth: .infinity, alignment: .center) // Centra il testo orizzontalmente
                            
                            Slider(value: $windowCenter, in: -1000...2000)
                                .frame(width: 150) // Imposta la larghezza dello slider
                        }

                        // Controllo per la regolazione della larghezza del windowing
                        VStack {
                            Text("Window Width: \(Int(windowWidth))")
                                .frame(maxWidth: .infinity, alignment: .center) // Centra il testo orizzontalmente

                            Slider(value: $windowWidth, in: 1...2000)
                                .frame(width: 150) // Imposta la larghezza dello slider
                        }

                        // Controllo per lo zoom dell'immagine
                        VStack {
                            Text("Zoom: \(String(format: "%.1f", zoom))x")
                                .frame(maxWidth: .infinity, alignment: .center) // Centra il testo orizzontalmente

                            Slider(value: $zoom, in: 0.5...2.0)
                                .frame(width: 100) // Imposta la larghezza dello slider
                        }

                        Spacer()
                    }
                    .padding()

                    // Visualizzazione dell'immagine DICOM con windowing applicato
                    GeometryReader { geometry in
                        ZStack {
                            // Sfondo nero per migliorare la visibilità
                            Color.black

                            // Verifica che l'immagine esista e venga applicato il windowing
                            if selectedImageIndex < series.images.count,
                               let cgImage = series.images[selectedImageIndex].applyWindowing(center: windowCenter, width: windowWidth) {
                                // Visualizzazione dell'immagine con zoom
                                Image(nsImage: NSImage(cgImage: cgImage, size: NSSize(width: cgImage.width, height: cgImage.height)))
                                    .resizable()
                                    .aspectRatio(contentMode: .fit)
                                    .scaleEffect(zoom)
                            } else {
                                // Messaggio di errore se l'immagine non può essere visualizzata
                                Text("Impossibile visualizzare l'immagine")
                                    .foregroundColor(.red)
                            }
                        }
                    }

                    // Barra di navigazione delle slice
                    HStack {
                        // Pulsante per navigare alla slice precedente
                        Button(action: {
                            print("DICOMViewerView: cliccato pulsante Slice Precedente")

                            // Riduci l'indice dell'immagine se non siamo alla prima slice
                            if selectedImageIndex > 0 {
                                selectedImageIndex -= 1
                            }
                        }) {
                            Image(systemName: "chevron.left")
                        }
                        .disabled(selectedImageIndex <= 0) // Disabilita se siamo alla prima slice

                        // Slider per selezionare la slice desiderata
                        Slider(
                            value: Binding(
                                get: { Double(selectedImageIndex) },
                                set: { selectedImageIndex = Int($0) }
                            ),
                            in: 0...Double(max(0, series.images.count - 1)),
                            step: 1
                        )
                        .frame(maxWidth: .infinity)

                        // Pulsante per navigare alla slice successiva
                        Button(action: {
                            print("DICOMViewerView: cliccato pulsante Slice Successiva")

                            // Aumenta l'indice dell'immagine se non siamo all'ultima slice
                            if selectedImageIndex < series.images.count - 1 {
                                selectedImageIndex += 1
                            }
                        }) {
                            Image(systemName: "chevron.right")
                        }
                        .disabled(selectedImageIndex >= series.images.count - 1) // Disabilita se siamo all'ultima slice

                        // Testo che mostra il numero della slice attuale rispetto al totale
                        Text("Slice: \(selectedImageIndex + 1)/\(series.images.count)")
                            .frame(width: 100)
                    }
                    .padding()
                }
            } else {
                // Messaggio quando non ci sono serie DICOM selezionate
                VStack {
                    Spacer()
                    Text("No DICOM series selected")
                        .foregroundColor(.secondary)
                    Spacer()
                }
            }
        }
    }
}
