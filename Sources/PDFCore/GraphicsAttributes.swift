// Copyright (c) 2026 Triple C Labs GmbH.
// SPDX-License-Identifier: MIT

/// Line cap style (PDF `J` operator).
public enum LineCap: Int, Sendable {
    case butt = 0
    case round = 1
    case projectingSquare = 2
}

/// Line join style (PDF `j` operator).
public enum LineJoin: Int, Sendable {
    case miter = 0
    case round = 1
    case bevel = 2
}

/// Fill rule for painting/clipping paths.
public enum FillRule: Sendable {
    case nonZero    // f / W
    case evenOdd    // f* / W*
}

/// A dash pattern: array of on/off lengths plus a starting phase.
public struct DashPattern: Equatable, Sendable {
    public var lengths: [Double]
    public var phase: Double
    public init(lengths: [Double], phase: Double = 0) {
        self.lengths = lengths
        self.phase = phase
    }
    /// A solid (no dashing) line.
    public static let solid = DashPattern(lengths: [], phase: 0)
}
