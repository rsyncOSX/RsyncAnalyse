//
//  RemoteDataNumbers.swift
//  RsyncAnalyse
//
//  Created by Thomas Evensen on 14/01/2026.
//

import Foundation

/// Minimal stub of RemoteDataNumbers for DetailsVerifyView
/// In a real implementation, this would contain more data
public struct RemoteDataNumbers: Identifiable, Hashable, Sendable {
    public var id: UUID
    public var outputfromrsync: [RsyncOutputData]?
    
    public init(id: UUID = UUID(), outputfromrsync: [RsyncOutputData]? = nil) {
        self.id = id
        self.outputfromrsync = outputfromrsync
    }
}
