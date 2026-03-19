import ArgumentParser
import HarborUtils
import Foundation
import ANSITerminal

var cwd: String = getCurrentWorkingDirectory()
var templateURL: String = "https://github.com/bitesomthing/harbor-template"

struct Init: AsyncParsableCommand {

    static let configuration = CommandConfiguration(
        abstract: "Initialize a new Harbor project"
    )

    @Argument(help: "Name of the project to create") var name = ""

    mutating func run() async throws {

        cursorOff()
        clearScreen()

        if name == "" {
            print("Please enter a name for your project: ")
            guard let name: String = Swift.readLine(strippingNewline: true) else {
                print("Error, invalid name")
                return
            }
            self.name = name
        } else {
            print("Initializing Harbor project: \(name)\n")
        }

        /* Check if valid destination */
        let destinationPath = cwd + "/" + name
        if isDirectory(atPath: destinationPath) && directoryEmpty(atPath: destinationPath) == false {
            print("Error: Destination directory '\(destinationPath)' already exists and is not empty.")
            return
        }

        /* Clone starter code */
        do {
            print("\nInitializing...\n")
            try await cloneRepositoryAsync(url: templateURL, destinationPath: destinationPath)
            try removeGitDirectory(atPath: destinationPath)
        } catch {
            print("Error: \(error)")
        }

        /* Replace template name with project name in Package.swift */
        let packagePath = destinationPath + "/Package.swift"
        do {
            let packageContents = try String(contentsOfFile: packagePath, encoding: .utf8)
            let newPackageContents = packageContents.replacingOccurrences(of: "HarborTemplate", with: name)
            try newPackageContents.write(toFile: packagePath, atomically: true, encoding: .utf8)
        } catch {
            print("Error: \(error)")
        }

        print("Done! Your Harbor project is ready at ./\(name)\n")
        let steps = [
            "cd \(name)",
            "harbor run web",
        ]
        print("Next steps:\n".bold)
        for (index, step) in steps.enumerated() {
            print("\(index + 1):".bold + " \(step)".asBlue)
        }

        print("\nTo stop the dev server, press " + "Ctrl + C\n".bold)
    }
}
