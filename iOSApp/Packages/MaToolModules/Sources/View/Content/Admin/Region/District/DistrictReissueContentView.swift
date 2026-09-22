import iOSShared
//
//  DistrictReissueContentView.swift
//  MaTool
//

import SwiftUI

@available(iOS 17.0, *)
public struct DistrictReissueContentView: View {
    @Binding var email: String
    let isLoading: Bool
    let onCancel: () -> Void
    let onReissue: () -> Void

    public init(
        email: Binding<String>,
        isLoading: Bool,
        onCancel: @escaping () -> Void,
        onReissue: @escaping () -> Void
    ) {
        self._email = email
        self.isLoading = isLoading
        self.onCancel = onCancel
        self.onReissue = onReissue
    }

    public var body: some View {
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
        .navigationTitle("アカウント再発行")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarCancelButton(action: onCancel)
            ToolbarSaveButton(title: "再発行", isLoading: isLoading, action: onReissue)
        }
    }
}
