import ComposableArchitecture
import PhotosUI
import SwiftUI
import Shared

@available(iOS 17.0, *)
struct ImageEditContentView: View {
    @SwiftUI.Bindable var store: StoreOf<ImageEditFeature>
    let onClose: () -> Void
    @State private var selectedItem: PhotosPickerItem?

    var body: some View {
        Form {
            Section {
                Picker(
                    "表示モード",
                    selection: Binding(
                        get: { store.selectedMode },
                        set: { store.send(.modeSelected($0)) }
                    )
                ) {
                    Text("ライト").tag(ImageEditFeature.Mode.light)
                    Text("ダーク").tag(ImageEditFeature.Mode.dark)
                }
                .pickerStyle(.segmented)
                .controlSize(.large)
                .disabled(store.isUploading)
            }

            Section("プレビュー") {
                preview
                    .frame(maxWidth: .infinity)
                    .frame(height: 240)
            }

            Section {
                PhotosPicker(
                    selection: $selectedItem,
                    matching: .images
                ) {
                    Label(store.hasImage ? "画像を変更" : "画像を追加", systemImage: "photo")
                }
                .disabled(store.isUploading)

                if store.hasImage {
                    Button("画像を削除", systemImage: "trash", role: .destructive) {
                        store.send(.removeTapped)
                    }
                    .disabled(store.isUploading)
                }

                if store.isUploading {
                    ProgressView("画像をアップロード中")
                }

                if case .failed(let data, let message) = store.state.draft(for: store.selectedMode) {
                    Text(message)
                        .foregroundStyle(.red)
                    if data != nil {
                        Button("再試行", systemImage: "arrow.clockwise") {
                            store.send(.retryTapped(id: UUID()))
                        }
                    }
                }
            }
        }
        .navigationTitle("紹介画像")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button(action: onClose) {
                    Image(systemName: "xmark")
                }
                .disabled(store.isUploading)
                .accessibilityLabel("閉じる")
            }
        }
        .onChange(of: selectedItem) { _, item in
            guard let item else { return }
            store.send(.photoSelected(id: UUID(), item: item))
            selectedItem = nil
        }
    }

    @ViewBuilder
    private var preview: some View {
        if let data = store.previewData, let image = UIImage(data: data) {
            Image(uiImage: image)
                .resizable()
                .aspectRatio(contentMode: .fit)
        } else if let path = store.previewURL {
            WebImageView(imagePath: path, contentMode: .fit)
        } else {
            ContentUnavailableView("画像がありません", systemImage: "photo")
        }
    }
}

#Preview {
    NavigationStack {
        ImageEditContentView(
            store: Store(
                initialState: ImageEditFeature.State(
                    targetType: .festival,
                    targetID: "preview",
                    image: ImagePath()
                )
            ) {
                ImageEditFeature()
            },
            onClose: {}
        )
    }
}
