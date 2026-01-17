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
    let location: FloatLocation
    @FetchOne var district: District?
    
    init(_ location: FloatLocation) {
        self.location = location
        self._district = FetchOne(District.where{ $0.id == location.districtId })
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16){
            BulletItem(text: "\(district?.name ?? "") 屋台")
            BulletItem(text: location.timestamp.text())
            Spacer()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
    }
}
