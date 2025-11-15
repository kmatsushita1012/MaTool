//
//  MaToolApp.swift
//  MaTool
//
//  Created by 松下和也 on 2025/02/28.
//

import SwiftUI

@main
struct MaToolApp: App {
    private let appInitializer = AppInitializer()

    init() {
        appInitializer.initializeEnvironment()
    }

    var body: some Scene {
        WindowGroup {
            RootSceneView()
        }
    }
}
