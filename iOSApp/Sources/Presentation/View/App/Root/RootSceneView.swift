//
//  RootSceneView.swift
//  MaTool
//
//  Created by 松下和也 on 2025/10/30.
//

import Foundation
import ComposableArchitecture
import Dependencies
import SwiftUI

public struct RootSceneView: View {
    @Shared var launchState: LaunchState
    @State var status: StatusCheckResult?
    @Dependency(SceneUsecaseKey.self) var sceneUsecase
    @Dependency(\.values.isLiquidGlassEnabled) var isLiquidGlassEnabled
    
    // 追加：エラー時だけ拾うBinding
    private var errorStatusBinding: Binding<StatusCheckResult?> {
        Binding(
            get: { if case .error = launchState { return status } else { return nil } },
            set: { status = $0 }
        )
    }

    // 追加：エラー以外だけ拾うBinding
    private var normalStatusBinding: Binding<StatusCheckResult?> {
        Binding(
            get: { if case .error = launchState { return nil } else { return status } },
            set: { status = $0 }
        )
    }

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
    }

    public var body: some View {
        Group {
            switch launchState {
            case .district(let userRole, let routeId):
                let store = Store(initialState: HomeFeature.State(userRole: userRole, currentRouteId: routeId)) { HomeFeature() }
                NavigationStack{
                    HomeView(store: store)
                        .task {
                            store.send(.initialize)
                        }
                }
            case .festival(let userRole):
                let store = Store(initialState: HomeFeature.State(userRole: userRole)) { HomeFeature() }
                NavigationStack{
                    HomeView(store: store)
                        .task {
                            store.send(.initialize)
                        }
                }
            case .onboarding:
                OnboardingView(store: .init(initialState: OnboardingFeature.State(launchState: $launchState)) {
                    OnboardingFeature() }
                )
                .preferredColorScheme(.light)
            case .loading:
                LoadingView()
                    .preferredColorScheme(.light)
            case .error(let message):
                errorView(message)
            }
        }
        .sheet(item: normalStatusBinding) { status in
            AppStatusModal(status)
        }
        .fullScreenCover(item: errorStatusBinding) { status in
            AppStatusModal(status, canDismiss: false)
        }
        .environment(\.isLiquidGlassDisabled, !isLiquidGlassEnabled)
        .task {
            let (launchState, status) = await sceneUsecase.launch()
            self.$launchState.withLock { $0 = launchState }
            self.status = status
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
