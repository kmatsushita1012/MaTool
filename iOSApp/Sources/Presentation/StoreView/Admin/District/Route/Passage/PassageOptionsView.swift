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
    let selected: (District) -> Void
    
    init(festivalId: Festival.ID, selected: @escaping (District) -> Void) {
        self._districts = FetchAll(festivalId: festivalId)
        self.selected = selected
    }
    
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        List(districts) { district in
            Button(district.name){
                selected(district)
            }
            .tint(.primary)
        }
        .toolbar {
            ToolbarCancelButton {
                dismiss()
            }
            ToolbarItem(placement: .title){
                Text("通過する町を選択")
            }
        }
        .toolbarTitleDisplayMode(.inline)
    }
}
