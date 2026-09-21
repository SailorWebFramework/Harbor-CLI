import ArgumentParser
import HarborUtils
import Foundation

struct Uninstall: AsyncParsableCommand {

    static let configuration = CommandConfiguration(
        abstract: "Remove a package dependency from the project"
    )

    @Argument(help: "Name of the package to remove")
    var name: String

    func run() async throws {
        let projectDir = getCurrentWorkingDirectory()
        let packageSwiftPath = projectDir + "/Package.swift"

        guard fileExists(atPath: packageSwiftPath) else {
            print("Error: No Package.swift found in current directory.")
            print("Run this command from the root of a Harbor project.")
            return
        }

        // Read Package.swift
        let packageContents: String
        do {
            packageContents = try String(contentsOfFile: packageSwiftPath, encoding: .utf8)
        } catch {
            print("Error reading Package.swift: \(error)")
            return
        }

        // Find and remove the dependency line containing the package name
        let lines = packageContents.components(separatedBy: "\n")
        var removedCount = 0
        let filteredLines = lines.filter { line in
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.contains(".package(") && trimmed.lowercased().contains(name.lowercased()) {
                removedCount += 1
                return false
            }
            return true
        }

        if removedCount == 0 {
            print("Could not find a dependency matching '\(name)' in Package.swift.")
            print("You may need to remove it manually.")
            return
        }

        let updatedContents = filteredLines.joined(separator: "\n")

        do {
            try updatedContents.write(toFile: packageSwiftPath, atomically: true, encoding: .utf8)
            print("Removed \(name) from Package.swift dependencies.")
            print("")
            print("Note: Also remove '\(name)' from any target dependency arrays,")
            print("then run 'swift package resolve' to update.")
        } catch {
            print("Error writing Package.swift: \(error)")
        }
    }
}
