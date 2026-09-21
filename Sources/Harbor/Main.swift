import HarborCLI
import HarborUtils
import Foundation
import ArgumentParser

@main
struct Main {
  typealias Command = Harbor

  public static func main() async {
    do {
      var command: any ParsableCommand = try Command.parseAsRoot()
      if var command = command as? AsyncParsableCommand {
        try await command.run()
      } else {
        try command.run()
      }
    } catch {
      Command.exit(withError: error)
    }
  }
}
