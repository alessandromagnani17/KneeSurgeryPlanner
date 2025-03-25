/*
 Vista per visualizzare le immagini DICOM di una singola serie.

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
    @ObservedObject var dicomManager: DICOMManager
    @State private var selectedImageIndex = 0
    @State private var windowCenter: Double = 40
    @State private var windowWidth: Double = 400
    @State private var zoom: CGFloat = 1.0

    var body: some View {
        VStack {
            if let series = dicomManager.currentSeries, !series.images.isEmpty {
                VStack {
                    // Barra degli strumenti con controlli per windowing e zoom
                    HStack {
                        Text("Window Center: \(Int(windowCenter))")
                        Slider(value: $windowCenter, in: -1000...1000)
                            .frame(width: 150)

                        Text("Window Width: \(Int(windowWidth))")
                        Slider(value: $windowWidth, in: 1...2000)
                            .frame(width: 150)

                        Text("Zoom: \(String(format: "%.1f", zoom))x")
                        Slider(value: $zoom, in: 0.5...3.0)
                            .frame(width: 100)

                        Spacer()
                    }
                    .padding()

                    // Visualizzazione dell'immagine DICOM
                    GeometryReader { geometry in
                        ZStack {
                            Color.black

                            if selectedImageIndex < series.images.count,
                               let cgImage = series.images[selectedImageIndex].applyWindowing(center: windowCenter, width: windowWidth) {
                                Image(nsImage: NSImage(cgImage: cgImage, size: NSSize(width: cgImage.width, height: cgImage.height)))
                                    .resizable()
                                    .aspectRatio(contentMode: .fit)
                                    .scaleEffect(zoom)
                            } else {
                                Text("Impossibile visualizzare l'immagine")
                                    .foregroundColor(.red)
                            }
                        }
                    }

                    // Barra di navigazione delle slice
                    HStack {
                        Button(action: {
                            print("DICOMViewerView: cliccato pulsante Slice Precedente")

                            if selectedImageIndex > 0 {
                                selectedImageIndex -= 1
                            }
                        }) {
                            Image(systemName: "chevron.left")
                        }
                        .disabled(selectedImageIndex <= 0)

                        Slider(
                            value: Binding(
                                get: { Double(selectedImageIndex) },
                                set: { selectedImageIndex = Int($0) }
                            ),
                            in: 0...Double(max(0, series.images.count - 1)),
                            step: 1
                        )
                        .frame(maxWidth: .infinity)

                        Button(action: {
                            print("DICOMViewerView: cliccato pulsante Slice Successiva")

                            if selectedImageIndex < series.images.count - 1 {
                                selectedImageIndex += 1
                            }
                        }) {
                            Image(systemName: "chevron.right")
                        }
                        .disabled(selectedImageIndex >= series.images.count - 1)

                        Text("Slice: \(selectedImageIndex + 1)/\(series.images.count)")
                            .frame(width: 100)
                    }
                    .padding()
                }
            } else {
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
