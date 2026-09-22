import iOSShared
//
//  AppStatusClient.swift
//  MaTool
//
//  Created by 松下和也 on 2025/08/12.
//

import Foundation
import Dependencies

// MARK: - AppStatusClient
public actor AppStatusClient: AppStatusClientProtocol {
    
    private var status: AppStatus?
    private let urlString: String

    public init(urlString: String) {
        self.urlString = urlString
    }
    
    public func checkStatus() async -> StatusCheckResult? {
        let currentVersion = Self.getCurrentVersion()
        return await checkStatus(currentVersion: currentVersion)
    }

    public func checkStatus(currentVersion: String) async -> StatusCheckResult? {
        guard  let status = await fetchIfNeeded() else { return nil}
        let version = currentVersion

        if let maintenance = status.maintenance,
            maintenance.until > Date() {
            return .maintenance(message: maintenance.message, until: maintenance.until)
        }
        if !version.isVersion(greaterThanOrEqualTo: status.update.ios.requiredVersion) {
            return .updateRequired(storeURL: status.update.ios.storeUrl)
        }
        return nil
    }

    private func fetchIfNeeded() async -> AppStatus? {
        if let cached = status {
            return cached
        }
        return try? await fetch()
    }

    private func fetch() async throws -> AppStatus {
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
        let status = try await Task.detached(priority: nil) {
            try decoder.decode(AppStatus.self, from: data)
        }.value
        return status
    }

    public static func getCurrentVersion() -> String {
        #if DEBUG
        "9.9.9"
        #else
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0.0.0"
        #endif
    }
}
