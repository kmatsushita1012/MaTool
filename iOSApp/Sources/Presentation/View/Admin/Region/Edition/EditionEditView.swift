import ComposableArchitecture
import Shared
import SwiftUI

struct EditionEditScreen: View {
    @SwiftUI.Bindable var store: StoreOf<EditionEditFeature>

    var body: some View {
        EditionEditContentView(
            editionYear: store.edition.year,
            periods: store.periods,
            isActive: store.isActive,
            hasLoaded: store.hasLoaded,
            hasLoadError: store.hasLoadError,
            isBusy: store.isBusy,
            isSaving: store.isSaving,
            isActivating: store.isActivating,
            isDirty: store.isDirty,
            onPeriodTapped: { store.send(.periodTapped($0)) },
            onAddPeriodTapped: { store.send(.addPeriodTapped) },
            onSaveTapped: { store.send(.saveTapped) },
            onActivateTapped: { store.send(.activateTapped) },
            onCloseTapped: { store.send(.closeTapped) }
        )
        .navigationDestination(item: $store.scope(state: \.periodEditor, action: \.periodEditor)) {
            PeriodDraftEditView(store: $0)
        }
        .alert($store.scope(state: \.alert, action: \.alert))
        .task { store.send(.onAppear) }
    }
}

typealias EditionEditView = EditionEditScreen

struct EditionEditContentView: View {
    let editionYear: Int
    let periods: [Period]
    let isActive: Bool
    let hasLoaded: Bool
    let hasLoadError: Bool
    let isBusy: Bool
    let isSaving: Bool
    let isActivating: Bool
    let isDirty: Bool
    let onPeriodTapped: (Period) -> Void
    let onAddPeriodTapped: () -> Void
    let onSaveTapped: () -> Void
    let onActivateTapped: () -> Void
    let onCloseTapped: () -> Void

    var body: some View {
        Form {
            Section {
                LabeledContent("年度", value: String(editionYear) + "年")
                Button(activationButtonTitle, systemImage: activationButtonSystemImage) {
                    onActivateTapped()
                }
                .disabled(isBusy || !hasLoaded || isDirty || isActive)
                .loadingIndicator(isLoading: isActivating)
            }

            Section {
                if !hasLoaded {
                    if hasLoadError {
                        ContentUnavailableView {
                            Label("年度情報を取得できません", systemImage: "exclamationmark.triangle")
                        } description: {
                            Text("通信状態を確認してください。")
                        }
                    } else {
                        ProgressView("年度情報を取得中")
                    }
                } else if periods.isEmpty {
                    ContentUnavailableView {
                        Label("日程がありません", systemImage: "calendar.badge.plus")
                    }
                } else {
                    ForEach(periods) { period in
                        NavigationItemView(title: period.text) {
                            onPeriodTapped(period)
                        }
                        .disabled(isBusy)
                    }
                }

                if hasLoaded {
                    Button("日程を追加", systemImage: "plus", action: onAddPeriodTapped)
                        .disabled(isBusy)
                }
            } header: {
                Text("日程")
            }
        }
        .navigationTitle(Text(String(editionYear) + "年度"))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarCancelButton(action: onCloseTapped)
            ToolbarSaveButton(
                isDisabled: isBusy || !hasLoaded || !isDirty,
                isLoading: isSaving,
                action: onSaveTapped
            )
        }
    }

    private var activationButtonTitle: String {
        if isActivating { return "有効化中" }
        if isActive { return "有効化済み" }
        if isDirty { return "保存後に有効化可能" }
        if !hasLoaded { return "年度情報を読込中" }
        return "有効化可能"
    }

    private var activationButtonSystemImage: String {
        isActive ? "checkmark.circle.fill" : "checkmark.circle"
    }
}


#Preview {
    EditionEditContentView(
        editionYear: 2026,
        periods: [],
        isActive: false,
        hasLoaded: true,
        hasLoadError: false,
        isBusy: false,
        isSaving: false,
        isActivating: false,
        isDirty: false,
        onPeriodTapped: { _ in },
        onAddPeriodTapped: {},
        onSaveTapped: {},
        onActivateTapped: {},
        onCloseTapped: {}
    )
}
