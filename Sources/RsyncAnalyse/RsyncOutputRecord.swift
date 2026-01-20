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
    public var message: String?

    /// Initialize with explicit values
    public init(path: String, updateType: Character, fileType: Character, attributes: [RsyncAttribute]) {
        self.path = path
        self.updateType = updateType
        self.fileType = fileType
        self.attributes = attributes
        self.message = nil
    }

    /// Parse rsync output record with automatic format detection
    /// - Parameter record: Raw rsync output line
    /// - Note: Format is 12 characters + space + path (e.g., ".f..t...... file.txt")
    public init?(from record: String) {
        // Handle deletion/message format:  "*deleting file.txt"
        // Other messages may be: *received, *unsafe, *skip-over
        // I exepcet the message to be followed by a space like the "*deleting file.txt"
        // Strip of the star and set the public message to use as label
        if record.hasPrefix("*") {
            let content = record.dropFirst()
            
            // Find the first space after the "*"
            if let spaceIndex = content.firstIndex(of: " ") {
                let msg = content[..<spaceIndex]
                let path = content[content.index(after: spaceIndex)...]
                
                self.path = String(path)
                self.updateType = "*"
                self.fileType = " "
                self.attributes = []
                self.message = String(msg)
                return
            }
            return nil
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

        // Position 3: checksum/content
        if chars[2] == "c" || chars[2] == "+" {
            attrs.append(RsyncAttribute(name: "checksum", code: chars[2]))
        }

        // Position 4: size
        if chars[3] == "s" || chars[3] == "+" {
            attrs.append(RsyncAttribute(name: "size", code: chars[3]))
        }

        // Position 5: time (can be 't', 'T', or '+')
        if chars[4] == "t" || chars[4] == "T" || chars[4] == "+" {
            attrs.append(RsyncAttribute(name: "time", code: chars[4]))
        }

        // Position 6: permissions
        if chars[5] == "p" || chars[5] == "+" {
            attrs.append(RsyncAttribute(name: "permissions", code: chars[5]))
        }

        // Position 7: owner
        if chars[6] == "o" || chars[6] == "+" {
            attrs.append(RsyncAttribute(name: "owner", code: chars[6]))
        }

        // Position 8: group
        if chars[7] == "g" || chars[7] == "+" {
            attrs.append(RsyncAttribute(name: "group", code: chars[7]))
        }

        // Position 9: reserved/user (usually 'u' or '+')
        if chars[8] == "u" || chars[8] == "+" {
            attrs.append(RsyncAttribute(name: "reserved", code: chars[8]))
        }

        // Position 10: ACL
        if chars[9] == "a" || chars[9] == "+" {
            attrs.append(RsyncAttribute(name: "acl", code: chars[9]))
        }

        // Position 11: extended attributes
        if chars[10] == "x" || chars[10] == "+" {
            attrs.append(RsyncAttribute(name: "xattr", code: chars[10]))
        }

        // Position 11: future use
        if chars[11] == "?" || chars[11] == "+" {
            attrs.append(RsyncAttribute(name: "future", code: chars[11]))
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
        case "*": {
            let msg = self.message ?? "MESSAGE"
            return (msg, .red)
        }()
        case "d": ("DELETE", .red)
        case "<": ("SENT", .blue)
        case ">": ("RECEIVED", .purple)
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
