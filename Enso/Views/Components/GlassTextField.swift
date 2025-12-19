//
//  GlassTextField.swift
//  Enso
//

import SwiftUI

struct GlassTextField: View {
    let title: String
    let placeholder: String
    @Binding var text: String
    let icon: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.caption)
                .fontWeight(.medium)
                .foregroundStyle(.secondary)

            HStack(spacing: 12) {
                if let icon {
                    Image(systemName: icon)
                        .foregroundStyle(.tertiary)
                        .frame(width: 20)
                        .imageScale(.medium)
                }

                TextField(placeholder, text: $text)
                    .textFieldStyle(.plain)
                    .foregroundStyle(.primary)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 12))
        }
    }
}

#Preview {
    VStack(spacing: 20) {
        GlassTextField(
            title: "Email Address",
            placeholder: "you@example.com",
            text: .constant(""),
            icon: "envelope"
        )

        GlassTextField(
            title: "IMAP Server",
            placeholder: "imap.example.com",
            text: .constant("imap.gmail.com"),
            icon: "server.rack"
        )

        GlassTextField(
            title: "Port",
            placeholder: "993",
            text: .constant(""),
            icon: nil
        )
    }
    .padding(40)
    .frame(width: 400)
}
