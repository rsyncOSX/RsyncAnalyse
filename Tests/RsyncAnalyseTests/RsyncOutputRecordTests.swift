//
//  RsyncOutputRecordTests.swift
//  RsyncAnalyse
//
//  Created by Thomas Evensen on 15/01/2026.
//

// MARK: - Basic Format Tests

import Foundation
@testable import RsyncAnalyse
import Testing

@Suite("Rsync Output Record Parser Tests")
struct RsyncOutputRecordTests {
    @Suite("Basic Format Tests - All Fixed")
    struct BasicFormatTestsFixed {
        @Test("Parse new file with all attributes new")
        func parseNewFile() {
            // Format: >f+++++++++ (11 chars:  > f and 9 plusses)
            let record = ">f+++++++++ documents/report.pdf"
            let parsed = RsyncOutputRecord(from: record)

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
            // Format: >f.st...... (11 chars: >f + .  + s + t + 6 dots)
            //         012345678901
            //         >f.st......
            let record = ">f.st...... images/photo.jpg"

            // Validate format
            let chars = Array(record)
            let formatString = String(chars.prefix(11))
            #expect(formatString.count == 11, "Format should be 11 chars, got \(formatString.count): '\(formatString)'")
            #expect(chars.count > 11 && chars[11] == " ", "Position 11 should be space")

            let parsed = RsyncOutputRecord(from: record)

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
            // Format:  .d..t...... (11 chars:  .  + d + 2 dots + t + 6 dots)
            //         012345678901
            //         .d..t......
            let record = ".d..t...... src/components/"

            let parsed = RsyncOutputRecord(from: record)

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
            // Format: .f....p.... (11 chars: . + f + 4 dots + p + 4 dots)
            //         012345678901
            //         .f....p....
            let record = ".f...p..... scripts/deploy.sh"

            let parsed = RsyncOutputRecord(from: record)

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
            // Format:   Y X c s t p o g u a  x
            // Example:  > f .  s t . . . . .   .

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
                let parsed = RsyncOutputRecord(from: record)
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
            let parsed = RsyncOutputRecord(from: record)

            #expect(parsed != nil)
            #expect(parsed?.updateType == "c")
            #expect(parsed?.fileType == "d")
            #expect(parsed?.path == "backup/2024/")
            #expect(parsed?.fileTypeLabel == "directory")
        }

        @Test("Parse symlink")
        func parseSymlink() {
            let record = "cL+++++++++ config/current -> v2.0"
            let parsed = RsyncOutputRecord(from: record)

            #expect(parsed != nil)
            #expect(parsed?.updateType == "c")
            #expect(parsed?.fileType == "L")
            #expect(parsed?.path == "config/current -> v2.0")
            #expect(parsed?.fileTypeLabel == "symlink")
        }

        @Test("Parse symlink with attribute changes")
        func parseSymlinkWithChanges() {
            let record = "cLc.t...... links/data -> /mnt/storage"
            let parsed = RsyncOutputRecord(from: record)

            #expect(parsed != nil)
            #expect(parsed?.updateType == "c")
            #expect(parsed?.fileType == "L")
            #expect(parsed?.attributes.count == 2)

            let attrNames = parsed?.attributes.map { $0.name }.sorted()
            #expect(attrNames == ["checksum", "time"])
        }

        @Test("Parse device file")
        func parseDevice() {
            let record = ">D+++++++++ dev/sda1"
            let parsed = RsyncOutputRecord(from: record)

            #expect(parsed != nil)
            #expect(parsed?.fileType == "D")
            #expect(parsed?.fileTypeLabel == "device")
        }

        @Test("Parse special file")
        func parseSpecialFile() {
            let record = ">S+++++++++ var/run/socket"
            let parsed = RsyncOutputRecord(from: record)

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
            let parsed = RsyncOutputRecord(from: record)

            #expect(parsed != nil)
            #expect(parsed?.updateType == "<")
            #expect(parsed?.updateTypeLabel.text == "SENT")
        }

        @Test("Parse received file")
        func parseReceivedFile() {
            let record = ">f.st...... data/import.csv"
            let parsed = RsyncOutputRecord(from: record)

            #expect(parsed != nil)
            #expect(parsed?.updateType == ">")
            #expect(parsed?.updateTypeLabel.text == "RECEIVED")
        }

        @Test("Parse local change")
        func parseLocalChange() {
            let record = "cd+++++++++ new_directory/"
            let parsed = RsyncOutputRecord(from: record)

            #expect(parsed != nil)
            #expect(parsed?.updateType == "c")
            #expect(parsed?.updateTypeLabel.text == "LOCAL_CHANGE")
        }

        @Test("Parse hard link")
        func parseHardLink() {
            let record = "hf......... docs/readme.txt"
            let parsed = RsyncOutputRecord(from: record)

            #expect(parsed != nil)
            #expect(parsed?.updateType == "h")
            #expect(parsed?.updateTypeLabel.text == "HARDLINK")
        }

        @Test("Parse no update")
        func parseNoUpdate() {
            let record = ".f......... unchanged.txt"
            let parsed = RsyncOutputRecord(from: record)

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
            let parsed = RsyncOutputRecord(from: record)

            #expect(parsed != nil)
            #expect(parsed?.updateType == "*")
            #expect(parsed?.path == "old/obsolete.txt")
            #expect(parsed?.isDeletion == true)
            #expect(parsed?.updateTypeLabel.text == "MESSAGE")
        }

        @Test("Parse deletion with path containing spaces")
        func parseDeletionWithMultipleSpaces() {
            let record = "*deleting path/with spaces/file.txt"
            let parsed = RsyncOutputRecord(from: record)

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
            let parsed = RsyncOutputRecord(from: record)

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
            let parsed = RsyncOutputRecord(from: record)

            #expect(parsed != nil)
            #expect(parsed?.attributes.count == 1)
            #expect(parsed?.attributes.first?.name == "checksum")
            #expect(parsed?.attributes.first?.code == "c")
        }

        @Test("Parse owner and group change")
        func parseOwnerAndGroupChange() {
            let record = ".f....og... file.txt"
            let parsed = RsyncOutputRecord(from: record)

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
            let parsed = RsyncOutputRecord(from: record)

            #expect(parsed != nil)
            #expect(parsed?.attributes.count == 1)
            #expect(parsed?.attributes.first?.name == "time")
            #expect(parsed?.attributes.first?.code == "t")
        }

        @Test("Parse uppercase time change")
        func parseUppercaseTimeChange() {
            let record = ".f..T...... file2.txt"
            let parsed = RsyncOutputRecord(from: record)

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
            let parsed = RsyncOutputRecord(from: record)

            #expect(parsed != nil)
            #expect(parsed?.attributes.count == 1)
            #expect(parsed?.attributes.first?.name == "acl")
            #expect(parsed?.attributes.first?.code == "a")
        }

        @Test("Parse xattr change")
        func parseXattrChange() {
            let record = ".f........x file_with_xattr.txt"
            let parsed = RsyncOutputRecord(from: record)

            #expect(parsed != nil)
            #expect(parsed?.attributes.count == 1)
            #expect(parsed?.attributes.first?.name == "xattr")
            #expect(parsed?.attributes.first?.code == "x")
        }

        @Test("Parse ACL and xattr change together")
        func parseACLAndXattrChange() {
            let record = ".f.......ax file_with_both.txt"
            let parsed = RsyncOutputRecord(from: record)

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
            let parsed = RsyncOutputRecord(from: record)

            #expect(parsed != nil)
            #expect(parsed?.path == "my documents/important file.txt")
        }

        @Test("Parse path with special characters")
        func parsePathWithSpecialCharacters() {
            let record = ">f+++++++++ files/test@#$%.txt"
            let parsed = RsyncOutputRecord(from: record)

            #expect(parsed != nil)
            #expect(parsed?.path == "files/test@#$%.txt")
        }

        @Test("Parse absolute path")
        func parseAbsolutePath() {
            let record = ">f+++++++++ /var/log/system.log"
            let parsed = RsyncOutputRecord(from: record)

            #expect(parsed != nil)
            #expect(parsed?.path == "/var/log/system.log")
        }

        @Test("Parse path with Unicode characters")
        func parsePathWithUnicode() {
            let record = ">f+++++++++ files/文档.txt"
            let parsed = RsyncOutputRecord(from: record)

            #expect(parsed != nil)
            #expect(parsed?.path == "files/文档.txt")
        }
    }

    // MARK: - Edge Cases

    @Suite("Edge Cases and Error Handling")
    struct EdgeCaseTests {
        @Test("Parse record with empty path")
        func parseEmptyPath() {
            let record = ">f+++++++++"
            let parsed = RsyncOutputRecord(from: record)

            // Should either be nil or have empty path
            if let parsed = parsed {
                #expect(parsed.path == "")
            }
        }

        @Test("Parse too short record")
        func parseTooShort() {
            let record = ">f+++"
            let parsed = RsyncOutputRecord(from: record)

            #expect(parsed == nil)
        }

        @Test("Parse invalid format")
        func parseInvalidFormat() {
            let record = "invalid format without proper structure"
            let parsed = RsyncOutputRecord(from: record)

            #expect(parsed == nil)
        }

        @Test("Parse empty string")
        func parseEmptyString() {
            let record = ""
            let parsed = RsyncOutputRecord(from: record)

            #expect(parsed == nil)
        }
    }

    // MARK: - Real World Examples

    @Suite("Real World Examples")
    struct RealWorldExamples {
        @Test("Typical file sync scenario - corrected format")
        func realWorldExample1Corrected() {
            // Each record must be exactly 11 chars + space + path
            // Format: YXcstpoguax path
            //         012345678901 12...
            let records = [
                ".d..t...... ./", // 11 chars: .d..t......
                ".f...p..... Something.pdf", // 11 chars: .f...p.....
                ".f......... md5sum-2010-02-21.txt", // 11 chars: .f.........
                ".f...p..... prova.rb", // 11 chars: .f...p.....
                ".d......... .metadata/", // 11 chars: .d.........
                ".f...p..... .metadata/.lock", // 11 chars: .f...p.....
                ".f...p..... .metadata/version.ini", // 11 chars: .f...p.....
                ">f+++++++++ Parameter_Usage.txt" // 11 chars: >f+++++++++
            ]

            // Verify each record format
            for (index, record) in records.enumerated() {
                let chars = Array(record)
                #expect(chars.count >= 12,
                        "Record \(index) too short: \(chars.count) chars - '\(record)'")
                if chars.count >= 12 {
                    let formatPart = String(chars[0 ... 10])
                    #expect(chars[11] == " ",
                            "Record \(index) missing space at position 11: '\(record)' - got '\(chars[11])' - format: '\(formatPart)'")
                }
            }

            let parsed = records.compactMap { RsyncOutputRecord(from: $0) }
            #expect(parsed.count == 8, "Expected 8 parsed records, got \(parsed.count)")

            guard parsed.count >= 8 else {
                Issue.record("Only parsed \(parsed.count) records")
                return
            }

            // Check root directory (index 0)
            #expect(parsed[0].fileType == "d", "First record should be directory")
            #expect(parsed[0].path == "./", "First record should be root path")
            #expect(parsed[0].attributes.contains { $0.name == "time" }, "Directory should have time change")

            // Check files with permission changes (indices 1, 3, 5, 6)
            #expect(parsed[1].attributes.contains { $0.name == "permissions" }, "Something.pdf should have permission change")
            #expect(parsed[3].attributes.contains { $0.name == "permissions" }, "prova.rb should have permission change")

            // Check file with no changes (index 2)
            #expect(parsed[2].attributes.isEmpty, "md5sum file should have no attribute changes")
            #expect(parsed[2].updateType == ".", "md5sum file should not be updated")

            // Check . metadata directory (index 4)
            #expect(parsed[4].fileType == "d", "metadata should be directory")
            #expect(parsed[4].path == ".metadata/", "Should have correct metadata path")

            // Check new file (index 7)
            #expect(parsed[7].updateType == ">", "Last file should be received")
            #expect(parsed[7].isNewItem == true, "Last file should be new")
            #expect(parsed[7].path == "Parameter_Usage.txt", "Should have correct filename")
            #expect(parsed[7].attributes.count == 9, "New file should have all 9 attributes marked as new")
        }

        @Test("Backup scenario with deletions - corrected format")
        func realWorldExample2Corrected() {
            // Each record must be exactly 11 chars + space + path
            // Format: YXcstpoguax path
            //         012345678901 12...
            let records = [
                ">f.st...... data/updated.csv", // 11 chars: >f.st......
                "cd+++++++++ logs/2024/", // 11 chars: cd+++++++++
                ">f+++++++++ logs/2024/app.log", // 11 chars: >f+++++++++
                "*deleting old/deprecated.txt", // Special deletion format
                ".f....p.... scripts/backup.sh" // 11 chars: .f....p....
            ]

            // Verify each record format
            for (index, record) in records.enumerated() {
                if !record.hasPrefix("*") {
                    let chars = Array(record)
                    #expect(chars.count >= 12,
                            "Record \(index) too short: \(chars.count) chars - '\(record)'")
                    if chars.count >= 12 {
                        #expect(chars[11] == " ",
                                "Record \(index) missing space at position 11: '\(record)' - got '\(chars[11])'")
                    }
                }
            }

            let parsed = records.compactMap { RsyncOutputRecord(from: $0) }

            #expect(parsed.count == 5, "Expected 5 parsed records, got \(parsed.count)")

            guard parsed.count >= 4 else {
                Issue.record("Only parsed \(parsed.count) records")
                return
            }

            // Check deletion (should be index 3)
            let deletionRecord = parsed.first { $0.isDeletion }
            #expect(deletionRecord != nil, "Should have one deletion record")
            #expect(deletionRecord?.path == "old/deprecated.txt")
        }

        @Test("Complex attribute changes - corrected format")
        func realWorldExample3Corrected() {
            // Each record must be exactly 11 chars + space + path
            // Format: YXcstpoguax path
            //         012345678901 12...
            let records = [
                ">f.stpog... /var/www/index.html", // 11 chars: >f.stpog...
                ".fc........ config/settings.json", // 11 chars: .fc........
                "cLc.t...... bin/current -> /usr/local/bin/v2.0", // 11 chars: cLc.t......
                "hf......... backup/file1.txt" // 11 chars: hf.........
            ]

            // Verify each record format
            for (index, record) in records.enumerated() {
                let chars = Array(record)
                #expect(chars.count >= 12,
                        "Record \(index) too short: \(chars.count) chars - '\(record)'")
                if chars.count >= 12 {
                    #expect(chars[11] == " ",
                            "Record \(index) missing space at position 11: '\(record)' - got '\(chars[11])'")
                }
            }

            let parsed = records.compactMap { RsyncOutputRecord(from: $0) }

            #expect(parsed.count == 4, "Expected 4 parsed records, got \(parsed.count)")

            guard parsed.count >= 4 else {
                Issue.record("Only parsed \(parsed.count) records")
                return
            }

            // Check multiple attributes (index 0)
            #expect(parsed[0].attributes.count == 5,
                    "Expected 5 attributes, got \(parsed[0].attributes.count)")

            let attrNames = Set(parsed[0].attributes.map { $0.name })
            #expect(attrNames.contains("size"))
            #expect(attrNames.contains("time"))
            #expect(attrNames.contains("permissions"))
            #expect(attrNames.contains("owner"))
            #expect(attrNames.contains("group"))

            // Check symlink (index 2)
            #expect(parsed[2].fileType == "L", "Expected symlink file type")
            #expect(parsed[2].path.contains("->"), "Symlink path should contain ->")

            // Check hard link (index 3)
            #expect(parsed[3].updateType == "h", "Expected hard link update type")
        }

        @Test("Helper:  Validate record format")
        func validateRecordFormat() {
            // This helper test shows the correct format
            let validRecords = [
                // Update type, file type, 9 attribute positions, space, path
                ">f+++++++++ file.txt", // All new
                ".d..t...... dir/", // Dir time changed
                "<f.st...... data.csv", // Size and time changed
                "cL......... link", // Local symlink change
                ".f...p..... script.sh", // Permission changed
                ".f.stpog... web.html", // Multiple attributes
                ".f........x file.dat", // Extended attribute
                ".f.......a. secure.txt", // ACL changed
                ".f.......ax both.txt" // ACL and xattr
            ]

            for record in validRecords {
                let chars = Array(record)

                // Must be at least 12 characters (11 format + space + at least 1 char path)
                #expect(chars.count >= 12, "Record too short: '\(record)'")

                // Position 11 must be a space
                #expect(chars[11] == " ",
                        "Position 11 must be space in '\(record)', got '\(chars[11])'")

                // Should parse successfully
                let parsed = RsyncOutputRecord(from: record)
                #expect(parsed != nil, "Failed to parse valid record: '\(record)'")
            }
        }
    }

    // MARK: - Helper Property Tests

    @Suite("Helper Properties")
    struct HelperPropertyTests {
        @Test("isNewItem returns true for new files")
        func isNewItemTrue() {
            let record = ">f+++++++++ new_file.txt"
            let parsed = RsyncOutputRecord(from: record)

            #expect(parsed?.isNewItem == true)
        }

        @Test("isNewItem returns false for modified files")
        func isNewItemFalse() {
            let record = ">f.st...... modified_file.txt"
            let parsed = RsyncOutputRecord(from: record)

            #expect(parsed?.isNewItem == false)
        }

        @Test("isDeletion returns true for deletion messages")
        func isDeletionTrue() {
            let record = "*deleting   removed.txt"
            let parsed = RsyncOutputRecord(from: record)

            #expect(parsed?.isDeletion == true)
        }

        @Test("isDeletion returns false for regular files")
        func isDeletionFalse() {
            let record = ">f+++++++++ added.txt"
            let parsed = RsyncOutputRecord(from: record)

            #expect(parsed?.isDeletion == false)
        }
    }

    // MARK: - Regression Tests

    @Suite("Regression Tests", .tags(.regression))
    struct RegressionTests {
        @Test("Bug Fix: Correct character count (11 not 12)")
        func bugFixCorrectCharacterCount() {
            // Ensure we're checking for 11 characters, not 12
            let record = ">f.st...... x.txt" // Exactly 11 chars + space + path
            let parsed = RsyncOutputRecord(from: record)

            #expect(parsed != nil, "Should parse 11-character format correctly")
        }

        @Test("Bug Fix: Correct attribute positions")
        func bugFixCorrectAttributePositions() {
            // Verify ACL is at position 9, not 8
            let record = ".f.......a. file.txt"
            let parsed = RsyncOutputRecord(from: record)

            #expect(parsed?.attributes.first?.name == "acl")
        }

        @Test("Bug Fix: Reserved position handling")
        func bugFixReservedPosition() {
            // Position 8 should be 'u' (reserved), not 'a'
            let record = ".f......u.. file.txt"
            let parsed = RsyncOutputRecord(from: record)

            #expect(parsed?.attributes.first?.name == "reserved")
            #expect(parsed?.attributes.first?.code == "u")
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
            let parsed = RsyncOutputRecord(from: record)

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
            let parsed = RsyncOutputRecord(from: record)

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
            let parsed = RsyncOutputRecord(from: record)

            #expect(parsed != nil)
            #expect(parsed?.attributes.contains { $0.name == name && $0.code == code } == true)
        }
    }
}

extension Tag {
    @Tag static var regression: Self
    @Tag static var performance: Self
    @Tag static var integration: Self
}
