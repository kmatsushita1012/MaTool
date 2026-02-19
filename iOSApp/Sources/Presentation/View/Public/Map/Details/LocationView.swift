//
//  LocationView.swift
//  MaTool
//
//  Created by 松下和也 on 2025/08/05.
//

import SwiftUI
import Shared
import SQLiteData

struct LocationView: View {
    let entry: FloatEntry
    
    init(_ entry: FloatEntry) {
        self.entry = entry
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16){
            BulletItem(text: "\(entry.district.name)")
            BulletItem(text: entry.floatLocation.timestamp.text())
            Spacer()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
    }
}
