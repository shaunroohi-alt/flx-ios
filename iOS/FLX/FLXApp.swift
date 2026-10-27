import SwiftUI

@main
struct FLXApp: App {
    @StateObject private var session = DJSession()
    var body: some Scene {
        WindowGroup { ConsoleView().environmentObject(session).preferredColorScheme(.dark) }
    }
}
