//
//  GlassCapsule.swift
//  Enso
//
//

import SwiftUI

struct GlassCapsule<Content: View>: View {
    var padding: EdgeInsets = EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16)
    var material: Material = .ultraThinMaterial
    var cornerRadius: CGFloat = 30 // Capsule shape
    @ViewBuilder let content: Content

    var body: some View {
        content
            .padding(padding)
            .background(material, in: RoundedRectangle(cornerRadius: cornerRadius))
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .stroke(.white.opacity(0.2), lineWidth: 0.5)
            )
            .shadow(color: .black.opacity(0.1), radius: 10, x: 0, y: 5)
    }
}

extension View {
    func glassCapsule(
        padding: EdgeInsets = EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16),
        material: Material = .ultraThinMaterial,
        cornerRadius: CGFloat = 30
    ) -> some View {
        GlassCapsule(padding: padding, material: material, cornerRadius: cornerRadius) {
            self
        }
    }
}

#Preview {
    ZStack {
        Color.blue.opacity(0.2).ignoresSafeArea()

        VStack {
            Text("Hello World")
                .glassCapsule()

            HStack {
                Image(systemName: "star.fill")
                Text("Starred")
            }
            .glassCapsule(material: .regular)
        }
    }
}
