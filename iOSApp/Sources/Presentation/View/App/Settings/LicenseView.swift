import SwiftUI

struct LicenseView: View {
    private let licenses = [
        LicenseEntry(
            name: "佑字 肅 (Yuji Syuku)",
            copyright: "Copyright 2021 The Yuji Project Authors",
            license: "SIL Open Font License 1.1",
            source: URL(string: "https://github.com/Kinutafontfactory/Yuji/blob/master/OFL.txt")!
        )
    ]

    var body: some View {
        Form {
            Section("ライセンス") {
                ForEach(licenses) { license in
                    VStack(alignment: .leading, spacing: 8) {
                        Text(license.name)
                            .font(.headline)
                        Text(license.copyright)
                        LabeledContent("ライセンス", value: license.license)
                        Link("ライセンス原文", destination: license.source)
                    }
                }
            }
        }
        .navigationTitle("ライセンス")
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct LicenseEntry: Identifiable {
    let name: String
    let copyright: String
    let license: String
    let source: URL

    var id: String { name }
}

#Preview {
    NavigationStack {
        LicenseView()
    }
}
