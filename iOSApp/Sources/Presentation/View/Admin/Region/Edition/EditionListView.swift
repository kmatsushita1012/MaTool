import ComposableArchitecture
import Shared
import SwiftUI

struct EditionListScreen: View {
    @SwiftUI.Bindable var store: StoreOf<EditionListFeature>

    var body: some View {
        EditionListContentView(
            editions: store.editions,
            activeEditionID: store.activeEditionID,
            isLoading: store.isLoading,
            hasLoadError: store.hasLoadError,
            isCreating: store.isCreating,
            isActivating: store.isActivating,
            isCreationAlertPresented: $store.isCreationAlertPresented,
            newEditionYearText: $store.newEditionYearText,
            onEditionTapped: { store.send(.editionTapped($0)) },
            onAddEditionTapped: { store.send(.addEditionTapped) },
            onCreateConfirmed: { store.send(.createConfirmed) },
            onCreateCancelled: { store.send(.createCancelled) },
            onAutoCreateTapped: { store.send(.autoCreateTapped) }
        )
        .fullScreenCover(item: $store.scope(state: \.destination?.edit, action: \.destination.edit)) { store in
            NavigationStack {
                EditionEditView(store: store)
            }
        }
        .alert($store.scope(state: \.alert, action: \.alert))
        .task { store.send(.onAppear) }
    }
}

typealias EditionListView = EditionListScreen

struct EditionListContentView: View {
    let editions: [Edition]
    let activeEditionID: Edition.ID?
    let isLoading: Bool
    let hasLoadError: Bool
    let isCreating: Bool
    let isActivating: Bool
    @Binding var isCreationAlertPresented: Bool
    @Binding var newEditionYearText: String
    let onEditionTapped: (Edition) -> Void
    let onAddEditionTapped: () -> Void
    let onCreateConfirmed: () -> Void
    let onCreateCancelled: () -> Void
    let onAutoCreateTapped: () -> Void

    var body: some View {
        List {
            if activeEditionID == nil, !editions.isEmpty {
                Section {
                    Label("有効な年度がありません", systemImage: "exclamationmark.circle")
                        .foregroundStyle(.secondary)
                }
            }

            Section("年度") {
                if isLoading && editions.isEmpty {
                    ProgressView("年度を取得中")
                } else if hasLoadError && editions.isEmpty {
                    ContentUnavailableView {
                        Label("年度一覧を取得できません", systemImage: "exclamationmark.triangle")
                    } description: {
                        Text("通信状態を確認してください。")
                    }
                } else if editions.isEmpty {
                    ContentUnavailableView {
                        Label("年度がありません", systemImage: "calendar.badge.plus")
                    } description: {
                        Text("右上の追加ボタンから年度を作成できます。")
                    }
                } else {
                    ForEach(editions) { edition in
                        NavigationItemView(
                            title: String(edition.year) + "年",
                            status: edition.id == activeEditionID ? "有効" : nil,
                            statusIconName: edition.id == activeEditionID ? "checkmark.circle.fill" : nil,
                            onTap: { onEditionTapped(edition) }
                        )
                        .disabled(isLoading || isCreating || isActivating)
                    }
                }
            }
        }
        .navigationTitle("年度一覧")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button(action: onAddEditionTapped) {
                    Label("年度を追加", systemImage: "plus")
                }
                .disabled(isLoading || isCreating || isActivating)
                .overlay {
                    if isCreating || isActivating {
                        ProgressView()
                            .controlSize(.small)
                    }
                }
            }
        }
        .alert("年度を追加", isPresented: $isCreationAlertPresented) {
            TextField("年度", text: $newEditionYearText)
                .keyboardType(.numberPad)
            Button("年度だけ作成", action: onCreateConfirmed)
            Button("年度と日程を自動作成", action: onAutoCreateTapped)
            Button("キャンセル", role: .cancel, action: onCreateCancelled)
        } message: {
            Text("年度を入力してください")
        }
    }
}

#Preview {
    EditionListContentView(
        editions: [Edition(id: "2026", festivalId: "preview", year: 2026)],
        activeEditionID: "2026",
        isLoading: false,
        hasLoadError: false,
        isCreating: false,
        isActivating: false,
        isCreationAlertPresented: .constant(false),
        newEditionYearText: .constant("2027"),
        onEditionTapped: { _ in },
        onAddEditionTapped: {},
        onCreateConfirmed: {},
        onCreateCancelled: {},
        onAutoCreateTapped: {}
    )
}
