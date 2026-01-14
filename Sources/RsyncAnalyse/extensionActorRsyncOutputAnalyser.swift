//
//  extensionActorRsyncOutputAnalyser.swift
//  RsyncAnalyse
//
//  Created by Thomas Evensen on 11/01/2026.
//

import Foundation

public extension ActorRsyncOutputAnalyser {
    struct AnalysisResult: Sendable {
        public let itemizedChanges: [ItemizedChange]
        public let statistics: Statistics
        public let isDryRun: Bool
        public let errors: [String]
        public let warnings: [String]

        public init(itemizedChanges: [ItemizedChange],
                    statistics: Statistics,
                    isDryRun: Bool,
                    errors: [String] = [],
                    warnings: [String] = []) {
            self.itemizedChanges = itemizedChanges
            self.statistics = statistics
            self.isDryRun = isDryRun
            self.errors = errors
            self.warnings = warnings
        }
    }

    struct ItemizedChange: Sendable {
        public let changeType: ChangeType
        public let path: String
        public let target: String? // For symlinks
        public let flags: ChangeFlags

        public init(changeType: ChangeType,
                    path: String,
                    target: String? = nil,
                    flags: ChangeFlags = .none) {
            self.changeType = changeType
            self.path = path
            self.target = target
            self.flags = flags
        }
    }

    enum ChangeType: String, CaseIterable, Sendable {
        case symlink = "L"
        case directory = "d"
        case file = "f"
        case device = "D"
        case special = "S"
        case deletion = "*deleting"
        case unknown = "?"

        public var description: String {
            switch self {
            case .symlink: "Symlink"
            case .directory: "Directory"
            case .file: "File"
            case .device: "Device"
            case .special: "Special"
            case .deletion: "Deletion"
            case .unknown: "Unknown"
            }
        }

        public static func fromFlag(_ flag: String) -> ChangeType {
            if flag.contains("L") { return .symlink }
            if flag.contains("d") { return .directory }
            if flag.contains("f") { return .file }
            if flag.contains("D") { return .device }
            if flag.contains("S") { return .special }
            if flag == "*deleting" { return .deletion }
            return .unknown
        }
    }

    struct ChangeFlags: Sendable {
        public let fileType: String
        public let checksum: Bool // c
        public let size: Bool // s
        public let timestamp: Bool // t
        public let permissions: Bool // p
        public let owner: Bool // o
        public let group: Bool // g
        public let acl: Bool // a
        public let xattr: Bool // x
        public let isDeletion: Bool

        public init(from flagString: String) {
            // Format: . L...p...... or *deleting
            if flagString.hasPrefix("*deleting") {
                fileType = ""
                checksum = false
                size = false
                timestamp = false
                permissions = false
                owner = false
                group = false
                acl = false
                xattr = false
                isDeletion = true
            } else {
                let cleanFlag = flagString.trimmingCharacters(in: .whitespaces)
                fileType = cleanFlag.count >= 2 ? String(cleanFlag.prefix(2)) : ""
                checksum = cleanFlag.contains("c")
                size = cleanFlag.contains("s")
                timestamp = cleanFlag.contains("t")
                permissions = cleanFlag.contains("p")
                owner = cleanFlag.contains("o")
                group = cleanFlag.contains("g")
                acl = cleanFlag.contains("a")
                xattr = cleanFlag.contains("x")
                isDeletion = false
            }
        }

        public init(isDeletion: Bool = false) {
            fileType = ""
            checksum = false
            size = false
            timestamp = false
            permissions = false
            owner = false
            group = false
            acl = false
            xattr = false
            self.isDeletion = isDeletion
        }

        public static let none = ChangeFlags(from: "")

        public var description: String {
            var flags: [String] = []
            if checksum { flags.append("checksum") }
            if size { flags.append("size") }
            if timestamp { flags.append("timestamp") }
            if permissions { flags.append("permissions") }
            if owner { flags.append("owner") }
            if group { flags.append("group") }
            if acl { flags.append("acl") }
            if xattr { flags.append("xattr") }
            if isDeletion { flags.append("deletion") }
            return flags.isEmpty ? "none" : flags.joined(separator: ", ")
        }
    }

    struct Statistics: Sendable {
        public let totalFiles: FileCount
        public let filesCreated: FileCount
        public let filesDeleted: Int
        public let regularFilesTransferred: Int
        public let totalFileSize: Int64
        public let totalTransferredSize: Int64
        public let literalData: Int64
        public let matchedData: Int64
        public let bytesSent: Int64
        public let bytesReceived: Int64
        public let speedup: Double
        public let errors: [String]
        public let warnings: [String]

        public init(totalFiles: FileCount,
                    filesCreated: FileCount,
                    filesDeleted: Int,
                    regularFilesTransferred: Int,
                    totalFileSize: Int64,
                    totalTransferredSize: Int64,
                    literalData: Int64,
                    matchedData: Int64,
                    bytesSent: Int64,
                    bytesReceived: Int64,
                    speedup: Double,
                    errors: [String] = [],
                    warnings: [String] = []) {
            self.totalFiles = totalFiles
            self.filesCreated = filesCreated
            self.filesDeleted = filesDeleted
            self.regularFilesTransferred = regularFilesTransferred
            self.totalFileSize = totalFileSize
            self.totalTransferredSize = totalTransferredSize
            self.literalData = literalData
            self.matchedData = matchedData
            self.bytesSent = bytesSent
            self.bytesReceived = bytesReceived
            self.speedup = speedup
            self.errors = errors
            self.warnings = warnings
        }

        public var totalFilesChanged: Int {
            filesCreated.total + filesDeleted
        }

        public var efficiencyPercentage: Double {
            guard totalFileSize > 0 else { return 0 }
            return (Double(totalTransferredSize) / Double(totalFileSize)) * 100.0
        }
    }

    struct FileCount: CustomStringConvertible, Sendable {
        public let total: Int
        public let regular: Int
        public let directories: Int
        public let links: Int

        public init(total: Int, regular: Int, directories: Int, links: Int) {
            self.total = total
            self.regular = regular
            self.directories = directories
            self.links = links
        }

        public var description: String {
            "\(total) total (reg: \(regular), dir: \(directories), link: \(links))"
        }

        public static var zero: FileCount {
            FileCount(total: 0, regular: 0, directories: 0, links: 0)
        }
    }
}

// MARK: - Additional Convenience Extensions

extension ActorRsyncOutputAnalyser.ItemizedChange: CustomStringConvertible {
    public var description: String {
        var result = "\(changeType.description): \(path)"
        if let target {
            result += " -> \(target)"
        }
        if !flags.description.isEmpty, flags.description != "none" {
            result += " [\(flags.description)]"
        }
        return result
    }
}

extension ActorRsyncOutputAnalyser.Statistics: CustomStringConvertible {
    public var description: String {
        var result = """
        📊 Statistics:
          Total files: \(totalFiles)
          Created: \(filesCreated)
          Deleted: \(filesDeleted)
          Transferred: \(regularFilesTransferred)

        💾 Data Transfer:
          Total size: \(ActorRsyncOutputAnalyser.formatBytes(totalFileSize))
          Transferred: \(ActorRsyncOutputAnalyser.formatBytes(totalTransferredSize))
          Efficiency: \(String(format: "%.2f", efficiencyPercentage))%
          Speedup: \(String(format: "%.2f", speedup))x

        📊 Transfer Details:
          Literal data: \(ActorRsyncOutputAnalyser.formatBytes(literalData))
          Matched data: \(ActorRsyncOutputAnalyser.formatBytes(matchedData))
          Sent: \(ActorRsyncOutputAnalyser.formatBytes(bytesSent))
          Received: \(ActorRsyncOutputAnalyser.formatBytes(bytesReceived))
        """

        if !errors.isEmpty {
            result += "\n❌ Errors: \(errors.count)"
        }
        if !warnings.isEmpty {
            result += "\n⚠️ Warnings: \(warnings.count)"
        }

        return result
    }
}

public extension ActorRsyncOutputAnalyser.ChangeFlags {
    var flagString: String {
        var flags = fileType
        if checksum { flags += "c" }
        if size { flags += "s" }
        if timestamp { flags += "t" }
        if permissions { flags += "p" }
        if owner { flags += "o" }
        if group { flags += "g" }
        if acl { flags += "a" }
        if xattr { flags += "x" }
        return flags
    }
}

// MARK: - Helper Methods

public extension ActorRsyncOutputAnalyser {
    func summary(for result: AnalysisResult) -> String {
        var summary = """
        ════════════════════════════
        RSYNC ANALYSIS SUMMARY
        ════════════════════════════

        Run Type: \(result.isDryRun ? "DRY RUN (simulation)" : "LIVE RUN")
        """

        if result.isDryRun {
            summary += "\n⚠️  No actual changes were made\n"
        }

        summary += """

        📈 Summary:
          • Total items: \(result.itemizedChanges.count)
          • Files created: \(result.statistics.filesCreated.total)
          • Files deleted: \(result.statistics.filesDeleted)
          • Data efficiency: \(String(format: "%.1f", result.statistics.efficiencyPercentage))%
          • Transfer speedup: \(String(format: "%.1f", result.statistics.speedup))x
        """

        if !result.errors.isEmpty {
            summary += "\n\n❌ Found \(result.errors.count) error(s)"
        }

        if !result.warnings.isEmpty {
            summary += "\n⚠️  Found \(result.warnings.count) warning(s)"
        }

        return summary
    }

    func changesByType(for result: AnalysisResult) -> [ChangeType: Int] {
        var counts: [ChangeType: Int] = [:]
        for change in result.itemizedChanges {
            counts[change.changeType, default: 0] += 1
        }
        return counts
    }
}
