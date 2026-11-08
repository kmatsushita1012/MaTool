import ComposableArchitecture
import SwiftUI
import Shared

struct StoreEditScreen: View {
    @SwiftUI.Bindable var store: StoreOf<StoreEditFeature>

    var body: some View {
        WithPerceptionTracking {
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
        AdvertiserGroupedPage {
            AdvertiserSection(title: "基本情報") {
                if isNew {
                    HStack(spacing: 12) {
                        Text("祭典")
                            .font(.subheadline)
                            .foregroundStyle(Color(uiColor: .label))
                            .frame(width: 85, alignment: .leading)
                        Spacer(minLength: 0)
                        Picker("祭典", selection: $selectedFestivalId) {
                            ForEach(festivals) { festival in
                                Text(festival.name).tag(Optional(festival.id))
                            }
                        }
                        .labelsHidden()
                        .pickerStyle(.menu)
                    }
                    .frame(minHeight: 54)
                    .padding(.horizontal, 18)
                } else if let selectedFestival {
                    HStack {
                        Text("祭典")
                            .font(.subheadline)
                        Spacer()
                        Text(selectedFestival.name)
                            .font(.subheadline)
                            .foregroundStyle(Color(uiColor: .secondaryLabel))
                    }
                    .frame(minHeight: 54)
                    .padding(.horizontal, 18)
                }

                AdvertiserRowSeparator()

                HStack(spacing: 12) {
                    Text("店舗名")
                        .font(.subheadline)
                        .frame(width: 85, alignment: .leading)
                    TextField("店舗名", text: $name)
                        .textInputAutocapitalization(.words)
                }
                .padding(.horizontal, 18)
                .frame(minHeight: 54)

                AdvertiserRowSeparator()

                HStack(spacing: 12) {
                    Text("住所")
                        .font(.subheadline)
                        .frame(width: 85, alignment: .leading)
                    TextField("住所", text: $address)
                        .textContentType(.fullStreetAddress)
                }
                .padding(.horizontal, 18)
                .frame(minHeight: 54)

                AdvertiserRowSeparator()

                TextEditor(text: $businessHours)
                    .scrollContentBackground(.hidden)
                    .frame(minHeight: 80)
                    .overlay(alignment: .topLeading) {
                        if businessHours.isEmpty {
                            Text("営業時間")
                                .foregroundStyle(Color(uiColor: .tertiaryLabel))
                                .padding(.top, 8)
                                .padding(.leading, 5)
                                .allowsHitTesting(false)
                        }
                    }
                    .padding(.horizontal, 18)
                    .padding(.vertical, 6)

                AdvertiserRowSeparator()

                TextEditor(text: $description)
                    .scrollContentBackground(.hidden)
                    .frame(minHeight: 100)
                    .overlay(alignment: .topLeading) {
                        if description.isEmpty {
                            Text("説明")
                                .foregroundStyle(Color(uiColor: .tertiaryLabel))
                                .padding(.top, 8)
                                .padding(.leading, 5)
                                .allowsHitTesting(false)
                        }
                    }
                    .padding(.horizontal, 18)
                    .padding(.vertical, 6)
            }

            AdvertiserSection(title: "位置") {
                AdvertiserNavigationRow(
                    title: "地図で指定",
                    value: hasCoordinate ? "設定済み" : nil,
                    action: onCoordinateTapped
                )
            }
        }
        .navigationTitle(isNew ? "店舗を追加" : "基本情報を編集")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarSaveButton(isDisabled: false, isLoading: isLoading, action: onSaveTapped)
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
