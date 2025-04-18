//
//  LocationAdminView.swift
//  FesTracking2
//
//  Created by 松下和也 on 2025/04/17.
//

import SwiftUI
import ComposableArchitecture

struct LocationAdminView: View {
    @Bindable var store: StoreOf<LocationAdminFeature>
    
    var body: some View {
        VStack {
            HStack {
                Toggle("位置情報共有", isOn: $store.isTracking.sending(\.toggleChanged))
                .padding()
            }
            .padding()
            LocationAdminMapView()
            Text("\(store.location)")
            Text("送信ログ")
                .font(.headline)
                .padding(.top)
            List(store.logs.reversed(), id: \.self) { log in
                Text(log)
                    .font(.caption)
                    .padding(.vertical, 2)
            }
            .listStyle(.plain)
        }
        .onAppear(){
            store.send(.onAppear)
        }
    }
}
