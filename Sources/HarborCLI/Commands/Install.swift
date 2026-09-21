import ArgumentParser
import HarborUtils
import Foundation

struct Install: AsyncParsableCommand {

    static let configuration = CommandConfiguration(
        abstract: "Install a Harbor package dependency"
    )

    @Argument(help: "Name of the package to install (e.g. 'sailor-ui', 'vapor')")
    var name: String

    @Option(name: .long, help: "Git URL to use instead of looking up from the fleet registry")
    var url: String?

    @Option(name: .long, help: "Version requirement (e.g. '1.0.0', 'main')")
    var version: String?

    func run() async throws {
        let projectDir = getCurrentWorkingDirectory()
        let packageSwiftPath = projectDir + "/Package.swift"

        guard fileExists(atPath: packageSwiftPath) else {
            print("Error: No Package.swift found in current directory.")
            print("Run this command from the root of a Harbor project.")
            return
        }

        // Step 1: Resolve package info from fleet registry or direct URL
        let resolvedURL: String
        let resolvedVersion: String

        if let directURL = url {
            resolvedURL = directURL
            resolvedVersion = version ?? "main"
            print("Installing \(name) from \(resolvedURL) (\(resolvedVersion))...")
        } else {
            // Try to look up from local fleet.json
            let fleetPath = projectDir + "/.harbor/fleet.json"
            if fileExists(atPath: fleetPath) {
                if let entry = try lookupFleetEntry(name: name, fleetPath: fleetPath) {
                    resolvedURL = entry.url
                    resolvedVersion = version ?? entry.version
                    print("Found \(name) in fleet registry: \(resolvedURL) (\(resolvedVersion))")
                } else {
                    print("Error: Package '\(name)' not found in fleet registry.")
                    print("Provide a URL directly: harbor install \(name) --url <git-url>")
                    return
                }
            } else {
                print("Error: No fleet registry found at \(fleetPath) and no --url provided.")
                print("Provide a URL directly: harbor install \(name) --url <git-url>")
                return
            }
        }

        // Step 2: Read Package.swift
        let packageContents: String
        do {
            packageContents = try String(contentsOfFile: packageSwiftPath, encoding: .utf8)
        } catch {
            print("Error reading Package.swift: \(error)")
            return
        }

        // Step 3: Add SPM dependency line
        let dependencyLine: String
        if resolvedVersion.contains(".") {
            // Looks like a semantic version
            dependencyLine = "        .package(url: \"\(resolvedURL)\", from: \"\(resolvedVersion)\"),"
        } else {
            // Treat as a branch name
            dependencyLine = "        .package(url: \"\(resolvedURL)\", branch: \"\(resolvedVersion)\"),"
        }

        // Find the dependencies array and insert
        guard let depsRange = packageContents.range(of: "dependencies: [") else {
            print("Error: Could not find 'dependencies: [' in Package.swift")
            print("Please add the dependency manually.")
            return
        }

        let insertionPoint = packageContents.index(depsRange.upperBound, offsetBy: 0)
        var updatedContents = packageContents
        updatedContents.insert(contentsOf: "\n\(dependencyLine)", at: insertionPoint)

        // Step 4: Write updated Package.swift
        do {
            try updatedContents.write(toFile: packageSwiftPath, atomically: true, encoding: .utf8)
            print("Added \(name) to Package.swift dependencies.")
            print("")
            print("Next: add \"\(name)\" to your target's dependencies array in Package.swift,")
            print("then run 'swift package resolve' to fetch the package.")
        } catch {
            print("Error writing Package.swift: \(error)")
        }
    }
}

// MARK: - Fleet registry lookup

struct FleetEntry: Codable {
    let url: String
    let version: String
    let description: String?
}

func lookupFleetEntry(name: String, fleetPath: String) throws -> FleetEntry? {
    let data = try Data(contentsOf: URL(fileURLWithPath: fleetPath))
    let fleet = try JSONDecoder().decode([String: FleetEntry].self, from: data)
    return fleet[name]
}
