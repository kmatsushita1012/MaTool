//
//  RouteEditScreen.swift
//  MaTool
//  Created by 松下和也 on 2025/08/01.
//

import ComposableArchitecture
import SwiftUI

@available(iOS 17.0, *)
struct RouteEditScreen: View {
    @Dependency(\.values.isLiquidGlassEnabled) var isLiquidGlassEnabled
    @SwiftUI.Bindable var store: StoreOf<RouteEditFeature>
    @State private var selectedDetent: PresentationDetent = .large

    var body: some View {
        WithPerceptionTracking {
            RouteEditContentView(
                tab: $store.tab,
                title: store.title,
                isLiquidGlassEnabled: isLiquidGlassEnabled,
                info: {
                    RouteEditInfoContentView(
                        route: $store.route,
                        districtName: store.district.name,
                        mode: store.mode,
                        periodText: store.period.text(dateFormat: "y/m/d (w)"),
                        timeText: routeTimeText,
                        passages: store.passages,
                        isAutoPassageDisabled: store.isAutoPassageDisabled,
                        isDeleteable: store.isDeleteable,
                        onAutoPassage: { store.send(.autoPassageTapped) },
                        onInsertAbove: { store.send(.passageInsertAboveTapped($0)) },
                        onInsertBelow: { store.send(.passageInsertBelowTapped($0)) },
                        onMoveUp: { store.send(.passageMoved(from: IndexSet(integer: $0), to: $0 - 1)) },
                        onMoveDown: { store.send(.passageMoved(from: IndexSet(integer: $0), to: $0 + 2)) },
                        onDeletePassage: { store.send(.passageDeleteTapped($0)) },
                        onMovePassages: { store.send(.passageMoved(from: $0, to: $1)) },
                        onAddPassage: { store.send(.passageAddTapped) },
                        onDeleteRoute: { store.send(.deleteTapped) }
                    )
                },
                map: {
                    MapView(
                        style: store.tab == .public ? .public : .edit,
                        points: store.pointEntries,
                        districtAreaOverlays: store.districtAreaOverlays,
                        showsDistrictAreaOverlay: store.isDistrictAreaOverlayVisible,
                        region: $store.region,
                        size: $store.size,
                        pointTapped: { store.send(.pointTapped($0)) },
                        onLongPress: { store.send(.mapLongPressed($0)) }
                    )
                }
            )
            .safeAreaInset(edge: .bottom) {
                if store.tab != .info {
                    Button {
                        store.send(.districtAreaOverlayTapped)
                    } label: {
                        Image(systemName: "square.grid.3x3.fill")
                            .padding()
                            .foregroundStyle(store.isDistrictAreaOverlayVisible ? Color.accent : Color.primary)
                    }
                    .accessibilityLabel("町域オーバーレイ")
                    .modifier(RouteOverlayGlassModifier(isLiquidGlassEnabled: isLiquidGlassEnabled))
                    .padding(.horizontal)
                    .frame(maxWidth: .infinity, alignment: .trailing)
                }
            }
            .toolbar {
                ToolbarSaveButton(
                    title: store.saveButtonTitle,
                    isDisabled: store.isConfirmDisabled,
                    isLoading: store.isLoading,
                    action: { store.send(.saveTapped) }
                )
                ToolbarCancelButton {
                    store.send(.cancelTapped)
                }
                if #available(iOS 26.0, *), isLiquidGlassEnabled {
                    if store.tab == .info {
                        ToolbarItem(placement: .bottomBar) {
                            Button("コピー", action: { store.send(.copyTapped) })
                        }
                    } else {
                        ToolbarItemGroup(placement: .bottomBar) {
                            Button(systemImage: "arrow.uturn.backward") {
                                store.send(.undoTapped)
                            }
                            .disabled(!store.canUndo)
                            Button(systemImage: "arrow.uturn.forward") {
                                store.send(.redoTapped)
                            }
                            .disabled(!store.canRedo)
                        }
                        ToolbarSpacer(placement: .bottomBar)
                        ToolbarItem(placement: .bottomBar) {
                            RouteLongPressModeContentView(operation: store.operation)
                        }
                    }
                    ToolbarSpacer(placement: .bottomBar)
                    ToolbarItem(placement: .bottomBar) {
                        RouteEditSubmitButton(
                            isLoading: store.isLoading,
                            isPartialEnabled: store.isPartialEnable,
                            isDialogPresented: $store.isSubmitDialogPresented,
                            onWhole: { store.send(.wholeTapped) },
                            onPartial: { store.send(.partialTapped) }
                        )
                    }
                } else {
                    ToolbarItem(placement: .bottomBar) {
                        HStack(alignment: .center, spacing: 16) {
                            if store.tab == .info {
                                Button("コピー", action: { store.send(.copyTapped) })
                            } else {
                                Button(systemImage: "arrow.uturn.backward") {
                                    store.send(.undoTapped)
                                }
                                .disabled(!store.canUndo)
                                Button(systemImage: "arrow.uturn.forward") {
                                    store.send(.redoTapped)
                                }
                                .disabled(!store.canRedo)
                                Spacer()
                                RouteLongPressModeContentView(operation: store.operation)
                            }
                            Spacer()
                            RouteEditSubmitButton(
                                isLoading: store.isLoading,
                                isPartialEnabled: store.isPartialEnable,
                                isDialogPresented: $store.isSubmitDialogPresented,
                                onWhole: { store.send(.wholeTapped) },
                                onPartial: { store.send(.partialTapped) }
                            )
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.horizontal)
                        .padding(.vertical, 4)
                    }
                }
            }
            .sheet(item: $store.scope(state: \.point, action: \.point)) { store in
                NavigationStack {
                    PointEditScreen(store: store)
                }
                .presentationDetents([.fraction(0.3), .fraction(0.5), .large], selection: $selectedDetent)
                .interactiveDismissDisabled()
            }
            .sheet(item: $store.destination) { destination in
                switch destination {
                case .preview(let item):
                    RoutePreviewScreen(item: item)
                case .history:
                    NavigationStack {
                        RouteHistoryView(.init(districtId: store.district.id, excludingRouteId: store.route.id) {
                            store.send(.sourceSelected($0))
                        })
                    }
                case .passage:
                    NavigationStack {
                        PassageOptionsView(festivalId: store.district.festivalId, myDistrictId: store.district.id) {
                            store.send(.passageSelected(districtId: $0, memo: $1))
                        }
                    }
                }
            }
            .alert($store.scope(state: \.alert?.notice, action: \.alert.notice))
            .alert($store.scope(state: \.alert?.delete, action: \.alert.delete))
            .onAppear {
                store.send(.onAppear)
            }
        }
    }

    private var routeTimeText: String? {
        guard let startTime = store.start?.time, let endTime = store.end?.time else { return nil }
        return "\(startTime.text) ~ \(endTime.text)"
    }
}

private struct RouteOverlayGlassModifier: ViewModifier {
    let isLiquidGlassEnabled: Bool

    @ViewBuilder
    func body(content: Content) -> some View {
        if #available(iOS 26.0, *), isLiquidGlassEnabled {
            content.glassEffect()
        } else {
            content
        }
    }
}
