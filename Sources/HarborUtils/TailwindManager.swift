import Foundation

/// Manages Tailwind CSS integration for Harbor projects that use Fleet-Tailwind.
/// Handles detection, class extraction from WASM binaries, config generation, and running the Tailwind CLI.
public struct TailwindManager {

    let projectDir: String

    public init(projectDir: String) {
        self.projectDir = projectDir
    }

    // MARK: - Detection

    /// Check if Fleet-Tailwind is listed as a dependency in the project's Package.swift
    public func isFleetTailwindPresent() -> Bool {
        let packagePath = projectDir + "/Package.swift"
        guard let contents = try? String(contentsOfFile: packagePath, encoding: .utf8) else {
            return false
        }
        return contents.contains("Fleet-Tailwind") || contents.contains("fleet-tailwind")
    }

    // MARK: - Tailwind binary

    /// Path to the tailwind binary in the project root
    public var tailwindBinaryPath: String {
        projectDir + "/tailwindcss"
    }

    public var hasTailwindBinary: Bool {
        fileExists(atPath: tailwindBinaryPath)
    }

    // MARK: - Class extraction

    /// Extract class name strings from the compiled WASM binary using `strings`
    /// and write them to `.tailwind-classes.txt` for Tailwind's content scanner.
    @discardableResult
    public func extractClasses(wasmDir: String) throws -> Bool {
        // Find the .wasm file in the build directory
        let fm = FileManager.default
        guard let files = try? fm.contentsOfDirectory(atPath: wasmDir) else {
            print("Warning: Could not read WASM build directory at \(wasmDir)")
            return false
        }

        let wasmFile = files.first { $0.hasSuffix(".wasm") }
        guard let wasmFile = wasmFile else {
            print("Warning: No .wasm file found in \(wasmDir)")
            return false
        }

        let wasmPath = wasmDir + "/" + wasmFile
        let outputPath = projectDir + "/.tailwind-classes.txt"

        print("Extracting class names from \(wasmFile)...")
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/strings")
        process.arguments = [wasmPath]

        let outFile = FileHandle(forWritingAtPath: outputPath)
            ?? { () -> FileHandle? in
                fm.createFile(atPath: outputPath, contents: nil)
                return FileHandle(forWritingAtPath: outputPath)
            }()

        guard let outFile = outFile else {
            print("Error: Could not create \(outputPath)")
            return false
        }

        process.standardOutput = outFile
        try process.run()
        process.waitUntilExit()
        try outFile.close()

        print("Wrote class names to .tailwind-classes.txt")
        return process.terminationStatus == 0
    }

    // MARK: - Config generation

    /// Generate a `tailwind.config.js` that scans `.tailwind-classes.txt` for class names.
    public func ensureTailwindConfig() {
        let configPath = projectDir + "/tailwind.config.js"
        if fileExists(atPath: configPath) {
            print("tailwind.config.js already exists, skipping generation.")
            return
        }

        let config = """
        /** @type {import('tailwindcss').Config} */
        module.exports = {
          content: ["./.tailwind-classes.txt"],
          theme: {
            extend: {},
          },
          plugins: [],
        }
        """

        do {
            try config.write(toFile: configPath, atomically: true, encoding: .utf8)
            print("Generated tailwind.config.js")
        } catch {
            print("Error writing tailwind.config.js: \(error)")
        }
    }

    /// Generate a minimal `input.css` if one doesn't already exist.
    public func ensureInputCSS() {
        let inputPath = projectDir + "/input.css"
        if fileExists(atPath: inputPath) {
            return
        }

        let css = """
        @tailwind base;
        @tailwind components;
        @tailwind utilities;
        """

        do {
            try css.write(toFile: inputPath, atomically: true, encoding: .utf8)
            print("Generated input.css")
        } catch {
            print("Error writing input.css: \(error)")
        }
    }

    // MARK: - Ensure serve directory

    func ensureServeDirectory() {
        let servePath = projectDir + "/serve"
        if !fileExists(atPath: servePath) {
            try? createDirectory(atPath: servePath)
        }
    }

    // MARK: - Run Tailwind (watch mode for dev)

    /// Start the Tailwind CLI in watch mode as a background process.
    /// Returns the Process so the caller can manage its lifecycle.
    public func startWatch() throws -> Process {
        guard hasTailwindBinary else {
            throw HarborError.buildFailed
        }

        ensureTailwindConfig()
        ensureInputCSS()
        ensureServeDirectory()

        let process = Process()
        process.executableURL = URL(fileURLWithPath: tailwindBinaryPath)
        process.arguments = [
            "-i", "input.css",
            "-o", "serve/tailwind.css",
            "--watch"
        ]
        process.currentDirectoryURL = URL(fileURLWithPath: projectDir)

        print("Starting Tailwind CSS in watch mode...")
        try process.run()
        return process
    }

    // MARK: - Run Tailwind (single build for production)

    /// Run a single Tailwind build (no watch). Outputs to the specified directory.
    @discardableResult
    public func build(outputDir: String, minify: Bool = true) async throws -> Bool {
        guard hasTailwindBinary else {
            print("Tailwind binary not found at \(tailwindBinaryPath)")
            print("Run 'harbor install tailwind' to set up Tailwind CSS.")
            return false
        }

        ensureTailwindConfig()
        ensureInputCSS()

        // Ensure output directory exists
        if !fileExists(atPath: outputDir) {
            try createDirectory(atPath: outputDir)
        }

        let outputPath = outputDir + "/tailwind.css"
        var args = ["-i", "input.css", "-o", outputPath]
        if minify {
            args.append("--minify")
        }

        print("Building Tailwind CSS to \(outputPath)...")
        return try await shellCommand(
            tailwindBinaryPath,
            arguments: args,
            workingDirectory: projectDir
        )
    }
}
