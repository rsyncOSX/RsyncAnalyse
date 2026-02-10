//
//  OpenRsyncOutputRecordTests.swift
//  RsyncAnalyse
//
//  Created by Thomas Evensen on 10/02/2026.
//

// MARK: - Basic Format Tests

import Foundation
@testable import RsyncAnalyse
import Testing

@Suite("OpenRsync Output Record Parser Tests")
struct OpenRsyncOutputRecordTests {
    @Suite("Basic Format Tests - All Fixed")
    struct BasicFormatTestsFixed {
        @Test("Parse new file with all attributes new")
        func parseNewFile() {
            // Format: >f+++++++ (9 chars: > f and 7 plusses)
            let record = ">f+++++++ documents/report.pdf"
            let parsed = OpenRsyncOutputRecord(from: record)

            #expect(parsed != nil, "Should parse new file record")
            #expect(parsed?.updateType == ">")
            #expect(parsed?.fileType == "f")
            #expect(parsed?.path == "documents/report.pdf")
            #expect(parsed?.attributes.count == 7)
            #expect(parsed?.isNewItem == true)
            #expect(parsed?.fileTypeLabel == "file")
        }

        @Test("Parse file with size and time change")
        func parseFileWithSizeAndTimeChange() {
            // Format: >f.st.... (9 chars: >f + . + s + t + 4 dots)
            //         012345678
            //         >f.st....
            let record = ">f.st.... images/photo.jpg"

            // Validate format
            let chars = Array(record)
            let formatString = String(chars.prefix(9))
            #expect(formatString.count == 9, "Format should be 9 chars, got \(formatString.count): '\(formatString)'")
            #expect(chars.count > 9 && chars[9] == " ", "Position 9 should be space")

            let parsed = OpenRsyncOutputRecord(from: record)

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
            // Format: .d..t.... (9 chars: . + d + 2 dots + t + 4 dots)
            //         012345678
            //         .d..t....
            let record = ".d..t.... src/components/"

            let parsed = OpenRsyncOutputRecord(from: record)

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
            // Format: .f...p... (9 chars: . + f + 3 dots + p + 3 dots)
            //         012345678
            //         .f...p...
            let record = ".f...p... scripts/deploy.sh"

            let parsed = OpenRsyncOutputRecord(from: record)

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
                (">f+++++++", "New file"),
                (">f.st....", "Size and time"),
                (".d..t....", "Dir time change"),
                (".f....p..", "Permission change"),
                (".f.stpog.", "Multiple attributes"),
                ("cd+++++++", "New directory"),
                ("<f.st....", "Sent file"),
                ("hf.......", "Hard link"),
                (".f.......", "No changes")
            ]

            for (format, description) in testCases {
                #expect(format.count == 9,
                        "\(description) format '\(format)' should be 9 chars, got \(format.count)")
            }
        }

        @Test("Parse with visual format guide")
        func parseWithVisualGuide() {
            // Visual guide for the 9-character format:
            // Position: 0 1 2 3 4 5 6 7 8
            // Format:   Y X c s t p o g z
            // Example:  > f . s t . . . .

            let testCases: [(record: String, expectedAttrs: [String])] = [
                (">f.st.... file1.txt", ["size", "time"]),
                (".f..t.... file2.txt", ["time"]),
                (".f...p... file3.txt", ["permissions"]),
                (".f....o.. file4.txt", ["owner"]),
                (".f.....g. file5.txt", ["group"]),
                (".f......z file6.txt", ["reserved"]),
                (".fc...... file7.txt", ["checksum"])
            ]

            for (record, expectedAttrs) in testCases {
                let parsed = OpenRsyncOutputRecord(from: record)
                #expect(parsed != nil, "Should parse: '\(record)'")

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
            let record = "cd+++++++ backup/2024/"
            let parsed = OpenRsyncOutputRecord(from: record)

            #expect(parsed != nil)
            #expect(parsed?.updateType == "c")
            #expect(parsed?.fileType == "d")
            #expect(parsed?.path == "backup/2024/")
            #expect(parsed?.fileTypeLabel == "directory")
        }

        @Test("Parse symlink")
        func parseSymlink() {
            let record = "cL+++++++ config/current -> v2.0"
            let parsed = OpenRsyncOutputRecord(from: record)

            #expect(parsed != nil)
            #expect(parsed?.updateType == "c")
            #expect(parsed?.fileType == "L")
            #expect(parsed?.path == "config/current -> v2.0")
            #expect(parsed?.fileTypeLabel == "symlink")
        }

        @Test("Parse symlink with attribute changes")
        func parseSymlinkWithChanges() {
            let record = "cLc.t.... links/data -> /mnt/storage"
            let parsed = OpenRsyncOutputRecord(from: record)

            #expect(parsed != nil)
            #expect(parsed?.updateType == "c")
            #expect(parsed?.fileType == "L")
            #expect(parsed?.attributes.count == 2)

            let attrNames = parsed?.attributes.map { $0.name }.sorted()
            #expect(attrNames == ["checksum", "time"])
        }

        @Test("Parse device file")
        func parseDevice() {
            let record = ">D+++++++ dev/sda1"
            let parsed = OpenRsyncOutputRecord(from: record)

            #expect(parsed != nil)
            #expect(parsed?.fileType == "D")
            #expect(parsed?.fileTypeLabel == "device")
        }

        @Test("Parse special file")
        func parseSpecialFile() {
            let record = ">S+++++++ var/run/socket"
            let parsed = OpenRsyncOutputRecord(from: record)

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
            let record = "<f.st.... data/export.csv"
            let parsed = OpenRsyncOutputRecord(from: record)

            #expect(parsed != nil)
            #expect(parsed?.updateType == "<")
            #expect(parsed?.updateTypeLabel.text == "SENT")
        }

        @Test("Parse received file")
        func parseReceivedFile() {
            let record = ">f.st.... data/import.csv"
            let parsed = OpenRsyncOutputRecord(from: record)

            #expect(parsed != nil)
            #expect(parsed?.updateType == ">")
            #expect(parsed?.updateTypeLabel.text == "RECEIVED")
        }

        @Test("Parse local change")
        func parseLocalChange() {
            let record = "cd+++++++ new_directory/"
            let parsed = OpenRsyncOutputRecord(from: record)

            #expect(parsed != nil)
            #expect(parsed?.updateType == "c")
            #expect(parsed?.updateTypeLabel.text == "LOCAL_CHANGE")
        }

        @Test("Parse hard link")
        func parseHardLink() {
            let record = "hf....... docs/readme.txt"
            let parsed = OpenRsyncOutputRecord(from: record)

            #expect(parsed != nil)
            #expect(parsed?.updateType == "h")
            #expect(parsed?.updateTypeLabel.text == "HARDLINK")
        }

        @Test("Parse no update")
        func parseNoUpdate() {
            let record = ".f....... unchanged.txt"
            let parsed = OpenRsyncOutputRecord(from: record)

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
            let parsed = OpenRsyncOutputRecord(from: record)

            #expect(parsed != nil)
            #expect(parsed?.updateType == "*")
            #expect(parsed?.path == "old/obsolete.txt")
            #expect(parsed?.isDeletion == true)
            #expect(parsed?.updateTypeLabel.text == "deleting")
        }

        @Test("Parse deletion with path containing spaces")
        func parseDeletionWithMultipleSpaces() {
            let record = "*deleting path/with spaces/file.txt"
            let parsed = OpenRsyncOutputRecord(from: record)

            #expect(parsed != nil)
            #expect(parsed?.path == "path/with spaces/file.txt")
        }
    }

    // MARK: - Attribute Combination Tests

    @Suite("Attribute Combinations")
    struct AttributeCombinationTests {
        @Test("Parse multiple attribute changes")
        func parseMultipleAttributeChanges() {
            let record = ">f.stpog. /var/www/index.html"
            let parsed = OpenRsyncOutputRecord(from: record)

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
            let record = ".fc...... config.json"
            let parsed = OpenRsyncOutputRecord(from: record)

            #expect(parsed != nil)
            #expect(parsed?.attributes.count == 1)
            #expect(parsed?.attributes.first?.name == "checksum")
            #expect(parsed?.attributes.first?.code == "c")
        }

        @Test("Parse owner and group change")
        func parseOwnerAndGroupChange() {
            let record = ".f....og. file.txt"
            let parsed = OpenRsyncOutputRecord(from: record)

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
            let record = ".f..t.... file1.txt"
            let parsed = OpenRsyncOutputRecord(from: record)

            #expect(parsed != nil)
            #expect(parsed?.attributes.count == 1)
            #expect(parsed?.attributes.first?.name == "time")
            #expect(parsed?.attributes.first?.code == "t")
        }

        @Test("Parse uppercase time change")
        func parseUppercaseTimeChange() {
            let record = ".f..T.... file2.txt"
            let parsed = OpenRsyncOutputRecord(from: record)

            #expect(parsed != nil)
            #expect(parsed?.attributes.count == 1)
            #expect(parsed?.attributes.first?.name == "time")
            #expect(parsed?.attributes.first?.code == "T")
        }
    }

    // MARK: - Reserved Position Tests

    @Suite("Reserved Position (z)")
    struct ReservedPositionTests {
        @Test("Parse reserved change")
        func parseReservedChange() {
            let record = ".f......z file_compressed.txt"
            let parsed = OpenRsyncOutputRecord(from: record)

            #expect(parsed != nil)
            #expect(parsed?.attributes.count == 1)
            #expect(parsed?.attributes.first?.name == "reserved")
            #expect(parsed?.attributes.first?.code == "z")
        }

        @Test("Parse reserved as plus")
        func parseReservedAsPlus() {
            let record = ".f......+ file_new_reserved.txt"
            let parsed = OpenRsyncOutputRecord(from: record)

            #expect(parsed != nil)
            #expect(parsed?.attributes.count == 1)
            #expect(parsed?.attributes.first?.name == "reserved")
            #expect(parsed?.attributes.first?.code == "+")
        }
    }

    // MARK: - Path Tests

    @Suite("Path Handling")
    struct PathTests {
        @Test("Parse path with spaces")
        func parsePathWithSpaces() {
            let record = ">f+++++++ my documents/important file.txt"
            let parsed = OpenRsyncOutputRecord(from: record)

            #expect(parsed != nil)
            #expect(parsed?.path == "my documents/important file.txt")
        }

        @Test("Parse path with special characters")
        func parsePathWithSpecialCharacters() {
            let record = ">f+++++++ files/test@#$%.txt"
            let parsed = OpenRsyncOutputRecord(from: record)

            #expect(parsed != nil)
            #expect(parsed?.path == "files/test@#$%.txt")
        }

        @Test("Parse absolute path")
        func parseAbsolutePath() {
            let record = ">f+++++++ /var/log/system.log"
            let parsed = OpenRsyncOutputRecord(from: record)

            #expect(parsed != nil)
            #expect(parsed?.path == "/var/log/system.log")
        }

        @Test("Parse path with Unicode characters")
        func parsePathWithUnicode() {
            let record = ">f+++++++ files/文档.txt"
            let parsed = OpenRsyncOutputRecord(from: record)

            #expect(parsed != nil)
            #expect(parsed?.path == "files/文档.txt")
        }
    }

    // MARK: - Edge Cases

    @Suite("Edge Cases and Error Handling")
    struct EdgeCaseTests {
        @Test("Parse record with empty path")
        func parseEmptyPath() {
            let record = ">f+++++++"
            let parsed = OpenRsyncOutputRecord(from: record)

            // Should either be nil or have empty path
            if let parsed = parsed {
                #expect(parsed.path == "")
            }
        }

        @Test("Parse too short record")
        func parseTooShort() {
            let record = ">f+++"
            let parsed = OpenRsyncOutputRecord(from: record)

            #expect(parsed == nil)
        }

        @Test("Parse invalid format")
        func parseInvalidFormat() {
            let record = "invalid format without proper structure"
            let parsed = OpenRsyncOutputRecord(from: record)

            #expect(parsed == nil)
        }

        @Test("Parse empty string")
        func parseEmptyString() {
            let record = ""
            let parsed = OpenRsyncOutputRecord(from: record)

            #expect(parsed == nil)
        }
    }

    // MARK: - Real World Examples

    @Suite("Real World Examples")
    struct RealWorldExamples {
        @Test("Typical file sync scenario - corrected format")
        func realWorldExample1Corrected() {
            // Each record must be exactly 9 chars + space + path
            // Format: YXcstpogz path
            //         012345678 9...
            let records = [
                ".d..t.... ./",
                ".f...p... Something.pdf",
                ".f....... md5sum-2010-02-21.txt",
                ".f...p... prova.rb",
                ".d....... .metadata/",
                ".f...p... .metadata/.lock",
                ".f...p... .metadata/version.ini",
                ">f+++++++ Parameter_Usage.txt"
            ]

            // Verify each record format
            for (index, record) in records.enumerated() {
                let chars = Array(record)
                #expect(chars.count >= 10,
                        "Record \(index) too short: \(chars.count) chars - '\(record)'")
                if chars.count >= 10 {
                    let formatPart = String(chars[0 ... 8])
                    #expect(chars[9] == " ",
                            "Record \(index) missing space at position 9: '\(record)' - got '\(chars[9])' - format: '\(formatPart)'")
                }
            }

            let parsed = records.compactMap { OpenRsyncOutputRecord(from: $0) }
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

            // Check .metadata directory (index 4)
            #expect(parsed[4].fileType == "d", "metadata should be directory")
            #expect(parsed[4].path == ".metadata/", "Should have correct metadata path")

            // Check new file (index 7)
            #expect(parsed[7].updateType == ">", "Last file should be received")
            #expect(parsed[7].isNewItem == true, "Last file should be new")
            #expect(parsed[7].path == "Parameter_Usage.txt", "Should have correct filename")
            #expect(parsed[7].attributes.count == 7, "New file should have all 7 attributes marked as new")
        }

        @Test("Backup scenario with deletions - corrected format")
        func realWorldExample2Corrected() {
            // Each record must be exactly 9 chars + space + path
            // Format: YXcstpogz path
            //         012345678 9...
            let records = [
                ">f.st.... data/updated.csv", // 9 chars: >f.st....
                "cd+++++++ logs/2024/", // 9 chars: cd+++++++
                ">f+++++++ logs/2024/app.log", // 9 chars: >f+++++++
                "*deleting old/deprecated.txt", // Special deletion format
                ".f....p.. scripts/backup.sh" // 9 chars: .f....p..
            ]

            // Verify each record format
            for (index, record) in records.enumerated() {
                if !record.hasPrefix("*") {
                    let chars = Array(record)
                    #expect(chars.count >= 10,
                            "Record \(index) too short: \(chars.count) chars - '\(record)'")
                    if chars.count >= 10 {
                        #expect(chars[9] == " ",
                                "Record \(index) missing space at position 9: '\(record)' - got '\(chars[9])'")
                    }
                }
            }

            let parsed = records.compactMap { OpenRsyncOutputRecord(from: $0) }

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
            // Each record must be exactly 9 chars + space + path
            // Format: YXcstpogz path
            //         012345678 9...
            let records = [
                ">f.stpog. /var/www/index.html",
                ".fc...... config/settings.json",
                "cLc.t.... bin/current -> /usr/local/bin/v2.0",
                "hf....... backup/file1.txt"
            ]

            // Verify each record format
            for (index, record) in records.enumerated() {
                let chars = Array(record)
                #expect(chars.count >= 10,
                        "Record \(index) too short: \(chars.count) chars - '\(record)'")
                if chars.count >= 10 {
                    #expect(chars[9] == " ",
                            "Record \(index) missing space at position 9: '\(record)' - got '\(chars[9])'")
                }
            }

            let parsed = records.compactMap { OpenRsyncOutputRecord(from: $0) }

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

        @Test("Helper: Validate record format")
        func validateRecordFormat() {
            // This helper test shows the correct format
            let validRecords = [
                // Update type, file type, 7 attribute positions, space, path
                ">f+++++++ file.txt", // All new (received)
                ".d..t.... dir/", // Dir time changed
                "<f.st.... data.csv", // Size and time changed (sent)
                "cL....... link", // Local symlink change
                ".f...p... script.sh", // Permission changed
                ".f.stpog. web.html", // Multiple attributes
                ".f......z file.dat", // Reserved position
                ".fc..... secure.txt" // Checksum changed
            ]

            for record in validRecords {
                let chars = Array(record)

                // Must be at least 10 characters (9 format + space + at least 1 char path)
                #expect(chars.count >= 10, "Record too short: '\(record)'")

                // Position 9 must be a space
                #expect(chars[9] == " ",
                        "Position 9 must be space in '\(record)', got '\(chars[9])'")

                // Should parse successfully
                let parsed = OpenRsyncOutputRecord(from: record)
                #expect(parsed != nil, "Failed to parse valid record: '\(record)'")
            }
        }
    }

    // MARK: - Helper Property Tests

    @Suite("Helper Properties")
    struct HelperPropertyTests {
        @Test("isNewItem returns true for new files")
        func isNewItemTrue() {
            let record = ">f+++++++ new_file.txt"
            let parsed = OpenRsyncOutputRecord(from: record)

            #expect(parsed?.isNewItem == true)
        }

        @Test("isNewItem returns false for modified files")
        func isNewItemFalse() {
            let record = ">f.st.... modified_file.txt"
            let parsed = OpenRsyncOutputRecord(from: record)

            #expect(parsed?.isNewItem == false)
        }

        @Test("isDeletion returns true for deletion messages")
        func isDeletionTrue() {
            let record = "*deleting removed.txt"
            let parsed = OpenRsyncOutputRecord(from: record)

            #expect(parsed?.isDeletion == true)
        }

        @Test("isDeletion returns false for regular files")
        func isDeletionFalse() {
            let record = ">f+++++++ added.txt"
            let parsed = OpenRsyncOutputRecord(from: record)

            #expect(parsed?.isDeletion == false)
        }
    }

    // MARK: - Regression Tests

    @Suite("Regression Tests", .tags(.regression))
    struct RegressionTests {
        @Test("Bug Fix: Correct character count (9 not 10)")
        func bugFixCorrectCharacterCount() {
            // Ensure we're checking for 9 characters, not 10
            let record = ">f.st.... x.txt" // Exactly 9 chars + space + path
            let parsed = OpenRsyncOutputRecord(from: record)

            #expect(parsed != nil, "Should parse 9-character format correctly")
        }

        @Test("Bug Fix: Correct space position (position 9, not 10)")
        func bugFixCorrectSpacePosition() {
            // Verify space is at position 9 in 9-character format
            let record = ".f..t.... file.txt"
            let chars = Array(record)

            #expect(chars[9] == " ", "Space must be at position 9 for 9-character format")

            let parsed = OpenRsyncOutputRecord(from: record)
            #expect(parsed != nil, "Should parse correctly with space at position 9")
        }

        @Test("Bug Fix: Reserved position handling (position 8)")
        func bugFixReservedPosition() {
            // Position 8 should be 'z' (reserved/compressed)
            let record = ".f......z file.txt"
            let parsed = OpenRsyncOutputRecord(from: record)

            #expect(parsed?.attributes.first?.name == "reserved")
            #expect(parsed?.attributes.first?.code == "z")
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
            let record = ">\(typeChar)+++++++ test"
            let parsed = OpenRsyncOutputRecord(from: record)

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
            let record = "\(typeChar)f....... test.txt"
            let parsed = OpenRsyncOutputRecord(from: record)

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
            (8, "z", "reserved")
        ])
        func parseIndividualAttributes(position: Int, code: Character, name: String) {
            var chars = Array(".f.......")
            chars[position] = code
            let record = String(chars) + " test.txt"
            let parsed = OpenRsyncOutputRecord(from: record)

            #expect(parsed != nil, "Should parse record with \(name) at position \(position)")
            #expect(parsed?.attributes.contains { $0.name == name && $0.code == code } == true,
                    "Should have \(name) attribute with code \(code)")
        }

        @Test("Verify all attribute positions", arguments: [
            ("checksum", 2),
            ("size", 3),
            ("time", 4),
            ("permissions", 5),
            ("owner", 6),
            ("group", 7),
            ("reserved", 8)
        ])
        func verifyAttributePositions(attrName: String, expectedPosition: Int) {
            // This test verifies the mapping between attribute names and positions
            // to ensure we're parsing the correct positions for each attribute
            let chars = [Character](repeating: ".", count: 9)
            var testChars = chars
            testChars[expectedPosition] = "+"
            let record = String(testChars) + " test.txt"

            let parsed = OpenRsyncOutputRecord(from: record)
            #expect(parsed != nil)
            #expect(parsed?.attributes.count == 1)
            #expect(parsed?.attributes.first?.name == attrName,
                    "Position \(expectedPosition) should map to \(attrName)")
        }
    }

    // MARK: - Comparison with Rsync Format

    @Suite("OpenRsync vs Rsync Format Differences")
    struct FormatComparisonTests {
        @Test("OpenRsync has 7 attributes, not 10")
        func verifyAttributeCount() {
            // OpenRsync: YXcstpogz (9 chars total, 7 attributes)
            // Rsync: YXcstpoguax (12 chars total, 10 attributes)
            let record = ">f+++++++ file.txt"
            let parsed = OpenRsyncOutputRecord(from: record)

            #expect(parsed?.attributes.count == 7, "OpenRsync should have 7 attributes for new items")
        }

        @Test("OpenRsync format is 9 characters")
        func verifyFormatLength() {
            let record = ">f.st.... file.txt"
            let chars = Array(record)

            // Verify format is exactly 9 characters before space
            let formatPart = String(chars.prefix(9))
            #expect(formatPart.count == 9)
            #expect(chars[9] == " ")
        }

        @Test("OpenRsync does not have ACL or xattr positions")
        func verifyMissingExtendedAttributes() {
            // OpenRsync format stops at position 8 (reserved/z)
            // It doesn't have positions for 'a' (ACL) or 'x' (xattr) like rsync
            let record = ">f+++++++ file.txt"
            let parsed = OpenRsyncOutputRecord(from: record)

            // All attributes should be one of: checksum, size, time, permissions, owner, group, reserved
            let validNames = ["checksum", "size", "time", "permissions", "owner", "group", "reserved"]
            let allValid = parsed?.attributes.allSatisfy { validNames.contains($0.name) } ?? false
            #expect(allValid, "OpenRsync should only have basic attributes, not ACL or xattr")
        }
    }
}
