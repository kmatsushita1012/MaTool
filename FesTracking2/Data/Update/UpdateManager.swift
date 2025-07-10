//
//  UpdateManager.swift
//  FesTracking2
//
//  Created by 松下和也 on 2025/07/10.
//

import Foundation
import SwiftUI

import Dependencies
import Foundation
import UIKit

@MainActor
final class UpdateManager: UpdateManagerProtocol {
    var currentVersion: String
    @Published var shouldShowUpdate = false
    @Published var appStoreVersion = ""

    private let bundleId = Bundle.main.bundleIdentifier ?? ""
    private let appStoreURL = URL(string: "https://apps.apple.com/jp/app/id6504391638")!
    private let skippedVersionKey = "SkippedAppVersion"
    
    init(_ currentVersion: String){
        self.currentVersion = currentVersion
    }

    func checkVersion() async {
        guard
            let storeVersion = try? await fetchLatestVersion()
        else {
            return
        }

        self.appStoreVersion = storeVersion
        let skippedVersion = getSkippedVersion()
        print("\(skippedVersion)")
        if isOlderVersion(currentVersion, than: storeVersion),
           storeVersion != skippedVersion {
            self.shouldShowUpdate = true
        }
    }

    func skipVersion() {
        UserDefaults.standard.set(appStoreVersion, forKey: skippedVersionKey)
        shouldShowUpdate = false
    }

    func openAppStore() {
        UIApplication.shared.open(appStoreURL)
    }

    // MARK: - Private helpers

    private func fetchLatestVersion() async throws -> String? {
        guard let url = URL(string: "https://itunes.apple.com/lookup?bundleId=\(bundleId)") else {
            return nil
        }

        let (data, _) = try await URLSession.shared.data(from: url)
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        let results = json?["results"] as? [[String: Any]]
        return results?.first?["version"] as? String
    }

    private func getSkippedVersion() -> String? {
        UserDefaults.standard.string(forKey: skippedVersionKey)
    }

    private func isOlderVersion(_ current: String, than store: String) -> Bool {
        current.compare(store, options: .numeric) == .orderedAscending
    }
}

