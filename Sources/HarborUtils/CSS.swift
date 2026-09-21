import Foundation

//TODO: improve consistency of absolute/relative paths

public class CSSWatcher: ResourceWatcher {

    let swiftPackagePath: String = getCurrentWorkingDirectory() + "/Package.swift"

    let resourceLower: String = "//Harbor Generated Resources (DONT REMOVE THIS COMMENT)"
    let resourceUpper: String = "//Harbor End (DONT REMOVE THIS COMMENT)"
    let filePrefix: String = "Sources/"

    override public init(file: String = "Resources/", title: String = "harbor.csswatcher") throws {
        try super.init(file: filePrefix + file, title: title)

        self.regenerate(path: filePrefix + file, file: file)

        self.watcher.callback = { [weak self] event in
            guard let self = self else { return }

            if event.fileModified { return }
            let path = event.path.replacingOccurrences(of: self.basePath, with: file)

            print("Event fileCreated: \(event.fileCreated)")
            print("Event fileRenamed: \(event.fileRenamed)")

            print("Event dirCreated: \(event.dirCreated)")
            print("Event dirRenamed: \(event.dirRenamed)")

            print(event.path)

            if event.fileRenamed {
                if !FileManager().fileExists(atPath: event.path) {
                    self.removeResource(path: path)
                } else {
                    self.addResource(path: path)
                }
            } else if event.fileCreated {
                self.addResource(path: path)
            } else if event.dirRenamed {
                if !FileManager().fileExists(atPath: event.path) {
                    print("removing")
                    self.removeResources(path: path)
                } else {
                    print("adding")
                    self.addResources(path: path)
                }
            } else if event.dirCreated {
                self.addResources(path: event.path)
            }

            if (event.fileRenamed || event.dirRenamed ) { self.removeTrailingComma() }
        }
    }

    func leadingWhitespace(content: String, range: Range<String.Index>) -> String {
        guard let start = content[..<range.lowerBound].lastIndex(of: "\n") else {
            return ""
        }

        let leadingWhitespaceRange = content.index(after: start)..<range.lowerBound
        let leadingWhitespace = content[leadingWhitespaceRange]
            .prefix(while: { $0.isWhitespace })
        return String(leadingWhitespace)
    }

    func readPackageFile() throws -> String {
        do {
            let packageContent = try String(contentsOfFile: swiftPackagePath, encoding: .utf8)
            return packageContent
        } catch {
            print("Error reading Package.swift file: \(error)")
            print("Your styles might not be properly updated.")
            throw error
        }
    }

    func writePackageFile(content: String) -> Bool {
        do {
            try content.write(toFile: self.swiftPackagePath, atomically: true, encoding: .utf8)
            return true
        } catch {
            print("Error writing to Package.swift file: \(error)")
            return false
        }
    }

    func removeTrailingComma() {
        guard let packageContent: String = try? self.readPackageFile() else { return }

        guard let start: String.Index = packageContent.range(of: resourceLower)?.upperBound else { return }
        guard let end: String.Index = packageContent.range(of: resourceUpper)?.lowerBound else { return }
        let range = start..<end
        let content = packageContent[range]

        let lines = content.split(separator: ",\n")
        if lines.count == 0 { return }
        let lastLine = content[lines[lines.count - 2].startIndex...]
        print("LAST LINE:", lastLine)
        if lastLine.hasSuffix(",\n") {
           print("Removing trailing comma")
           let newContent = packageContent.replacingOccurrences(of: """
              \(lastLine)
              """, with: """
                \(lastLine.dropLast(2))\n
                """)
              let _ = writePackageFile(content: newContent)
        }
    }

    func addResource(path: String) {
        print("Adding resource: \(path)")
        guard let packageContent: String = try? self.readPackageFile() else { return }
        guard let range = packageContent.range(of: resourceLower) else { return }

        let whitespace = leadingWhitespace(content: packageContent, range: range)

        if packageContent.contains("\(whitespace).process(\"\(path)\"),") { return }
        if packageContent.contains("\(whitespace).process(\"\(path)\")") { return }

        let newContent = packageContent.replacingOccurrences(of: resourceLower, with: """
        \(resourceLower)
        \(whitespace).process("\(path)"),
        """)

        let _ = writePackageFile(content: newContent)
    }

    func removeResource(path: String) {
        print("Removing resource: \(path)")
        guard let packageContent: String = try? self.readPackageFile() else { return }
        guard let range = packageContent.range(of: resourceLower) else { return }

        let whitespace = leadingWhitespace(content: packageContent, range: range)

        var newContent = packageContent.replacingOccurrences(of: """
        \(whitespace).process("\(path)")\n
        """, with: "")
        let _ = writePackageFile(content: newContent)

        newContent = newContent.replacingOccurrences(of: """
        \(whitespace).process("\(path)"),\n
        """, with: "")
        let _ = writePackageFile(content: newContent)
    }

    func addResources(path: String) {
        print("Adding resources: \(path)")
        let filePath = getCurrentWorkingDirectory() + "/" + path
        let files = try? FileManager().contentsOfDirectory(atPath: filePath)
        files?.forEach { file in
            if isDirectory(atPath: path + "/\(String(file))") {
                self.addResources(path: path + "/" + file)
            } else {
                self.addResource(path: path + "/" + file)
            }
        }
    }

    func removeResources(path: String) {
        print("Removing resources: \(path)")
        guard let packageContent: String = try? self.readPackageFile() else { return }

        guard let start: String.Index = packageContent.range(of: resourceLower)?.upperBound else { return }
        guard let end: String.Index = packageContent.range(of: resourceUpper)?.lowerBound else { return }

        let range = start..<end
        let lines = packageContent[range].split(separator: "\n")

        var linesToRemove: [String] = []

        let pattern = #""(.*)""#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) else { return }

        for line in lines {
            print("Line: \(line)")
            if !line.contains(path) { continue }

            print("THIS LINE HAS THING: \(line)")
            let nsrange = NSRange(line.startIndex..<line.endIndex, in: line)
            let matches = regex.matches(in: String(line), options: [], range: nsrange)
            for match in matches {
                let range = match.range(at: 1)
                if let swiftRange = Range(range, in: line) {
                    linesToRemove.append(String(line[swiftRange]))
                }
            }
        }
        for line in linesToRemove {
            self.removeResource(path: line)
        }
        return
    }

    func regenerate(path: String, file: String) {
        self.removeResources(path: path.replacingOccurrences(of: path, with: file))
        self.addResources(path: String(path.dropLast(1).replacingOccurrences(of: filePrefix, with: "")))
        self.removeTrailingComma()
    }
}
