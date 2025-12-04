//
//  AdminPointEditStoreView.swift
//  MaTool
//
//  Created by 松下和也 on 2025/04/08.
//

import SwiftUI
import ComposableArchitecture
import NavigationSwipeControl
import Shared

@available(iOS 17.0, *)
struct AdminPointEditStoreView: View {
    
    @Dependency(\.values.isLiquidGlassEnabled) var isLiquidGlassEnabled: Bool
    @SwiftUI.Bindable var store: StoreOf<AdminPointEdit>
    
    var body: some View {
        Form {
            Section(header: Text("イベント")) {
                HStack{
                    TextField("イベントを入力", text: $store.item.title.nonOptional)
                        .popover(isPresented: $store.showPopover, content: {
                            Popover(items: store.milestones, textClosure: { $0.name }, onTapGesture: { option in
                                store.send(.titleOptionSelected(option))
                            }).presentationCompactAdaptation(PresentationAdaptation.popover)
                        })
                    Button(action: {
                        store.send(.titleFieldFocused)
                        }) {
                            Image(systemName: "ellipsis")
                                .font(.title2)
                        }
                }
            }
            Section(header: Text("詳細")) {
                TextEditor(text: $store.item.description.nonOptional)
                    .frame(height:60)
            }
            
            Section(
                header: Text("時刻"),
                footer: Text("先頭および末尾の地点は「経路図（PDF）への出力」がオフでも自動的に経路図に出力されます。時刻は前画面で設定した開始時刻もしくは終了時刻が適用されます。オンの場合はこの画面の「時刻を設定」で設定した時刻が適用されます。")
            ) {
                Toggle("時刻を設定", isOn: Binding(
                    get: { store.item.time != nil },
                    set: { hasTime in
                        store.send(.binding(.set(
                            \.item.time,
                             hasTime ? SimpleTime.fromDate(Date()) : nil
                        )))
                    }
                ))
                if store.item.time != nil {
                    DatePicker(
                        "時刻を選択",
                        selection: $store.item.time.fullDate,
                        displayedComponents: [.hourAndMinute]
                    )
                    .datePickerStyle(.compact)
                }
                Toggle("経路図（PDF）への出力", isOn: $store.item.shouldExport)
            }
            
            Section {
                Button(action: {
                    store.send(.moveTapped)
                }) {
                    Label("この地点を移動", systemImage: "line.diagonal.arrow")
                        .font(.body)
                }
                Button(action: {
                    store.send(.insertTapped)
                }) {
                    Label("この地点の前に新しい地点を挿入", systemImage: "plus.circle")
                        .font(.body)
                }
            }
            Section {
                Button(action: {
                    store.send(.deleteTapped)
                }) {
                    Label("この地点を削除", systemImage: "trash")
                        .font(.body)
                        .foregroundStyle(.red)
                }
            }
        }
        .navigationTitle("地点")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if #available(iOS 26.0, *), isLiquidGlassEnabled{
                toolbarAfterLiquidGlass
            } else {
                toolbarBeforeLiquidGlass
            }
        }
    }
    
    @ToolbarContentBuilder
    var toolbarBeforeLiquidGlass: some ToolbarContent {
        ToolbarItem(placement: .confirmationAction) {
            Button{
                store.send(.doneTapped)
            } label: {
                Text("完了")
                    .bold()
            }
            .padding(.horizontal, 8)
        }
    }
    
    @ToolbarContentBuilder
    var toolbarAfterLiquidGlass: some ToolbarContent {
        ToolbarItem(placement: .confirmationAction) {
            Button(systemImage: "xmark"){
                store.send(.doneTapped)
            }
        }
    }
}


struct Popover<T: Hashable> : View{
    let items: [T]
    let textClosure: (T)->String
    let onTapGesture: (T)->Void
    
    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                ForEach(items.indices, id: \.self) { index in
                    let item = items[index]
                    
                    VStack(spacing: 0) {
                        Text(textClosure(item))
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(8)
                            .contentShape(Rectangle())
                            .onTapGesture {
                                onTapGesture(item)
                            }
                        if index != items.count - 1 {
                            Divider()
                        }
                    }
                }
            }
            .background(Color.white)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.gray.opacity(0.2))
            )
        }
        .frame(maxHeight: 300)
    }
}

