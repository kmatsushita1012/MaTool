//
//  InfoStoreView.swift
//  FesTracking2
//
//  Created by 松下和也 on 2025/05/08.
//

import SwiftUI
import ComposableArchitecture

struct InfoStoreView: View {
    let store: StoreOf<Info>
    var body: some View {
        NavigationStack{
            VStack{
                Text("info")
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
                    Text("紹介")
                        .bold()
                }
            }
        }
        
    }
}
