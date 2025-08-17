//
//  AppStatus.swift
//  FesTracking2
//
//  Created by 松下和也 on 2025/08/12.
//

import Foundation

import Foundation

actor AppStatusClient: AppStatusClientProtocol {
    
    private var status: AppStatus?
    private let urlString: String

    init(urlString: String) {
        self.urlString = urlString
    }

    func isMaintenanceActive() async -> Bool {
        let status = await fetchIfNeeded()
        return status.maintenance.isActive && (status.maintenance.until > Date())
    }

    func maintenanceMessage() async -> String? {
        let status = await fetchIfNeeded()
        return (status.maintenance.isActive && (status.maintenance.until > Date())) ? status.maintenance.message : nil
    }
    
    func checkStatus() async -> StatusCheckResult? {
        let currentVersion = Self.getCurrentVersion()
        return await checkStatus(currentVersion: currentVersion)
    }

    func checkStatus(currentVersion: String) async -> StatusCheckResult? {
        let status = await fetchIfNeeded()
        let version = currentVersion

        if status.maintenance.isActive && (status.maintenance.until > Date()) {
            return .maintenance(message: status.maintenance.message)
        }
        if !version.isVersion(greaterThanOrEqualTo: status.update.ios.requiredVersion) {
            return .updateRequired(storeURL: status.update.ios.storeUrl)
        }
        return nil
    }

    private func fetchIfNeeded() async -> AppStatus {
        if let cached = status {
            return cached
        }
        do {
            let fetchedStatus = try await fetch()
            status = fetchedStatus
            return fetchedStatus
        } catch {
            fatalError("AppStatus fetch failed: \(error)")
        }
    }

    func fetch() async throws -> AppStatus {
        guard let url = URL(string: urlString) else {
            throw URLError(.badURL)
        }
        let (data, response) = try await URLSession.shared.data(from: url)
        guard let httpResp = response as? HTTPURLResponse,
              (200..<300).contains(httpResp.statusCode) else {
            throw URLError(.badServerResponse)
        }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let status = try decoder.decode(AppStatus.self, from: data)
        return status
    }

    static func getCurrentVersion() -> String {
        #if DEBUG
        "9.9.9"
        #else
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0.0.0"
        #endif
    }
}
