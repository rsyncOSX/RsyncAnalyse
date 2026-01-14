//
//  RsyncOutputData.swift
//  RsyncAnalyse
//
//  Created by Thomas Evensen on 11/01/2026.
//

import Foundation

/// Represents a single line of rsync output
public struct RsyncOutputData: Identifiable, Equatable, Hashable, Sendable {
    public let id = UUID()
    public var record: String

    public init(record: String) {
        self.record = record
    }
}
