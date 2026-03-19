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
            let projectDir = getCurrentWorkingDirectory()
            let tailwind = TailwindManager(projectDir: projectDir)

            // Step 1: Build WASM in release mode
            print("Building WASM target (release)...")
            let buildOk = try await shellCommand(
                "/usr/bin/env",
                arguments: ["swift", "build", "-c", "release", "--triple", "wasm32-unknown-wasi"],
                workingDirectory: projectDir
            )
            guard buildOk else {
                print("Error: WASM build failed.")
                throw ExitCode.failure
            }
            print("WASM build complete.\n")

            // Step 2: Tailwind CSS (single build, minified)
            if tailwind.isFleetTailwindPresent() {
                let wasmDir = projectDir + "/.build/wasm32-unknown-wasi/release"
                try tailwind.extractClasses(wasmDir: wasmDir)

                let outputDir = projectDir + "/" + output
                let ok = try await tailwind.build(outputDir: outputDir, minify: true)
                if ok {
                    print("Tailwind CSS build complete.\n")
                } else {
                    print("Warning: Tailwind CSS build had issues.\n")
                }
            } else {
                print("Fleet-Tailwind not detected, skipping Tailwind CSS.\n")
            }

            // Step 3: Copy build artifacts to output directory
            let outputDir = projectDir + "/" + output
            if !fileExists(atPath: outputDir) {
                try createDirectory(atPath: outputDir)
            }

            print("Production build written to '\(output)/'")
        }
    }
}
