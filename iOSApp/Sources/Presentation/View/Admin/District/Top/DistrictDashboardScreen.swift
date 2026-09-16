//
//  DistrictDashboardView.swift
//  MaTool
//
//  Created by 松下和也 on 2025/04/17.
//

import SwiftUI
import ComposableArchitecture

@available(iOS 17.0, *)
struct DistrictDashboardScreen: View{
    @SwiftUI.Bindable var store: StoreOf<DistrictDashboardFeature>
    @Dependency(\.values.userGuideUrl) private var userGuideURLString
    @Dependency(\.values.contactURL) private var contactURLString

    private var userGuide: URL { URL(string: userGuideURLString)! }
    private var contact: URL { URL(string: contactURLString)! }

    var body: some View {
        WithPerceptionTracking {
            let contentState = DistrictDashboardContentState(
                districtName: store.district.name,
                routes: store.routes,
                isSubmissionExportLoading: store.isSubmissionExportLoading,
                isTableExportLoading: store.isTableExportLoading,
                isRouteLoading: store.isRouteLoading,
                isLocationLoading: store.isLocationLoading,
                isAWSLoading: store.isAWSLoading,
                userGuide: userGuide,
                contact: contact,
                version: AppStatusClient.getCurrentVersion()
            )
            let actions = DistrictDashboardActions(
                onEdit: { store.send(.onEdit) },
                onLocation: { store.send(.onLocation) },
                onRouteEdit: { store.send(.onRouteEdit($0)) },
                onSubmissionExport: { store.send(.submissionExportTapped) },
                onTableExport: { store.send(.tableExportTapped) },
                onChangePassword: { store.send(.changePasswordTapped) },
                onUpdateEmail: { store.send(.updateEmailTapped) },
                onSignOut: { store.send(.signOutTapped) }
            )

            DistrictDashboardContentView(state: contentState, actions: actions)
            .fullScreenCover(item: $store.scope(state: \.editDestination, action: \.editDestination)) { destination in
                switch destination.case {
                case .district(let store):
                    DistrictEditScreen(store: store)
                case .route(let store):
                    RouteEditScreen(store: store)
                }
            }
            .navigationDestination(item: $store.scope(state: \.destination, action: \.destination)) { destination in
                switch destination.case {
                case .location(let store):
                    LocationTrackingScreen(store: store)
                case .changePassword(let store):
                    ChangePasswordScreen(store: store)
                case .updateEmail(let store):
                    UpdateEmailScreen(store: store)
                }
            }
            .sheet(item: $store.url) { url in
                ShareSheet(item: url)
            }
            .alert($store.scope(state: \.alert, action: \.alert))
        }
    }
}
