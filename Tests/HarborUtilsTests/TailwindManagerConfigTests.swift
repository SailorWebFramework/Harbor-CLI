import Testing
import Foundation
@testable import HarborUtils

private func makeTempDir() throws -> String {
    let dir = FileManager.default.temporaryDirectory
        .appendingPathComponent("HarborTailwindConfigTests-" + UUID().uuidString).path
    try FileManager.default.createDirectory(atPath: dir, withIntermediateDirectories: true)
    return dir
}

private func write(_ contents: String, to path: String) throws {
    try FileManager.default.createDirectory(
        atPath: (path as NSString).deletingLastPathComponent,
        withIntermediateDirectories: true
    )
    try contents.write(toFile: path, atomically: true, encoding: .utf8)
}

@Suite("TailwindManager — detection")
struct TailwindDetectionTests {

    @Test("isFleetTailwindPresent is false without a Package.swift")
    func noPackage() throws {
        let dir = try makeTempDir()
        defer { try? FileManager.default.removeItem(atPath: dir) }
        #expect(!TailwindManager(projectDir: dir).isFleetTailwindPresent())
    }

    @Test("isFleetTailwindPresent detects either spelling of the dependency")
    func detectsDependency() throws {
        let dir = try makeTempDir()
        defer { try? FileManager.default.removeItem(atPath: dir) }

        try write(#".package(path: "../Fleet-Tailwind")"#, to: dir + "/Package.swift")
        #expect(TailwindManager(projectDir: dir).isFleetTailwindPresent())

        try write(#".package(url: "https://x/fleet-tailwind", from: "1.0.0")"#, to: dir + "/Package.swift")
        #expect(TailwindManager(projectDir: dir).isFleetTailwindPresent())

        try write(#".package(path: "../Sailor")"#, to: dir + "/Package.swift")
        #expect(!TailwindManager(projectDir: dir).isFleetTailwindPresent())
    }

    @Test("hasTailwindBinary checks for ./tailwindcss in the project root")
    func binaryDetection() throws {
        let dir = try makeTempDir()
        defer { try? FileManager.default.removeItem(atPath: dir) }

        let mgr = TailwindManager(projectDir: dir)
        #expect(!mgr.hasTailwindBinary)
        #expect(mgr.tailwindBinaryPath == dir + "/tailwindcss")
        try write("", to: mgr.tailwindBinaryPath)
        #expect(mgr.hasTailwindBinary)
    }
}

@Suite("TailwindManager — config generation")
struct TailwindConfigTests {

    @Test("ensureTailwindConfig writes a config that scans .tailwind-classes.txt")
    func writesConfig() throws {
        let dir = try makeTempDir()
        defer { try? FileManager.default.removeItem(atPath: dir) }

        TailwindManager(projectDir: dir).ensureTailwindConfig()
        let config = try String(contentsOfFile: dir + "/tailwind.config.js", encoding: .utf8)
        #expect(config.contains(".tailwind-classes.txt"))
        #expect(config.contains("module.exports"))
    }

    @Test("ensureTailwindConfig does not overwrite an existing config")
    func keepsExistingConfig() throws {
        let dir = try makeTempDir()
        defer { try? FileManager.default.removeItem(atPath: dir) }

        try write("// custom", to: dir + "/tailwind.config.js")
        TailwindManager(projectDir: dir).ensureTailwindConfig()
        #expect(try String(contentsOfFile: dir + "/tailwind.config.js", encoding: .utf8) == "// custom")
    }

    @Test("ensureInputCSS writes the three @tailwind directives")
    func writesInputCSS() throws {
        let dir = try makeTempDir()
        defer { try? FileManager.default.removeItem(atPath: dir) }

        TailwindManager(projectDir: dir).ensureInputCSS()
        let css = try String(contentsOfFile: dir + "/input.css", encoding: .utf8)
        #expect(css.contains("@tailwind base;"))
        #expect(css.contains("@tailwind components;"))
        #expect(css.contains("@tailwind utilities;"))
    }

    @Test("ensureInputCSS does not overwrite an existing input.css")
    func keepsExistingInputCSS() throws {
        let dir = try makeTempDir()
        defer { try? FileManager.default.removeItem(atPath: dir) }

        try write("/* mine */", to: dir + "/input.css")
        TailwindManager(projectDir: dir).ensureInputCSS()
        #expect(try String(contentsOfFile: dir + "/input.css", encoding: .utf8) == "/* mine */")
    }
}

@Suite("TailwindManager — source discovery")
struct TailwindDiscoveryTests {

    @Test("walkSwiftFiles recurses and returns only .swift files, skipping hidden dirs")
    func walksSwiftFiles() throws {
        let dir = try makeTempDir()
        defer { try? FileManager.default.removeItem(atPath: dir) }

        try write("", to: dir + "/A.swift")
        try write("", to: dir + "/Nested/Deep/B.swift")
        try write("", to: dir + "/README.md")
        try write("", to: dir + "/.build/Hidden.swift")

        let names = TailwindManager(projectDir: dir).walkSwiftFiles(dir)
            .map { ($0 as NSString).lastPathComponent }
            .sorted()
        #expect(names == ["A.swift", "B.swift"])
    }

    @Test("walkSwiftFiles returns an empty list for a missing directory")
    func walkMissing() throws {
        let dir = try makeTempDir()
        defer { try? FileManager.default.removeItem(atPath: dir) }
        #expect(TailwindManager(projectDir: dir).walkSwiftFiles(dir + "/nope").isEmpty)
    }

    @Test("parseTWMap accepts identifiers without backticks")
    func parseWithoutBackticks() throws {
        let dir = try makeTempDir()
        defer { try? FileManager.default.removeItem(atPath: dir) }

        let tw = """
        public extension TW {
            static var flex: TW {
                "flex"
            }
        }
        """
        try write(tw, to: dir + "/TW.swift")
        let map = try TailwindManager(projectDir: dir).parseTWMap(twSwiftPath: dir + "/TW.swift")
        #expect(map == ["flex": "flex"])
    }

    @Test("findTWSwiftPath resolves a local path dependency from workspace-state.json")
    func findsLocalDependency() throws {
        let dir = try makeTempDir()
        defer { try? FileManager.default.removeItem(atPath: dir) }

        let fleet = dir + "/Fleet"
        try write("// tw", to: fleet + "/Sources/TW.swift")
        let state = """
        {"object": {"dependencies": [
          {"packageRef": {"identity": "fleet-tailwind", "name": "Fleet-Tailwind"},
           "state": {"path": "\(fleet)"}}
        ]}}
        """
        try write(state, to: dir + "/.build/workspace-state.json")

        #expect(try TailwindManager(projectDir: dir).findTWSwiftPath() == fleet + "/Sources/TW.swift")
    }

    @Test("findTWSwiftPath resolves a remote checkout via its subpath")
    func findsRemoteCheckout() throws {
        let dir = try makeTempDir()
        defer { try? FileManager.default.removeItem(atPath: dir) }

        try write("// tw", to: dir + "/.build/checkouts/Fleet-Tailwind/Sources/TW.swift")
        let state = """
        {"object": {"dependencies": [
          {"packageRef": {"identity": "fleet-tailwind", "name": "Fleet-Tailwind"},
           "subpath": "Fleet-Tailwind", "state": {"checkoutState": {}}}
        ]}}
        """
        try write(state, to: dir + "/.build/workspace-state.json")

        #expect(try TailwindManager(projectDir: dir).findTWSwiftPath()
                == dir + "/.build/checkouts/Fleet-Tailwind/Sources/TW.swift")
    }

    @Test("findTWSwiftPath ignores non-tailwind dependencies")
    func ignoresOtherDependencies() throws {
        let dir = try makeTempDir()
        defer { try? FileManager.default.removeItem(atPath: dir) }

        let other = dir + "/Other"
        try write("// not tw", to: other + "/Sources/TW.swift")
        let state = """
        {"object": {"dependencies": [
          {"packageRef": {"identity": "sailor", "name": "Sailor"}, "state": {"path": "\(other)"}}
        ]}}
        """
        try write(state, to: dir + "/.build/workspace-state.json")

        #expect(try TailwindManager(projectDir: dir).findTWSwiftPath() == nil)
    }

    @Test("findTWSwiftPath falls back to a sibling Fleet-Tailwind checkout")
    func fallsBackToSibling() throws {
        let dir = try makeTempDir()
        defer { try? FileManager.default.removeItem(atPath: dir) }

        let project = dir + "/project"
        try createDirectory(atPath: project)
        try write("// tw", to: dir + "/Fleet-Tailwind/Sources/TW.swift")

        let found = try TailwindManager(projectDir: project).findTWSwiftPath()
        #expect(found.map { ($0 as NSString).standardizingPath } == dir + "/Fleet-Tailwind/Sources/TW.swift")
    }

    @Test("findTWSwiftPath returns nil when nothing can be located")
    func nothingFound() throws {
        let dir = try makeTempDir()
        defer { try? FileManager.default.removeItem(atPath: dir) }
        #expect(try TailwindManager(projectDir: dir).findTWSwiftPath() == nil)
    }

    @Test("extractClassesFromSource returns false when TW.swift cannot be found")
    func extractWithoutTW() throws {
        let dir = try makeTempDir()
        defer { try? FileManager.default.removeItem(atPath: dir) }
        try write("let a = TW.flex", to: dir + "/Sources/A.swift")
        #expect(try TailwindManager(projectDir: dir).extractClassesFromSource() == false)
        #expect(!fileExists(atPath: dir + "/.tailwind-classes.txt"))
    }

    @Test("generateFullClassList returns false for a TW.swift with no entries")
    func fullListEmptyTW() throws {
        let dir = try makeTempDir()
        defer { try? FileManager.default.removeItem(atPath: dir) }
        try write("// nothing here", to: dir + "/TW.swift")
        #expect(try TailwindManager(projectDir: dir).generateFullClassList(twSwiftPath: dir + "/TW.swift") == false)
    }
}
