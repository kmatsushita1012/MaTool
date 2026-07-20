//
//  MaToolApp.swift
//  MaTool
//
//  Created by 松下和也 on 2025/02/28.
//

import SwiftUI
import Dependencies

@main
struct MaToolApp: App {
    @Dependency(\.adManager) private var adManager

    init() {
        let adManager = self.adManager
        Task { @MainActor in
            adManager.configureIfNeeded()
        }
    }

    var body: some Scene {
        WindowGroup {
            RootSceneView()
        }
    }
}

// 差分用
