//
//  MaToolApp.swift
//  MaTool
//
//  Created by 松下和也 on 2025/02/28.
//

import SwiftUI
import SwiftData
import ComposableArchitecture

@main
struct MaToolApp: App {
    @Dependency(\.authService) var authService
    
    init() {
        let result = authService.initialize()
        print(result)
    }
    
    //    @UIApplicationDelegateAdaptor(AppDelegate.self) var delegate
    @AppStorage(hasLaunchedBeforePath, store: UserDefaults(suiteName: "matool")) var hasLaunchedBefore: Bool = false
    let store = Store(initialState:Home.State()){
        Home()
    }
    
    var body: some Scene {
        WindowGroup {
            Group{
                if hasLaunchedBefore {
                    HomeStoreView(
                        store: store
                    )
                } else {
                    OnboardingStoreView(store: Store(initialState: OnboardingFeature.State()){ OnboardingFeature() })
                }
            }
            .task{
                store.send(.initialize)
                if #available(iOS 17.0, *){
                    isPerceptionCheckingEnabled = false
                }
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
