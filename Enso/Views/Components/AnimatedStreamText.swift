//
//  AnimatedStreamText.swift
//  Enso
//

import SwiftUI

/// A text view that animates words fading in as they stream from the AI model.
/// When streaming, new words appear with a smooth fade-in animation.
/// When not streaming (complete text), all words are fully visible.
struct AnimatedStreamText: View {
    let text: String
    let isStreaming: Bool
    let font: Font
    let foregroundStyle: Color

    @State private var revealedWordCount: Int = 0
    @State private var previousWordCount: Int = 0

    init(
        text: String,
        isStreaming: Bool,
        font: Font = .body,
        foregroundStyle: Color = .primary
    ) {
        self.text = text
        self.isStreaming = isStreaming
        self.font = font
        self.foregroundStyle = foregroundStyle
    }

    private var words: [WordToken] {
        tokenize(text)
    }

    var body: some View {
        FlowLayout(spacing: 4, lineSpacing: 4) {
            ForEach(Array(words.enumerated()), id: \.offset) { index, token in
                WordView(
                    token: token,
                    isRevealed: !isStreaming || index < revealedWordCount,
                    font: font,
                    foregroundStyle: foregroundStyle
                )
            }
        }
        .onChange(of: text) { _, newText in
            let newWords = tokenize(newText)
            let newCount = newWords.count

            if newCount > previousWordCount {
                // New words arrived - animate them in
                animateNewWords(from: previousWordCount, to: newCount)
            }
            previousWordCount = newCount
        }
        .onChange(of: isStreaming) { _, streaming in
            if !streaming {
                // Streaming ended - reveal all words immediately
                revealedWordCount = words.count
            }
        }
        .onAppear {
            // If not streaming, show all words immediately
            if !isStreaming {
                revealedWordCount = words.count
                previousWordCount = words.count
            }
        }
    }

    private func animateNewWords(from startIndex: Int, to endIndex: Int) {
        // Reveal words one by one with a slight delay between each
        let wordsToReveal = endIndex - startIndex
        let baseDelay: Double = 0.03 // 30ms between words

        for i in 0..<wordsToReveal {
            let delay = Double(i) * baseDelay
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                withAnimation(.easeIn(duration: 0.15)) {
                    revealedWordCount = startIndex + i + 1
                }
            }
        }
    }

    /// Tokenize text into words while preserving whitespace and punctuation groupings
    private func tokenize(_ text: String) -> [WordToken] {
        var tokens: [WordToken] = []
        var currentWord = ""
        var currentIndex = 0

        for char in text {
            if char.isWhitespace {
                if !currentWord.isEmpty {
                    tokens.append(WordToken(id: currentIndex, content: currentWord))
                    currentIndex += 1
                    currentWord = ""
                }
            } else {
                currentWord.append(char)
            }
        }

        // Don't forget the last word
        if !currentWord.isEmpty {
            tokens.append(WordToken(id: currentIndex, content: currentWord))
        }

        return tokens
    }
}

// MARK: - Word Token

struct WordToken: Identifiable, Equatable {
    let id: Int
    let content: String
}

// MARK: - Word View

private struct WordView: View {
    let token: WordToken
    let isRevealed: Bool
    let font: Font
    let foregroundStyle: Color

    var body: some View {
        Text(token.content)
            .font(font)
            .foregroundStyle(foregroundStyle)
            .opacity(isRevealed ? 1 : 0)
    }
}

// MARK: - Flow Layout

/// A layout that arranges views in a flowing manner, wrapping to new lines as needed.
struct FlowLayout: Layout {
    var spacing: CGFloat
    var lineSpacing: CGFloat

    init(spacing: CGFloat = 8, lineSpacing: CGFloat = 4) {
        self.spacing = spacing
        self.lineSpacing = lineSpacing
    }

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = arrangeSubviews(proposal: proposal, subviews: subviews)
        return result.size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = arrangeSubviews(proposal: proposal, subviews: subviews)

        for (index, position) in result.positions.enumerated() {
            guard index < subviews.count else { break }
            subviews[index].place(
                at: CGPoint(x: bounds.minX + position.x, y: bounds.minY + position.y),
                proposal: ProposedViewSize(result.sizes[index])
            )
        }
    }

    private func arrangeSubviews(proposal: ProposedViewSize, subviews: Subviews) -> ArrangementResult {
        let maxWidth = proposal.width ?? .infinity
        var positions: [CGPoint] = []
        var sizes: [CGSize] = []
        var currentX: CGFloat = 0
        var currentY: CGFloat = 0
        var lineHeight: CGFloat = 0
        var totalHeight: CGFloat = 0
        var totalWidth: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            sizes.append(size)

            // Check if we need to wrap to next line
            if currentX + size.width > maxWidth && currentX > 0 {
                currentX = 0
                currentY += lineHeight + lineSpacing
                lineHeight = 0
            }

            positions.append(CGPoint(x: currentX, y: currentY))
            lineHeight = max(lineHeight, size.height)
            currentX += size.width + spacing
            totalWidth = max(totalWidth, currentX - spacing)
        }

        totalHeight = currentY + lineHeight

        return ArrangementResult(
            positions: positions,
            sizes: sizes,
            size: CGSize(width: totalWidth, height: totalHeight)
        )
    }

    private struct ArrangementResult {
        let positions: [CGPoint]
        let sizes: [CGSize]
        let size: CGSize
    }
}

// MARK: - Preview

#Preview("Streaming") {
    @Previewable @State var text = "Hello world this is a streaming text animation test."
    @Previewable @State var isStreaming = true

    VStack(spacing: 20) {
        AnimatedStreamText(text: text, isStreaming: isStreaming)
            .padding()
            .background(Color(.controlBackgroundColor))
            .cornerRadius(12)

        Button(isStreaming ? "Stop Streaming" : "Start Streaming") {
            isStreaming.toggle()
        }

        Button("Add Words") {
            text += " More words appear here."
        }
    }
    .padding()
    .frame(width: 350)
}
