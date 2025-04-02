//
//  KneeSurgeryPlannerApp.swift
//  KneeSurgeryPlanner
//
//  Created by Alessandro Magnani on 24/03/25.
//

import SwiftUI

@main
struct KneeSurgeryPlannerApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .frame(minWidth: 1500, minHeight: 768)
                .onAppear {
                    // Configurazione aggiuntiva all'avvio dell'app
                }
        }
        .commands {
            // Aggiunta di comandi menu personalizzati
            SidebarCommands()
            
            CommandGroup(replacing: .newItem) {
                Button("Importa DICOM...") {
                    NotificationCenter.default.post(name: Notification.Name("ImportDICOM"), object: nil)
                }
                .keyboardShortcut("o", modifiers: [.command])
            }
        }
    }
}
