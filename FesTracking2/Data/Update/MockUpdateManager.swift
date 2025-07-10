//
//  UpdateClientMock.swift
//  FesTracking2
//
//  Created by 松下和也 on 2025/07/10.
//

import Dependencies

import Foundation
import SwiftUI

@MainActor
final class MockUpdateManager: UpdateManagerProtocol {
    @Published var shouldShowUpdate = false
    @Published var appStoreVersion = ""

    // テスト時に返したいバージョンを設定できる
    var mockLatestVersion: String? = "9.9.9"
    var skipCalled = false
    var openAppStoreCalled = false

    func checkVersion() async {
        if let version = mockLatestVersion {
            appStoreVersion = version
            shouldShowUpdate = true
        } else {
            shouldShowUpdate = false
        }
    }

    func skipVersion() {
        skipCalled = true
        shouldShowUpdate = false
    }

    func openAppStore() {
        openAppStoreCalled = true
    }
}
