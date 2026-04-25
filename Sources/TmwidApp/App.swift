import SwiftUI

@main
struct TmwidApp: App {
    var body: some Scene {
        MenuBarExtra("Tmwid", systemImage: "hare") {
            Text("Hello Tmwid")
            Button("Quit") { NSApplication.shared.terminate(nil) }
        }
        .menuBarExtraStyle(.menu)
    }
}
