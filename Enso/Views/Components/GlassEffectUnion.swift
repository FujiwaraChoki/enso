//
//  GlassEffectUnion.swift
//  Enso
//
//

import SwiftUI

// MARK: - Preference Key
struct GlassEffectUnionKey: PreferenceKey {
    static var defaultValue: [String: [CGRect]] = [:]

    static func reduce(value: inout [String: [CGRect]], nextValue: () -> [String: [CGRect]]) {
        for (key, rects) in nextValue() {
            value[key, default: []].append(contentsOf: rects)
        }
    }
}

// MARK: - Modifier
struct GlassEffectUnionModifier: ViewModifier {
    let id: String
    let namespace: Namespace.ID

    func body(content: Content) -> some View {
        content
            .background(
                GeometryReader { proxy in
                    Color.clear
                        .preference(
                            key: GlassEffectUnionKey.self,
                            value: [id: [proxy.frame(in: .named(namespace))]]
                        )
                }
            )
    }
}

extension View {
    func glassEffectUnion(id: String, namespace: Namespace.ID) -> some View {
        modifier(GlassEffectUnionModifier(id: id, namespace: namespace))
    }
}

// MARK: - Container
struct GlassEffectContainer<Content: View>: View {
    let namespace: Namespace.ID
    let material: Material
    let content: Content

    init(namespace: Namespace.ID, material: Material = .ultraThinMaterial, @ViewBuilder content: () -> Content) {
        self.namespace = namespace
        self.material = material
        self.content = content()
    }

    var body: some View {
        content
            .backgroundPreferenceValue(GlassEffectUnionKey.self) { (preferences: [String: [CGRect]]) in
                GeometryReader { proxy in
                    ForEach(preferences.keys.sorted(), id: \.self) { (key: String) in
                        if let rects = preferences[key], !rects.isEmpty {
                            // Calculate union rect
                            let unionRect = rects.reduce(rects[0]) { $0.union($1) }

                            // Draw the glass background
                            // We use a capsule shape for the "Liquid Glass" feel
                            Color.clear
                                .frame(width: unionRect.width, height: unionRect.height)
                                .glassEffect(.regular, in: Capsule())
                                .offset(x: unionRect.minX, y: unionRect.minY)
                                .shadow(color: .black.opacity(0.1), radius: 10, x: 0, y: 5)
                        }
                    }
                }
            }
            .coordinateSpace(name: namespace)
    }
}
