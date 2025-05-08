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
        NavigationStack{
            VStack {
                HStack {
                    Toggle("配信", isOn: $store.isTracking.sending(\.toggleChanged))
                        .padding()
                }
                LocationAdminMap(location: store.location)
                Text("履歴")
                    .font(.title3)
                    .bold()
                    .padding(.top)
                List(store.history.map{ $0.text }.reversed(), id: \.self) { text in
                    Text(text)
                        .font(.body)
                        .padding(.vertical, 2)
                }
                .listStyle(.plain)
            }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        store.send(.dismissButtonTapped)
                    } label: {
                        HStack {
                            Image(systemName: "chevron.left")
                            Text("戻る")
                        }
                        .padding(8)
                    }
                }
                ToolbarItem(placement: .principal) {
                    Text("位置情報配信")
                        .bold()
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .onAppear(){
                store.send(.onAppear)
            }
        }
    }
}
