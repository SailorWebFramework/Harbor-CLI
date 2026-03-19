import ArgumentParser
import HarborUtils

public struct Harbor: ParsableCommand {

    public static let configuration: CommandConfiguration = CommandConfiguration(
        commandName: "harbor",
        abstract: "CLI tool for Harbor - a full-stack Swift framework for iOS, web, and server apps",
        version: harborVersion,
        subcommands: [Init.self, Run.self, Build.self, Install.self, Uninstall.self]
    )

    public init() {}
}
