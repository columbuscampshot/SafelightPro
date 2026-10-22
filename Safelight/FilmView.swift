import SwiftUI

/// The camera's photos as a strip of film. New frames show as negatives
/// until you develop them into Photos, then they turn positive.
struct FilmSection: View {
    @EnvironmentObject private var camera: CameraStore
    @EnvironmentObject private var developer: PhotoDeveloper
    let showToast: (String) -> Void

    @State private var confirmClear = false
    @State private var confirmRedevelop = false
    @State private var preview: CameraPhoto?

    private var newFrames: [CameraPhoto] { camera.photos.filter { !developer.isDeveloped($0) } }
    private var printedFrames: [CameraPhoto] { camera.photos.filter { developer.isDeveloped($0) } }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionLabel(
                title: "Film strip",
                detail: camera.isConnected ? "\(camera.photos.count) frames, \(newFrames.count) new" : nil
            )

            if !camera.isConnected {
                Text("Plug in your camera to see its frames.")
                    .font(Darkroom.body(14))
                    .foregroundStyle(Darkroom.dim)
            } else if camera.isScanning && camera.photos.isEmpty {
                HStack(spacing: 10) {
                    ProgressView().tint(Darkroom.safelight)
                    Text("Reading the roll")
                        .font(Darkroom.body(14))
                        .foregroundStyle(Darkroom.dim)
                }
            } else if camera.photos.isEmpty {
                Text("No frames on the camera yet. Go shoot something.")
                    .font(Darkroom.body(14))
                    .foregroundStyle(Darkroom.dim)
            } else {
                FilmStrip(photos: Array(camera.photos.reversed()), onTap: { preview = $0 })

                if developer.isDeveloping {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Developing frame \(min(developer.done + 1, developer.total)) of \(developer.total)")
                            .font(Darkroom.body(15))
                            .foregroundStyle(Darkroom.amber)
                        ProgressView(value: Double(developer.done), total: Double(max(developer.total, 1)))
                            .tint(Darkroom.safelight)
                    }
                    .padding(.vertical, 6)
                } else {
                    Button(developButtonTitle) {
                        Task { showToast(await developer.develop(newFrames)) }
                    }
                    .buttonStyle(DarkroomButtonStyle())
                    .disabled(newFrames.isEmpty)

                    Menu {
                        Button("Develop every frame again", systemImage: "arrow.counterclockwise") { confirmRedevelop = true }
                        if !newFrames.isEmpty {
                            Button("Mark all as developed", systemImage: "checkmark") {
                                developer.markDeveloped(newFrames)
                                showToast("All frames marked as developed.")
                            }
                        }
                        if !printedFrames.isEmpty {
                            Button("Clear developed frames from camera", systemImage: "trash", role: .destructive) { confirmClear = true }
                        }
                    } label: {
                        Text("More options")
                            .font(Darkroom.body(14))
                            .foregroundStyle(Darkroom.amber)
                            .frame(maxWidth: .infinity)
                    }
                }
            }
        }
        .confirmationDialog(
            "Clear \(printedFrames.count) developed frames from the camera?",
            isPresented: $confirmClear,
            titleVisibility: .visible
        ) {
            Button("Delete from camera", role: .destructive) {
                let removed = camera.delete(printedFrames)
                showToast(removed == 1 ? "1 frame cleared. Your copy in Photos is safe." : "\(removed) frames cleared. Your copies in Photos are safe.")
            }
        } message: {
            Text("Only frames already in Photos get deleted. New frames stay on the camera.")
        }
        .confirmationDialog(
            "Develop all \(camera.photos.count) frames again?",
            isPresented: $confirmRedevelop,
            titleVisibility: .visible
        ) {
            Button("Develop all again") {
                Task { showToast(await developer.develop(camera.photos)) }
            }
        } message: {
            Text("This adds a second copy of anything already in Photos.")
        }
        .sheet(item: $preview) { photo in
            FramePreview(photo: photo)
        }
    }

    private var developButtonTitle: String {
        switch newFrames.count {
        case 0: return "All frames developed"
        case 1: return "Develop 1 new frame"
        default: return "Develop \(newFrames.count) new frames"
        }
    }
}

struct FilmStrip: View {
    @EnvironmentObject private var developer: PhotoDeveloper
    let photos: [CameraPhoto]
    let onTap: (CameraPhoto) -> Void

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            LazyHStack(spacing: 0) {
                ForEach(Array(photos.enumerated()), id: \.element.id) { index, photo in
                    FilmFrame(
                        photo: photo,
                        number: photos.count - index,
                        developed: developer.isDeveloped(photo)
                    )
                    .onTapGesture { onTap(photo) }
                }
            }
            .padding(.vertical, 6)
        }
        .background(Darkroom.filmBase)
        .clipShape(RoundedRectangle(cornerRadius: 6))
        .overlay(RoundedRectangle(cornerRadius: 6).stroke(Darkroom.black, lineWidth: 1))
    }
}

struct FilmFrame: View {
    let photo: CameraPhoto
    let number: Int
    let developed: Bool

    @State private var image: UIImage?

    var body: some View {
        VStack(spacing: 4) {
            Sprockets()
            ZStack {
                Rectangle().fill(Color.black)
                if let image {
                    // Negative: inverted with an orange film base
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                        .colorInvert()
                        .colorMultiply(Color(red: 1.0, green: 0.72, blue: 0.48))
                        .opacity(developed ? 0 : 1)
                    // Print: the real photo
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                        .opacity(developed ? 1 : 0)
                }
                if photo.isVideo {
                    Image(systemName: "video.fill")
                        .foregroundStyle(Darkroom.paper)
                        .shadow(radius: 3)
                }
            }
            .frame(width: 132, height: 99)
            .clipped()
            .animation(.easeInOut(duration: 1.8), value: developed)
            .overlay(alignment: .bottomTrailing) {
                if developed {
                    Text("PRINTED")
                        .font(Darkroom.stencil(9))
                        .foregroundStyle(Darkroom.safelight)
                        .padding(.horizontal, 3)
                        .padding(.vertical, 1)
                        .background(Darkroom.black.opacity(0.7))
                        .overlay(Rectangle().stroke(Darkroom.safelight, lineWidth: 1))
                        .rotationEffect(.degrees(-8))
                        .padding(5)
                        .transition(.scale.combined(with: .opacity))
                }
            }
            HStack {
                Text("\(number)")
                    .font(Darkroom.stencil(10))
                Spacer()
                Text("SAFELIGHT 400")
                    .font(Darkroom.stencil(8))
            }
            .foregroundStyle(Darkroom.edgeprint)
            .frame(width: 132)
            Sprockets()
        }
        .padding(.horizontal, 6)
        .task(id: photo.id) {
            if !photo.isVideo {
                image = await Thumbnailer.image(for: photo.url)
            }
        }
    }
}

struct Sprockets: View {
    var body: some View {
        HStack(spacing: 9) {
            ForEach(0..<8, id: \.self) { _ in
                RoundedRectangle(cornerRadius: 2)
                    .fill(Darkroom.black.opacity(0.9))
                    .frame(width: 9, height: 7)
            }
        }
        .frame(width: 144)
    }
}

/// A bigger look at one frame.
struct FramePreview: View {
    let photo: CameraPhoto
    @Environment(\.dismiss) private var dismiss
    @State private var image: UIImage?

    var body: some View {
        ZStack {
            Darkroom.black.ignoresSafeArea()
            VStack(spacing: 16) {
                if let image {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFit()
                        .padding(10)
                        .background(Darkroom.paper)
                        .shadow(color: Darkroom.safelight.opacity(0.4), radius: 20)
                } else if photo.isVideo {
                    Text("Video frames preview in Photos after you develop them.")
                        .font(Darkroom.body(15))
                        .foregroundStyle(Darkroom.dim)
                } else {
                    ProgressView().tint(Darkroom.safelight)
                }
                Text(photo.url.lastPathComponent)
                    .font(Darkroom.stencil(13))
                    .foregroundStyle(Darkroom.edgeprint)
                Text(photo.date.formatted(date: .abbreviated, time: .shortened))
                    .font(Darkroom.body(13))
                    .foregroundStyle(Darkroom.dim)
                Button("Close") { dismiss() }
                    .buttonStyle(DarkroomButtonStyle(prominent: false))
                    .frame(width: 160)
            }
            .padding(20)
        }
        .preferredColorScheme(.dark)
        .task {
            if !photo.isVideo {
                image = await Thumbnailer.image(for: photo.url, maxPixel: 1800)
            }
        }
    }
}
