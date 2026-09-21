import Testing
import ArgumentParser
@testable import HarborCLI
@testable import HarborUtils

@Suite("Harbor command parsing")
struct CommandParsingTests {

    @Test("root command reports the package version")
    func version() {
        #expect(Harbor.configuration.version == harborVersion)
        #expect(Harbor.configuration.commandName == "harbor")
    }

    @Test("build web parses --output and defaults to dist")
    func buildWeb() throws {
        let explicit = try Harbor.parseAsRoot(["build", "web", "--output", "out"]) as? Build.Web
        #expect(explicit?.output == "out")

        let defaulted = try Harbor.parseAsRoot(["build", "web"]) as? Build.Web
        #expect(defaulted?.output == "dist")
    }

    @Test("run web parses --port and defaults to 8080")
    func runWeb() throws {
        let explicit = try Harbor.parseAsRoot(["run", "web", "--port", "3000"]) as? Run.Web
        #expect(explicit?.port == 3000)

        let defaulted = try Harbor.parseAsRoot(["run", "web"]) as? Run.Web
        #expect(defaulted?.port == 8080)
    }

    @Test("run ios parses --device")
    func runIOS() throws {
        let cmd = try Harbor.parseAsRoot(["run", "ios", "--device", "iPhone 17"]) as? Run.IOS
        #expect(cmd?.device == "iPhone 17")
    }

    @Test("run server parses --port and defaults to 8081")
    func runServer() throws {
        let cmd = try Harbor.parseAsRoot(["run", "server"]) as? Run.Server
        #expect(cmd?.port == 8081)
    }

    @Test("unknown subcommands and bad option values are rejected")
    func rejectsInvalid() {
        #expect(throws: (any Error).self) { try Harbor.parseAsRoot(["bogus"]) }
        #expect(throws: (any Error).self) { try Harbor.parseAsRoot(["run", "web", "--port", "abc"]) }
    }
}
