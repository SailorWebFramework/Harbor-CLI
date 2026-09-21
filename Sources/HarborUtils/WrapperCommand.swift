import Foundation
import ArgumentParser
import Dispatch

public protocol WrapperCommand: AsyncParsableCommand {
  var command: String { get }
  var args: [String] { get }
  var help: Bool { get }
  mutating func run() async throws
}

extension WrapperCommand {
  public mutating func run() async throws {
    let process = Process()
    process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
    //TODO: passing args is conditional on whether or not the --help flag is included... is this right?
    process.arguments = ["swift", "run", "carton", command] + (help ? ["--help"] : args)
    print("I am a Running \(process.executableURL!.path) with \(process.arguments!.joined(separator: " "))")
    /// TODO: or...
    // process.executableURL = URL(fileURLWithPath: "/usr/bin/swift")
    // process.arguments = ["run", "carton", command] + args + (help ? ["--help"] : [])
    let signalSource = DispatchSource.makeSignalSource(signal: SIGINT, queue: .main)
    signalSource.setEventHandler {
        print("Cleaning up...")
        process.interrupt()
        signalSource.cancel()
    }
    signal(SIGINT, SIG_IGN)
    signalSource.resume()

    try process.run()
    process.waitUntilExit()
  }
}