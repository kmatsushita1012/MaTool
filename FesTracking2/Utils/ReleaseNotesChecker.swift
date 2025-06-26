//
//  ReleaseChecker.swift
//  FesTracking2
//
//  Created by 松下和也 on 2025/06/25.
//

import SwiftUI
import UIKit
import SwiftyUpdateKit

struct ReleaseNotesChecker: UIViewControllerRepresentable {
    func makeUIViewController(context: Context) -> ResolverViewController {
        ResolverViewController()
    }

    func updateUIViewController(_ uiViewController: ResolverViewController, context: Context) {}

    class ResolverViewController: UIViewController {
        private var hasChecked = false

        override func viewDidAppear(_ animated: Bool) {
            super.viewDidAppear(animated)

            guard !hasChecked else { return }
            hasChecked = true

            SUK.checkVersion(
                VersionCheckConditionAlways(),
                update: { [weak self] newVersion, releaseNotes in
                    guard let self = self else { return }
                    SUK.openAppStore()
                }
            )
        }
    }
}
