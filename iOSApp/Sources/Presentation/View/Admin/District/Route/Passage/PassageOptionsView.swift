//
//  PassageOptionsView.swift
//  MaTool
//
//  Created by 松下和也 on 2026/02/18.
//

import SwiftUI
import Shared

@available(iOS 17.0, *)
struct PassageOptionsView: View {
    
    // FIXME: 永続化レイヤー再構築後に町一覧を取得する。
    var districts: [District] = []
    let myDistrictId: District.ID
    let selected: (_ districtId: District.ID?, _ memo: String?) -> Void
    @State private var memo: String = ""
    
    init(festivalId: Festival.ID, myDistrictId: District.ID, selected: @escaping (_ districtId: District.ID?, _ memo: String?) -> Void) {
        // FIXME: 永続化レイヤー再構築後に町一覧を取得する。
        self.districts = []
        self.myDistrictId = myDistrictId
        self.selected = selected
    }
    
    @Environment(\.dismiss) var dismiss
    
    private var normalizedMemo: String? {
        let value = memo.trimmingCharacters(in: .whitespacesAndNewlines)
        return value.isEmpty ? nil : value
    }
    
    private var isDoneEnabled: Bool {
        normalizedMemo != nil
    }
    
    private var prioritizedDistricts: [District] {
        districts.prioritizingForPassage(myDistrictId: myDistrictId)
    }
    
    var body: some View {
        List {
            Section {
                TextField("自由入力（例: 〇〇神社）", text: $memo, axis: .vertical)
            }
            
            Section("町一覧") {
                ForEach(prioritizedDistricts) { district in
                    Button(district.name){
                        selected(district.id, nil)
                        dismiss()
                    }
                    .tint(.primary)
                }
            }
        }
        .toolbar {
            ToolbarCancelButton {
                dismiss()
            }
            ToolbarDoneButton(isDisabled: !isDoneEnabled) {
                selected(nil, normalizedMemo)
                dismiss()
            }
            ToolbarItem(placement: .title){
                Text("通過する町を選択")
            }
        }
        .toolbarTitleDisplayMode(.inline)
    }
}
