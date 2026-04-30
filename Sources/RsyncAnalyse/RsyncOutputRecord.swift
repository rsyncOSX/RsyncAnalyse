//
//  RsyncOutputRecord.swift
//  RsyncAnalyse
//
//  Created by Thomas Evensen on 11/01/2026.
//

import SwiftUI

// MARK: - Rsync Version

public enum RsyncVersion {
    case v341 // 12-char attribute prefix (includes namespace 'n' at position 8)
    case v342 // 11-char attribute prefix
}

// MARK: - Unified Rsync Output Parser

/// Unified parser for rsync itemized output.
/// Supports both rsync 3.4.2 (11-char attribute prefix) and rsync 3.4.1 (12-char attribute prefix).
/// Format: YX<attrs> where Y=update type, X=file type, followed by space + path.
public struct RsyncOutputRecord {
    public let path: String
    public let updateType: Character
    public let fileType: Character
    public let attributes: [RsyncAttribute]
    public let version: RsyncVersion?
    public var message: String?

    /// Initialize with explicit values
    public init(path: String,
                updateType: Character,
                fileType: Character,
                attributes: [RsyncAttribute],
                version: RsyncVersion? = nil) {
        self.path = path
        self.updateType = updateType
        self.fileType = fileType
        self.attributes = attributes
        self.version = version
        message = nil
    }

    /// Parse rsync output record with automatic format detection.
    /// - Parameter record: Raw rsync output line
    /// - Note: Format is 11 or 12 characters + space + path, depending on rsync version.
    public init?(from record: String) {
        // Handle deletion/message format:  "*deleting file.txt"
        // Other messages may be: *received, *unsafe, *skip-over
        // Strip the star and set the public message to use as label.
        if record.hasPrefix("*") {
            let content = record.dropFirst()

            if let spaceIndex = content.firstIndex(of: " ") {
                let msg = content[..<spaceIndex]
                let path = content[content.index(after: spaceIndex)...]

                self.path = String(path)
                updateType = "*"
                fileType = " "
                attributes = []
                version = nil
                message = String(msg)
                return
            }
            return nil
        }

        switch Self.detectRsyncVersion(record) {
        case .v342:
            if let parsed = Self.parseV342(record) {
                self = parsed
                return
            }
        case .v341:
            if let parsed = Self.parseV341(record) {
                self = parsed
                return
            }
        case .none:
            return nil
        }

        return nil
    }

    // MARK: - Version Detection

    /// Detect rsync version from the position of the trailing space in the attribute prefix.
    /// - 11-char prefix → space at index 11 → rsync 3.4.2
    /// - 12-char prefix → space at index 12 → rsync 3.4.1
    public static func detectRsyncVersion(_ record: String) -> RsyncVersion? {
        let chars = Array(record)
        if chars.count >= 12, chars[11] == " " { return .v342 }
        if chars.count >= 13, chars[12] == " " { return .v341 }
        return nil
    }

    // MARK: - Parsing Methods

    private static func appendAttr(_ attrs: inout [RsyncAttribute],
                                   name: String,
                                   code: Character,
                                   expected: Character) {
        if code == expected || code == "+" {
            attrs.append(RsyncAttribute(name: name, code: code))
        }
    }

    /// Parse rsync 3.4.2 format: 11-char prefix + space + path (e.g., ".f..t...... file.txt")
    /// Layout: Y X c s t p o g u a x
    private static func parseV342(_ record: String) -> RsyncOutputRecord? {
        let chars = Array(record)
        guard chars.count >= 12, chars[11] == " " else { return nil }

        let updateType = chars[0]
        let fileType = chars[1]

        var attrs: [RsyncAttribute] = []
        appendAttr(&attrs, name: "checksum",    code: chars[2],  expected: "c")
        appendAttr(&attrs, name: "size",        code: chars[3],  expected: "s")
        // time can be 't', 'T', or '+'
        if chars[4] == "t" || chars[4] == "T" || chars[4] == "+" {
            attrs.append(RsyncAttribute(name: "time", code: chars[4]))
        }
        appendAttr(&attrs, name: "permissions", code: chars[5],  expected: "p")
        appendAttr(&attrs, name: "owner",       code: chars[6],  expected: "o")
        appendAttr(&attrs, name: "group",       code: chars[7],  expected: "g")
        appendAttr(&attrs, name: "reserved",    code: chars[8],  expected: "u")
        appendAttr(&attrs, name: "acl",         code: chars[9],  expected: "a")
        appendAttr(&attrs, name: "xattr",       code: chars[10], expected: "x")

        let path = String(chars.dropFirst(12)).trimmingCharacters(in: .whitespaces)

        return RsyncOutputRecord(
            path: path,
            updateType: updateType,
            fileType: fileType,
            attributes: attrs,
            version: .v342
        )
    }

    /// Parse rsync 3.4.1 format: 12-char prefix + space + path (e.g., ".f..t....... file.txt")
    /// Layout: Y X c s t p o g n u a x  (extra namespace 'n' at position 8)
    private static func parseV341(_ record: String) -> RsyncOutputRecord? {
        let chars = Array(record)
        guard chars.count >= 13, chars[12] == " " else { return nil }

        let updateType = chars[0]
        let fileType = chars[1]

        var attrs: [RsyncAttribute] = []
        appendAttr(&attrs, name: "checksum",    code: chars[2],  expected: "c")
        appendAttr(&attrs, name: "size",        code: chars[3],  expected: "s")
        if chars[4] == "t" || chars[4] == "T" || chars[4] == "+" {
            attrs.append(RsyncAttribute(name: "time", code: chars[4]))
        }
        appendAttr(&attrs, name: "permissions", code: chars[5],  expected: "p")
        appendAttr(&attrs, name: "owner",       code: chars[6],  expected: "o")
        appendAttr(&attrs, name: "group",       code: chars[7],  expected: "g")
        appendAttr(&attrs, name: "namespace",   code: chars[8],  expected: "n")
        appendAttr(&attrs, name: "reserved",    code: chars[9],  expected: "u")
        appendAttr(&attrs, name: "acl",         code: chars[10], expected: "a")
        appendAttr(&attrs, name: "xattr",       code: chars[11], expected: "x")

        let path = String(chars.dropFirst(13)).trimmingCharacters(in: .whitespaces)

        return RsyncOutputRecord(
            path: path,
            updateType: updateType,
            fileType: fileType,
            attributes: attrs,
            version: .v341
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
