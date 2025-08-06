//
//  LocationView.swift
//  FesTracking2
//
//  Created by 松下和也 on 2025/08/05.
//

import SwiftUI

struct LocationView: View {
    let item: LocationInfo
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16){
            BulletItem(text: "\(item.districtName) 屋台")
            BulletItem(text: item.timestamp.text())
            Spacer()
        }
        .frame(maxWidth: .infinity)
        .padding()
    }
}
