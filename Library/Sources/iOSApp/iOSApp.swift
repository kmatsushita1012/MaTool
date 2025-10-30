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

// iOSApp/Presentation/RootSceneView.swift
import SwiftUI
import ComposableArchitecture

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
let defaultRegionKey: String = "region"
let defaultDistrictKey: String = "district"
let loginIdKey: String = "login"
let hasLaunchedBeforePath = "hasLaunchedBefore"
let userGuideURLString = "https://s3.ap-northeast-1.amazonaws.com/studiomk.documents/userguides/matool.pdf"
let contactURLString = "https://forms.gle/ppaAwkqrFPKiC9mr8"

extension Bundle {
    static var iOSApp: Bundle { .module }
}
