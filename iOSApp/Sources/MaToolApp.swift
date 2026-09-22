//
//  MaToolApp.swift
//  MaTool
//
//  Created by 松下和也 on 2025/02/28.
//

import SwiftUI
import Dependencies
import iOSShared
import Infrastructure
import Presentation

@main
struct MaToolApp: App {
    @Dependency(\.adManager) private var adManager

    init() {
        do {
            try InfrastructureResolver.configure()
        } catch {
            fatalError("Failed to setup default database: \(error.localizedDescription)")
        }

        let adManager = self.adManager
        Task { @MainActor in
            adManager.configureIfNeeded()
        }
    }

    var body: some Scene {
        WindowGroup {
            RootSceneScreen()
        }
    }
}

// 差分用
