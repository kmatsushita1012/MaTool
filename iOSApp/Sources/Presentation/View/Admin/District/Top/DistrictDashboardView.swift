//
//  DistrictDashboardView.swift
//  MaTool
//
//  Created by 松下和也 on 2025/04/17.
//

import SwiftUI
import ComposableArchitecture
import NavigationSwipeControl

@available(iOS 17.0, *)
struct DistrictDashboardView: View{
    @SwiftUI.Bindable var store: StoreOf<DistrictDashboardFeature>
    
    var body: some View {
        content
            .navigationDestination(item: $store.scope(state: \.destination, action: \.destination)){ destination in
                switch destination.case {
                case .edit(let store):
                    DistrictEditView(store: store)
                case .location(let store):
                    LocationTrackingView(store: store)
                case .route(let store):
                    RouteEditView(store: store)
                case .changePassword(let store):
                    ChangePasswordView(store: store)
                case .updateEmail(let store):
                    UpdateEmailView(store: store)
                }
            }
            .sheet(item: $store.url) { url in
                ShareSheet(item: url)
            }
            .alert($store.scope(state: \.alert, action: \.alert))
            .loadingOverlay(store.isRouteLoading || store.isAWSLoading)
        
    }
    
    @ViewBuilder
    var content: some View {
        List {
            Section {
                NavigationItemView(
                    title: "地区情報",
                    iconName: "info.circle" ,
                    onTap: {
                        store.send(.onEdit)
                    })
                NavigationItemView(
                    title: "位置情報配信",
                    iconName: "mappin.and.ellipse",
                    onTap: {
                        store.send(.onLocation)
                    }
                )
            }
            Section(header: Text("行動")){
                ForEach(store.routes) { pair in
                    RouteSlotView(
                        pair,
                        onTap: { store.send(.onRouteEdit(pair)) }
                    )
                }
            }
            Section(header: Text("ルート出力")) {
                loadingButton(
                    "提出資料出力",
                    showsProgress: store.isSubmissionExportLoading,
                    isDisabled: store.isSubmissionExportLoading || store.isTableExportLoading
                ) {
                    store.send(.submissionExportTapped)
                }
                loadingButton(
                    "行動表出力",
                    showsProgress: store.isTableExportLoading,
                    isDisabled: store.isSubmissionExportLoading || store.isTableExportLoading
                ) {
                    store.send(.tableExportTapped)
                }
            }
            Section {
                Button(action: {
                    store.send(.changePasswordTapped)
                }) {
                    Text("パスワード変更")
                }
                Button(action: {
                    store.send(.updateEmailTapped)
                }) {
                    Text("メールアドレス変更")
                }
            }
            Section {
                Button(action: {
                    store.send(.signOutTapped)
                }) {
                    Text("ログアウト")
                        .foregroundColor(.red)
                }
            }
        }
        .navigationTitle(
            store.district.name
        )
        .navigationBarTitleDisplayMode(.large)
    }

    @ViewBuilder
    private func loadingButton(
        _ title: String,
        showsProgress: Bool,
        isDisabled: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Text(title)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .overlay(alignment: .trailing) {
            if showsProgress {
                ProgressView()
                    .controlSize(.small)
            }
        }
        .disabled(isDisabled)
    }
}
