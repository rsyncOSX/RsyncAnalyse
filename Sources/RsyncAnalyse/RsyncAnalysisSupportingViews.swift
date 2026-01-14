//
//  RsyncAnalysisSupportingViews.swift
//  RsyncAnalyse
//
//  Created by Thomas Evensen on 13/01/2026.
//

import SwiftUI

// MARK: - Supporting Views

public struct SectionHeader: View {
    public let icon: String
    public let title: String

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
    public let title: String
    public let value: String
    public let icon: String
    public let color: Color

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
    public let icon: String
    public let label: String
    public let count: Int
    public let color: Color

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
    public let label: String
    public let value: String
    public var indent: Bool = false

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
    public let icon: String
    public let label: String
    public let isSelected: Bool
    public let action: () -> Void

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
    public let change: ActorRsyncOutputAnalyzer.ItemizedChange

    public init(change: ActorRsyncOutputAnalyzer.ItemizedChange) {
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
    public let label: String
    public let color: Color

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
