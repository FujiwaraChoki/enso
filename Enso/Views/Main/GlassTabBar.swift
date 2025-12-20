//
//  GlassTabBar.swift
//  Enso
//
//

import SwiftUI

struct GlassTabBar: View {
    @Binding var tabs: [EnsoTab]
    @Binding var selectedTabId: UUID?
    var onNewTab: () -> Void
    var onCloseTab: (UUID) -> Void

    @Namespace private var tabNamespace

    var body: some View {
        HStack(spacing: 0) {
            // Tab items
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 4) {
                    ForEach(tabs) { tab in
                        TabItemView(
                            tab: tab,
                            isSelected: tab.id == selectedTabId,
                            onSelect: { selectedTabId = tab.id },
                            onClose: { onCloseTab(tab.id) }
                        )
                    }
                }
                .padding(.horizontal, 4)
            }
            // Limit the scroll view width so it doesn't push the button off if not needed,
            // but allow it to expand.
            // Actually, ScrollView takes available space.

            // Divider
            Divider()
                .frame(height: 16)
                .padding(.horizontal, 8)
                .opacity(0.3)

            // New Tab Button
            Button(action: onNewTab) {
                Image(systemName: "plus")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(Color.primary.opacity(0.7))
                    .frame(width: 28, height: 28)
                    .contentShape(Circle())
            }
            .buttonStyle(.plain)
            .padding(.trailing, 4)
        }
        .padding(5)
        .glassEffect(.regular, in: Capsule())
        .padding(.horizontal)
        .padding(.top, 8)
        .frame(height: 50) // Fixed height for stability
    }
}

struct TabItemView: View {
    let tab: EnsoTab
    let isSelected: Bool
    var onSelect: () -> Void
    var onClose: () -> Void

    @State private var isHovering = false

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: tab.icon)
                .font(.system(size: 12, weight: isSelected ? .semibold : .regular))
                .foregroundStyle(isSelected ? Color.accentColor : Color.primary.opacity(0.6))

            Text(tab.title)
                .font(.system(size: 13, weight: isSelected ? .medium : .regular))
                .lineLimit(1)
                .foregroundStyle(isSelected ? Color.primary : Color.primary.opacity(0.6))

            if tab.isClosable && (isHovering || isSelected) {
                Button(action: onClose) {
                    Image(systemName: "xmark")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(Color.primary.opacity(0.5))
                        .padding(4)
                        .contentShape(Circle())
                }
                .buttonStyle(.plain)
                .background(
                    Circle()
                        .fill(Color.primary.opacity(isHovering ? 0.1 : 0.0))
                )
                .transition(.opacity.combined(with: .scale))
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .frame(minWidth: 100, maxWidth: 180)
        .contentShape(Capsule())
        .background(
            Capsule()
                .fill(isSelected ? Color.accentColor.opacity(0.15) : (isHovering ? Color.primary.opacity(0.08) : Color.clear))
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
    ZStack {
        Color.gray.opacity(0.2).ignoresSafeArea()

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
    }
    .frame(width: 600, height: 400)
}
