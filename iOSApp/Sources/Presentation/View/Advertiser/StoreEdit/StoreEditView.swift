import ComposableArchitecture
import PhotosUI
import SwiftUI
import UIKit
import Shared

struct StoreEditScreen: View {
    @SwiftUI.Bindable var store: StoreOf<StoreEditFeature>
    @State private var selectedPhotoItem: PhotosPickerItem?

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
                coordinateText: store.coordinateText,
                hasStore: store.store != nil,
                bannerImagePath: store.bannerImagePath,
                bannerPreviewData: store.bannerPreviewData,
                isUploading: store.isUploading,
                isLoading: store.isLoading,
                ownerPaused: $store.ownerPaused,
                selectedPhotoItem: $selectedPhotoItem,
                onCoordinateTapped: { store.send(.coordinateTapped) },
                onBannerRemoveTapped: { store.send(.bannerRemoveTapped) },
                onCreditTapped: { store.send(.creditTapped) },
                onSaveTapped: { store.send(.saveTapped) }
            )
            .navigationDestination(
                item: $store.scope(state: \.destination?.coordinate, action: \.destination.coordinate)
            ) { coordinateStore in
                DistrictBaseEditView(store: coordinateStore)
            }
            .navigationDestination(
                item: $store.scope(state: \.destination?.credit, action: \.destination.credit)
            ) { creditStore in
                StoreCreditScreen(store: creditStore)
            }
            .alert($store.scope(state: \.alert, action: \.alert))
            .onChange(of: selectedPhotoItem) { _, item in
                guard let item else { return }
                store.send(.bannerPhotoSelected(StoreBannerPhotoSelection(id: UUID(), item: item)))
                selectedPhotoItem = nil
            }
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
    let coordinateText: String
    let hasStore: Bool
    let bannerImagePath: String?
    let bannerPreviewData: Data?
    let isUploading: Bool
    let isLoading: Bool
    @Binding var ownerPaused: Bool
    @Binding var selectedPhotoItem: PhotosPickerItem?
    let onCoordinateTapped: () -> Void
    let onBannerRemoveTapped: () -> Void
    let onCreditTapped: () -> Void
    let onSaveTapped: () -> Void

    var body: some View {
        Form {
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

                TextField("店名", text: $name)
                    .textInputAutocapitalization(.words)
                TextField("住所", text: $address)
                    .textContentType(.fullStreetAddress)
                TextField("営業時間", text: $businessHours)
                TextEditor(text: $description)
                    .frame(minHeight: 100)
            }

            Section("位置") {
                Button(action: onCoordinateTapped) {
                    LabeledContent("地図で指定", value: coordinateText)
                }
            }

            if hasStore {
                Section("広告") {
                    PhotosPicker(selection: $selectedPhotoItem, matching: .images) {
                        Label(bannerImagePath == nil ? "バナー画像を選択" : "バナー画像を変更", systemImage: "photo")
                    }
                    .disabled(isUploading || isLoading)

                    if isUploading {
                        ProgressView("画像をアップロード中")
                    } else if let image = previewImage {
                        image
                            .resizable()
                            .scaledToFit()
                            .frame(maxWidth: .infinity)
                            .frame(maxHeight: 150)
                    } else if let bannerImagePath {
                        WebImageView(imagePath: bannerImagePath, contentMode: .fit)
                            .frame(maxWidth: .infinity)
                            .frame(maxHeight: 150)
                    }

                    if bannerImagePath != nil {
                        Button("バナー画像を削除", role: .destructive, action: onBannerRemoveTapped)
                            .disabled(isUploading || isLoading)
                    }

                    Toggle("広告配信を一時停止", isOn: $ownerPaused)
                        .disabled(isLoading)
                }

                Section("クレジット") {
                    Button("残高・購入", action: onCreditTapped)
                        .disabled(isLoading || isUploading)
                }
            }
        }
        .navigationTitle(isNew ? "店舗登録" : "店舗編集")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("保存", action: onSaveTapped)
                    .disabled(isLoading || isUploading)
                    .loadingIndicator(isLoading: isLoading)
            }
        }
    }

    private var previewImage: Image? {
        guard let bannerPreviewData, let image = UIImage(data: bannerPreviewData) else { return nil }
        return Image(uiImage: image)
    }
}

struct StoreBannerPhotoSelection: Equatable {
    let id: UUID
    let item: PhotosPickerItem

    static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.id == rhs.id
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
            coordinateText: "",
            hasStore: false,
            bannerImagePath: nil,
            bannerPreviewData: nil,
            isUploading: false,
            isLoading: false,
            ownerPaused: .constant(false),
            selectedPhotoItem: .constant(nil),
            onCoordinateTapped: {},
            onBannerRemoveTapped: {},
            onCreditTapped: {},
            onSaveTapped: {}
        )
    }
}
