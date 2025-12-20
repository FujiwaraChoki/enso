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
            .padding(.horizontal, 16)
            .padding(.vertical, 4)
        }
        .scrollClipDisabled()
    }
}

// MARK: - Action Chip Button

/// A single action chip button with Liquid Glass styling.
struct ActionChipButton: View {
    let chip: ActionChip
    let isDisabled: Bool
    let onTap: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: {
            onTap()
        }) {
            Text(chip.rawValue.uppercased())
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(isDisabled ? Color.secondary.opacity(0.3) : .secondary)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(
                    Capsule()
                        .fill(Color.secondary.opacity(isHovered ? 0.15 : 0.08))
                )
        }
        .buttonStyle(.plain)
        .disabled(isDisabled)
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
