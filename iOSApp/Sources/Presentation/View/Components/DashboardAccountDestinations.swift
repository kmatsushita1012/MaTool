import ComposableArchitecture
import SwiftUI

struct DashboardAccountDestinations: ViewModifier {
    let changePassword: Binding<StoreOf<ChangePasswordFeature>?>
    let updateEmail: Binding<StoreOf<UpdateEmailFeature>?>
    let settings: Binding<StoreOf<SettingsFeature>?>

    func body(content: Content) -> some View {
        content
            .fullScreenCover(item: changePassword) { store in
                NavigationStack {
                    ChangePasswordView(store: store)
                }
            }
            .fullScreenCover(item: updateEmail) { store in
                NavigationStack {
                    UpdateEmailView(store: store)
                }
            }
            .navigationDestination(item: settings) { store in
                SettingsView(store: store)
            }
    }
}
