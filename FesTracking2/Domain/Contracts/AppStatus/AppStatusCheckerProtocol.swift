//
//  VersionClient.swift
//  FesTracking2
//
//  Created by 松下和也 on 2025/07/10.
//

import Foundation
import Dependencies

protocol AppStatusClientProtocol {

    func isMaintenanceActive() async -> Bool

    func maintenanceMessage() async -> String?

    func checkStatus() async -> StatusCheckResult?
    
    func checkStatus(currentVersion: String) async -> StatusCheckResult?
    
}

enum AppStatusClientKey: DependencyKey {
    static let liveValue: any AppStatusClientProtocol = AppStatusClient(urlString: "https://studiomk-app-assets.s3.ap-northeast-1.amazonaws.com/MaTool/app-config.json")
}

// 2. DependencyValues の拡張
extension DependencyValues {
    var appStatusClient: any AppStatusClientProtocol {
        get { self[AppStatusClientKey.self] }
        set { self[AppStatusClientKey.self] = newValue }
    }
}
