// Copyright (c) 2026 the swift-pdf authors.
// SPDX-License-Identifier: MIT

// Public umbrella for swift-pdf. Re-exports the pure-Swift core so consumers
// `import SwiftPDF` and get the whole API surface. Optional capability layers
// (compression, font embedding, images) are wired in here in later milestones.
@_exported import PDFCore
