//
//  Rsyncver342OutputRecordTests.swift
//  RsyncAnalyse
//
//  Created by Thomas Evensen on 29/04/2026.
//

// MARK: - Basic Format Tests

import Foundation
@testable import RsyncAnalyse
import Testing

@Suite("Rsync 3.4.2 Output Record Parser Tests")
struct Rsyncver342OutputRecordTests {
    @Suite("Basic Format Tests")
    struct BasicFormatTests {
        @Test("Parse new file with all attributes new")
        func parseNewFile() {
            // Format: >f+++++++++ (11 chars: > f and 9 plusses)
            let record = ">f+++++++++ documents/report.pdf"
            let parsed = Rsyncver342OutputRecord(from: record)

            #expect(parsed != nil, "Should parse new file record")
            #expect(parsed?.updateType == ">")
            #expect(parsed?.fileType == "f")
            #expect(parsed?.path == "documents/report.pdf")
            #expect(parsed?.attributes.count == 9)
            #expect(parsed?.isNewItem == true)
            #expect(parsed?.fileTypeLabel == "file")
        }

        @Test("Parse file with size and time change")
        func parseFileWithSizeAndTimeChange() {
            // Format: >f.st...... (11 chars: >f + . + s + t + 6 dots)
            //         0123456789A
            //         >f.st......
            let record = ">f.st...... images/photo.jpg"

            let chars = Array(record)
            let formatString = String(chars.prefix(11))
            #expect(formatString.count == 11, "Format should be 11 chars, got \(formatString.count): '\(formatString)'")
            #expect(chars.count > 11 && chars[11] == " ", "Position 11 should be space")

            let parsed = Rsyncver342OutputRecord(from: record)

            #expect(parsed != nil, "Should parse size+time change record")
            #expect(parsed?.updateType == ">")
            #expect(parsed?.fileType == "f")
            #expect(parsed?.path == "images/photo.jpg")
            #expect(parsed?.attributes.count == 2, "Should have 2 attributes (size and time)")

            let attrNames = parsed?.attributes.map { $0.name }.sorted()
            #expect(attrNames == ["size", "time"])
        }

        @Test("Parse directory with timestamp change")
        func parseDirectoryTimestampChange() {
            // Format: .d..t...... (11 chars: . + d + 2 dots + t + 6 dots)
            let record = ".d..t...... src/components/"

            let parsed = Rsyncver342OutputRecord(from: record)

            #expect(parsed != nil, "Should parse directory timestamp record")
            #expect(parsed?.updateType == ".")
            #expect(parsed?.fileType == "d")
            #expect(parsed?.path == "src/components/")
            #expect(parsed?.attributes.count == 1)
            #expect(parsed?.attributes.first?.name == "time")
            #expect(parsed?.fileTypeLabel == "directory")
        }

        @Test("Parse permission change only")
        func parsePermissionChange() {
            // Format: .f...p..... (11 chars: . + f + 3 dots + p + 5 dots)
            let record = ".f...p..... scripts/deploy.sh"

            let parsed = Rsyncver342OutputRecord(from: record)

            #expect(parsed != nil, "Should parse permission change record")
            #expect(parsed?.updateType == ".")
            #expect(parsed?.fileType == "f")
            #expect(parsed?.path == "scripts/deploy.sh")
            #expect(parsed?.attributes.count == 1)
            #expect(parsed?.attributes.first?.name == "permissions")
        }

        @Test("Verify format string lengths")
        func verifyFormatLengths() {
            let testCases: [(format: String, description: String)] = [
                (">f+++++++++", "New file"),
                (">f.st......", "Size and time"),
                (".d..t......", "Dir time change"),
                (".f....p....", "Permission change"),
                (".f.stpog...", "Multiple attributes"),
                ("cd+++++++++", "New directory"),
                ("<f.st......", "Sent file"),
                ("hf.........", "Hard link"),
                (".f.........", "No changes")
            ]

            for (format, description) in testCases {
                #expect(format.count == 11,
                        "\(description) format '\(format)' should be 11 chars, got \(format.count)")
            }
        }

        @Test("Parse with visual format guide")
        func parseWithVisualGuide() {
            // Visual guide for the 11-character format:
            // Position:  0 1 2 3 4 5 6 7 8 9 10
            // Format:   Y X c s t p o g u a x
            // Example:  > f .  s t . . . . . .

            let testCases: [(record: String, expectedAttrs: [String])] = [
                (">f.st...... file1.txt", ["size", "time"]),
                (".f..t...... file2.txt", ["time"]),
                (".f...p..... file3.txt", ["permissions"]),
                (".f....o.... file4.txt", ["owner"]),
                (".f.....g... file5.txt", ["group"]),
                (".f........x file6.txt", ["xattr"]),
                (".f.......a. file7.txt", ["acl"]),
                (".fc........ file8.txt", ["checksum"])
            ]

            for (record, expectedAttrs) in testCases {
                let parsed = Rsyncver342OutputRecord(from: record)
                #expect(parsed != nil, "Should parse:  '\(record)'")

                let actualAttrs = parsed?.attributes.map { $0.name }.sorted() ?? []
                #expect(actualAttrs == expectedAttrs.sorted(),
                        "Record '\(record)' - Expected \(expectedAttrs), got \(actualAttrs)")
            }
        }
    }

    // MARK: - File Type Tests

    @Suite("File Type Parsing")
    struct FileTypeTests {
        @Test("Parse directory")
        func parseDirectory() {
            let record = "cd+++++++++ backup/2024/"
            let parsed = Rsyncver342OutputRecord(from: record)

            #expect(parsed != nil)
            #expect(parsed?.updateType == "c")
            #expect(parsed?.fileType == "d")
            #expect(parsed?.path == "backup/2024/")
            #expect(parsed?.fileTypeLabel == "directory")
        }

        @Test("Parse symlink")
        func parseSymlink() {
            let record = "cL+++++++++ config/current -> v2.0"
            let parsed = Rsyncver342OutputRecord(from: record)

            #expect(parsed != nil)
            #expect(parsed?.updateType == "c")
            #expect(parsed?.fileType == "L")
            #expect(parsed?.path == "config/current -> v2.0")
            #expect(parsed?.fileTypeLabel == "symlink")
        }

        @Test("Parse device file")
        func parseDevice() {
            let record = ">D+++++++++ dev/sda1"
            let parsed = Rsyncver342OutputRecord(from: record)

            #expect(parsed != nil)
            #expect(parsed?.fileType == "D")
            #expect(parsed?.fileTypeLabel == "device")
        }

        @Test("Parse special file")
        func parseSpecialFile() {
            let record = ">S+++++++++ var/run/socket"
            let parsed = Rsyncver342OutputRecord(from: record)

            #expect(parsed != nil)
            #expect(parsed?.fileType == "S")
            #expect(parsed?.fileTypeLabel == "special")
        }
    }

    // MARK: - Update Type Tests

    @Suite("Update Type Parsing")
    struct UpdateTypeTests {
        @Test("Parse sent file")
        func parseSentFile() {
            let record = "<f.st...... data/export.csv"
            let parsed = Rsyncver342OutputRecord(from: record)

            #expect(parsed != nil)
            #expect(parsed?.updateType == "<")
            #expect(parsed?.updateTypeLabel.text == "SENT")
        }

        @Test("Parse received file")
        func parseReceivedFile() {
            let record = ">f.st...... data/import.csv"
            let parsed = Rsyncver342OutputRecord(from: record)

            #expect(parsed != nil)
            #expect(parsed?.updateType == ">")
            #expect(parsed?.updateTypeLabel.text == "RECEIVED")
        }

        @Test("Parse local change")
        func parseLocalChange() {
            let record = "cd+++++++++ new_directory/"
            let parsed = Rsyncver342OutputRecord(from: record)

            #expect(parsed != nil)
            #expect(parsed?.updateType == "c")
            #expect(parsed?.updateTypeLabel.text == "LOCAL_CHANGE")
        }

        @Test("Parse hard link")
        func parseHardLink() {
            let record = "hf......... docs/readme.txt"
            let parsed = Rsyncver342OutputRecord(from: record)

            #expect(parsed != nil)
            #expect(parsed?.updateType == "h")
            #expect(parsed?.updateTypeLabel.text == "HARDLINK")
        }

        @Test("Parse no update")
        func parseNoUpdate() {
            let record = ".f......... unchanged.txt"
            let parsed = Rsyncver342OutputRecord(from: record)

            #expect(parsed != nil)
            #expect(parsed?.updateType == ".")
            #expect(parsed?.updateTypeLabel.text == "NO_UPDATE")
        }
    }

    // MARK: - Deletion Tests

    @Suite("Deletion Message Parsing")
    struct DeletionTests {
        @Test("Parse standard deletion message")
        func parseDeletion() {
            let record = "*deleting old/obsolete.txt"
            let parsed = Rsyncver342OutputRecord(from: record)

            #expect(parsed != nil)
            #expect(parsed?.updateType == "*")
            #expect(parsed?.path == "old/obsolete.txt")
            #expect(parsed?.isDeletion == true)
            #expect(parsed?.updateTypeLabel.text == "deleting")
        }

        @Test("Parse deletion with path containing spaces")
        func parseDeletionWithMultipleSpaces() {
            let record = "*deleting path/with spaces/file.txt"
            let parsed = Rsyncver342OutputRecord(from: record)

            #expect(parsed != nil)
            #expect(parsed?.path == "path/with spaces/file.txt")
        }
    }

    // MARK: - Attribute Combination Tests

    @Suite("Attribute Combinations")
    struct AttributeCombinationTests {
        @Test("Parse multiple attribute changes")
        func parseMultipleAttributeChanges() {
            let record = ">f.stpog... /var/www/index.html"
            let parsed = Rsyncver342OutputRecord(from: record)

            #expect(parsed != nil)
            #expect(parsed?.attributes.count == 5)

            let attrNames = Set(parsed?.attributes.map { $0.name } ?? [])
            #expect(attrNames.contains("size"))
            #expect(attrNames.contains("time"))
            #expect(attrNames.contains("permissions"))
            #expect(attrNames.contains("owner"))
            #expect(attrNames.contains("group"))
        }

        @Test("Parse checksum change")
        func parseChecksumChange() {
            let record = ".fc........ config.json"
            let parsed = Rsyncver342OutputRecord(from: record)

            #expect(parsed != nil)
            #expect(parsed?.attributes.count == 1)
            #expect(parsed?.attributes.first?.name == "checksum")
            #expect(parsed?.attributes.first?.code == "c")
        }

        @Test("Parse owner and group change")
        func parseOwnerAndGroupChange() {
            let record = ".f....og... file.txt"
            let parsed = Rsyncver342OutputRecord(from: record)

            #expect(parsed != nil)
            #expect(parsed?.attributes.count == 2)

            let attrNames = parsed?.attributes.map { $0.name }.sorted()
            #expect(attrNames == ["group", "owner"])
        }
    }

    // MARK: - Time Variant Tests

    @Suite("Time Change Variants")
    struct TimeVariantTests {
        @Test("Parse lowercase time change")
        func parseLowercaseTimeChange() {
            let record = ".f..t...... file1.txt"
            let parsed = Rsyncver342OutputRecord(from: record)

            #expect(parsed != nil)
            #expect(parsed?.attributes.count == 1)
            #expect(parsed?.attributes.first?.name == "time")
            #expect(parsed?.attributes.first?.code == "t")
        }

        @Test("Parse uppercase time change")
        func parseUppercaseTimeChange() {
            let record = ".f..T...... file2.txt"
            let parsed = Rsyncver342OutputRecord(from: record)

            #expect(parsed != nil)
            #expect(parsed?.attributes.count == 1)
            #expect(parsed?.attributes.first?.name == "time")
            #expect(parsed?.attributes.first?.code == "T")
        }
    }

    // MARK: - Extended Attribute Tests

    @Suite("Extended Attributes (ACL and xattr)")
    struct ExtendedAttributeTests {
        @Test("Parse ACL change")
        func parseACLChange() {
            let record = ".f.......a. file_with_acl.txt"
            let parsed = Rsyncver342OutputRecord(from: record)

            #expect(parsed != nil)
            #expect(parsed?.attributes.count == 1)
            #expect(parsed?.attributes.first?.name == "acl")
            #expect(parsed?.attributes.first?.code == "a")
        }

        @Test("Parse xattr change")
        func parseXattrChange() {
            let record = ".f........x file_with_xattr.txt"
            let parsed = Rsyncver342OutputRecord(from: record)

            #expect(parsed != nil)
            #expect(parsed?.attributes.count == 1)
            #expect(parsed?.attributes.first?.name == "xattr")
            #expect(parsed?.attributes.first?.code == "x")
        }

        @Test("Parse ACL and xattr change together")
        func parseACLAndXattrChange() {
            let record = ".f.......ax file_with_both.txt"
            let parsed = Rsyncver342OutputRecord(from: record)

            #expect(parsed != nil)
            #expect(parsed?.attributes.count == 2)

            let attrNames = parsed?.attributes.map { $0.name }.sorted()
            #expect(attrNames == ["acl", "xattr"])
        }
    }

    // MARK: - Path Tests

    @Suite("Path Handling")
    struct PathTests {
        @Test("Parse path with spaces")
        func parsePathWithSpaces() {
            let record = ">f+++++++++ my documents/important file.txt"
            let parsed = Rsyncver342OutputRecord(from: record)

            #expect(parsed != nil)
            #expect(parsed?.path == "my documents/important file.txt")
        }

        @Test("Parse absolute path")
        func parseAbsolutePath() {
            let record = ">f+++++++++ /var/log/system.log"
            let parsed = Rsyncver342OutputRecord(from: record)

            #expect(parsed != nil)
            #expect(parsed?.path == "/var/log/system.log")
        }

        @Test("Parse path with Unicode characters")
        func parsePathWithUnicode() {
            let record = ">f+++++++++ files/文档.txt"
            let parsed = Rsyncver342OutputRecord(from: record)

            #expect(parsed != nil)
            #expect(parsed?.path == "files/文档.txt")
        }
    }

    // MARK: - Edge Cases

    @Suite("Edge Cases and Error Handling")
    struct EdgeCaseTests {
        @Test("Parse too short record")
        func parseTooShort() {
            let record = ">f+++"
            let parsed = Rsyncver342OutputRecord(from: record)

            #expect(parsed == nil)
        }

        @Test("Parse 10-char prefix is rejected")
        func parseTenCharRejected() {
            // 10 chars + space — too short for 3.4.2 format
            let record = ">f.st..... file.txt"
            let parsed = Rsyncver342OutputRecord(from: record)

            #expect(parsed == nil, "10-char prefix must not parse as 3.4.2 format")
        }

        @Test("Parse old 12-char prefix is rejected")
        func parseTwelveCharRejected() {
            // 12 chars + space — pre-3.4.2 format. Must NOT parse here so callers
            // can dispatch based on a nil return.
            let record = ">f.st....... file.txt"
            let parsed = Rsyncver342OutputRecord(from: record)

            #expect(parsed == nil, "Old 12-char prefix must not parse as 3.4.2 format")
        }

        @Test("Parse missing space at position 11")
        func parseMissingSpace() {
            // 11 chars but no space at index 11 (path runs in immediately)
            let record = ">f.st......file.txt"
            let parsed = Rsyncver342OutputRecord(from: record)

            #expect(parsed == nil)
        }

        @Test("Parse invalid format")
        func parseInvalidFormat() {
            let record = "invalid format without proper structure"
            let parsed = Rsyncver342OutputRecord(from: record)

            #expect(parsed == nil)
        }

        @Test("Parse empty string")
        func parseEmptyString() {
            let record = ""
            let parsed = Rsyncver342OutputRecord(from: record)

            #expect(parsed == nil)
        }
    }

    // MARK: - Real World Examples

    @Suite("Real World Examples")
    struct RealWorldExamples {
        @Test("rsync 3.4.2 sample output")
        func rsync342SampleOutput() {
            // Verbatim from the rsync 3.4.2 release sample
            let records = [
                ".d..t...... RawCull/RawCull/.claude/",
                "<f.st...... RawCull/RawCull/.claude/settings.local.json",
                ".d..t...... RawCull/RawCull/.git/",
                "<f..t...... RawCull/RawCull/.git/FETCH_HEAD",
                "<f..t...... RawCull/RawCull/.git/HEAD",
                "<f..t...... RawCull/RawCull/.git/ORIG_HEAD",
                "<f..t...... RawCull/RawCull/.git/index",
                "<f.st...... RawCull/RawCull/.git/logs/HEAD",
                "<f.st...... RawCull/RawCull/.git/logs/refs/heads/main",
                "<f.st...... RawCull/RawCull/.git/logs/refs/heads/version-1.6.8",
                "<f.st...... RawCull/RawCull/.git/logs/refs/remotes/origin/main",
                "<f.st...... RawCull/RawCull/.git/logs/refs/remotes/origin/version-1.6.8",
                ".d..t...... RawCull/RawCull/.git/objects/",
                ".d..t...... RawCull/RawCull/.git/objects/0b/"
            ]

            for (index, record) in records.enumerated() {
                let chars = Array(record)
                #expect(chars.count >= 12,
                        "Record \(index) too short: \(chars.count) chars - '\(record)'")
                if chars.count >= 12 {
                    #expect(chars[11] == " ",
                            "Record \(index) missing space at position 11: '\(record)'")
                }
            }

            let parsed = records.compactMap { Rsyncver342OutputRecord(from: $0) }
            #expect(parsed.count == records.count,
                    "Expected \(records.count) parsed records, got \(parsed.count)")

            // Spot-check a directory-time entry
            #expect(parsed[0].fileType == "d")
            #expect(parsed[0].updateType == ".")
            #expect(parsed[0].path == "RawCull/RawCull/.claude/")
            #expect(parsed[0].attributes.map(\.name) == ["time"])

            // Spot-check a sent file with size+time
            #expect(parsed[1].fileType == "f")
            #expect(parsed[1].updateType == "<")
            #expect(parsed[1].path == "RawCull/RawCull/.claude/settings.local.json")
            #expect(parsed[1].attributes.map(\.name).sorted() == ["size", "time"])

            // Spot-check time-only on a sent file
            #expect(parsed[3].fileType == "f")
            #expect(parsed[3].updateType == "<")
            #expect(parsed[3].attributes.map(\.name) == ["time"])
        }

        @Test("Backup scenario with deletions")
        func backupScenarioWithDeletions() {
            let records = [
                ">f.st...... data/updated.csv",
                "cd+++++++++ logs/2024/",
                ">f+++++++++ logs/2024/app.log",
                "*deleting old/deprecated.txt",
                ".f....p.... scripts/backup.sh"
            ]

            let parsed = records.compactMap { Rsyncver342OutputRecord(from: $0) }

            #expect(parsed.count == 5, "Expected 5 parsed records, got \(parsed.count)")

            let deletionRecord = parsed.first { $0.isDeletion }
            #expect(deletionRecord != nil, "Should have one deletion record")
            #expect(deletionRecord?.path == "old/deprecated.txt")
        }
    }

    // MARK: - Helper Property Tests

    @Suite("Helper Properties")
    struct HelperPropertyTests {
        @Test("isNewItem returns true for new files")
        func isNewItemTrue() {
            let record = ">f+++++++++ new_file.txt"
            let parsed = Rsyncver342OutputRecord(from: record)

            #expect(parsed?.isNewItem == true)
        }

        @Test("isNewItem returns false for modified files")
        func isNewItemFalse() {
            let record = ">f.st...... modified_file.txt"
            let parsed = Rsyncver342OutputRecord(from: record)

            #expect(parsed?.isNewItem == false)
        }

        @Test("isDeletion returns true for deletion messages")
        func isDeletionTrue() {
            let record = "*deleting   removed.txt"
            let parsed = Rsyncver342OutputRecord(from: record)

            #expect(parsed?.isDeletion == true)
        }

        @Test("isDeletion returns false for regular files")
        func isDeletionFalse() {
            let record = ">f+++++++++ added.txt"
            let parsed = Rsyncver342OutputRecord(from: record)

            #expect(parsed?.isDeletion == false)
        }
    }

    // MARK: - Parameterized Tests

    @Suite("Parameterized Tests")
    struct ParameterizedTests {
        @Test("Parse various file types", arguments: [
            ("f", "file"),
            ("d", "directory"),
            ("L", "symlink"),
            ("D", "device"),
            ("S", "special")
        ])
        func parseFileTypes(typeChar: Character, expectedLabel: String) {
            let record = ">\(typeChar)+++++++++ test"
            let parsed = Rsyncver342OutputRecord(from: record)

            #expect(parsed?.fileType == typeChar)
            #expect(parsed?.fileTypeLabel == expectedLabel)
        }

        @Test("Parse various update types", arguments: [
            ("<", "SENT"),
            (">", "RECEIVED"),
            ("c", "LOCAL_CHANGE"),
            ("h", "HARDLINK"),
            (".", "NO_UPDATE")
        ])
        func parseUpdateTypes(typeChar: Character, expectedLabel: String) {
            let record = "\(typeChar)f......... test.txt"
            let parsed = Rsyncver342OutputRecord(from: record)

            #expect(parsed?.updateType == typeChar)
            #expect(parsed?.updateTypeLabel.text == expectedLabel)
        }

        @Test("Parse individual attributes", arguments: [
            (2, "c", "checksum"),
            (3, "s", "size"),
            (4, "t", "time"),
            (5, "p", "permissions"),
            (6, "o", "owner"),
            (7, "g", "group"),
            (8, "u", "reserved"),
            (9, "a", "acl"),
            (10, "x", "xattr")
        ])
        func parseIndividualAttributes(position: Int, code: Character, name: String) {
            var chars = Array(".f.........")
            chars[position] = code
            let record = String(chars) + " test.txt"
            let parsed = Rsyncver342OutputRecord(from: record)

            #expect(parsed != nil)
            #expect(parsed?.attributes.contains { $0.name == name && $0.code == code } == true)
        }
    }
}
