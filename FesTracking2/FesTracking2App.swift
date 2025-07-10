//
//  FesTracking2App.swift
//  FesTracking2
//
//  Created by 松下和也 on 2025/02/28.
//

import SwiftUI
import SwiftData
import FirebaseCore
import ComposableArchitecture
import AWSMobileClient

@main
struct FesTracking2App: App {
    //    @UIApplicationDelegateAdaptor(AppDelegate.self) var delegate
    @AppStorage(hasLaunchedBeforePath, store: UserDefaults(suiteName: "matool")) var hasLaunchedBefore: Bool = false
    
    @State private var shouldShowUpdate = false

    
    init(){
        FirebaseApp.configure()
    }
    var body: some Scene {
        WindowGroup {
            if hasLaunchedBefore {
                HomeStoreView(
                    store: Store(
                        initialState:Home.State()
                    ){
                        Home()
                    }
                )
            } else {
                OnboardingStoreView(store: Store(initialState: OnboardingFeature.State()){ OnboardingFeature() })
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
