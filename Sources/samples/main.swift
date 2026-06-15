// Copyright (c) 2026 Triple C Labs GmbH.
// SPDX-License-Identifier: MIT
//
// Dev CLI: generates the showcase PDFs into an output directory.
//   swift run samples [output-dir]      (default: ./Samples)

import Foundation
import SwiftPDF

let outputDir = CommandLine.arguments.count > 1
    ? CommandLine.arguments[1]
    : "Samples"

let dirURL = URL(fileURLWithPath: outputDir, isDirectory: true)
try FileManager.default.createDirectory(at: dirURL, withIntermediateDirectories: true)

print("Generating \(Samples.all.count) samples into \(dirURL.path)/")
for sample in Samples.all {
    let doc = sample.make()
    doc.useFlateCompression()
    let data = doc.data()
    let url = dirURL.appendingPathComponent("\(sample.name).pdf")
    try data.write(to: url)
    print("  \(sample.name).pdf  (\(data.count) bytes)")
}
print("Done.")
