import Foundation
import FileWatcher

public func getCurrentWorkingDirectory() -> String {
    return FileManager.default.currentDirectoryPath
}

public func directoryEmpty(atPath path: String) -> Bool {
    do {
        let contents = try FileManager.default.contentsOfDirectory(atPath: path)
        return contents.isEmpty
    } catch {
        return false
    }
}

public func isAbsolutePath(_ path: String) -> Bool {
    return path.hasPrefix("/")
}

public func removeFile(atPath path: String) throws {
    try FileManager.default.removeItem(atPath: path)
}

public func removeFolder(atPath path: String) throws {
    try FileManager.default.removeItem(atPath: path)
}

public func fileExists(atPath path: String) -> Bool {
    return FileManager.default.fileExists(atPath: path)
}

public func isDirectory(atPath path: String) -> Bool {
    var isDir: ObjCBool = false
    FileManager.default.fileExists(atPath: path, isDirectory: &isDir)
    return isDir.boolValue
}

public func createDirectory(atPath path: String) throws {
    try FileManager.default.createDirectory(atPath: path, withIntermediateDirectories: true, attributes: nil)
}

public class ResourceWatcher {
    let watcher: FileWatcher
    let basePath: String
    let cwd: String = getCurrentWorkingDirectory()

    public init(file: String, title: String) throws {
        guard isDirectory(atPath: String(self.cwd + "/\(file)")) else { throw HarborError.invalidDirectory }
        self.basePath = self.cwd + "/\(file)"

        print("Setting up watcher for \(self.basePath)")

        self.watcher = FileWatcher([self.cwd + "/\(file)"])
        self.watcher.queue = DispatchQueue(label: "\(title)")
    }

    public func start() {
        watcher.start()
    }
    public func stop() {
        watcher.stop()
    }
}

/// Run a shell command and return whether it succeeded (exit code 0)
@discardableResult
public func shellCommand(_ executable: String, arguments: [String], workingDirectory: String? = nil) async throws -> Bool {
    let process = Process()
    process.executableURL = URL(fileURLWithPath: executable)
    process.arguments = arguments
    if let wd = workingDirectory {
        process.currentDirectoryURL = URL(fileURLWithPath: wd)
    }
    try process.run()
    process.waitUntilExit()
    return process.terminationStatus == 0
}
