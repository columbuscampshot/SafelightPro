import SwiftUI
import UniformTypeIdentifiers

struct ContentView: View {
    @EnvironmentObject private var library: FilterLibrary
    @EnvironmentObject private var camera: CameraStore
    @EnvironmentObject private var developer: PhotoDeveloper
    @Environment(\.scenePhase) private var scenePhase

    enum ImportMode { case camera, filters }

    @State private var showImporter = false
    @State private var importMode: ImportMode = .filters
    @State private var traySheet: DialSlot?
    @State private var toast: String?
    @State private var toastTask: Task<Void, Never>?

    var body: some View {
        ZStack(alignment: .bottom) {
            DarkroomBackground(lit: camera.isConnected)

            ScrollView {
                VStack(spacing: 26) {
                    HeaderView(onChooseFolder: { presentImporter(.camera) })

                    if !camera.isConnected {
                        BenchCard(onFind: { presentImporter(.camera) })
                    }

                    TraysSection(onTap: { traySheet = $0 })

                    FilmSection(showToast: show)

                    ShelfSection(onAdd: { presentImporter(.filters) }, showToast: show)

                    Text("Your filters also live in the Files app under On My iPhone, Safelight, Filters.")
                        .font(Darkroom.body(12))
                        .foregroundStyle(Darkroom.dim)
                        .multilineTextAlignment(.center)
                        .padding(.top, 4)
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 90)
            }
            .refreshable {
                library.reload()
                camera.refresh()
            }

            if let toast {
                ToastView(text: toast)
                    .padding(.bottom, 28)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .sheet(item: $traySheet) { slot in
            TrayPickerSheet(slot: slot, showToast: show)
                .environmentObject(library)
                .environmentObject(camera)
        }
        .fileImporter(
            isPresented: $showImporter,
            allowedContentTypes: importMode == .camera ? [.folder] : [.data],
            allowsMultipleSelection: importMode == .filters,
            onCompletion: handleImport
        )
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                library.reload()
                camera.refresh()
            }
        }
        .onChange(of: camera.trays, initial: true) { _, trays in
            backUpOriginals(trays)
        }
        .task {
            // Notice when the camera gets plugged in or pulled out.
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(3))
                camera.poll()
            }
        }
    }

    private func presentImporter(_ mode: ImportMode) {
        importMode = mode
        showImporter = true
    }

    private func handleImport(_ result: Result<[URL], Error>) {
        switch result {
        case .failure(let error):
            show(error.localizedDescription)
        case .success(let urls):
            switch importMode {
            case .camera:
                guard let url = urls.first else { return }
                camera.connect(to: url)
                if !camera.isConnected {
                    show("Couldn't open that folder. Try again with the camera plugged in.")
                } else if !camera.looksLikeCamera {
                    show("Connected, but this folder has no DCIM folder or filters. Pick the camera's top folder.")
                } else {
                    show("Camera's on the bench.")
                }
            case .filters:
                show(library.importFiles(urls))
            }
        }
    }

    /// The first time each tray is seen, keep a copy of what came on the camera.
    private func backUpOriginals(_ trays: [DialSlot: TrayContents]) {
        let key = "safelight.originalsSaved"
        var saved = Set(UserDefaults.standard.stringArray(forKey: key) ?? [])
        for (slot, contents) in trays where !saved.contains(slot.rawValue) {
            library.save(contents.data, named: "Original \(slot.dialLabel)")
            saved.insert(slot.rawValue)
        }
        UserDefaults.standard.set(Array(saved), forKey: key)
    }

    private func show(_ text: String) {
        guard !text.isEmpty else { return }
        toastTask?.cancel()
        withAnimation(.spring(duration: 0.35)) { toast = text }
        toastTask = Task { @MainActor in
            try? await Task.sleep(for: .seconds(3.5))
            guard !Task.isCancelled else { return }
            withAnimation(.easeOut(duration: 0.3)) { toast = nil }
        }
    }
}

// MARK: Header

struct HeaderView: View {
    @EnvironmentObject private var camera: CameraStore
    let onChooseFolder: () -> Void

    var body: some View {
        HStack(spacing: 14) {
            SafelightLamp(on: camera.isConnected)
            VStack(alignment: .leading, spacing: 2) {
                Text("Safelight")
                    .font(Darkroom.title(32))
                    .foregroundStyle(Darkroom.paper)
                Text(camera.isConnected ? "Camp Snap Pro on the bench" : "No camera on the bench")
                    .font(Darkroom.body(14))
                    .foregroundStyle(camera.isConnected ? Darkroom.amber : Darkroom.dim)
            }
            Spacer()
            Menu {
                Button("Check for camera", systemImage: "arrow.clockwise") { camera.refresh() }
                Button("Choose camera folder", systemImage: "folder") { onChooseFolder() }
                if camera.hasBookmark {
                    Button("Forget this camera", systemImage: "eject", role: .destructive) { camera.forget() }
                }
            } label: {
                Image(systemName: "ellipsis.circle")
                    .font(.title2)
                    .foregroundStyle(Darkroom.amber)
            }
        }
        .padding(.top, 12)
    }
}

// MARK: Connect card

struct BenchCard: View {
    @EnvironmentObject private var camera: CameraStore
    let onFind: () -> Void

    var body: some View {
        Panel {
            VStack(alignment: .leading, spacing: 12) {
                Text(camera.hasBookmark ? "Plug in your camera" : "Set up your camera")
                    .font(Darkroom.title(20))
                    .foregroundStyle(Darkroom.paper)

                Text(camera.hasBookmark
                     ? "Connect the Camp Snap Pro with your USB-C cable. Safelight finds it on its own and the lamp turns on."
                     : "Connect the Camp Snap Pro with your USB-C cable. Tap the button, open Browse, tap the camera under Locations, then tap Open. You only do this once.")
                    .font(Darkroom.body(15))
                    .foregroundStyle(Darkroom.amber.opacity(0.85))
                    .fixedSize(horizontal: false, vertical: true)

                if camera.hasBookmark {
                    Button("Check again") { camera.refresh() }
                        .buttonStyle(DarkroomButtonStyle())
                    Button("Choose the camera folder") { onFind() }
                        .buttonStyle(DarkroomButtonStyle(prominent: false))
                } else {
                    Button("Find my camera") { onFind() }
                        .buttonStyle(DarkroomButtonStyle())
                }
            }
        }
    }
}
