//
//  VersionClient.swift
//  FesTracking2
//
//  Created by 松下和也 on 2025/07/10.
//

import Foundation
import Dependencies

@MainActor
protocol UpdateManagerProtocol: ObservableObject {
    var shouldShowUpdate: Bool { get set }
    var appStoreVersion: String { get set }

    func checkVersion() async
    func skipVersion()
    func openAppStore()
}

extension UpdateManager: DependencyKey {
    static var liveValue: UpdateManager {
        #if DEBUG
        let version = "9.9.9" // 強制的に古いバージョンとして振る舞う
        #else
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0"
        #endif

        return UpdateManager(version)
    }
}
extension UpdateManager: TestDependencyKey {
    static let previewValue = MockUpdateManager()
    static let testValue = MockUpdateManager()
}

extension DependencyValues {
    var updateManager: any UpdateManagerProtocol {
        get { self[UpdateManager.self] }
    }
}

