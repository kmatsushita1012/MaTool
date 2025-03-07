//
//  DistrictManagementReducer.swift
//  FesTracking2
//
//  Created by 松下和也 on 2025/03/06.
//

//state 共通
struct DistrictAdminState: Equatable {
    var district: District
    var summaries: [Route]
    var isLoading: Bool = false
    var errorMessage: String?
}

enum DistrictAdminAction: Equatable{
    case edit
}

