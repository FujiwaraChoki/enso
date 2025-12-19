//
//  ContextualActionChips.swift
//  Enso
//

import SwiftUI

// MARK: - Action Chip Type

/// Represents the different types of quick actions available in the AI sidebar.
enum ActionChip: String, CaseIterable, Identifiable {
    case summarize = "Summarize"
    case draftReply = "Draft Reply"
    case extractInfo = "Extract Info"
    case actionItems = "Action Items"
    case moreDetail = "More Detail"
    case makeShorter = "Make Shorter"
    case makeFormal = "Make Formal"
    case makeCasual = "Make Casual"
    case copy = "Copy"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .summarize: return "doc.text"
        case .draftReply: return "arrowshape.turn.up.left"
        case .extractInfo: return "text.magnifyingglass"
        case .actionItems: return "checklist"
        case .moreDetail: return "plus.magnifyingglass"
        case .makeShorter: return "arrow.down.left.and.arrow.up.right"
        case .makeFormal: return "briefcase"
        case .makeCasual: return "face.smiling"
        case .copy: return "doc.on.doc"
        }
    }

    var accentColor: Color {
        switch self {
        case .summarize: return .blue
        case .draftReply: return .green
        case .extractInfo: return .purple
        case .actionItems: return .orange
        case .moreDetail: return .cyan
        case .makeShorter: return .indigo
        case .makeFormal: return .teal
        case .makeCasual: return .pink
        case .copy: return .secondary
        }
    }

    /// The prompt to send when this chip is tapped
    var prompt: String {
        switch self {
        case .summarize:
            return "Please summarize this email concisely."
        case .draftReply:
            return "Draft a professional reply to this email."
        case .extractInfo:
            return "Extract key information from this email including dates, names, topics, and any requests."
        case .actionItems:
            return "List any action items or tasks mentioned in this email."
        case .moreDetail:
            return "Please provide more detail about the previous response."
        case .makeShorter:
            return "Please make the previous response shorter and more concise."
        case .makeFormal:
            return "Please rewrite the previous response in a more formal tone."
        case .makeCasual:
            return "Please rewrite the previous response in a more casual, friendly tone."
        case .copy:
            return "" // Copy is handled specially
        }
    }
}

// MARK: - Contextual Action Chips View

/// A horizontally scrolling row of contextual action chips with Liquid Glass styling.
struct ContextualActionChips: View {
    let hasEmail: Bool
    let lastResponseType: AIService.ResponseType
    let isGenerating: Bool
    let onChipTap: (ActionChip) -> Void
    let onCopy: () -> Void

    private var chips: [ActionChip] {
        guard hasEmail else { return [] }

        switch lastResponseType {
        case .none:
            return [.summarize, .draftReply, .extractInfo, .actionItems]
        case .summary:
            return [.draftReply, .moreDetail, .actionItems, .copy]
        case .draftReply:
            return [.makeShorter, .makeFormal, .makeCasual, .copy]
        case .extractedInfo:
            return [.summarize, .draftReply, .actionItems, .copy]
        case .actionItems:
            return [.summarize, .draftReply, .copy]
        case .other:
            return [.summarize, .draftReply, .moreDetail, .copy]
        }
    }

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            GlassEffectContainer(spacing: 8) {
                HStack(spacing: 8) {
                    ForEach(chips) { chip in
                        ActionChipButton(
                            chip: chip,
                            isDisabled: isGenerating || (!hasEmail && chip != .copy),
                            onTap: {
                                if chip == .copy {
                                    onCopy()
                                } else {
                                    onChipTap(chip)
                                }
                            }
                        )
                    }
                }
                .padding(.horizontal, 4)
            }
        }
        .scrollClipDisabled()
        .animation(.spring(duration: 0.3), value: lastResponseType)
    }
}

// MARK: - Action Chip Button

/// A single action chip button with Liquid Glass styling.
struct ActionChipButton: View {
    let chip: ActionChip
    let isDisabled: Bool
    let onTap: () -> Void

    @State private var isHovered = false
    @State private var isPressed = false

    var body: some View {
        Button(action: {
            withAnimation(.spring(duration: 0.2)) {
                isPressed = true
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                isPressed = false
                onTap()
            }
        }) {
            HStack(spacing: 7) {
                // Icon with subtle color accent
                ZStack {
                    Circle()
                        .fill(chip.accentColor.opacity(isDisabled ? 0.05 : 0.12))
                        .frame(width: 22, height: 22)

                    Image(systemName: chip.icon)
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(isDisabled ? Color.secondary.opacity(0.5) : chip.accentColor)
                }

                Text(chip.rawValue)
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundStyle(isDisabled ? Color.secondary.opacity(0.5) : .primary)
            }
            .padding(.leading, 6)
            .padding(.trailing, 14)
            .padding(.vertical, 8)
            .background(
                .regularMaterial,
                in: Capsule()
            )
        }
        .buttonStyle(.plain)
        .disabled(isDisabled)
        .scaleEffect(isPressed ? 0.95 : (isHovered ? 1.03 : 1.0))
        .opacity(isDisabled ? 0.6 : 1.0)
        .animation(.spring(duration: 0.2), value: isHovered)
        .animation(.spring(duration: 0.15), value: isPressed)
        .onHover { hovering in
            guard !isDisabled else { return }
            isHovered = hovering
        }
    }
}

// MARK: - Previews

#Preview("Initial State") {
    ContextualActionChips(
        hasEmail: true,
        lastResponseType: .none,
        isGenerating: false,
        onChipTap: { _ in },
        onCopy: {}
    )
    .frame(width: 350)
    .padding()
}

#Preview("After Summary") {
    ContextualActionChips(
        hasEmail: true,
        lastResponseType: .summary,
        isGenerating: false,
        onChipTap: { _ in },
        onCopy: {}
    )
    .frame(width: 350)
    .padding()
}

#Preview("After Draft Reply") {
    ContextualActionChips(
        hasEmail: true,
        lastResponseType: .draftReply,
        isGenerating: false,
        onChipTap: { _ in },
        onCopy: {}
    )
    .frame(width: 350)
    .padding()
}

#Preview("No Email") {
    ContextualActionChips(
        hasEmail: false,
        lastResponseType: .none,
        isGenerating: false,
        onChipTap: { _ in },
        onCopy: {}
    )
    .frame(width: 350)
    .padding()
}
