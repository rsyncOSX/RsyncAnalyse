# RsyncAnalyse

A Swift package for parsing and analyzing rsync output with SwiftUI views for visualization.

## Overview

RsyncAnalyse provides powerful parsing, analysis, and visualization capabilities for rsync command output. It includes:

- **ActorRsyncOutputAnalyzer**: Thread-safe actor for parsing rsync output
- **Rich Data Models**: Comprehensive models for itemized changes and statistics
- **SwiftUI Views**: Pre-built components for displaying rsync output
- **Swift Testing**: Complete test suite using Swift Testing framework

## Features

✅ Parse rsync itemized output format  
✅ Extract comprehensive statistics (file counts, sizes, speedup)  
✅ Detect errors and warnings  
✅ Support for dry-run detection  
✅ Thread-safe with Swift concurrency  
✅ Caching support for performance  
✅ Sendable types for safe concurrency  

## Requirements

- macOS 14.0+
- Swift 6.0+
- Xcode 16.0+

## Installation

### Swift Package Manager

Add RsyncAnalyse to your `Package.swift`:

```swift
dependencies: [
    .package(path: "../RsyncAnalyse")
]
```

Or in Xcode, go to File > Add Package Dependencies and add the local package.

## Usage

### Basic Analysis

```swift
import RsyncAnalyse

let analyzer = ActorRsyncOutputAnalyzer()

let rsyncOutput = """
.f..t....... file.txt
.d..t....... folder/
Number of files: 10 (reg: 8, dir: 1, link: 1)
Total file size: 1,024 bytes
speedup is 2.00
"""

let result = await analyzer.analyze(rsyncOutput)

if let result = result {
    print("Files changed: \\(result.itemizedChanges.count)")
    print("Total files: \\(result.statistics.totalFiles.total)")
    print("Speedup: \\(result.statistics.speedup)x")
}
```

### Using with Array Input

```swift
let data = [
    RsyncOutputData(record: ".f..t....... file1.txt"),
    RsyncOutputData(record: "Number of files: 1 (reg: 1, dir: 0, link: 0)")
]

let result = await analyzer.analyze(data)
```

### Caching for Performance

```swift
// Use cached version for repeated analysis
let result1 = await analyzer.analyzeCached(output)
let result2 = await analyzer.analyzeCached(output) // Uses cache

// Clear cache when needed
await analyzer.clearCache()
```

### Supporting Views

```swift
// Display statistics
StatCard(
    title: "Total Size",
    value: "1.5 GB",
    icon: "externaldrive",
    color: .blue
)

// Display change items
ChangeItemRow(change: itemizedChange)

// Filter chips
FilterChip(
    icon: "📄",
    label: "Files",
    isSelected: true,
    action: { /* toggle filter */ }
)
```

## Data Models

### AnalysisResult

Contains the complete analysis of rsync output:

```swift
struct AnalysisResult {
    let itemizedChanges: [ItemizedChange]
    let statistics: Statistics
    let isDryRun: Bool
    let errors: [String]
    let warnings: [String]
}
```

### ItemizedChange

Represents a single file change:

```swift
struct ItemizedChange {
    let changeType: ChangeType  // .file, .directory, .symlink, etc.
    let path: String
    let target: String?         // For symlinks
    let flags: ChangeFlags
}
```

### Statistics

Comprehensive rsync statistics:

```swift
struct Statistics {
    let totalFiles: FileCount
    let filesCreated: FileCount
    let filesDeleted: Int
    let regularFilesTransferred: Int
    let totalFileSize: Int64
    let totalTransferredSize: Int64
    let literalData: Int64
    let matchedData: Int64
    let bytesSent: Int64
    let bytesReceived: Int64
    let speedup: Double
    let errors: [String]
    let warnings: [String]
    
    var efficiencyPercentage: Double { get }
    var totalFilesChanged: Int { get }
}
```

## Utility Functions

### Format Bytes

```swift
let formatted = ActorRsyncOutputAnalyzer.formatBytes(1_048_576)
// Result: "1 MB"
```

### Calculate Efficiency

```swift
let efficiency = ActorRsyncOutputAnalyzer.efficiencyPercentage(statistics: stats)
// Result: percentage of data transferred vs total
```

### Generate Summary

```swift
let summary = await analyzer.summary(for: result)
print(summary)
// Displays formatted summary with statistics
```

### Group by Change Type

```swift
let changesByType = await analyzer.changesByType(for: result)
// Returns: [ChangeType: Int] dictionary
```

## Testing

The package includes comprehensive tests using Swift Testing:

```bash
swift test
```

Tests cover:
- Basic parsing
- Edge cases
- Error handling
- Performance
- Concurrent access
- Cache functionality

## Architecture

### Thread Safety

All analyzer operations are thread-safe using Swift actors:

```swift
actor ActorRsyncOutputAnalyzer {
    // All methods are automatically isolated
}
```

### Sendable Types

All data models conform to `Sendable` for safe concurrent usage:

```swift
struct AnalysisResult: Sendable { }
struct ItemizedChange: Sendable { }
struct Statistics: Sendable { }
```

## Performance

- Supports parsing 100k+ lines efficiently
- Built-in caching for repeated analysis
- Concurrent-safe for parallel operations
- Memory-efficient with proper cleanup

## License

See the LICENSE file in the original RsyncVerify project.

## Author

Created by Thomas Evensen on 11/01/2026.

## Contributing

This package is extracted from the RsyncVerify project. For contributions, please refer to the main project repository.
