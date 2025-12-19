//
//  GlassSecureField.swift
//  Enso
//

import SwiftUI

struct GlassSecureField: View {
    let title: String
    let placeholder: String
    @Binding var text: String
    let icon: String?
    @State private var showPassword = false

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

                Group {
                    if showPassword {
                        TextField(placeholder, text: $text)
                    } else {
                        SecureField(placeholder, text: $text)
                    }
                }
                .textFieldStyle(.plain)
                .foregroundStyle(.primary)

                Button(action: {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        showPassword.toggle()
                    }
                }) {
                    Image(systemName: showPassword ? "eye.slash.fill" : "eye.fill")
                        .foregroundStyle(.secondary)
                        .imageScale(.medium)
                        .frame(width: 20)
                        .contentTransition(.symbolEffect(.replace))
                }
                .buttonStyle(.plain)
                .help(showPassword ? "Hide password" : "Show password")
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 12))
        }
    }
}

#Preview {
    VStack(spacing: 20) {
        GlassSecureField(
            title: "Password",
            placeholder: "Your email password",
            text: .constant(""),
            icon: "lock"
        )

        GlassSecureField(
            title: "Password",
            placeholder: "Your email password",
            text: .constant("SuperSecret123!"),
            icon: "lock"
        )
    }
    .padding(40)
    .frame(width: 400)
}
