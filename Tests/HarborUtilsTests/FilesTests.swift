import Testing
import Foundation
@testable import HarborUtils

private func makeTempDir() throws -> String {
    let dir = FileManager.default.temporaryDirectory
        .appendingPathComponent("HarborFilesTests-" + UUID().uuidString).path
    try FileManager.default.createDirectory(atPath: dir, withIntermediateDirectories: true)
    return dir
}

@Suite("Files helpers")
struct FilesTests {

    @Test("isAbsolutePath is true only for leading-slash paths")
    func absolutePath() {
        #expect(isAbsolutePath("/usr/local"))
        #expect(!isAbsolutePath("relative/path"))
        #expect(!isAbsolutePath(""))
    }

    @Test("directoryEmpty reflects directory contents and is false for missing paths")
    func directoryEmptyStates() throws {
        let dir = try makeTempDir()
        defer { try? FileManager.default.removeItem(atPath: dir) }

        #expect(directoryEmpty(atPath: dir))
        try "x".write(toFile: dir + "/file.txt", atomically: true, encoding: .utf8)
        #expect(!directoryEmpty(atPath: dir))
        #expect(!directoryEmpty(atPath: dir + "/does-not-exist"))
    }

    @Test("isDirectory distinguishes directories, files and missing paths")
    func isDirectoryStates() throws {
        let dir = try makeTempDir()
        defer { try? FileManager.default.removeItem(atPath: dir) }

        try "x".write(toFile: dir + "/file.txt", atomically: true, encoding: .utf8)
        #expect(isDirectory(atPath: dir))
        #expect(!isDirectory(atPath: dir + "/file.txt"))
        #expect(!isDirectory(atPath: dir + "/missing"))
    }

    @Test("createDirectory creates intermediate directories")
    func createsIntermediate() throws {
        let dir = try makeTempDir()
        defer { try? FileManager.default.removeItem(atPath: dir) }

        let nested = dir + "/a/b/c"
        try createDirectory(atPath: nested)
        #expect(isDirectory(atPath: nested))
        #expect(fileExists(atPath: nested))
    }

    @Test("removeFile and removeFolder delete their targets")
    func removes() throws {
        let dir = try makeTempDir()
        defer { try? FileManager.default.removeItem(atPath: dir) }

        let file = dir + "/f.txt"
        try "x".write(toFile: file, atomically: true, encoding: .utf8)
        try removeFile(atPath: file)
        #expect(!fileExists(atPath: file))

        let folder = dir + "/folder"
        try createDirectory(atPath: folder)
        try removeFolder(atPath: folder)
        #expect(!fileExists(atPath: folder))
    }

    @Test("shellCommand reports success and failure by exit status")
    func shell() async throws {
        #expect(try await shellCommand("/usr/bin/true", arguments: []))
        #expect(try await !shellCommand("/usr/bin/false", arguments: []))
    }
}
