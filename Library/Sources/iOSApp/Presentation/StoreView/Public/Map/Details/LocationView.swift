//
//  LocationView.swift
//  MaTool
//
//  Created by 松下和也 on 2025/08/05.
//

import SwiftUI
import Shared

struct LocationView: View {
    let item: FloatLocationGetDTO
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16){
            BulletItem(text: "\(item.districtName) 屋台")
            BulletItem(text: item.timestamp.text())
            Spacer()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
    }
}
