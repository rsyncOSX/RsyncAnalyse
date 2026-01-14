//
//  DetailsVerifyView.swift
//  RsyncAnalyse
//
//  Created by Thomas Evensen on 11/01/2026.
//

import SwiftUI

// MARK: - Unified Rsync Output Parser

/// Unified parser for rsync itemized output format.
/// Handles both strict 12-character format and whitespace-separated format.
public struct RsyncOutputRecord {
    public let path: String
    public let updateType: Character
    public let fileType: Character
    public let attributes: [RsyncAttribute]

    /// Initialize with explicit values
    public init(path: String, updateType: Character, fileType: Character, attributes: [RsyncAttribute]) {
        self.path = path
        self.updateType = updateType
        self.fileType = fileType
        self.attributes = attributes
    }

    /// Parse rsync output record with automatic format detection
    /// - Parameter record: Raw rsync output line
    /// - Note: Supports both strict format (".f..t....... file.txt") and flexible format ("*deleting file.txt")
    public init?(from record: String) {
        // Handle deletion format first
        if record.hasPrefix("*deleting") {
            updateType = "-"
            fileType = "f"
            attributes = []
            path = record.replacingOccurrences(of: "*deleting", with: "").trimmingCharacters(in: .whitespaces)
            return
        }

        // Try strict 12-character format first (most common)
        if record.count >= 13, let parsed = Self.parseStrictFormat(record) {
            self = parsed
            return
        }

        // Fall back to flexible whitespace-separated format
        if let parsed = Self.parseFlexibleFormat(record) {
            self = parsed
            return
        }

        return nil
    }

    // MARK: - Parsing Methods

    /// Parse strict 12-character rsync format: ".f..t....... file.txt"
    private static func parseStrictFormat(_ record: String) -> RsyncOutputRecord? {
        let chars = Array(record)
        guard chars.count >= 13, chars[12] == Character(" ") else { return nil }

        let updateType = chars[0]
        let fileType = chars[1]

        var attrs: [RsyncAttribute] = []
        let attributePositions = [
            (index: 2, name: "checksum", code: Character("c")),
            (index: 3, name: "size", code: Character("s")),
            (index: 4, name: "time", code: Character("t")),
            (index: 5, name: "permissions", code: Character("p")),
            (index: 6, name: "owner", code: Character("o")),
            (index: 7, name: "group", code: Character("g")),
            (index: 8, name: "acl", code: Character("a")),
            (index: 9, name: "xattr", code: Character("x"))
        ]

        for position in attributePositions where position.index < chars.count && chars[position.index] == position.code {
            attrs.append(RsyncAttribute(name: position.name, code: position.code))
        }

        let path = String(chars.dropFirst(13)).trimmingCharacters(in: .whitespaces)

        return RsyncOutputRecord(
            path: path,
            updateType: updateType,
            fileType: fileType,
            attributes: attrs
        )
    }

    /// Parse flexible whitespace-separated format: ">f.stp file.txt"
    private static func parseFlexibleFormat(_ record: String) -> RsyncOutputRecord? {
        let components = record.components(separatedBy: .whitespaces).filter { !$0.isEmpty }
        guard components.count >= 2 else { return nil }

        let flagChars = Array(components[0])
        guard flagChars.count >= 2 else { return nil }

        let updateType = flagChars[0]
        let fileType = flagChars[1]
        let path = components.dropFirst().joined(separator: " ")

        var attrs: [RsyncAttribute] = []
        let attributeMapping: [(code: Character, name: String)] = [
            (Character("c"), "checksum"),
            (Character("s"), "size"),
            (Character("t"), "time"),
            (Character("p"), "permissions"),
            (Character("o"), "owner"),
            (Character("g"), "group"),
            (Character("a"), "acl"),
            (Character("x"), "xattr")
        ]

        for (code, name) in attributeMapping where flagChars.dropFirst(2).contains(code) {
            attrs.append(RsyncAttribute(name: name, code: code))
        }

        return RsyncOutputRecord(
            path: path,
            updateType: updateType,
            fileType: fileType,
            attributes: attrs
        )
    }

    // MARK: - Computed Properties

    public var fileTypeLabel: String {
        switch fileType {
        case "f": "file"
        case "d": "dir"
        case "L": "link"
        case "D": "device"
        case "S": "special"
        default: String(fileType)
        }
    }

    public var updateTypeLabel: (text: String, color: Color) {
        switch updateType {
        case ".": ("NONE", .gray)
        case "*": ("UPDATED", .orange)
        case "+": ("CREATED", .green)
        case "-": ("DELETED", .red)
        case ">": ("RECEIVED", .blue)
        case "<": ("SENT", .purple)
        case "h": ("HARDLINK", .indigo)
        case "?": ("ERROR", .red)
        default: (String(updateType), .primary)
        }
    }
}

public struct RsyncAttribute: Identifiable {
    public let id = UUID()
    public let name: String
    public let code: Character
    
    public init(name: String, code: Character) {
        self.name = name
        self.code = code
    }
}

// MARK: - SwiftUI View Components

public struct DetailsVerifyView: View {
    public let remotedatanumbers: RemoteDataNumbers
    public let istagged: Bool

    public init(remotedatanumbers: RemoteDataNumbers, istagged: Bool) {
        self.remotedatanumbers = remotedatanumbers
        self.istagged = istagged
    }

    public var body: some View {
        if let records = remotedatanumbers.outputfromrsync {
            if istagged {
                Table(records) {
                    TableColumn("Output from rsync (\(records.count) rows)") { data in
                        RsyncOutputRowView(record: data.record)
                    }
                }
            } else {
                Table(records) {
                    TableColumn("Output from rsync (\(records.count) rows)") { data in
                        Text(data.record)
                            .font(.caption)
                            .textSelection(.enabled)
                    }
                }
            }
        } else {
            Text("No rsync output available")
                .foregroundColor(.secondary)
        }
    }
}

// MARK: - Row View Component

public struct RsyncOutputRowView: View {
    public let record: String

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
    public let parsed: RsyncOutputRecord

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
    public let updateTypeLabel: (text: String, color: Color)

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
    public let fileTypeLabel: String

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
    public let name: String

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
