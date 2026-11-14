import SwiftUI

@main
struct KeytoneApp: App {
    @State private var state = AppState.shared

    var body: some Scene {
        MenuBarExtra {
            MenuView().environment(state)
        } label: {
            Image(systemName: state.enabled ? "keyboard.fill" : "keyboard")
        }
        .menuBarExtraStyle(.window)
    }
}
