//
//  iOSApp.swift
//  MaTool
//
//  Created by 松下和也 on 2025/10/30.
//

// iOSApp/AppInitializer.swift
import Foundation
import ComposableArchitecture
import Dependencies
import SwiftUI

public struct AppInitializer {
    @Dependency(\.authService) var authService: AuthService
    public init() {}

    public func initializeEnvironment() {
        // AmplifyなどのAuth初期化
        Task{
            let result = await authService.initialize()
            print("Auth init result:", result)
        }
    }
}

public struct RootSceneView: View {
    @AppStorage("hasLaunchedBefore", store: UserDefaults(suiteName: "matool")) private var hasLaunchedBefore = false
    private let store: Store<Home.State, Home.Action>

    public init() {
        store = Store(initialState: Home.State()) { Home() }
        if #available(iOS 17.0, *){
            isPerceptionCheckingEnabled = false
        }
    }

    public var body: some View {
        Group {
            if hasLaunchedBefore {
                HomeStoreView(store: store)
                    .task {
                        store.send(.initialize)
                    }
            } else {
                OnboardingStoreView(store: .init(initialState: OnboardingFeature.State()) { OnboardingFeature() })
            }
        }
    }
}

//定数
let spanDelta: Double = 0.005
