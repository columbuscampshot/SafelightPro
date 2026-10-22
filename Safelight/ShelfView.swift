import SwiftUI

/// The chemical shelf: every filter you've added, as a row of amber bottles.
struct ShelfSection: View {
    @EnvironmentObject private var library: FilterLibrary
    @EnvironmentObject private var camera: CameraStore
    let onAdd: () -> Void
    let showToast: (String) -> Void

    @State private var loadTarget: ShelfFilter?
    @State private var renaming: ShelfFilter?
    @State private var newName = ""
    @State private var removing: ShelfFilter?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionLabel(
                title: "Chemical shelf",
                detail: library.filters.count == 1 ? "1 filter" : "\(library.filters.count) filters"
            )

            Button(action: onAdd) {
                Label("Add .flt filters", systemImage: "plus")
            }
            .buttonStyle(DarkroomButtonStyle(prominent: false))

            if library.filters.isEmpty {
                Text("Add the filters you downloaded. If they came in a zip, tap the zip in the Files app to unpack it, then pick the .flt files here.")
                    .font(Darkroom.body(14))
                    .foregroundStyle(Darkroom.dim)
                    .fixedSize(horizontal: false, vertical: true)
            }

            ForEach(library.filters) { filter in
                BottleRow(filter: filter, trays: traysHolding(filter))
                    .contentShape(Rectangle())
                    .onTapGesture {
                        if camera.isConnected {
                            loadTarget = filter
                        } else {
                            showToast("Plug in your camera to load filters.")
                        }
                    }
                    .contextMenu {
                        if camera.isConnected {
                            Menu("Load into tray") {
                                ForEach(DialSlot.allCases) { slot in
                                    Button("Tray \(slot.tray), \(slot.dialLabel)") { load(filter, into: slot) }
                                }
                            }
                        }
                        Button("Rename", systemImage: "pencil") {
                            newName = filter.name
                            renaming = filter
                        }
                        Button("Remove from shelf", systemImage: "trash", role: .destructive) {
                            removing = filter
                        }
                    }
            }

            if !library.filters.isEmpty {
                Text("Tap a bottle to load it. Press and hold to rename or remove.")
                    .font(Darkroom.body(12))
                    .foregroundStyle(Darkroom.dim)
            }
        }
        .confirmationDialog(
            loadTarget.map { "Load \($0.name)" } ?? "",
            isPresented: Binding(get: { loadTarget != nil }, set: { if !$0 { loadTarget = nil } }),
            titleVisibility: .visible,
            presenting: loadTarget
        ) { filter in
            ForEach(DialSlot.allCases) { slot in
                Button("Tray \(slot.tray), \(slot.dialLabel)") { load(filter, into: slot) }
            }
        } message: { _ in
            Text("Choose a dial position. This replaces what's in that tray now.")
        }
        .confirmationDialog(
            removing.map { "Remove \($0.name)?" } ?? "",
            isPresented: Binding(get: { removing != nil }, set: { if !$0 { removing = nil } }),
            titleVisibility: .visible,
            presenting: removing
        ) { filter in
            Button("Remove from shelf", role: .destructive) { library.delete(filter) }
        } message: { _ in
            Text("This removes it from your phone. Anything already on the camera stays there.")
        }
        .alert("Rename filter", isPresented: Binding(get: { renaming != nil }, set: { if !$0 { renaming = nil } })) {
            TextField("Name", text: $newName)
            Button("Save") {
                if let filter = renaming {
                    do { try library.rename(filter, to: newName) } catch { showToast("Couldn't rename that filter.") }
                }
                renaming = nil
            }
            Button("Cancel", role: .cancel) { renaming = nil }
        }
    }

    private func traysHolding(_ filter: ShelfFilter) -> [DialSlot] {
        DialSlot.allCases.filter { camera.trays[$0]?.fingerprint == filter.fingerprint }
    }

    private func load(_ filter: ShelfFilter, into slot: DialSlot) {
        do {
            try camera.load(filter, into: slot)
            showToast("\(filter.name) is in tray \(slot.tray), \(slot.dialLabel).")
        } catch {
            showToast(error.localizedDescription)
        }
    }
}

struct BottleRow: View {
    let filter: ShelfFilter
    let trays: [DialSlot]
    var highlighted = false

    var body: some View {
        HStack(spacing: 14) {
            Bottle(monochrome: filter.isMonochrome)
                .frame(width: 28, height: 46)

            VStack(alignment: .leading, spacing: 3) {
                Text(filter.name)
                    .font(Darkroom.title(16))
                    .foregroundStyle(Darkroom.paper)
                    .lineLimit(1)
                if let note = filter.note {
                    Text(note)
                        .font(Darkroom.body(12))
                        .foregroundStyle(Darkroom.dim)
                        .lineLimit(2)
                }
            }

            Spacer(minLength: 8)

            HStack(spacing: 4) {
                ForEach(trays) { slot in
                    Text(slot.dialLabel)
                        .font(Darkroom.stencil(11))
                        .foregroundStyle(Darkroom.black)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 3)
                        .background(RoundedRectangle(cornerRadius: 4).fill(Darkroom.safelight))
                }
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(highlighted ? Darkroom.ember.opacity(0.55) : Darkroom.wall.opacity(0.85))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(highlighted ? Darkroom.safelight : Darkroom.ember.opacity(0.55), lineWidth: 1)
        )
    }
}

/// A little amber chemistry bottle. Smoke glass for black and white filters.
struct Bottle: View {
    var monochrome: Bool

    private var glass: Color {
        monochrome ? Color(white: 0.38) : Color(red: 0.58, green: 0.28, blue: 0.08)
    }

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            ZStack(alignment: .top) {
                RoundedRectangle(cornerRadius: w * 0.22)
                    .fill(LinearGradient(colors: [glass, glass.opacity(0.55)], startPoint: .leading, endPoint: .trailing))
                    .frame(width: w, height: h * 0.70)
                    .offset(y: h * 0.30)
                RoundedRectangle(cornerRadius: 2)
                    .fill(Darkroom.paper.opacity(0.85))
                    .frame(width: w * 0.74, height: h * 0.24)
                    .offset(y: h * 0.50)
                RoundedRectangle(cornerRadius: 2)
                    .fill(glass)
                    .frame(width: w * 0.36, height: h * 0.18)
                    .offset(y: h * 0.14)
                RoundedRectangle(cornerRadius: 2)
                    .fill(Darkroom.dim)
                    .frame(width: w * 0.46, height: h * 0.15)
            }
            .frame(width: w, height: h, alignment: .top)
        }
    }
}
