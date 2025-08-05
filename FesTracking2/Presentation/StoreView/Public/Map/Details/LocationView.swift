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
        VStack{
            BulletItem(text: "\(item.districtName) 屋台")
            BulletItem(text: item.timestamp.text())
        }
    }
}
