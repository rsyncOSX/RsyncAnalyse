//
//  SupportingViewComponents.swift
//  RsyncAnalyse
//
//  Created by Thomas Evensen on 15/01/2026.
//

import SwiftUI

// MARK: - Row View Component

public struct RsyncOutputRowView: View {
    let record: String

    public init(record: String) {
        self.record = record
    }

    public var body: some View {
        if let parsed = RsyncOutputRecord(from: record) {
            ParsedRsyncRow(parsed: parsed)
        } else {
            // Unparseable output - show as plain text
            Text(record)
                .font(.caption)
                .textSelection(.enabled)
        }
    }
}

// MARK: - Parsed Row Component

public struct ParsedRsyncRow: View {
    let parsed: RsyncOutputRecord

    public init(parsed: RsyncOutputRecord) {
        self.parsed = parsed
    }

    public var body: some View {
        HStack(spacing: 6) {
            // Update type tag
            UpdateTypeTag(updateTypeLabel: parsed.updateTypeLabel)

            // File type tag
            FileTypeTag(fileTypeLabel: parsed.fileTypeLabel)

            // Changed attributes
            if !parsed.attributes.isEmpty {
                ForEach(parsed.attributes) { attr in
                    AttributeBadge(name: attr.name)
                }
            }

            // Path
            Text(parsed.path)
                .lineLimit(1)
                .font(.caption)
                .textSelection(.enabled)
        }
    }
}

// MARK: - Reusable Tag Components

public struct UpdateTypeTag: View {
    let updateTypeLabel: (text: String, color: Color)

    public init(updateTypeLabel: (text: String, color: Color)) {
        self.updateTypeLabel = updateTypeLabel
    }

    public var body: some View {
        Text(updateTypeLabel.text)
            .foregroundColor(.white)
            .font(.caption.bold())
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(updateTypeLabel.color)
            .cornerRadius(4)
            .accessibilityLabel("Update type: \(updateTypeLabel.text)")
    }
}

public struct FileTypeTag: View {
    let fileTypeLabel: String

    public init(fileTypeLabel: String) {
        self.fileTypeLabel = fileTypeLabel
    }

    public var body: some View {
        Text(fileTypeLabel)
            .foregroundColor(.secondary)
            .font(.caption)
            .padding(.horizontal, 4)
            .padding(.vertical, 2)
            .background(Color.secondary.opacity(0.1))
            .cornerRadius(3)
            .accessibilityLabel("File type: \(fileTypeLabel)")
    }
}

public struct AttributeBadge: View {
    let name: String

    public init(name: String) {
        self.name = name
    }

    public var body: some View {
        Text(name)
            .foregroundColor(.orange)
            .font(.caption2)
            .padding(.horizontal, 4)
            .padding(.vertical, 2)
            .background(Color.orange.opacity(0.15))
            .cornerRadius(3)
            .accessibilityLabel("Changed attribute: \(name)")
    }
}

// MARK: - Supporting Views

public struct SectionHeader: View {
    let icon: String
    let title: String

    public init(icon: String, title: String) {
        self.icon = icon
        self.title = title
    }

    public var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(.accentColor)
            Text(title)
                .font(.headline)
        }
        .padding(.bottom, 4)
    }
}

public struct StatCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color

    public init(title: String, value: String, icon: String, color: Color) {
        self.title = title
        self.value = value
        self.icon = icon
        self.color = color
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(color)
                Spacer()
            }

            Text(value)
                .font(.title2)
                .fontWeight(.bold)

            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding()
        .background(color.opacity(0.1))
        .cornerRadius(8)
    }
}

public struct ChangeTypeRow: View {
    let icon: String
    let label: String
    let count: Int
    let color: Color

    public init(icon: String, label: String, count: Int, color: Color) {
        self.icon = icon
        self.label = label
        self.count = count
        self.color = color
    }

    public var body: some View {
        HStack {
            Text(icon)
            Text(label)
                .foregroundColor(.primary)
            Spacer()
            Text("\(count)")
                .fontWeight(.semibold)
                .foregroundColor(color)
        }
        .padding(.vertical, 4)
    }
}

public struct StatRow: View {
    let label: String
    let value: String
    var indent: Bool = false

    public init(label: String, value: String, indent: Bool = false) {
        self.label = label
        self.value = value
        self.indent = indent
    }

    public var body: some View {
        HStack {
            Text(label)
                .foregroundColor(indent ? .secondary : .primary)
                .padding(.leading, indent ? 16 : 0)
            Spacer()
            Text(value)
                .fontWeight(indent ? .regular : .medium)
        }
        .padding(.vertical, 2)
    }
}

public struct FilterChip: View {
    let icon: String
    let label: String
    let isSelected: Bool
    let action: () -> Void

    public init(icon: String, label: String, isSelected: Bool, action: @escaping () -> Void) {
        self.icon = icon
        self.label = label
        self.isSelected = isSelected
        self.action = action
    }

    public var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Text(icon)
                Text(label)
                    .font(.caption)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(isSelected ? Color.accentColor : Color.gray.opacity(0.2))
            .foregroundColor(isSelected ? .white : .primary)
            .cornerRadius(16)
        }
        .buttonStyle(.plain)
    }
}

public struct ChangeItemRow: View {
    let change: ActorRsyncOutputAnalyser.ItemizedChange

    public init(change: ActorRsyncOutputAnalyser.ItemizedChange) {
        self.change = change
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                // Change type icon
                Text(changeTypeIcon)
                    .font(.title3)

                // Path
                VStack(alignment: .leading, spacing: 2) {
                    Text(change.path)
                        .font(.body)
                        .lineLimit(2)

                    // Target for symlinks
                    if let target = change.target {
                        HStack(spacing: 4) {
                            Image(systemName: "arrow.right")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text(target)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }

                Spacer()
            }

            // Flags
            if hasFlags {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        if change.flags.checksum {
                            FlagBadge(label: "checksum", color: .blue)
                        }
                        if change.flags.size {
                            FlagBadge(label: "size", color: .orange)
                        }
                        if change.flags.timestamp {
                            FlagBadge(label: "time", color: .purple)
                        }
                        if change.flags.permissions {
                            FlagBadge(label: "perms", color: .green)
                        }
                        if change.flags.owner {
                            FlagBadge(label: "owner", color: .red)
                        }
                        if change.flags.group {
                            FlagBadge(label: "group", color: .pink)
                        }
                        if change.flags.acl {
                            FlagBadge(label: "acl", color: .indigo)
                        }
                        if change.flags.xattr {
                            FlagBadge(label: "xattr", color: .teal)
                        }
                    }
                }
            }
        }
        .padding(.vertical, 4)
    }

    private var changeTypeIcon: String {
        switch change.changeType {
        case .file: "📄"
        case .directory: "📁"
        case .symlink: "🔗"
        case .device: "💿"
        case .special: "⚙️"
        case .unknown: "❓"
        case .deletion: "🗑️"
        }
    }

    private var hasFlags: Bool {
        change.flags.checksum || change.flags.size || change.flags.timestamp ||
            change.flags.permissions || change.flags.owner || change.flags.group ||
            change.flags.acl || change.flags.xattr
    }
}

public struct FlagBadge: View {
    let label: String
    let color: Color

    public init(label: String, color: Color) {
        self.label = label
        self.color = color
    }

    public var body: some View {
        Text(label)
            .font(.caption2)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(color.opacity(0.2))
            .foregroundColor(color)
            .cornerRadius(4)
    }
}
