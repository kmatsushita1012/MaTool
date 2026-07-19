//
//  PublicMapBannerAdSection.swift
//  MaTool
//
//  Created by Codex on 2026/06/30.
//

import Dependencies
import OSLog
import SwiftUI
import UIKit

#if canImport(GoogleMobileAds)
import GoogleMobileAds
#endif

struct PublicMapBannerAdSection: View {
    @Dependency(\.values) var values
    @Dependency(\.adManager) var adManager

    var body: some View {
        if let unitID = values.publicMapBannerAdUnitId, !unitID.isEmpty {
            #if canImport(GoogleMobileAds)
            let adSize = AdMobBannerView.currentAdSize
            AdMobBannerView(unitID: unitID, adSize: adSize, adManager: adManager)
                .frame(width: adSize.size.width, height: adSize.size.height)
                .frame(maxWidth: .infinity)
            #endif
        }
    }
}

private struct AdMobBannerView: UIViewRepresentable {
    let unitID: String
    let adSize: AdSize
    let adManager: any AdManagerProtocol

    private static let logger = Logger(subsystem: "com.studiomk.MaTool", category: "AdMob")

    static var currentAdSize: AdSize {
        let width = UIScreen.main.bounds.width - 32
        return currentOrientationAnchoredAdaptiveBanner(width: max(width, 320))
    }

    func makeUIView(context: Context) -> UIView {
        #if canImport(GoogleMobileAds)
        let container = UIView(frame: .zero)
        let bannerView = BannerView(adSize: adSize)
        bannerView.translatesAutoresizingMaskIntoConstraints = false
        bannerView.adUnitID = unitID
        bannerView.delegate = context.coordinator

        container.addSubview(bannerView)
        NSLayoutConstraint.activate([
            bannerView.centerXAnchor.constraint(equalTo: container.centerXAnchor),
            bannerView.topAnchor.constraint(equalTo: container.topAnchor),
            bannerView.bottomAnchor.constraint(equalTo: container.bottomAnchor)
        ])
        context.coordinator.bannerView = bannerView
        context.coordinator.loadIfPossible(adManager: adManager)
        return container
        #else
        return UIView(frame: .zero)
        #endif
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        #if canImport(GoogleMobileAds)
        context.coordinator.bannerView?.adSize = adSize
        context.coordinator.loadIfPossible(adManager: adManager)
        #endif
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    final class Coordinator: NSObject {
        #if canImport(GoogleMobileAds)
        var bannerView: BannerView?
        private var didLoadRequest = false

        @MainActor
        func loadIfPossible(adManager: any AdManagerProtocol) {
            guard !didLoadRequest,
                  let bannerView,
                  let rootViewController = UIApplication.shared.topViewController() else {
                return
            }

            adManager.configureIfNeeded()
            bannerView.rootViewController = rootViewController
            bannerView.load(Request())
            didLoadRequest = true
        }

        func bannerViewDidReceiveAd(_ bannerView: BannerView) {
            AdMobBannerView.logger.debug("Banner ad loaded")
        }

        func bannerView(_ bannerView: BannerView, didFailToReceiveAdWithError error: Error) {
            AdMobBannerView.logger.error("Banner ad failed to load: \(error.localizedDescription, privacy: .public)")
        }
        #endif
    }
}

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
