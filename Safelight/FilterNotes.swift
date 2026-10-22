import Foundation

/// Short label notes for filters the community has shared.
/// Matching ignores numbers, spaces, and punctuation, so "01_Golden92.flt" still finds Golden '92.
enum FilterNotes {
    private static let notes: [String: String] = [
        "golden92": "Lomochrome '92 color. Warm and a little strange.",
        "eternalhour": "Kodak Gold warmth. A great everyday pick.",
        "streetcool": "Superia cool tones for the city.",
        "deepseparation": "Pro 400H look that keeps people in front.",
        "vividlandscape": "Ektar saturation for sky, water, and hills.",
        "crimsondusk": "Velvia deep reds at sunset.",
        "neutraltransparency": "Provia slide film. Clean with a hint of cyan.",
        "complexionpriority": "Portrait friendly skin without the orange.",
        "pastelshoulder": "Overexposed Portra. Soft highlights, gentle color.",
        "ceremonialwash": "Airy and bright for events and sunny days.",
        "drugstoregreen": "90s one hour prints with a faint green cast.",
        "instantbloom": "Polaroid glow and soft color bleed.",
        "pastelmemory": "Faded print from the family album.",
        "classicdispo": "The disposable camera look.",
        "crimsonregister": "Centuria reds in daylight.",
        "coollabslip": "Agfa Vista with a cool scanner drift.",
        "rivieracyanotype": "60s to 80s coastal travel color.",
        "chromaticstorybook": "Storybook color in the Wes Anderson style.",
        "isleofochre": "Sun bleached ochre. Made for beach towns.",
        "moodybw": "Atmospheric black and white, Ilford FP4.",
        "texturedbw": "FP4 black and white with extra texture.",
        "charcoaldepth": "Heavy black and white with deep blacks.",
        "catdays": "Soft contrast, warm color, creamy whites. Built for the Pro.",
        "dogdays": "Warm summer tones from the community.",
        "originalstd": "The camera's original Standard filter.",
        "originalvtg1": "The camera's original Vintage 1 filter.",
        "originalvtg2": "The camera's original Vintage 2 filter.",
        "originalbw": "The camera's original Black and White filter.",
        "neutral": "No styling. A clean baseline from the sensor."
    ]

    /// Longest keys first so "neutraltransparency" wins over "neutral".
    private static let orderedKeys = notes.keys.sorted { $0.count > $1.count }

    static func note(for name: String) -> String? {
        let normalized = name.lowercased()
            .replacingOccurrences(of: "&", with: "")
            .filter { $0.isLetter }
        guard !normalized.isEmpty else { return nil }
        for key in orderedKeys {
            let letters = key.filter { $0.isLetter }
            if normalized.contains(letters) { return notes[key] }
        }
        return nil
    }
}
