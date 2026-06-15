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

        // zlib (standard locations on macOS SDK and Linux; no pkg-config needed).
        .systemLibrary(name: "CZlib"),

        // FlateDecode stream compression. Links zlib; depends on PDFCore's
        // StreamCompressor protocol.
        .target(name: "PDFFlate", dependencies: ["PDFCore", "CZlib"]),

        // HarfBuzz (shaping + subsetting). harfbuzz-subset.pc transitively
        // links harfbuzz. Needs PKG_CONFIG_PATH set to brew's pkgconfig on macOS.
        .systemLibrary(
            name: "CHarfBuzz",
            pkgConfig: "harfbuzz-subset",
            providers: [.apt(["libharfbuzz-dev"]), .brew(["harfbuzz"])]
        ),

        // TTF/OTF font loading, shaping, subsetting, and embedding via HarfBuzz.
        .target(name: "PDFFonts", dependencies: ["PDFCore", "CHarfBuzz"]),

        // Public umbrella. Re-exports PDFCore and wires in the optional
        // capability layers (PDFFlate now; PDFFonts / PDFImage later).
        .target(name: "SwiftPDF", dependencies: ["PDFCore", "PDFFlate"]),

        // Dev CLI: `swift run samples [output-dir]` writes showcase PDFs so the
        // current feature set can be eyeballed in a real viewer.
        .executableTarget(name: "samples", dependencies: ["SwiftPDF"]),

        .testTarget(name: "PDFCoreTests", dependencies: ["PDFCore"]),
        .testTarget(name: "SwiftPDFTests", dependencies: ["SwiftPDF", "CZlib"]),
        .testTarget(name: "PDFFontsTests", dependencies: ["PDFFonts"],
                    resources: [.copy("Fixtures")]),
    ]
)
