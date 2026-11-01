import ComposableArchitecture
import PhotosUI
import SwiftUI
import Shared
import UIKit

@available(iOS 17.0, *)
struct ImageEditContentView: View {
    @SwiftUI.Bindable var store: StoreOf<ImageEditFeature>
    let onClose: () -> Void
    @State private var selectedItem: PhotosPickerItem?

    var body: some View {
        VStack(spacing: 0) {
            previewArea
                .frame(maxWidth: .infinity, maxHeight: .infinity)

            actionsCard
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .padding(.bottom, 8)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(uiColor: .systemGroupedBackground))
        .safeAreaInset(edge: .top, spacing: 0) {
            if #available(iOS 26.0, *) {
                modePicker
                    .glassEffect(.regular)
                    .padding(.horizontal)
                    .padding(.vertical, 8)
            } else {
                modePicker
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 24))
                    .padding(.horizontal)
                    .padding(.vertical, 8)
            }
        }
        .navigationTitle("紹介画像")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("完了", action: onClose)
                    .disabled(store.isUploading)
            }
        }
        .onChange(of: selectedItem) { _, item in
            guard let item else { return }
            store.send(.photoSelected(id: UUID(), item: item))
            selectedItem = nil
        }
    }

    private var modePicker: some View {
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
        .labelsHidden()
        .modifier(ImageEditSegmentPickerStyleModifier())
        .frame(maxWidth: .infinity)
        .disabled(store.isUploading)
    }

    private var previewArea: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("プレビュー")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 8)

            preview
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(12)
                .background(.background, in: RoundedRectangle(cornerRadius: 24))
        }
        .padding(.horizontal, 16)
        .padding(.top, 12)
        .padding(.bottom, 8)
    }

    private var actionsCard: some View {
        VStack(spacing: 0) {
            PhotosPicker(
                selection: $selectedItem,
                matching: .images
            ) {
                Label(store.hasImage ? "画像を変更" : "画像を追加", systemImage: "photo")
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .disabled(store.isUploading)
            .padding(.horizontal, 16)
            .padding(.vertical, 16)

            if store.hasImage {
                Divider()
                    .padding(.leading, 48)

                Button(role: .destructive) {
                    store.send(.removeTapped)
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "trash")
                            .foregroundStyle(.red)
                        Text("画像を削除")
                            .foregroundStyle(.red)
                        Spacer(minLength: 0)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .contentShape(Rectangle())
                }
                .tint(.red)
                .buttonStyle(.plain)
                .disabled(store.isUploading)
                .padding(.horizontal, 16)
                .padding(.vertical, 16)
            }

            if store.isUploading {
                ProgressView("画像をアップロード中")
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
            }

            if let message = store.state.failureMessage(for: store.selectedMode) {
                Text(message)
                    .font(.footnote)
                    .foregroundStyle(.red)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
            }
        }
        .background(.background, in: RoundedRectangle(cornerRadius: 24))
    }

    @ViewBuilder
    private var preview: some View {
        if let data = store.previewData, let image = UIImage(data: data) {
            Image(uiImage: image)
                .resizable()
                .scaledToFit()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if let path = store.previewURL {
            WebImageView(imagePath: path, contentMode: .fit)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            ContentUnavailableView("画像がありません", systemImage: "photo")
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}

private struct ImageEditSegmentPickerStyleModifier: ViewModifier {
    init() {
        UISegmentedControl.appearance().setTitleTextAttributes(
            [.font: UIFont.preferredFont(forTextStyle: .body)],
            for: .normal
        )
        UISegmentedControl.appearance().setTitleTextAttributes(
            [.font: UIFont.preferredFont(forTextStyle: .headline)],
            for: .selected
        )
    }

    func body(content: Content) -> some View {
        content
            .pickerStyle(.segmented)
            .controlSize(.large)
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
