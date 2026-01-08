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
            Section(){
                Picker("種類", selection: $store.type) {
                    ForEach(PointType.allCases, id: \.self) { type in
                        Text(type.title)
                    }
                }
            }
            
            switch store.type {
            case .checkpoint:
                checkpointForm
            case .performance:
                performanceForm
            case .start,
                .end,
                .rest:
                anchorForm
            case .waypoint:
                EmptyView()
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
    
    @ViewBuilder
    var checkpointForm: some View {
        Section("重要地点"){
            Picker("重要地点の種類", selection: $store.selectedCheckpoint) {
                ForEach(store.checkpoints) { checkpoint in
                    Text(checkpoint.name)
                }
            }
        }
        timeSection
    }
    
    @ViewBuilder
    var performanceForm: some View {
        Section("余興"){
            Picker("余興の種類", selection: $store.selectedPerformance) {
                ForEach(store.performances) { performance in
                    Text(performance.name)
                }
            }
        }
        nullableTimeSection
    }
    
    @ViewBuilder
    var anchorForm: some View {
        timeSection
    }
    
    @ViewBuilder
    var timePicker: some View {
        DatePicker(
            "時刻を選択",
            selection: $store.time.fullDate,
            displayedComponents: [.hourAndMinute]
        )
        .datePickerStyle(.compact)
    }
    
    @ViewBuilder
    var timeSection: some View {
        Section(
            header: Text("時刻")
        ) {
            timePicker
        }
    }
    
    @ViewBuilder
    var nullableTimeSection: some View {
        Section(
            header: Text("時刻")
        ) {
            Toggle("時刻を設定", isOn: $store.time.isPresent(default: { .now }))
            if store.time != nil {
                timePicker
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

