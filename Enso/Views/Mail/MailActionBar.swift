//
//  MailActionBar.swift
//  Enso
//

import SwiftUI

struct MailActionBar: View {
    let email: Email?
    let onReply: (Email) -> Void
    let onReplyAll: (Email) -> Void
    let onForward: (Email) -> Void
    let onMarkRead: (Email) async -> Void
    let onMarkUnread: (Email) async -> Void
    let onStar: (Email) async -> Void
    let onUnstar: (Email) async -> Void
    let onMove: (Email) -> Void
    let onDelete: (Email) async -> Void

    var body: some View {
        if let email {
            HStack(spacing: 14) {
                MailActionButton(systemImage: "arrowshape.turn.up.left", help: "Reply") {
                    onReply(email)
                }
                MailActionButton(systemImage: "arrowshape.turn.up.left.2", help: "Reply All") {
                    onReplyAll(email)
                }
                MailActionButton(systemImage: "arrowshape.turn.up.right", help: "Forward") {
                    onForward(email)
                }

                Divider()
                    .frame(height: 18)

                MailActionButton(
                    systemImage: email.isRead ? "envelope.badge" : "envelope.open",
                    help: email.isRead ? "Mark as Unread" : "Mark as Read"
                ) {
                    Task {
                        if email.isRead {
                            await onMarkUnread(email)
                        } else {
                            await onMarkRead(email)
                        }
                    }
                }

                MailActionButton(
                    systemImage: email.isStarred ? "star.fill" : "star",
                    help: email.isStarred ? "Unstar" : "Star",
                    tint: email.isStarred ? .yellow : .primary
                ) {
                    Task {
                        if email.isStarred {
                            await onUnstar(email)
                        } else {
                            await onStar(email)
                        }
                    }
                }

                MailActionButton(systemImage: "folder", help: "Move to Folder") {
                    onMove(email)
                }

                MailActionButton(systemImage: "trash", help: "Delete") {
                    Task { await onDelete(email) }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(.ultraThinMaterial, in: Capsule())
            .overlay(
                Capsule()
                    .stroke(.white.opacity(0.08), lineWidth: 1)
            )
        }
    }
}

private struct MailActionButton: View {
    let systemImage: String
    let help: String
    var tint: Color = .primary
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(tint)
                .frame(width: 28, height: 28)
        }
        .buttonStyle(.plain)
        .contentShape(Rectangle())
        .help(help)
    }
}

struct MoveFolderSheet: View {
    let email: Email
    let onMove: (Folder) async -> Void
    @Environment(\.dismiss) private var dismiss

    var folders: [Folder] {
        email.account?.folders.filter { $0.id != email.folder?.id } ?? []
    }

    var body: some View {
        NavigationStack {
            List(folders) { folder in
                Button(action: {
                    Task {
                        await onMove(folder)
                        dismiss()
                    }
                }) {
                    Label(folder.name, systemImage: folder.icon)
                }
            }
            .navigationTitle("Move to Folder")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
        .frame(minWidth: 300, minHeight: 400)
    }
}
