//
//  PublicMapView.swift
//  MaTool
//
//  Created by 松下和也 on 2025/03/19.
//

import ComposableArchitecture
import SwiftUI

struct PublicMapView: View {
    @SwiftUI.Bindable var store: StoreOf<PublicMapFeature>
    var isAdminLoggedIn = false
    var isNavigationDisabled = false
    
    var body: some View {
        WithPerceptionTracking {
            Group {
                if let routeStore = store.scope(state: \.destination?.route, action: \.destination.route) {
                    mapContent(
                        routes: routeStore.routes,
                        selectedRouteId: routeStore.selectedRouteId,
                        selectedPeriodTitle: routeStore.selected?.text ?? "日程を選択",
                        isRouteLoading: routeStore.isRouteLoading,
                        isPeriodDisabled: store.isLoading,
                        toast: routeStore.toast,
                        onPeriodSelected: { routeStore.send(.selected($0)) },
                        onToastDismissed: { routeStore.send(.toastDismissed) }
                    ) {
                        PublicRouteMapView(store: routeStore)
                            .id(routeStore.district.id)
                    }
                } else if let locationsStore = store.scope(
                    state: \.destination?.locations,
                    action: \.destination.locations
                ) {
                    mapContent(
                        toast: locationsStore.toast,
                        onToastDismissed: { locationsStore.send(.toastDismissed) }
                    ) {
                        PublicLocationsMapView(store: locationsStore)
                    }
                } else {
                    Spacer()
                }
            }
            .onAppear { store.send(.onAppear) }
        }
    }

    private func mapContent<MapContent: View>(
        routes: [RouteEntry]? = nil,
        selectedRouteId: RouteEntry.ID? = nil,
        selectedPeriodTitle: String = "日程を選択",
        isRouteLoading: Bool = false,
        isPeriodDisabled: Bool = false,
        toast: MapToast? = nil,
        onPeriodSelected: @escaping (RouteEntry) -> Void = { _ in },
        onToastDismissed: @escaping () -> Void = {},
        @ViewBuilder content: @escaping () -> MapContent
    ) -> some View {
        PublicMapContentView(
            festivalTitle: store.festivalTitle,
            contents: store.contents,
            selectedContent: store.selectedContent,
            contentTitles: store.contentTitles,
            isLoading: store.isLoading,
            routes: routes,
            selectedRouteId: selectedRouteId,
            selectedPeriodTitle: selectedPeriodTitle,
            isRouteLoading: isRouteLoading,
            isPeriodDisabled: isPeriodDisabled,
            isAdminLoggedIn: isAdminLoggedIn,
            isNavigationDisabled: isNavigationDisabled,
            toast: toast,
            onAdminPageTapped: { store.send(.delegate(.settingsOrAdminTapped)) },
            onSettingsTapped: { store.send(.delegate(.settingsTapped)) },
            onEmergencySignOutTapped: { store.send(.delegate(.emergencySignOutTapped)) },
            onIntroductionTapped: { store.send(.delegate(.introductionTapped)) },
            onContentSelected: { store.send(.contentSelected($0)) },
            onPeriodSelected: onPeriodSelected,
            onToastDismissed: onToastDismissed,
            mapContent: content
        )
    }

}

struct PublicMapContentView<MapContent: View>: View {
    let festivalTitle: String
    let contents: [PublicMapFeature.Content]
    let selectedContent: PublicMapFeature.Content
    let contentTitles: [PublicMapFeature.Content: String]
    let isLoading: Bool
    let routes: [RouteEntry]?
    let selectedRouteId: RouteEntry.ID?
    let selectedPeriodTitle: String
    let isRouteLoading: Bool
    let isPeriodDisabled: Bool
    let isAdminLoggedIn: Bool
    let isNavigationDisabled: Bool
    let toast: MapToast?
    let onAdminPageTapped: () -> Void
    let onSettingsTapped: () -> Void
    let onEmergencySignOutTapped: () -> Void
    let onIntroductionTapped: () -> Void
    let onContentSelected: (PublicMapFeature.Content) -> Void
    let onPeriodSelected: (RouteEntry) -> Void
    let onToastDismissed: () -> Void
    @ViewBuilder let mapContent: () -> MapContent
    @Environment(\.isLiquidGlassDisabled) private var isLiquidGlassDisabled

    var body: some View {
        ZStack {
            mapContent()
                .ignoresSafeArea(.all)
        }
        .safeAreaInset(edge: .top, spacing: 0) {
            VStack(alignment: .leading, spacing: 16) {
                topControls
                if let toast {
                    MapToastView(toast: toast, onDismiss: onToastDismissed)
                        .transition(.opacity)
                }
            }
            .animation(.easeInOut(duration: 0.2), value: toast)
        }
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Text(festivalTitle)
                    .font(.title2)
                    .bold()
                    .lineLimit(1)
                    .fixedSize(horizontal: true, vertical: false)
            }
            .hideSharedBackgroundVisibility()
            ToolbarItem(placement: .topBarTrailing) {
                Button(selectedContent == .locations ? "祭紹介" : "町紹介", action: onIntroductionTapped)
                    .disabled(isNavigationDisabled)
            }
            if #available(iOS 26.0, *) {
                ToolbarSpacer(.fixed, placement: .topBarTrailing)
            }
            ToolbarItem(placement: .topBarTrailing) {
                if isAdminLoggedIn {
                    Menu {
                        Button(action: onAdminPageTapped) {
                            MapMenuItemLabel(title: "管理者ページ", systemImage: "person.crop.circle")
                        }
                        Button(action: onSettingsTapped) {
                            MapMenuItemLabel(title: "設定", systemImage: "gearshape")
                        }
                        Button(role: .destructive, action: onEmergencySignOutTapped) {
                            MapMenuItemLabel(title: "ログアウト", systemImage: "rectangle.portrait.and.arrow.right")
                        }
                    } label: {
                        Image(systemName: "person.crop.circle")
                    } primaryAction: {
                        onAdminPageTapped()
                    }
                    .accessibilityLabel("管理者")
                    .disabled(isNavigationDisabled)
                } else {
                    Button(action: onSettingsTapped) {
                        Image(systemName: "gearshape")
                    }
                    .accessibilityLabel("設定")
                    .disabled(isNavigationDisabled)
                }
            }
        }
        .toolbarBackground(.hidden, for: .navigationBar)
    }

    private var topControls: some View {
        HStack(spacing: 16) {
            Picker(
                selection: Binding(
                    get: { selectedContent },
                    set: onContentSelected
                )
            ) {
                ForEach(contents, id: \.self) { item in
                    Text(contentTitles[item] ?? "")
                        .tag(item)
                }
            } label: {
                Text(contentTitles[selectedContent] ?? "")
            }
            .pickerStyle(.menu)
            .padding()
            .modifier(MapTopMenuStyle(isLiquidGlassDisabled: isLiquidGlassDisabled))
            .loadingIndicator(isLoading: isLoading)

            if let routes {
                Picker(
                    selection: Binding<RouteEntry.ID?>(
                        get: { selectedRouteId },
                        set: { selectedID in
                            guard let selectedID,
                                  let entry = routes.first(where: { $0.id == selectedID }) else { return }
                            onPeriodSelected(entry)
                        }
                    )
                ) {
                    ForEach(routes) { entry in
                        Text(entry.text)
                            .tag(Optional(entry.id))
                    }
                } label: {
                    Text(selectedPeriodTitle)
                }
                .pickerStyle(.menu)
                .padding()
                .modifier(MapTopMenuStyle(isLiquidGlassDisabled: isLiquidGlassDisabled))
                .disabled(isPeriodDisabled || isRouteLoading || routes.isEmpty)
                .overlay {
                    if isRouteLoading {
                        ProgressView()
                            .controlSize(.small)
                    }
                }
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 16)
    }
}

private struct MapMenuItemLabel: View {
    let title: String
    let systemImage: String

    var body: some View {
        Label(title, systemImage: systemImage)
            .modifier(MapMenuLabelIconWidth())
    }
}

private struct MapMenuLabelIconWidth: ViewModifier {
    @ViewBuilder
    func body(content: Content) -> some View {
        if #available(iOS 26.0, *) {
            content.labelReservedIconWidth(44)
        } else {
            content
        }
    }
}

private struct MapTopMenuStyle: ViewModifier {
    let isLiquidGlassDisabled: Bool

    @ViewBuilder
    func body(content: Content) -> some View {
        if #available(iOS 26.0, *), !isLiquidGlassDisabled {
            content
                .menuStyle(.button)
                .buttonStyle(.glass)
                .buttonSizing(.fitted)
                .controlSize(.large)
        } else {
            content
                .menuStyle(.button)
                .buttonStyle(.bordered)
                .controlSize(.large)
        }
    }
}

private extension PublicMapFeature.Content {
    var menuSymbol: String {
        switch self {
        case .locations: "mappin.and.ellipse"
        case .route(_): "map"
        }
    }
}

#Preview {
    NavigationStack {
        PublicMapContentView(
            festivalTitle: "祭典名",
            contents: [.locations],
            selectedContent: .locations,
            contentTitles: [.locations: "現在地一覧"],
            isLoading: false,
            routes: nil,
            selectedRouteId: nil,
            selectedPeriodTitle: "日程を選択",
            isRouteLoading: false,
            isPeriodDisabled: false,
            isAdminLoggedIn: false,
            isNavigationDisabled: false,
            toast: nil,
            onAdminPageTapped: {},
            onSettingsTapped: {},
            onEmergencySignOutTapped: {},
            onIntroductionTapped: {},
            onContentSelected: { _ in },
            onPeriodSelected: { _ in },
            onToastDismissed: {}
        ) {
            Color.gray
        }
    }
}
