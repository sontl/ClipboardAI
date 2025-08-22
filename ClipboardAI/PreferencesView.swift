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
        VStack(alignment: .leading, spacing: 16) {
            Text("Preferences")
                .font(.title2)
                .bold()

            GroupBox(label: Text("Rephrase Style")) {
                HStack {
                    Text("Tone")
                    Spacer()
                    Picker("Tone", selection: $tone) {
                        ForEach(tones, id: \.self) { t in
                            Text(t).tag(t)
                        }
                    }
                    .pickerStyle(.menu)
                    .frame(width: 180)
                }
                .padding(.vertical, 4)
                Text("Controls the writing tone used when rephrasing.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            GroupBox(label: Text("Shortcuts")) {
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text("Copy & Rephrase")
                        Spacer()
                        Text("⇧⌘C")
                            .monospaced()
                            .padding(4)
                            .background(RoundedRectangle(cornerRadius: 4).fill(Color.gray.opacity(0.15)))
                    }
                    Text("Use the menu bar icon → Preferences… to view settings. Shortcut is currently fixed.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            HStack {
                Spacer()
                Button("Close") { dismiss() }
            }
        }
        .padding(20)
        .frame(minWidth: 420, minHeight: 260)
    }
}

#Preview {
    PreferencesView()
        .frame(width: 420, height: 260)
}
