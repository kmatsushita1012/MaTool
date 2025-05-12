//
//  AdminPointView.swift
//  FesTracking2
//
//  Created by 松下和也 on 2025/04/08.
//

import SwiftUI
import ComposableArchitecture

struct AdminPointView: View {
    @Bindable var store: StoreOf<AdminPointFeature>
    
    let savedTitles: [String] = ["ポンポコニャ","浮世囃子","伊勢音頭","六段くづし","木遣くづし","奴さん","休憩"]
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("イベント")) {
                    HStack{
                        TextField("イベントを入力", text: $store.item.title.nonOptional)
                            .popover(isPresented: $store.showPopover, content: {
                                Popover(items: savedTitles,textClosure: { $0 }, onTapGesture: { option in
                                    store.send(.titleOptionSelected(option))
                                    
                                }).presentationCompactAdaptation(PresentationAdaptation.popover)
                            })
                        Button(action: {
                            store.send(.titleFieldFocused)
                            }) {
                                Image(systemName: "ellipsis.circle")
                                    .font(.title2)
                            }
                    }
                }
                Section(header: Text("詳細")) {
                    TextField("説明を入力", text: $store.item.description.nonOptional)
                }
                
                Section(header: Text("時刻") ) {
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
                        Toggle("経路図（PDF）への出力", isOn: $store.item.shouldExport)
                    }
                }
            }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button{
                        store.send(.cancelButtonTapped)
                    } label: {
                        Text("キャンセル")
                    }
                    .padding(.horizontal, 8)
                }
                ToolbarItem(placement: .principal) {
                    Text("地点編集")
                        .bold()
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button{
                        store.send(.doneButtonTapped)
                    } label: {
                        Text("完了")
                            .bold()
                    }
                    .padding(.horizontal, 8)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.visible, for: .navigationBar)
        }
    }
}
#Preview{
    AdminPointView(store: Store(initialState: AdminPointFeature.State(item: Point.sample), reducer: { AdminPointFeature() }))
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

