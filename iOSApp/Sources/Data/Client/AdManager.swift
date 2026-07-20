//
//  AdManager.swift
//  MaTool
//
//  Created by Codex on 2026/06/30.
//

import Dependencies
import Foundation
import UIKit

#if canImport(GoogleMobileAds)
import GoogleMobileAds
#endif

enum AdManagerKey: DependencyKey {
    static let liveValue: any AdManagerProtocol = {
        @Dependency(\.values) var values
        return AdManager(
            configuration: .init(
                appID: values.admobAppId,
                publicMapInterstitialUnitID: values.publicMapInterstitialAdUnitId
            )
        )
    }()
}

extension DependencyValues {
    var adManager: any AdManagerProtocol {
        get { self[AdManagerKey.self] }
        set { self[AdManagerKey.self] = newValue }
    }
}

enum AdPlacement: Hashable, Sendable {
    case publicMapInterstitial
}

protocol AdManagerProtocol: Sendable {
    @MainActor
    func configureIfNeeded()
    @MainActor
    func preloadInterstitial(for placement: AdPlacement)
    @MainActor
    func presentInterstitial(for placement: AdPlacement)
}

final class AdManager: NSObject, AdManagerProtocol, @unchecked Sendable {
    struct Configuration: Sendable {
        let appID: String?
        let publicMapInterstitialUnitID: String?
    }

    private let configuration: Configuration
    private var isConfigured = false

    #if canImport(GoogleMobileAds)
    private var interstitials: [AdPlacement: InterstitialAd] = [:]
    private var placementsByAd: [ObjectIdentifier: AdPlacement] = [:]
    #endif

    init(configuration: Configuration) {
        self.configuration = configuration
    }

    @MainActor
    func configureIfNeeded() {
        guard !isConfigured else { return }
        isConfigured = true

        #if canImport(GoogleMobileAds)
        guard configuration.appID?.isEmpty == false else { return }
        MobileAds.shared.start(completionHandler: nil)
        #endif
    }

    @MainActor
    func preloadInterstitial(for placement: AdPlacement) {
        configureIfNeeded()

        #if canImport(GoogleMobileAds)
        guard interstitials[placement] == nil else { return }
        guard let unitID = interstitialUnitID(for: placement), !unitID.isEmpty else { return }

        InterstitialAd.load(with: unitID, request: Request()) { [weak self] ad, _ in
            guard let self, let ad else { return }
            ad.fullScreenContentDelegate = self
            self.interstitials[placement] = ad
            self.placementsByAd[ObjectIdentifier(ad)] = placement
        }
        #endif
    }

    @MainActor
    func presentInterstitial(for placement: AdPlacement) {
        configureIfNeeded()

        #if canImport(GoogleMobileAds)
        guard let ad = interstitials[placement] else {
            preloadInterstitial(for: placement)
            return
        }
        guard let rootViewController = UIApplication.shared.topViewController() else {
            return
        }

        interstitials[placement] = nil
        ad.present(from: rootViewController)
        #endif
    }

    private func interstitialUnitID(for placement: AdPlacement) -> String? {
        switch placement {
        case .publicMapInterstitial:
            configuration.publicMapInterstitialUnitID
        }
    }
}

#if canImport(GoogleMobileAds)
extension AdManager: FullScreenContentDelegate {
    func adDidDismissFullScreenContent(_ ad: any FullScreenPresentingAd) {
        guard let ad = ad as? InterstitialAd else { return }
        let identifier = ObjectIdentifier(ad)
        guard let placement = placementsByAd.removeValue(forKey: identifier) else { return }
        interstitials[placement] = nil
        preloadInterstitial(for: placement)
    }

    func ad(_ ad: any FullScreenPresentingAd, didFailToPresentFullScreenContentWithError error: any Error) {
        guard let ad = ad as? InterstitialAd else { return }
        let identifier = ObjectIdentifier(ad)
        guard let placement = placementsByAd.removeValue(forKey: identifier) else { return }
        interstitials[placement] = nil
        preloadInterstitial(for: placement)
    }
}
#endif

private extension UIApplication {
    func topViewController(
        base: UIViewController? = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap(\.windows)
            .first(where: \.isKeyWindow)?
            .rootViewController
    ) -> UIViewController? {
        if let navigationController = base as? UINavigationController {
            return topViewController(base: navigationController.visibleViewController)
        }
        if let tabBarController = base as? UITabBarController,
           let selected = tabBarController.selectedViewController {
            return topViewController(base: selected)
        }
        if let presented = base?.presentedViewController {
            return topViewController(base: presented)
        }
        return base
    }
}
