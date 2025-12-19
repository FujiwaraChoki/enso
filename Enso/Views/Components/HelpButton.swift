//
//  HelpButton.swift
//  Enso
//

import SwiftUI

struct HelpButton: View {
    let title: String
    let message: String
    @State private var showPopover = false

    var body: some View {
        Button(action: {
            showPopover.toggle()
        }) {
            Image(systemName: "info.circle")
                .foregroundStyle(.secondary)
                .imageScale(.small)
        }
        .buttonStyle(.plain)
        .help("Learn more")
        .popover(isPresented: $showPopover, arrowEdge: .trailing) {
            VStack(alignment: .leading, spacing: 12) {
                Text(title)
                    .font(.headline)
                    .foregroundStyle(.primary)

                Text(message)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(16)
            .frame(maxWidth: 280)
        }
    }
}

#Preview {
    HStack {
        Text("Server Settings")
            .font(.subheadline)
            .foregroundStyle(.secondary)

        HelpButton(
            title: "About Server Settings",
            message: "IMAP is used to receive emails, while SMTP is used to send them. Enso will try to detect these settings automatically based on your email address."
        )
    }
    .padding(40)
}
