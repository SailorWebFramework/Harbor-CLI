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

            // Step 1: Tree-shake Tailwind classes (source scan, fast: < 0.1s)
            // Must run before Tailwind CSS build so the class list is fresh.
            if tailwind.isFleetTailwindPresent() {
                print("Extracting used Tailwind classes from source...")
                do {
                    try tailwind.extractClassesFromSource()
                } catch {
                    print("Warning: Tailwind source extraction failed: \(error). Continuing with existing class list.")
                }
            }

            // Step 2: Build WASM in release mode via PackageToJS
            let sdk = SwiftSDK.resolveWasmSDK()
            print("Building WASM target (release) with Swift SDK '\(sdk)'...")
            let buildOk = try await shellCommand(
                "/usr/bin/env",
                arguments: ["swift", "package", "-c", "release", "--swift-sdk", sdk, "js"],
                workingDirectory: projectDir
            )
            guard buildOk else {
                print("Error: WASM build failed.")
                throw ExitCode.failure
            }
            print("WASM build complete.\n")

            // Step 3: Tailwind CSS (single build, minified)
            let outputDir = projectDir + "/" + output
            if tailwind.isFleetTailwindPresent() {
                let ok = try await tailwind.build(outputDir: outputDir, minify: true)
                if ok {
                    print("Tailwind CSS build complete.\n")
                } else {
                    print("Warning: Tailwind CSS build had issues.\n")
                }
            } else {
                print("Fleet-Tailwind not detected, skipping Tailwind CSS.\n")
            }

            // Step 4: Copy PackageToJS artifacts into dist/
            if !fileExists(atPath: outputDir) {
                try createDirectory(atPath: outputDir)
            }
            let packageOutputDir = projectDir + "/.build/plugins/PackageToJS/outputs/Package"
            if fileExists(atPath: packageOutputDir) {
                let fm = FileManager.default
                let items = (try? fm.contentsOfDirectory(atPath: packageOutputDir)) ?? []
                for item in items {
                    let src = packageOutputDir + "/" + item
                    let dst = outputDir + "/" + item
                    if fm.fileExists(atPath: dst) {
                        try fm.removeItem(atPath: dst)
                    }
                    try fm.copyItem(atPath: src, toPath: dst)
                }
                print("Copied PackageToJS artifacts to '\(output)/'")
            } else {
                print("Note: PackageToJS output not found at \(packageOutputDir). Skipping artifact copy.")
            }

            print("Production build written to '\(output)/'")
        }
    }
}
