// swift-tools-version:5.9
import PackageDescription

// swift-pdf — a pure-Swift PDF generation library.
//
// Layered so the pure-Swift core (PDFCore) never links any C library: the
// base-14 text + vector-graphics path has ZERO native dependencies. Optional
// capability layers (Flate/fonts/images) sit behind systemLibrary targets and
// are wired in only by the umbrella `SwiftPDF` product. See the plan for the
// full target map; this manifest grows milestone by milestone.
let package = Package(
    name: "swift-pdf",
    products: [
        .library(name: "SwiftPDF", targets: ["SwiftPDF"]),
        .library(name: "PDFCore", targets: ["PDFCore"]),
    ],
    targets: [
        // Pure Swift, no dependencies. Original work against ISO 32000.
        .target(name: "PDFCore"),

        // Public umbrella. For now it just re-exports PDFCore; later milestones
        // wire in PDFFlate / PDFFonts / PDFImage here.
        .target(name: "SwiftPDF", dependencies: ["PDFCore"]),

        // Dev CLI: `swift run samples [output-dir]` writes showcase PDFs so the
        // current feature set can be eyeballed in a real viewer.
        .executableTarget(name: "samples", dependencies: ["SwiftPDF"]),

        .testTarget(name: "PDFCoreTests", dependencies: ["PDFCore"]),
    ]
)
