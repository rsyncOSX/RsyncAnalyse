//
//  RsyncOutputRecord.swift
//  RsyncAnalyse
//
//  Created by Thomas Evensen on 11/01/2026.
//

import SwiftUI

// MARK: - Unified Rsync Output Parser

/// Unified parser for rsync itemized output format (12-character format).
/// Format: YXcstpoguax where Y=update type, X=file type, rest=attributes
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
    /// - Note: Format is 12 characters + space + path (e.g., ".f..t...... file.txt")
    public init?(from record: String) {
        // Handle deletion/message format:  "*deleting file.txt"
        if record.hasPrefix("*") {
            let components = record.split(separator: " ", maxSplits: 1)
            guard components.count == 2 else { return nil }

            updateType = "*"
            fileType = " " // Unknown in message format
            attributes = []
            path = String(components[1])
            return
        }

        // Try strict 12-character format
        if record.count >= 13, let parsed = Self.parseStrictFormat(record) {
            self = parsed
            return
        }

        return nil
    }

    // MARK: - Parsing Methods

    /// Parse strict 12-character rsync format: ".f..t...... file.txt"
    private static func parseStrictFormat(_ record: String) -> RsyncOutputRecord? {
        let chars = Array(record)
        guard chars.count >= 13, chars[12] == Character(" ") else { return nil }

        let updateType = chars[0]
        let fileType = chars[1]

        var attrs: [RsyncAttribute] = []

        // Position 2: checksum/content
        if chars[2] == "c" || chars[2] == "+" {
            attrs.append(RsyncAttribute(name: "checksum", code: chars[2]))
        }

        // Position 3: size
        if chars[3] == "s" || chars[3] == "+" {
            attrs.append(RsyncAttribute(name: "size", code: chars[3]))
        }

        // Position 4: time (can be 't', 'T', or '+')
        if chars[4] == "t" || chars[4] == "T" || chars[4] == "+" {
            attrs.append(RsyncAttribute(name: "time", code: chars[4]))
        }

        // Position 5: permissions
        if chars[5] == "p" || chars[5] == "+" {
            attrs.append(RsyncAttribute(name: "permissions", code: chars[5]))
        }

        // Position 6: owner
        if chars[6] == "o" || chars[6] == "+" {
            attrs.append(RsyncAttribute(name: "owner", code: chars[6]))
        }

        // Position 7: group
        if chars[7] == "g" || chars[7] == "+" {
            attrs.append(RsyncAttribute(name: "group", code: chars[7]))
        }

        // Position 8: reserved/user (usually 'u' or '+')
        if chars[8] == "u" || chars[8] == "+" {
            attrs.append(RsyncAttribute(name: "reserved", code: chars[8]))
        }

        // Position 9: ACL
        if chars.count > 9, chars[9] == "a" || chars[9] == "+" {
            attrs.append(RsyncAttribute(name: "acl", code: chars[9]))
        }

        // Position 10: extended attributes
        if chars.count > 10, chars[10] == "x" || chars[10] == "+" {
            attrs.append(RsyncAttribute(name: "xattr", code: chars[10]))
        }

        let path = String(chars.dropFirst(13)).trimmingCharacters(in: .whitespaces)

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
        case "d": "directory"
        case "L": "symlink"
        case "D": "device"
        case "S": "special"
        case " ": "unknown"
        default: String(fileType)
        }
    }

    public var updateTypeLabel: (text: String, color: Color) {
        switch updateType {
        case ".": ("NO_UPDATE", .gray)
        case "*": ("MESSAGE", .orange)
        case ">": ("SENT", .purple)
        case "<": ("RECEIVED", .blue)
        case "c": ("LOCAL_CHANGE", .green)
        case "h": ("HARDLINK", .indigo)
        default: ("UNKNOWN", .red)
        }
    }

    /// Check if this record represents a new item (all attributes are '+')
    public var isNewItem: Bool {
        return attributes.allSatisfy { $0.code == "+" }
    }

    /// Check if this is a deletion message
    public var isDeletion: Bool {
        return updateType == "*" && path.isEmpty == false
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
