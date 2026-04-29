//
//  ConstantValues.swift
//  MaTool
//
//  Created by 松下和也 on 2025/11/12.
//
import Dependencies
import Foundation

extension DependencyValues {
  var values: ConstantValues {
    get { self[ConstantValues.self] }
    set { self[ConstantValues.self] = newValue }
  }
}

struct ConstantValues:Sendable {
    let apiBaseUrl: String
    let appStatusUrl: String
    let defaultFestivalKey: String
    let defaultDistrictKey: String
    let loginIdKey: String
    let hasLaunchedBeforeKey: String
    let userGuideUrl: String
    let contactURL: String
    let isLiquidGlassEnabled: Bool
}

extension ConstantValues: DependencyKey {
    private static let apiBaseUrlKey = "MATOOL_API_BASE_URL"

    static let liveValue = Self(
        apiBaseUrl: {
            let configName: String = {
                #if DEBUG
                    "Debug"
                #else
                    "Release"
                #endif
            }()

            guard let url = Bundle.main.url(forResource: configName, withExtension: "xcconfig") else {
                fatalError("\(configName).xcconfig がアプリに含まれていません")
            }

            guard let content = try? String(contentsOf: url, encoding: .utf8) else {
                fatalError("\(configName).xcconfig の読み込みに失敗しました")
            }

            let prefix = "\(apiBaseUrlKey) ="
            let lines = content.components(separatedBy: .newlines)

            guard
                let line = lines.first(where: { $0.trimmingCharacters(in: .whitespaces).hasPrefix(prefix) }),
                let value = line.split(separator: "=", maxSplits: 1).last?.trimmingCharacters(in: .whitespacesAndNewlines),
                !value.isEmpty
            else {
                fatalError("\(configName).xcconfig に \(apiBaseUrlKey) が設定されていません")
            }

            return value
        }(),
        appStatusUrl: "https://studiomk-app-assets.s3.ap-northeast-1.amazonaws.com/MaTool/app-config.json",
        defaultFestivalKey: "region",
        defaultDistrictKey: "district",
        loginIdKey: "login",
        hasLaunchedBeforeKey: "hasLaunchedBefore",
        userGuideUrl: "",
        contactURL: "",
        isLiquidGlassEnabled: {
            let uiDesignRequiresCompatibility = Bundle.main.object(forInfoDictionaryKey: "UIDesignRequiresCompatibility") as? Bool ?? false
            if #available(iOS 26.0, *), !uiDesignRequiresCompatibility {
                return true
            } else {
                return false
            }
        }()
    )
}
