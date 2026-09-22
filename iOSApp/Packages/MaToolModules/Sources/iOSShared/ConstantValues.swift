//
//  ConstantValues.swift
//  MaTool
//
//  Created by 松下和也 on 2025/11/12.
//
import Dependencies
import Foundation

extension DependencyValues {
  public var values: ConstantValues {
    get { self[ConstantValues.self] }
    set { self[ConstantValues.self] = newValue }
  }
}

public struct ConstantValues: Sendable {
    public let apiBaseUrl: String
    public let appStatusUrl: String
    public let defaultFestivalKey: String
    public let defaultDistrictKey: String
    public let publicTabLinkingKey: String
    public let loginIdKey: String
    public let hasLaunchedBeforeKey: String
    public let userGuideUrl: String
    public let contactURL: String
    public let isLiquidGlassEnabled: Bool
    public let admobAppId: String?
    public let publicMapInterstitialAdUnitId: String?
    public let publicMapBannerAdUnitId: String?
}

extension ConstantValues: DependencyKey {
    private static let apiBaseUrlKey = "MATOOL_API_BASE_URL"
    private static let userGuideUrlKey = "MATOOL_USER_GUIDE_URL"
    private static let contactUrlKey = "MATOOL_CONTACT_URL"
    private static let admobAppIdKey = "MATOOL_ADMOB_APP_ID"
    private static let publicMapInterstitialAdUnitIdKey = "MATOOL_PUBLIC_MAP_INTERSTITIAL_AD_UNIT_ID"
    private static let publicMapBannerAdUnitIdKey = "MATOOL_PUBLIC_MAP_BANNER_AD_UNIT_ID"

    private static func value(fromXCConfig key: String) -> String {
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

        let prefix = "\(key) ="
        let lines = content.components(separatedBy: .newlines)

        guard
            let line = lines.first(where: { $0.trimmingCharacters(in: .whitespaces).hasPrefix(prefix) }),
            let value = line.split(separator: "=", maxSplits: 1).last?.trimmingCharacters(in: .whitespacesAndNewlines),
            !value.isEmpty
        else {
            fatalError("\(configName).xcconfig に \(key) が設定されていません")
        }

        return value
    }

    private static func optionalValue(fromXCConfig key: String) -> String? {
        let configName: String = {
            #if DEBUG
                "Debug"
            #else
                "Release"
            #endif
        }()

        guard let url = Bundle.main.url(forResource: configName, withExtension: "xcconfig"),
              let content = try? String(contentsOf: url, encoding: .utf8) else {
            return nil
        }

        let prefix = "\(key) ="
        let lines = content.components(separatedBy: .newlines)
        guard
            let line = lines.first(where: { $0.trimmingCharacters(in: .whitespaces).hasPrefix(prefix) }),
            let rawValue = line.split(separator: "=", maxSplits: 1).last?.trimmingCharacters(in: .whitespacesAndNewlines),
            !rawValue.isEmpty
        else {
            return nil
        }

        return rawValue
    }

    public static let liveValue = Self(
        apiBaseUrl: value(fromXCConfig: apiBaseUrlKey),
        appStatusUrl: "https://studiomk-app-assets.s3.ap-northeast-1.amazonaws.com/MaTool/app-config.json",
        defaultFestivalKey: "region",
        defaultDistrictKey: "district",
        publicTabLinkingKey: "publicTabLinking",
        loginIdKey: "login",
        hasLaunchedBeforeKey: "hasLaunchedBefore",
        userGuideUrl: value(fromXCConfig: userGuideUrlKey),
        contactURL: value(fromXCConfig: contactUrlKey),
        isLiquidGlassEnabled: {
            let uiDesignRequiresCompatibility = Bundle.main.object(forInfoDictionaryKey: "UIDesignRequiresCompatibility") as? Bool ?? false
            if #available(iOS 26.0, *), !uiDesignRequiresCompatibility {
                return true
            } else {
                return false
            }
        }(),
        admobAppId: optionalValue(fromXCConfig: admobAppIdKey),
        publicMapInterstitialAdUnitId: optionalValue(fromXCConfig: publicMapInterstitialAdUnitIdKey),
        publicMapBannerAdUnitId: optionalValue(fromXCConfig: publicMapBannerAdUnitIdKey)
    )
}
