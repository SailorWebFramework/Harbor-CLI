import ArgumentParser
import HarborUtils
import Foundation

struct Build: ParsableCommand {

    static let configuration = CommandConfiguration(
        abstract: "Build Harbor targets for production",
        subcommands: [Web.self]
    )
}

// MARK: - harbor build web

extension Build {
    struct Web: AsyncParsableCommand {
        static let configuration = CommandConfiguration(
            abstract: "Build the web target for production deployment"
        )

        @Option(name: .long, help: "Output directory for the production build")
        var output: String = "dist"

        func run() async throws {
            print("harbor build web")
            print("Building web target for production...")
            print("[Not yet implemented] This will:")
            print("  1. Build WASM in release mode (swift build -c release --triple wasm32-unknown-wasi)")
            print("  2. Run wasm-opt for size optimization")
            print("  3. Run Tailwind CSS with --minify")
            print("  4. Copy assets to '\(output)/' directory")
            print("  5. Generate index.html with production paths")
            print("")
            print("For now, run manually:")
            print("  swift build -c release --triple wasm32-unknown-wasi")
        }
    }
}
