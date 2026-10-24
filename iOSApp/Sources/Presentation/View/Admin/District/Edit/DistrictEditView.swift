//
//  DistrictEditView.swift
//  MaTool
//
//  Created by 松下和也 on 2025/04/16.
//

import SwiftUI
import ComposableArchitecture
import NavigationSwipeControl
import Shared

@available(iOS 17.0, *)
struct DistrictEditScreen: View {
    @SwiftUI.Bindable var store: StoreOf<DistrictEditFeature>

    var body: some View {
        DistrictEditContentView(
            name: Binding(
                get: { store.district.name },
                set: { store.send(.binding(.set(\.district.name, $0))) }
            ),
            description: Binding(
                get: { store.district.description ?? "" },
                set: { store.send(.binding(.set(\.district.description, $0.isEmpty ? nil : $0))) }
            ),
            visibility: Binding(
                get: { store.district.visibility },
                set: { store.send(.binding(.set(\.district.visibility, $0))) }
            ),
            visibilityLabel: { $0.label },
            performances: store.performances,
            onBaseTapped: { store.send(.baseTapped) },
            onAreaTapped: { store.send(.areaTapped) },
            onPerformanceEditTapped: { store.send(.performanceEditTapped($0)) },
            onPerformanceAddTapped: { store.send(.performanceAddTapped) },
            onCancelTapped: { store.send(.cancelTapped) },
            onSaveTapped: { store.send(.saveTapped) }
        )
        .dismissible(backButton: false, edgeSwipe: false)
        .navigationDestination(item: $store.scope(state: \.destination?.base, action: \.destination.base)) { store in
            DistrictBaseEditView(store: store)
        }
        .navigationDestination(item: $store.scope(state: \.destination?.area, action: \.destination.area)) { store in
            DistrictAreaEditView(store: store)
        }
        .navigationDestination(item: $store.scope(state: \.destination?.performance, action: \.destination.performance)) { store in
            PerformanceEditView(store: store)
        }
        .alert($store.scope(state: \.alert, action: \.alert))
        .loadingOverlay(store.isLoading)
    }
}

@available(iOS 17.0, *)
typealias DistrictEditView = DistrictEditScreen

@available(iOS 17.0, *)
struct DistrictEditContentView<VisibilityValue: Hashable & CaseIterable>: View {
    @Binding var name: String
    @Binding var description: String
    @Binding var visibility: VisibilityValue
    let visibilityLabel: (VisibilityValue) -> String
    let performances: [Performance]
    let onBaseTapped: () -> Void
    let onAreaTapped: () -> Void
    let onPerformanceEditTapped: (Performance) -> Void
    let onPerformanceAddTapped: () -> Void
    let onCancelTapped: () -> Void
    let onSaveTapped: () -> Void

    var body: some View {
        List {
            Section(
                header: Text("町名"),
                footer: Text("IDは更新できません")
            ) {
                TextField("町名を入力", text: $name)
            }
            Section(header: Text("紹介文")) {
                TextEditor(text: $description)
                    .frame(height: 120)
            }
            Section(header: Text("会所")) {
                Button(action: onBaseTapped) {
                    Label("地図で選択", systemImage: "map")
                        .font(.body)
                }
            }
            Section(header: Text("町域")) {
                Button(action: onAreaTapped) {
                    Label("地図で選択", systemImage: "map")
                        .font(.body)
                }
            }
            Section(header: Text("ルート"), footer: Text("最新年の全てのルートの公開範囲が変更されます")) {
                Picker("デフォルトの公開範囲", selection: $visibility) {
                    ForEach(Array(VisibilityValue.allCases), id: \.self) { option in
                        Text(visibilityLabel(option)).tag(option)
                    }
                }
                .pickerStyle(.menu)
            }
            Section(header: Text("余興")) {
                ForEach(performances) { item in
                    NavigationItemView(
                        title: item.name,
                        onTap: { onPerformanceEditTapped(item) }
                    )
                }
                Button(action: onPerformanceAddTapped) {
                    Label("追加", systemImage: "plus.circle")
                        .frame(maxWidth: .infinity, alignment: .center)
                }
            }
        }
        .navigationTitle("地区情報")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarCancelButton(action: onCancelTapped)
            ToolbarSaveButton(action: onSaveTapped)
        }
    }
}

#Preview {
    let visibility = District(id: "", name: "", festivalId: "", visibility: .route).visibility

    DistrictEditContentView(
        name: .constant(""),
        description: .constant(""),
        visibility: .constant(visibility),
        visibilityLabel: { $0.label },
        performances: [],
        onBaseTapped: {},
        onAreaTapped: {},
        onPerformanceEditTapped: { _ in },
        onPerformanceAddTapped: {},
        onCancelTapped: {},
        onSaveTapped: {}
    )
}
