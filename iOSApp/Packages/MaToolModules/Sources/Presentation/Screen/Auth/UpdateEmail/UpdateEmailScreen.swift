import iOSShared
import Application
import View
//
//  UpdateEmailScreen.swift
//  MaTool
//  Created by 松下和也 on 2025/07/17.
//

import ComposableArchitecture
import SwiftUI

@available(iOS 17.0, *)
struct UpdateEmailScreen: View {
    @SwiftUI.Bindable var store: StoreOf<UpdateEmailFeature>

    var body: some View {
        WithPerceptionTracking {
            UpdateEmailContentView(
                onDismiss: {
                    switch store.step {
                    case .enterEmail:
                        store.send(.enterEmail(.dismissTapped))
                    case .enterCode:
                        store.send(.enterCode(.dismissTapped))
                    }
                },
                content: {
                    switch store.step {
                    case .enterEmail:
                        UpdateEmailEntryContentView(
                            email: $store.email,
                            isLoading: store.isLoading,
                            onSubmit: { store.send(.enterEmail(.okTapped)) }
                        )
                    case .enterCode(let destination):
                        UpdateEmailCodeContentView(
                            code: $store.code,
                            destination: destination,
                            isLoading: store.isLoading,
                            onSubmit: { store.send(.enterCode(.okTapped)) }
                        )
                    }
                }
            )
            .preferredColorScheme(.light)
            .alert($store.scope(state: \.errorAlert, action: \.errorAlert))
            .alert($store.scope(state: \.completeAlert, action: \.completeAlert))
        }
    }
}
