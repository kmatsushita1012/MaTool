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
    init(){
        print("App")
        FirebaseApp.configure()
//        initializeAWSMobileClient()
    }
    var body: some Scene {
        WindowGroup {
            ContentView(store: Store(initialState:AuthFeature.State(isSignIn: false)){ AuthFeature()._printChanges()})
        }
    }
    
//    func initializeAWSMobileClient() {
//        AWSMobileClient.default().initialize { (userState, error) in
//            if let error = error {
//                print("AWSMobileClient initialization failed: \(error.localizedDescription)")
//            } else {
//                print("AWSMobileClient initialized with state: \(String(describing: userState))")
//            }
//        }
//    }
}
