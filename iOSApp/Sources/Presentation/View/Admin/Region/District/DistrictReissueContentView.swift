//
//  DistrictReissueContentView.swift
//  MaTool
//

import SwiftUI

@available(iOS 17.0, *)
struct DistrictReissueContentView: View {
    @Binding var email: String

    var body: some View {
        List {
            Section {
                TextField("メールアドレスを入力", text: $email)
                    .textContentType(.emailAddress)
                    .autocapitalization(.none)
                    .disableAutocorrection(true)
            } header: {
                Text("新しいメールアドレス")
            } footer: {
                Text("再発行すると既存アカウントは無効になり、ここで入力したメールアドレスで再登録が必要になります。")
            }
        }
    }
}
