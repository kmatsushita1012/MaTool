//
//  PublicMapView.swift
//  MaTool
//
//  Created by 松下和也 on 2025/03/19.
//

import ComposableArchitecture
import SwiftUI
import Shared

struct PublicMapView: View {
    @SwiftUI.Bindable var store: StoreOf<PublicMapFeature>
    var isNavigationDisabled = false
    
    var body: some View {
        WithPerceptionTracking {
            Group {
                if let routeStore = store.scope(state: \.destination?.route, action: \.destination.route) {
                    mapContent(
                        routes: routeStore.routes,
                        selectedRouteId: routeStore.selected?.id,
                        selectedPeriodTitle: routeStore.selected?.text ?? "日程を選択",
                        isRouteLoading: routeStore.isRouteLoading,
                        isPeriodDisabled: store.isLoading,
                        toast: routeStore.toast,
                        onPeriodSelected: { routeStore.send(.selected($0)) },
                        onToastDismissed: { routeStore.send(.toastDismissed) }
                    ) {
                        PublicRouteMapView(
                            store: routeStore
                        )
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
                        PublicLocationsMapView(
                            store: locationsStore
                        )
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
        selectedRouteId: String? = nil,
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
            districtContentGroups: store.districtContentGroups,
            selectedContent: store.selectedContentItem,
            selectedRouteId: selectedRouteId,
            isLoading: store.isLoading,
            routes: routes,
            selectedPeriodTitle: selectedPeriodTitle,
            isRouteLoading: isRouteLoading,
            isPeriodDisabled: isPeriodDisabled,
            userRole: store.userRole,
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
    let districtContentGroups: [PublicMapFeature.DistrictContentGroup]
    let selectedContent: PublicMapFeature.Content
    let selectedRouteId: String?
    let isLoading: Bool
    let routes: [RouteEntry]?
    let selectedPeriodTitle: String
    let isRouteLoading: Bool
    let isPeriodDisabled: Bool
    let userRole: UserRole
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
                    .fixedSize(horizontal: false, vertical: true)
                    .background {
                        GeometryReader { geometry in
                            let controlsFrame = geometry.frame(in: .global)

                            if #available(iOS 26.0, *) {
                                Color.clear
                                    .glassEffect(.regular, in: .rect)
                                    .ignoresSafeArea(edges: [.top, .horizontal])
                                    .frame(width: geometry.size.width, height: controlsFrame.maxY + 8)
                                    .offset(y: -controlsFrame.minY)
                                    .allowsHitTesting(false)
                                    .accessibilityHidden(true)
                            }
                        }
                    }
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
                switch userRole {
                case .district, .headquarter:
                    Menu {
                        Button("管理者ページ", action: onAdminPageTapped)
                        Button("設定", action: onSettingsTapped)
                        Button("ログアウト", role: .destructive, action: onEmergencySignOutTapped)
                    } label: {
                        Image(systemName: "person.crop.circle")
                    } primaryAction: {
                        onAdminPageTapped()
                    }
                    .accessibilityLabel("管理者")
                    .disabled(isNavigationDisabled)
                case .advertiser:
                    Menu {
                        Button("広告主ページ", action: onAdminPageTapped)
                        Button("設定", action: onSettingsTapped)
                        Button("ログアウト", role: .destructive, action: onEmergencySignOutTapped)
                    } label: {
                        Image(systemName: "storefront")
                    } primaryAction: {
                        onAdminPageTapped()
                    }
                    .accessibilityLabel("広告主")
                    .disabled(isNavigationDisabled)
                case .guest:
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
            Menu {
                contentButton(for: .locations)
                ForEach(districtContentGroups) { group in
                    if let name = group.name {
                        Section(name) {
                            ForEach(group.contents) { item in
                                contentButton(for: item)
                            }
                        }
                    } else {
                        ForEach(group.contents) { item in
                            contentButton(for: item)
                        }
                    }
                }
            } label: {
                Label {
                    Text(selectedContent.displayTitle)
                        .lineLimit(1)
                        .truncationMode(.tail)
                } icon: {
                    Image(systemName: selectedContent.menuSymbol)
                }
                .labelStyle(.titleOnly)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .modifier(MapTopMenuStyle(isLiquidGlassDisabled: isLiquidGlassDisabled))
            .frame(maxWidth: .infinity, alignment: .leading)
            .loadingIndicator(isLoading: isLoading)

            if let routes {
                Menu {
                    ForEach(routes) { entry in
                        Button {
                            onPeriodSelected(entry)
                        } label: {
                            Label {
                                Text(entry.text)
                            } icon: {
                                Image(systemName: "checkmark")
                                    .tint(entry.id == selectedRouteId ? nil : .clear)
                            }
                        }
                    }
                } label: {
                    Label {
                        Text(selectedPeriodTitle)
                    } icon: {
                        Image(systemName: "calendar")
                    }
                }
                .modifier(MapTopMenuStyle(isLiquidGlassDisabled: isLiquidGlassDisabled))
                .fixedSize(horizontal: true, vertical: false)
                .layoutPriority(1)
                .disabled(isPeriodDisabled || isRouteLoading || routes.isEmpty)
                .overlay {
                    if isRouteLoading {
                        ProgressView()
                            .controlSize(.small)
                    }
                }
            }

        }
        .padding(.horizontal, 16)
    }

    private func contentButton(for item: PublicMapFeature.Content) -> some View {
        Button {
            guard item != selectedContent else { return }
            onContentSelected(item)
        } label: {
            Label {
                Text(item.displayTitle)
            } icon: {
                Image(systemName: "checkmark")
                    .tint(item == selectedContent ? nil : .clear)
            }
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
    var displayTitle: String {
        guard let subname, !subname.isEmpty else { return name }
        return "\(name)（\(subname)）"
    }

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
            districtContentGroups: [],
            selectedContent: .locations,
            selectedRouteId: nil,
            isLoading: false,
            routes: nil,
            selectedPeriodTitle: "日程を選択",
            isRouteLoading: false,
            isPeriodDisabled: false,
            userRole: .guest,
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
