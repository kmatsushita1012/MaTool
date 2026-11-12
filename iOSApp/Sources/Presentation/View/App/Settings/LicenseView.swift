import SwiftUI

struct LicenseView: View {
    private let licenseURL = URL(string: "https://github.com/Kinutafontfactory/Yuji/blob/master/OFL.txt")!

    var body: some View {
        Form {
            Section("フォント") {
                LabeledContent("書体", value: "佑字 肅 (Yuji Syuku)")
                LabeledContent("著作権", value: "Copyright 2021 The Yuji Project Authors")
            }

            Section("ライセンス") {
                LabeledContent("ライセンス", value: "SIL Open Font License 1.1")
                Link("ライセンス原文", destination: licenseURL)
            }
        }
        .navigationTitle("ライセンス")
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    NavigationStack {
        LicenseView()
    }
}
