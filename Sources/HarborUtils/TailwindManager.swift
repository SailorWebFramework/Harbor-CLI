import Foundation

/// Manages Tailwind CSS integration for Harbor projects that use Fleet-Tailwind.
/// Handles detection, class extraction from Swift source, config generation, and running the Tailwind CLI.
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

    // MARK: - TW.swift discovery

    /// Locate TW.swift from Fleet-Tailwind by reading SPM workspace-state.json.
    /// Supports both local path packages (fileSystem) and remote checkouts.
    func findTWSwiftPath() throws -> String? {
        let workspaceStatePath = projectDir + "/.build/workspace-state.json"

        if let data = FileManager.default.contents(atPath: workspaceStatePath),
           let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let object = json["object"] as? [String: Any],
           let deps = object["dependencies"] as? [[String: Any]] {
            for dep in deps {
                guard let ref = dep["packageRef"] as? [String: Any] else { continue }
                let name = (ref["name"] as? String ?? "").lowercased()
                let identity = (ref["identity"] as? String ?? "").lowercased()
                guard name.contains("tailwind") || identity.contains("tailwind") else { continue }

                // Local fileSystem package: state.path is the absolute path
                if let state = dep["state"] as? [String: Any],
                   let localPath = state["path"] as? String {
                    let candidate = localPath + "/Sources/TW.swift"
                    if FileManager.default.fileExists(atPath: candidate) { return candidate }
                }

                // Remote package: lives in .build/checkouts/{subpath}/
                if let subpath = dep["subpath"] as? String {
                    let candidate = projectDir + "/.build/checkouts/" + subpath + "/Sources/TW.swift"
                    if FileManager.default.fileExists(atPath: candidate) { return candidate }
                }
            }
        }

        // Fallback: common relative locations for local development setups
        let fallbacks = [
            (projectDir as NSString).appendingPathComponent("../Fleet-Tailwind/Sources/TW.swift"),
            projectDir + "/.build/checkouts/fleet-tailwind/Sources/TW.swift",
        ]
        return fallbacks.first { FileManager.default.fileExists(atPath: $0) }
    }

    // MARK: - TW.swift parsing

    /// Parse TW.swift → Map of Swift identifier → CSS class string.
    ///
    /// TW.swift format (Shipwright-generated, multi-line):
    /// ```
    /// static var `identifier`: TW {
    ///     "css-class"
    /// }
    /// ```
    /// This format is a stable contract between Shipwright codegen and Harbor.
    func parseTWMap(twSwiftPath: String) throws -> [String: String] {
        let contents = try String(contentsOfFile: twSwiftPath, encoding: .utf8)
        var result: [String: String] = [:]

        // Matches multi-line: static var `ident`: TW {\n    "css-class"
        let pattern = #"static var `?(\w+)`?\s*:\s*TW\s*\{\s*\n\s*"([^"]+)""#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else {
            throw HarborError.buildFailed
        }
        let range = NSRange(contents.startIndex..., in: contents)
        for match in regex.matches(in: contents, range: range) {
            guard let identRange = Range(match.range(at: 1), in: contents),
                  let cssRange = Range(match.range(at: 2), in: contents) else { continue }
            result[String(contents[identRange])] = String(contents[cssRange])
        }
        return result
    }

    // MARK: - Swift file enumeration

    /// Recursively enumerate all .swift files under a directory.
    func walkSwiftFiles(_ dir: String) -> [String] {
        var results: [String] = []
        guard let enumerator = FileManager.default.enumerator(
            at: URL(fileURLWithPath: dir),
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        ) else { return [] }
        for case let url as URL in enumerator where url.pathExtension == "swift" {
            results.append(url.path)
        }
        return results
    }

    // MARK: - Source-based class extraction (recommended, prod)

    /// Extract used Tailwind class names by scanning Swift source files.
    ///
    /// Algorithm:
    /// 1. Parse TW.swift → Map<SwiftIdentifier, CSSClass>
    /// 2. Walk Sources/**/*.swift, find `TW.identifier` patterns
    /// 3. Resolve identifiers to CSS class strings via the map
    /// 4. Write sorted list to `.tailwind-classes.txt`
    ///
    /// This replaces the deprecated WASM-based `extractClasses(wasmDir:)`.
    /// Result: ~84 classes for sailor-shore vs 15,547 from the full dump (183× reduction).
    ///
    /// - Parameters:
    ///   - sourcesDir: Path to scan for .swift files. Defaults to `{projectDir}/Sources`.
    ///   - twSwiftPath: Explicit path to TW.swift. Defaults to auto-discovery via workspace-state.json.
    /// - Returns: `true` if at least one class was extracted and written.
    @discardableResult
    public func extractClassesFromSource(
        sourcesDir: String? = nil,
        twSwiftPath: String? = nil
    ) throws -> Bool {
        // 1. Locate TW.swift
        let twPath: String
        if let explicit = twSwiftPath {
            twPath = explicit
        } else if let found = try findTWSwiftPath() {
            twPath = found
        } else {
            print("Warning: Could not find TW.swift. Run 'swift package resolve' first.")
            return false
        }

        // 2. Parse TW.swift → identifier → CSS class map
        let twMap = try parseTWMap(twSwiftPath: twPath)
        guard !twMap.isEmpty else {
            print("Warning: Parsed TW.swift but found no entries. Check file format.")
            return false
        }

        // 3. Walk .swift source files for TW.identifier references
        let scanDir = sourcesDir ?? (projectDir + "/Sources")
        var usedIdentifiers = Set<String>()
        guard let scanRegex = try? NSRegularExpression(pattern: #"TW\.`?([a-zA-Z_]\w*)`?"#) else {
            throw HarborError.buildFailed
        }
        for filePath in walkSwiftFiles(scanDir) {
            // Throws on read failure (permissions / encoding) — caller handles it
            let contents = try String(contentsOfFile: filePath, encoding: .utf8)
            let range = NSRange(contents.startIndex..., in: contents)
            for match in scanRegex.matches(in: contents, range: range) {
                guard let identRange = Range(match.range(at: 1), in: contents) else { continue }
                usedIdentifiers.insert(String(contents[identRange]))
            }
        }

        // 4. Resolve identifiers → CSS class names (unresolved identifiers are silently skipped)
        let classes = usedIdentifiers.compactMap { twMap[$0] }.sorted()
        guard !classes.isEmpty else {
            print("Warning: No TW.* references found in \(scanDir).")
            return false
        }

        // 5. Write .tailwind-classes.txt
        let outputPath = projectDir + "/.tailwind-classes.txt"
        let output = classes.joined(separator: "\n") + "\n"
        try output.write(toFile: outputPath, atomically: true, encoding: .utf8)
        print("Extracted \(classes.count) Tailwind classes to .tailwind-classes.txt")
        return true
    }

    // MARK: - Full class list (dev mode)

    /// Generate a full Tailwind class list from TW.swift (every class, no tree-shaking).
    ///
    /// Used by `harbor run web` for dev mode — includes all classes so new
    /// TW.* usages appear in CSS immediately without restarting the CLI.
    ///
    /// - Parameter twSwiftPath: Explicit path to TW.swift. Defaults to auto-discovery.
    /// - Returns: `true` if classes were written.
    @discardableResult
    public func generateFullClassList(twSwiftPath: String? = nil) throws -> Bool {
        let twPath: String
        if let explicit = twSwiftPath {
            twPath = explicit
        } else if let found = try findTWSwiftPath() {
            twPath = found
        } else {
            print("Warning: Could not find TW.swift. Tailwind will use existing .tailwind-classes.txt if present.")
            return false
        }

        let twMap = try parseTWMap(twSwiftPath: twPath)
        guard !twMap.isEmpty else {
            print("Warning: Parsed TW.swift but found no entries.")
            return false
        }

        let classes = twMap.values.sorted()
        let outputPath = projectDir + "/.tailwind-classes.txt"
        let output = classes.joined(separator: "\n") + "\n"
        try output.write(toFile: outputPath, atomically: true, encoding: .utf8)
        print("Generated full Tailwind class list (\(classes.count) classes) to .tailwind-classes.txt")
        return true
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

    // MARK: - Deprecated: WASM string extraction

    /// Extract class name strings from the compiled WASM binary using `strings`.
    ///
    /// - Warning: **Deprecated.** This approach is architecturally broken for Fleet-Tailwind:
    ///   Swift compiles all 16,954 `public static var` string literals into the WASM data segment
    ///   regardless of which properties are actually called. Empirical testing shows 13,941 of
    ///   15,547 Tailwind classes appear in the release WASM — essentially no tree-shaking occurs.
    ///   Use `extractClassesFromSource()` instead for a true 183× reduction (15,547 → ~84 classes).
    @available(*, deprecated, message: "WASM string extraction is broken for Fleet-Tailwind architecture. Use extractClassesFromSource() instead.")
    @discardableResult
    public func extractClasses(wasmDir: String) throws -> Bool {
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
}
