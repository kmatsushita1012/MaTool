import ComposableArchitecture
import Shared
import SwiftUI

struct StoreEditScreen: View {
    @SwiftUI.Bindable var store: StoreOf<StoreEditFeature>

    var body: some View {
        StoreEditContentView(
            festivals: store.festivals,
            selectedFestivalId: $store.selectedFestivalId,
            selectedFestival: store.festival,
            isNew: store.isNew,
            name: $store.name,
            address: $store.address,
            businessHours: $store.businessHours,
            description: $store.description,
            hasCoordinate: store.coordinate != nil,
            isLoading: store.isLoading,
            onCoordinateTapped: { store.send(.coordinateTapped) },
            onSaveTapped: { store.send(.saveTapped) }
        )
        .navigationDestination(
            item: $store.scope(state: \.destination?.coordinate, action: \.destination.coordinate)
        ) { coordinateStore in
            MapCoordinatePickerScreen(store: coordinateStore)
        }
        .alert($store.scope(state: \.alert, action: \.alert))
    }
}

struct StoreEditContentView: View {
    let festivals: [Festival]
    @Binding var selectedFestivalId: Festival.ID?
    let selectedFestival: Festival?
    let isNew: Bool
    @Binding var name: String
    @Binding var address: String
    @Binding var businessHours: String
    @Binding var description: String
    let hasCoordinate: Bool
    let isLoading: Bool
    let onCoordinateTapped: () -> Void
    let onSaveTapped: () -> Void

    var body: some View {
        List {
            Section("基本情報") {
                if isNew {
                    Picker("祭典", selection: $selectedFestivalId) {
                        ForEach(festivals) { festival in
                            Text(festival.name).tag(Optional(festival.id))
                        }
                    }
                } else if let selectedFestival {
                    LabeledContent("祭典", value: selectedFestival.name)
                }

                TextField("店舗名", text: $name)
                    .textInputAutocapitalization(.words)
                TextField("住所", text: $address)
                    .textContentType(.fullStreetAddress)
            }

            Section("営業時間") {
                TextEditor(text: $businessHours)
                    .frame(minHeight: 80)
                    .scrollContentBackground(.hidden)
                    .overlay(alignment: .topLeading) {
                        if businessHours.isEmpty {
                            Text("営業時間")
                                .foregroundStyle(.tertiary)
                                .padding(8)
                                .allowsHitTesting(false)
                        }
                    }
            }

            Section("説明") {
                TextEditor(text: $description)
                    .frame(minHeight: 80)
                    .scrollContentBackground(.hidden)
                    .overlay(alignment: .topLeading) {
                        if description.isEmpty {
                            Text("説明")
                                .foregroundStyle(.tertiary)
                                .padding(8)
                                .allowsHitTesting(false)
                        }
                    }
            }

            Section("位置") {
                NavigationItemView(
                    title: "地図で指定",
                    status: hasCoordinate ? "設定済み" : "未設定",
                    onTap: onCoordinateTapped
                )
                .disabled(isLoading)
            }
        }
        .navigationTitle(isNew ? "店舗を追加" : "基本情報を編集")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarSaveButton(isLoading: isLoading, action: onSaveTapped)
        }
    }
}

#Preview {
    NavigationStack {
        StoreEditContentView(
            festivals: [],
            selectedFestivalId: .constant(nil),
            selectedFestival: nil,
            isNew: true,
            name: .constant(""),
            address: .constant(""),
            businessHours: .constant(""),
            description: .constant(""),
            hasCoordinate: false,
            isLoading: false,
            onCoordinateTapped: {},
            onSaveTapped: {}
        )
    }
}
