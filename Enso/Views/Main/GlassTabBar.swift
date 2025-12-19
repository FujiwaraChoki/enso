//
//  GlassTabBar.swift
//  Enso
//

import SwiftUI

struct GlassTabBar: View {
    @Binding var tabs: [EnsoTab]
    @Binding var selectedTabId: UUID?
    var onNewTab: () -> Void
    var onCloseTab: (UUID) -> Void

    @Namespace private var tabNamespace

    var body: some View {
        GlassEffectContainer(spacing: 8) {
            HStack(spacing: 0) {
                // Tab items
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(tabs) { tab in
                            TabItemView(
                                tab: tab,
                                isSelected: tab.id == selectedTabId,
                                namespace: tabNamespace,
                                onSelect: { selectedTabId = tab.id },
                                onClose: { onCloseTab(tab.id) }
                            )
                            .glassEffectID(tab.id.uuidString, in: tabNamespace)
                        }
                    }
                    .padding(.horizontal, 8)
                }

                Divider()
                    .frame(height: 20)
                    .padding(.horizontal, 8)

                // New Tab Button
                Button(action: onNewTab) {
                    Image(systemName: "plus")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.primary)
                        .frame(width: 28, height: 28)
                }
                .buttonStyle(.plain)
                .glassEffect(.clear, in: Circle())
                .padding(.trailing, 8)
            }
        }
        .frame(height: 44)
        .background(.ultraThinMaterial)
    }
}

struct TabItemView: View {
    let tab: EnsoTab
    let isSelected: Bool
    let namespace: Namespace.ID
    var onSelect: () -> Void
    var onClose: () -> Void

    @State private var isHovering = false

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: tab.icon)
                .font(.system(size: 11))
                .foregroundStyle(isSelected ? .primary : .secondary)

            Text(tab.title)
                .font(.system(size: 12))
                .lineLimit(1)
                .foregroundStyle(isSelected ? .primary : .secondary)

            if tab.isClosable && (isHovering || isSelected) {
                Button(action: onClose) {
                    Image(systemName: "xmark")
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .transition(.opacity.combined(with: .scale))
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .frame(minWidth: 100, maxWidth: 180)
        .contentShape(Rectangle())
        .glassEffect(
            isSelected ? .regular : .clear,
            in: RoundedRectangle(cornerRadius: 8)
        )
        .onTapGesture(perform: onSelect)
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
                isHovering = hovering
            }
        }
        .animation(.easeInOut(duration: 0.2), value: isSelected)
    }
}

#Preview {
    VStack {
        GlassTabBar(
            tabs: .constant([
                EnsoTab(type: .mail(folderId: nil), title: "Inbox", isClosable: false),
                EnsoTab(type: .compose(draftId: nil), title: "New Message"),
                EnsoTab(type: .aiConversation(conversationId: nil), title: "AI Assistant")
            ]),
            selectedTabId: .constant(nil),
            onNewTab: {},
            onCloseTab: { _ in }
        )

        Spacer()
    }
    .frame(width: 600, height: 400)
    .background(.background)
}
