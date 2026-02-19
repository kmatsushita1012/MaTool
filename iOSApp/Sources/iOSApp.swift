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

public struct RootSceneView: View {
    @Shared var launchState: LaunchState
    @Dependency(SceneUsecaseKey.self) var sceneUsecase
    @Dependency(\.values.isLiquidGlassEnabled) var isLiquidGlassEnabled

    public init() {
        if #available(iOS 17.0, *){
            isPerceptionCheckingEnabled = false
        }
        self._launchState = Shared(value: .loading)
        prepareDependencies {
            if let database = try? setupDatabase() {
                $0.defaultDatabase = database
            }
        }
        
        Task { [self] in
            let launchState = await sceneUsecase.launch()
            self.$launchState.withLock { $0 = launchState }
        }
    }

    public var body: some View {
        Group {
            switch launchState {
            case .district(let userRole, let routeId):
                let store = Store(initialState: HomeFeature.State(userRole: userRole, currentRouteId: routeId)) { HomeFeature() }
                HomeView(store: store)
                    .task {
                        store.send(.initialize)
                    }
            case .festival(let userRole):
                let store = Store(initialState: HomeFeature.State(userRole: userRole)) { HomeFeature() }
                HomeView(store: store)
                    .task {
                        store.send(.initialize)
                    }
            case .onboarding:
                OnboardingView(store: .init(initialState: OnboardingFeature.State(launchState: $launchState)) { OnboardingFeature() })
            case .loading:
                loadingView
            case .error(let message):
                errorView(message)
            }
        }
        .environment(\.isLiquidGlassDisabled, !isLiquidGlassEnabled)
    }
    
    @ViewBuilder
    var loadingView: some View {
        VStack {
            Spacer()
            ProgressView()
                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                .scaleEffect(2)
            Spacer()
        }
    }
    
    @ViewBuilder
    func errorView(_ message: String) -> some View {
        VStack {
            Spacer()
            Text("エラー　\(message)")
            Spacer()
        }
    }
}

//定数
let spanDelta: Double = 0.005
