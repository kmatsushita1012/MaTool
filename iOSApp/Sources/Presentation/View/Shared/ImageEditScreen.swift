import ComposableArchitecture
import PhotosUI
import Shared
import SwiftUI
import UIKit

@available(iOS 17.0, *)
struct ImageEditScreen: View {
    @SwiftUI.Bindable var store: StoreOf<ImageEditFeature>

    var body: some View {
        ImageEditContentView(
            isStoreTarget: store.targetType == .store,
            targetType: store.targetType,
            selectedMode: $store.selectedMode,
            selectedPhotoItem: $store.selectedPhotoItem,
            previewData: store.previewData,
            previewURL: store.previewURL,
            hasImage: store.hasImage,
            isUploading: store.isUploading,
            isSaving: store.isSaving,
            failureMessage: store.failureMessages[store.selectedMode],
            onRemoveTapped: { store.send(.removeTapped) },
            onSaveTapped: { store.send(.saveTapped) },
            onCloseTapped: { store.send(.closeTapped) }
        )
        .alert($store.scope(state: \.alert, action: \.alert))
    }
}

@available(iOS 17.0, *)
struct ImageEditContentView: View {
    let isStoreTarget: Bool
    let targetType: ImageUploadTarget.Kind
    @Binding var selectedMode: ImageEditMode
    @Binding var selectedPhotoItem: PhotosPickerItem?
    let previewData: Data?
    let previewURL: String?
    let hasImage: Bool
    let isUploading: Bool
    let isSaving: Bool
    let failureMessage: String?
    let onRemoveTapped: () -> Void
    let onSaveTapped: () -> Void
    let onCloseTapped: () -> Void

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
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 24))
                    .padding(.horizontal)
                    .padding(.vertical, 8)
            }
        }
        .navigationTitle(navigationTitle)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if isStoreTarget {
                ToolbarSaveButton(
                    isDisabled: isUploading,
                    isLoading: isSaving,
                    action: onSaveTapped
                )
            } else {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("完了", action: onCloseTapped)
                        .disabled(isUploading)
                }
            }
        }
    }

    private var modePicker: some View {
        Picker("表示モード", selection: $selectedMode) {
            Text(ImageEditMode.light.title(for: targetType))
                .tag(isStoreTarget ? ImageEditMode.banner : .light)
            Text(ImageEditMode.dark.title(for: targetType))
                .tag(isStoreTarget ? ImageEditMode.interstitial : .dark)
        }
        .labelsHidden()
        .modifier(ImageEditSegmentPickerStyleModifier())
        .frame(maxWidth: .infinity)
        .disabled(isUploading || isSaving)
    }

    private var previewArea: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("プレビュー")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 8)

            preview
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(16)
                .background(.background, in: RoundedRectangle(cornerRadius: 24))
        }
        .padding(.horizontal, 16)
        .padding(.top, 16)
        .padding(.bottom, 8)
    }

    private var navigationTitle: String {
        guard isStoreTarget else { return "紹介画像" }
        return "\(selectedMode.title(for: targetType))広告"
    }

    private var actionsCard: some View {
        VStack(spacing: 0) {
            PhotosPicker(selection: $selectedPhotoItem, matching: .images) {
                Label(hasImage ? "画像を変更" : "画像を追加", systemImage: "photo")
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .loadingIndicator(isLoading: isUploading)
            .disabled(isSaving)
            .padding(.horizontal, 16)
            .padding(.vertical, 16)

            if hasImage {
                Divider()
                    .padding(.leading, 48)

                Button(role: .destructive, action: onRemoveTapped) {
                    Label("画像を削除", systemImage: "trash")
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .disabled(isUploading || isSaving)
                .padding(.horizontal, 16)
                .padding(.vertical, 16)
            }

            if let failureMessage {
                Text(failureMessage)
                    .font(.footnote)
                    .foregroundStyle(.red)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 16)
            }
        }
        .background(.background, in: RoundedRectangle(cornerRadius: 24))
    }

    @ViewBuilder
    private var preview: some View {
        if let previewData, let image = UIImage(data: previewData) {
            Image(uiImage: image)
                .resizable()
                .scaledToFit()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if let previewURL {
            WebImageView(imagePath: previewURL, contentMode: .fit)
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
            isStoreTarget: false,
            targetType: .festival,
            selectedMode: .constant(.light),
            selectedPhotoItem: .constant(nil),
            previewData: nil,
            previewURL: nil,
            hasImage: false,
            isUploading: false,
            isSaving: false,
            failureMessage: nil,
            onRemoveTapped: {},
            onSaveTapped: {},
            onCloseTapped: {}
        )
    }
}
