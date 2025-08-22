//
//  PreferencesView.swift
//  ClipboardAI
//
//  Created by Cascade on 2025-08-22.
//

import SwiftUI

struct PreferencesView: View {
    @Environment(\.dismiss) private var dismiss
    @AppStorage("rephrase_tone") private var tone: String = "Professional"

    private let tones: [String] = [
        "Professional",
        "Friendly",
        "Concise",
        "Formal",
        "Casual"
    ]

    var body: some View {
        let labelWidth: CGFloat = 120
        VStack(alignment: .leading, spacing: 16) {
            // Rephrase section
            VStack(alignment: .leading, spacing: 8) {
                Text("Rephrase")
                    .font(.headline)
                Grid(alignment: .leading, horizontalSpacing: 12, verticalSpacing: 8) {
                    GridRow(alignment: .firstTextBaseline) {
                        Text("Tone")
                            .frame(width: labelWidth, alignment: .trailing)
                            .foregroundStyle(.secondary)
                        Picker(selection: $tone) {
                            ForEach(tones, id: \.self) { t in
                                Text(t).tag(t)
                            }
                        } label: { EmptyView() }
                        .pickerStyle(.menu)
                        .frame(minWidth: 220, maxWidth: 260, alignment: .leading)
                    }
                    GridRow {
                        Color.clear.frame(width: labelWidth)
                        Text("Controls the writing tone used when rephrasing.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            Divider().padding(.horizontal, -8)

            // Shortcuts section
            VStack(alignment: .leading, spacing: 8) {
                Text("Shortcuts")
                    .font(.headline)
                Grid(alignment: .leading, horizontalSpacing: 12, verticalSpacing: 8) {
                    GridRow(alignment: .firstTextBaseline) {
                        Text("Copy & Rephrase")
                            .frame(width: labelWidth, alignment: .trailing)
                            .foregroundStyle(.secondary)
                        Text("⇧⌘C")
                            .monospaced()
                            .padding(.vertical, 3)
                            .padding(.horizontal, 8)
                            .background(RoundedRectangle(cornerRadius: 6).fill(Color.gray.opacity(0.15)))
                    }
                    GridRow {
                        Color.clear.frame(width: labelWidth)
                        Text("Open via the menu bar icon → Preferences…. The shortcut is currently fixed.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            Spacer(minLength: 0)

            HStack {
                Spacer()
                Button("Close") { dismiss() }
                    .keyboardShortcut(.cancelAction)
            }
        }
        .padding(.all, 14)
        .frame(minWidth: 480, minHeight: 270)
    }
}

#Preview {
    PreferencesView()
        .frame(width: 420, height: 260)
}
