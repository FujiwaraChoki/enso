//
//  Typography.swift
//  Enso
//

import SwiftUI
import CoreText

enum Typography {
    // MARK: - Font Registration

    static func registerFonts() {
        let fontNames = [
            "InstrumentSerif-Regular",
            "InstrumentSerif-Italic"
        ]

        for fontName in fontNames {
            guard let fontURL = Bundle.main.url(forResource: fontName, withExtension: "ttf") else {
                print("Font file not found: \(fontName).ttf")
                continue
            }

            var error: Unmanaged<CFError>?
            if !CTFontManagerRegisterFontsForURL(fontURL as CFURL, .process, &error) {
                print("Failed to register font \(fontName): \(error?.takeRetainedValue().localizedDescription ?? "Unknown error")")
            }
        }
    }
}

// MARK: - Custom Font Extensions

extension Font {
    /// Instrument Serif font for large titles and onboarding
    static func instrumentSerif(size: CGFloat) -> Font {
        .custom("InstrumentSerif-Regular", size: size)
    }

    static func instrumentSerifItalic(size: CGFloat) -> Font {
        .custom("InstrumentSerif-Italic", size: size)
    }

    // MARK: - Enso Typography Scale

    /// Large title - 34pt Instrument Serif
    static var ensoLargeTitle: Font {
        .instrumentSerif(size: 34)
    }

    /// Title - 28pt Instrument Serif
    static var ensoTitle: Font {
        .instrumentSerif(size: 28)
    }

    /// Title 2 - 22pt Instrument Serif
    static var ensoTitle2: Font {
        .instrumentSerif(size: 22)
    }

    /// Headline - 17pt Instrument Serif
    static var ensoHeadline: Font {
        .instrumentSerif(size: 17)
    }

    /// Subtitle - 20pt Instrument Serif Italic
    static var ensoSubtitle: Font {
        .instrumentSerifItalic(size: 20)
    }
}

// MARK: - View Modifiers

extension View {
    /// Apply Instrument Serif large title style
    func ensoLargeTitleStyle() -> some View {
        self
            .font(.ensoLargeTitle)
            .foregroundStyle(.primary)
    }

    /// Apply Instrument Serif title style
    func ensoTitleStyle() -> some View {
        self
            .font(.ensoTitle)
            .foregroundStyle(.primary)
    }

    /// Apply Instrument Serif subtitle style (italic)
    func ensoSubtitleStyle() -> some View {
        self
            .font(.ensoSubtitle)
            .foregroundStyle(.secondary)
    }
}
