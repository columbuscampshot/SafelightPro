import SwiftUI

/// The four developing trays, one for each dial position.
struct TraysSection: View {
    @EnvironmentObject private var camera: CameraStore
    @EnvironmentObject private var library: FilterLibrary
    let onTap: (DialSlot) -> Void

    private let columns = [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionLabel(title: "Developing trays", detail: "Your four dial positions")
            LazyVGrid(columns: columns, spacing: 12) {
                ForEach(DialSlot.allCases) { slot in
                    Button { onTap(slot) } label: {
                        TrayView(
                            slot: slot,
                            title: title(for: slot),
                            subtitle: camera.isConnected ? "Tap to change" : "Plug in to see",
                            lit: camera.isConnected
                        )
                    }
                    .buttonStyle(.plain)
                    .disabled(!camera.isConnected)
                }
            }
        }
    }

    private func title(for slot: DialSlot) -> String {
        guard camera.isConnected else { return "Unknown" }
        guard let contents = camera.trays[slot] else { return "Camera default" }
        return library.match(contents.fingerprint)?.name ?? "Unlabeled filter"
    }
}

struct TrayView: View {
    let slot: DialSlot
    let title: String
    let subtitle: String
    let lit: Bool
    @State private var ripple = false

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("TRAY \(slot.tray)")
                    .font(Darkroom.stencil(11))
                    .tracking(2)
                    .foregroundStyle(Darkroom.dim)
                Spacer()
                Text(slot.dialLabel)
                    .font(Darkroom.stencil(13))
                    .foregroundStyle(Darkroom.safelight)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .overlay(RoundedRectangle(cornerRadius: 4).stroke(Darkroom.safelight.opacity(0.6), lineWidth: 1))
            }
            Spacer(minLength: 4)
            Text(title)
                .font(Darkroom.title(17))
                .foregroundStyle(lit ? Darkroom.paper : Darkroom.dim)
                .lineLimit(2)
                .minimumScaleFactor(0.7)
            Text(subtitle)
                .font(Darkroom.body(12))
                .foregroundStyle(Darkroom.dim)
                .lineLimit(1)
        }
        .padding(12)
        .frame(height: 120)
        .background(liquid)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Darkroom.ember, lineWidth: 2))
        .overlay(alignment: .top) {
            // The lip of the tray
            RoundedRectangle(cornerRadius: 2)
                .fill(Darkroom.dim.opacity(0.35))
                .frame(height: 3)
                .padding(.horizontal, 14)
                .padding(.top, 1)
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 3.2).repeatForever(autoreverses: true)) { ripple = true }
        }
    }

    /// Dark chemistry with a slow red reflection sliding across it.
    private var liquid: some View {
        ZStack {
            Darkroom.panel
            Ellipse()
                .fill(Darkroom.safelight.opacity(lit ? 0.22 : 0.06))
                .frame(width: 130, height: 34)
                .blur(radius: 16)
                .offset(x: ripple ? 34 : -34, y: 34)
        }
    }
}

/// Lets you pick which shelf filter goes into one tray.
struct TrayPickerSheet: View {
    let slot: DialSlot
    let showToast: (String) -> Void

    @EnvironmentObject private var camera: CameraStore
    @EnvironmentObject private var library: FilterLibrary
    @Environment(\.dismiss) private var dismiss

    private var current: ShelfFilter? { library.match(camera.trays[slot]?.fingerprint) }

    var body: some View {
        NavigationStack {
            ZStack {
                DarkroomBackground(lit: true)
                ScrollView {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Pick a filter for the \(slot.dialLabel) position on your dial.")
                            .font(Darkroom.body(15))
                            .foregroundStyle(Darkroom.amber)
                            .padding(.bottom, 6)

                        if let contents = camera.trays[slot], current == nil {
                            Button("Save the filter in this tray to your shelf") {
                                library.save(contents.data, named: "Saved \(slot.dialLabel)")
                                showToast("Saved to your shelf.")
                            }
                            .buttonStyle(DarkroomButtonStyle(prominent: false))
                            .padding(.bottom, 6)
                        }

                        if camera.trays[slot] != nil {
                            Button("Return to camera default") {
                                do {
                                    try camera.returnToDefault(slot)
                                    showToast("Tray \(slot.tray) is back to the camera's built in \(slot.dialLabel) look.")
                                    dismiss()
                                } catch {
                                    showToast(error.localizedDescription)
                                }
                            }
                            .buttonStyle(DarkroomButtonStyle(prominent: false))
                            .padding(.bottom, 6)
                        }

                        if library.filters.isEmpty {
                            Text("Your shelf is empty. Close this and add some .flt filters first.")
                                .font(Darkroom.body(15))
                                .foregroundStyle(Darkroom.dim)
                        }

                        ForEach(library.filters) { filter in
                            Button { load(filter) } label: {
                                BottleRow(
                                    filter: filter,
                                    trays: DialSlot.allCases.filter { camera.trays[$0]?.fingerprint == filter.fingerprint },
                                    highlighted: filter == current
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(16)
                }
            }
            .navigationTitle("Tray \(slot.tray), \(slot.dialLabel)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Darkroom.black, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                        .foregroundStyle(Darkroom.amber)
                }
            }
        }
        .preferredColorScheme(.dark)
    }

    private func load(_ filter: ShelfFilter) {
        do {
            try camera.load(filter, into: slot)
            showToast("\(filter.name) is in tray \(slot.tray), \(slot.dialLabel).")
            dismiss()
        } catch {
            showToast(error.localizedDescription)
        }
    }
}
