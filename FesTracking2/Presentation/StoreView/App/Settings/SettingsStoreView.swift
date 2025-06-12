//
//  SettingsStoreView.swift
//  FesTracking2
//
//  Created by 松下和也 on 2025/04/21.
//

import ComposableArchitecture
import SwiftUI

struct SettingsStoreView: View {
    let store: StoreOf<Settings>
    
    var body: some View {
        NavigationStack{
            VStack{
                Text("Settings")
            }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(action: {
                        store.send(.homeTapped)
                    }) {
                        Image(systemName: "house")
                            .foregroundColor(.black)
                    }
                    .padding(.horizontal, 8)
                }
                ToolbarItem(placement: .principal) {
                    Text("設定")
                        .bold()
                }
            }
        }
        
    }
}
