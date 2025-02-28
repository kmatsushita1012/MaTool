//
//  FesTracking2App.swift
//  FesTracking2
//
//  Created by 松下和也 on 2025/02/28.
//

import SwiftUI
import SwiftData
import FirebaseCore

@main
struct FesTracking2App: App {
//    @UIApplicationDelegateAdaptor(AppDelegate.self) var delegate
    init(){
        FirebaseApp.configure()
    }
    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            Item.self,
        ])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(sharedModelContainer)
    }
}
