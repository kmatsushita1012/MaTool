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

    public init(name: Binding<String>, email: Binding<String>) {
        self._name = name
        self._email = email
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
    }
}
