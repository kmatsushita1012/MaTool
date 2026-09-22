import iOSShared
//
//  DistrictCreateContentView.swift
//  MaTool
//

import SwiftUI

@available(iOS 17.0, *)
public struct DistrictCreateContentView: View {
    @Binding var name: String
    @Binding var email: String
    let isLoading: Bool
    let onCancel: () -> Void
    let onCreate: () -> Void

    public init(
        name: Binding<String>,
        email: Binding<String>,
        isLoading: Bool,
        onCancel: @escaping () -> Void,
        onCreate: @escaping () -> Void
    ) {
        self._name = name
        self._email = email
        self.isLoading = isLoading
        self.onCancel = onCancel
        self.onCreate = onCreate
    }

    public var body: some View {
        List {
            Section(header: Text("町名")) {
                TextField("町名を入力", text: $name)
            }
            Section(header: Text("メールアドレス")) {
                TextField("メールアドレスを入力", text: $email)
                    .textContentType(.emailAddress)
                    .autocapitalization(.none)
                    .disableAutocorrection(true)
            }
        }
        .navigationTitle("新規作成")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarCancelButton(action: onCancel)
            ToolbarSaveButton(title: "作成", isLoading: isLoading, action: onCreate)
        }
    }
}
