//
//  ProgramEditView.swift
//  MaTool
//
//  Created by 松下和也 on 2025/12/07.
//

import SwiftUI
import ComposableArchitecture

@available(iOS 17.0, *)
struct ProgramEditView: View {
    @SwiftUI.Bindable var store: StoreOf<ProgramEditFeature>
    @Dependency(\.values.isLiquidGlassEnabled) var isLiquidGlassEnabled: Bool
    
    var body: some View {
        content
            
            .toolbar{
                if #available(iOS 26.0, *), isLiquidGlassEnabled {
                    toolbarAfterLiquidGlass
                } else {
                    toolbarBeforeLiquidGlass
                }
            }
            .loadingOverlay(store.isLoading)
            .dismissible(backButton: false, edgeSwipe: false)
            .navigationTitle(store.mode.title)
            .navigationBarTitleDisplayMode(.inline)
            .navigationDestination(item: $store.scope(state: \.destination?.period, action: \.destination.period)) {
                PeriodEditView(store: $0)
            }
            .alert($store.scope(state: \.alert, action: \.alert))
    }
    
    @ViewBuilder
    var content: some View {
        Form {
            Section(
                header: Text("年")
            ){
                if store.isYearEditable {
                    YearPicker("年を選択", selection: $store.year)
                        .disabled(!store.isYearEditable)
                } else {
                    Text("\(String(store.year))年")
                }
            }
            Section(header: Text("タイトル")){
                TextField("タイトルを入力（任意）", text: $store.program.title)
            }
            Section(header: Text("時間帯")){
                ForEach(store.program.periods){ period in
                    NavigationItemView(title: period.text) {
                        store.send(.periodTapped(period))
                    }
                }
                Button("追加", systemImage: "plus.circle"){
                    store.send(.periodCreateTapped)
                }
            }
            Section{
                Button("削除", systemImage: "trash",  role: .destructive) {
                    store.send(.deleteTapped)
                }
                .foregroundStyle(.red)
            }
        }
    }
    
    @ViewBuilder
    var yearSectionFooter: some View {
        if !store.isYearEditable {
            Text("年の変更はできません。削除した上で新しい年を作成してください。")
        }
    }
    
    @ToolbarContentBuilder
    var toolbarBeforeLiquidGlass: some ToolbarContent {
        ToolbarItem(placement: .cancellationAction){
            Button("キャンセル", role: .cancel) {
                store.send(.cancelTapped)
            }
        }
        ToolbarItemGroup(placement: .confirmationAction) {
            Button {
                store.send(.periodCreateTapped)
            } label: {
                Text("追加")
            }
            Button {
                store.send(.saveTapped)
            } label: {
                Text("保存")
            }
        }
    }
    
    @ToolbarContentBuilder
    @available(iOS 26.0, *)
    var toolbarAfterLiquidGlass: some ToolbarContent {
        ToolbarItem(placement: .cancellationAction){
            Button(systemImage: "xmark") {
                store.send(.cancelTapped)
            }
        }
        ToolbarItem(placement: .primaryAction) {
            Button(systemImage: "plus") {
                store.send(.periodCreateTapped)
            }
        }
        ToolbarItem(placement: .confirmationAction) {
            Button(systemImage: "checkmark") {
                store.send(.saveTapped)
            }
        }
    }
}
