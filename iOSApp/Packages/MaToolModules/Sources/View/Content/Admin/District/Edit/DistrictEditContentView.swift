import iOSShared
//
//  DistrictEditContentView.swift
//  MaTool
//

import SwiftUI
import Shared

@available(iOS 17.0, *)
public struct DistrictEditContentView: View {
    @Binding var name: String
    @Binding var description: String
    @Binding var visibility: Shared.Visibility
    let performances: [Performance]
    let onBaseTapped: () -> Void
    let onAreaTapped: () -> Void
    let onPerformanceTapped: (Performance) -> Void
    let onAddPerformanceTapped: () -> Void

    public init(
        name: Binding<String>,
        description: Binding<String>,
        visibility: Binding<Shared.Visibility>,
        performances: [Performance],
        onBaseTapped: @escaping () -> Void,
        onAreaTapped: @escaping () -> Void,
        onPerformanceTapped: @escaping (Performance) -> Void,
        onAddPerformanceTapped: @escaping () -> Void
    ) {
        self._name = name
        self._description = description
        self._visibility = visibility
        self.performances = performances
        self.onBaseTapped = onBaseTapped
        self.onAreaTapped = onAreaTapped
        self.onPerformanceTapped = onPerformanceTapped
        self.onAddPerformanceTapped = onAddPerformanceTapped
    }

    public var body: some View {
        List {
            Section(
                header: Text("町名"),
                footer: Text("IDは更新できません")
            ) {
                TextField("町名を入力", text: $name)
            }
            Section(header: Text("紹介文")) {
                TextEditor(text: $description)
                    .frame(height: 120)
            }
            Section(header: Text("会所")) {
                Button(action: onBaseTapped) {
                    Label("地図で選択", systemImage: "map")
                        .font(.body)
                }
            }
            Section(header: Text("町域")) {
                Button(action: onAreaTapped) {
                    Label("地図で選択", systemImage: "map")
                        .font(.body)
                }
            }
            Section(header: Text("ルート"), footer: Text("最新年の全てのルートの公開範囲が変更されます")) {
                Picker("デフォルトの公開範囲", selection: $visibility) {
                    ForEach(Shared.Visibility.allCases) { option in
                        Text(option.label).tag(option)
                    }
                }
                .pickerStyle(.menu)
            }
            Section(header: Text("余興")) {
                ForEach(performances) { item in
                    NavigationItemView(
                        title: item.name,
                        onTap: { onPerformanceTapped(item) }
                    )
                }
                Button(action: onAddPerformanceTapped) {
                    Label("追加", systemImage: "plus.circle")
                        .frame(maxWidth: .infinity, alignment: .center)
                }
            }
        }
    }
}
