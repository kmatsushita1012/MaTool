//
//  MaToolApp.swift
//  MaTool
//
//  Created by 松下和也 on 2025/02/28.
//

import SwiftUI
import ComposableArchitecture
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
            // Unit tests run inside the host application; avoid starting the live root store.
            if TestContext.current == nil {
                RootSceneView()
            }
        }
    }
}

// 差分用
