//
//  PublicMapBannerAdSection.swift
//  MaTool
//
//  Created by Codex on 2026/06/30.
//

import Dependencies
import SwiftUI
import UIKit

#if canImport(GoogleMobileAds)
import GoogleMobileAds
#endif

struct PublicMapBannerAdSection: View {
    @Dependency(\.values) var values

    var body: some View {
        if let unitID = values.publicMapBannerAdUnitId, !unitID.isEmpty {
            AdMobBannerView(unitID: unitID)
                .frame(maxWidth: .infinity)
        }
    }
}

private struct AdMobBannerView: UIViewRepresentable {
    let unitID: String

    func makeUIView(context: Context) -> UIView {
        #if canImport(GoogleMobileAds)
        let container = UIView(frame: .zero)
        let bannerView = BannerView(adSize: currentAdSize)
        bannerView.translatesAutoresizingMaskIntoConstraints = false
        bannerView.adUnitID = unitID
        bannerView.rootViewController = UIApplication.shared.topViewController()
        bannerView.load(Request())

        container.addSubview(bannerView)
        NSLayoutConstraint.activate([
            bannerView.centerXAnchor.constraint(equalTo: container.centerXAnchor),
            bannerView.topAnchor.constraint(equalTo: container.topAnchor),
            bannerView.bottomAnchor.constraint(equalTo: container.bottomAnchor)
        ])
        context.coordinator.bannerView = bannerView
        return container
        #else
        return UIView(frame: .zero)
        #endif
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        #if canImport(GoogleMobileAds)
        context.coordinator.bannerView?.adSize = currentAdSize
        context.coordinator.bannerView?.rootViewController = UIApplication.shared.topViewController()
        #endif
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    #if canImport(GoogleMobileAds)
    private var currentAdSize: AdSize {
        let width = UIScreen.main.bounds.width - 32
        return currentOrientationAnchoredAdaptiveBanner(width: max(width, 320))
    }
    #endif

    final class Coordinator {
        #if canImport(GoogleMobileAds)
        var bannerView: BannerView?
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
