//
//  PassageItemView.swift
//  MaTool
//
//  Created by 松下和也 on 2026/02/18.
//

import SwiftUI
import SQLiteData
import Shared

struct PassageItemView: View {
    let passage: RoutePassage
    @FetchOne var district: District?
    
    init(passage: RoutePassage) {
        self.passage = passage
        self._district = FetchOne(District.find(passage.districtId))
    }
    
    
    var body: some View {
        if let district {
            Text(district.name)
        } else {
            Text("データがありません")
        }
        
    }
}
