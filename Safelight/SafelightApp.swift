import SwiftUI

@main
struct SafelightApp: App {
    @StateObject private var library = FilterLibrary()
    @StateObject private var camera = CameraStore()
    @StateObject private var developer = PhotoDeveloper()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(library)
                .environmentObject(camera)
                .environmentObject(developer)
                .preferredColorScheme(.dark)
        }
    }
}
