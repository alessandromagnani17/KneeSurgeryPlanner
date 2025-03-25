/*
 Vista SwiftUI per il rendering volumetrico con Metal.

 Proprietà principali:
 - dicomManager: Gestisce i dati DICOM.
 - windowCenter, windowWidth: Parametri per il windowing del volume.

 Funzionalità:
 - Visualizza il volume 3D usando Metal.
 - Aggiorna il rendering quando cambiano i parametri di visualizzazione.

 Scopo:
 Offrire una visualizzazione volumetrica avanzata per un'analisi dettagliata del volume.
 */


import SwiftUI
import Metal
import MetalKit

struct VolumeRenderingView: NSViewRepresentable {
    @ObservedObject var dicomManager: DICOMManager
    var windowCenter: Double = 40
    var windowWidth: Double = 400
    
    func makeNSView(context: Context) -> MTKView {
        let mtkView = MTKView()
        mtkView.delegate = context.coordinator
        mtkView.device = MTLCreateSystemDefaultDevice()
        mtkView.colorPixelFormat = .bgra8Unorm
        mtkView.depthStencilPixelFormat = .depth32Float
        mtkView.framebufferOnly = false
        mtkView.clearColor = MTLClearColor(red: 0, green: 0, blue: 0, alpha: 1)
        mtkView.enableSetNeedsDisplay = true
        
        return mtkView
    }
    
    func updateNSView(_ nsView: MTKView, context: Context) {
        context.coordinator.windowCenter = windowCenter
        context.coordinator.windowWidth = windowWidth
        
        if let series = dicomManager.currentSeries,
           let volume = dicomManager.createVolumeFromSeries(series) {
            context.coordinator.updateVolume(volume)
        }
        
        nsView.setNeedsDisplay(nsView.bounds)
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, MTKViewDelegate {
        var parent: VolumeRenderingView
        var renderer: VolumeRenderer?
        var volume: Volume?
        var windowCenter: Double
        var windowWidth: Double
        
        init(_ parent: VolumeRenderingView) {
            self.parent = parent
            self.windowCenter = parent.windowCenter
            self.windowWidth = parent.windowWidth
            super.init()
        }
        
        func updateVolume(_ newVolume: Volume) {
            volume = newVolume
            
            if let device = MTLCreateSystemDefaultDevice() {
                renderer = VolumeRenderer(device: device, volume: newVolume)
            }
        }
        
        func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
            // Aggiorna il renderer per la nuova dimensione, se necessario
            renderer?.updateViewport(size: size)
        }
        
        func draw(in view: MTKView) {
            guard let renderer = renderer,
                  let drawable = view.currentDrawable,
                  let commandBuffer = renderer.commandQueue.makeCommandBuffer(),
                  let renderPassDescriptor = view.currentRenderPassDescriptor else {
                return
            }
            
            renderer.render(
                commandBuffer: commandBuffer,
                renderPassDescriptor: renderPassDescriptor,
                drawable: drawable,
                windowCenter: Float(windowCenter),
                windowWidth: Float(windowWidth)
            )
            
            commandBuffer.present(drawable)
            commandBuffer.commit()
        }
    }
}
