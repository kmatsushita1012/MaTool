//
//  PassageOptionsView.swift
//  MaTool
//
//  Created by 松下和也 on 2026/02/18.
//

import SQLiteData
import SwiftUI
import Shared

@available(iOS 17.0, *)
struct PassageOptionsView: View {
    
    @FetchAll var districts: [District]
    let selected: (_ districtId: District.ID?, _ memo: String?) -> Void
    @State private var selectedDistrictId: District.ID?
    @State private var memo: String = ""
    
    init(festivalId: Festival.ID, selected: @escaping (_ districtId: District.ID?, _ memo: String?) -> Void) {
        self._districts = FetchAll(festivalId: festivalId)
        self.selected = selected
    }
    
    @Environment(\.dismiss) var dismiss
    
    private var normalizedMemo: String? {
        let value = memo.trimmingCharacters(in: .whitespacesAndNewlines)
        return value.isEmpty ? nil : value
    }
    
    private var isDoneEnabled: Bool {
        selectedDistrictId != nil || normalizedMemo != nil
    }
    
    var body: some View {
        List {
            Section {
                TextField("自由入力（例: 〇〇神社）", text: $memo, axis: .vertical)
            }
            
            Section("町一覧") {
                ForEach(districts) { district in
                    Button {
                        selectedDistrictId = district.id
                    } label: {
                        HStack {
                            Text(district.name)
                            Spacer()
                            if selectedDistrictId == district.id {
                                Image(systemName: "checkmark")
                                    .foregroundStyle(.accent)
                            }
                        }
                    }
                }
            }
        }
        .toolbar {
            ToolbarCancelButton {
                dismiss()
            }
            ToolbarSaveButton(isDisabled: !isDoneEnabled) {
                selected(selectedDistrictId, normalizedMemo)
            }
            ToolbarItem(placement: .title){
                Text("通過する町を選択")
            }
        }
        .toolbarTitleDisplayMode(.inline)
    }
}
