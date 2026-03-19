import ArgumentParser
import HarborUtils
import Foundation
import Darwin
import Dispatch

struct Run: ParsableCommand {

    static let configuration = CommandConfiguration(
        abstract: "Run a Harbor target in development mode",
        subcommands: [Web.self, IOS.self, Server.self]
    )
}

// MARK: - harbor run web

extension Run {
    struct Web: AsyncParsableCommand {
        static let configuration = CommandConfiguration(
            abstract: "Build WASM, run Tailwind, and start the Vite dev server"
        )

        @Option(name: .long, help: "Port for the dev server")
        var port: Int = 8080

        func run() async throws {
            let projectDir = getCurrentWorkingDirectory()
            let tailwind = TailwindManager(projectDir: projectDir)

            // Step 1: Build WASM target
            print("Building WASM target...")
            let buildOk = try await shellCommand(
                "/usr/bin/env",
                arguments: ["swift", "build", "--triple", "wasm32-unknown-wasi"],
                workingDirectory: projectDir
            )
            guard buildOk else {
                print("Error: WASM build failed.")
                return
            }
            print("WASM build complete.\n")

            // Step 2: Tailwind CSS integration (if Fleet-Tailwind is a dependency)
            var tailwindProcess: Process? = nil

            if tailwind.isFleetTailwindPresent() {
                let wasmDir = projectDir + "/.build/wasm32-unknown-wasi/debug"

                // Extract class names from the WASM binary
                try tailwind.extractClasses(wasmDir: wasmDir)

                if tailwind.hasTailwindBinary {
                    // Start Tailwind in watch mode
                    tailwindProcess = try tailwind.startWatch()
                    print("Tailwind CSS watching for changes.\n")
                } else {
                    print("Fleet-Tailwind detected but tailwindcss binary not found.")
                    print("Run 'harbor install tailwind' to set up the Tailwind CLI.\n")
                }
            } else {
                print("Fleet-Tailwind not detected, skipping Tailwind CSS.\n")
            }

            // Step 3: Start dev server
            print("Starting dev server on port \(port)...")
            print("(Press Ctrl+C to stop)\n")

            let serverProcess = Process()
            serverProcess.executableURL = URL(fileURLWithPath: "/usr/bin/env")

            // Try npx vite first, fall back to python http.server
            let viteConfigExists = fileExists(atPath: projectDir + "/vite.config.js") ||
                                   fileExists(atPath: projectDir + "/vite.config.ts")

            if viteConfigExists {
                serverProcess.arguments = ["npx", "vite", "--port", "\(port)"]
            } else {
                // Fallback: simple Python HTTP server serving from serve/
                serverProcess.arguments = ["python3", "-m", "http.server", "\(port)", "--directory", "serve"]
            }
            serverProcess.currentDirectoryURL = URL(fileURLWithPath: projectDir)

            // Handle SIGINT gracefully — stop Tailwind watch and dev server
            let signalSource = DispatchSource.makeSignalSource(signal: SIGINT, queue: .main)
            signalSource.setEventHandler {
                print("\nShutting down...")
                tailwindProcess?.interrupt()
                serverProcess.interrupt()
                signalSource.cancel()
            }
            signal(SIGINT, SIG_IGN)
            signalSource.resume()

            try serverProcess.run()
            serverProcess.waitUntilExit()

            // Clean up Tailwind watch if still running
            if let tp = tailwindProcess, tp.isRunning {
                tp.interrupt()
            }
        }
    }
}

// MARK: - harbor run ios

extension Run {
    struct IOS: AsyncParsableCommand {
        static let configuration = CommandConfiguration(
            commandName: "ios",
            abstract: "Build and run the native iOS target in the simulator"
        )

        @Option(name: .long, help: "Simulator device name")
        var device: String = "iPhone 16"

        func run() async throws {
            print("harbor run ios")
            print("Building iOS target for simulator (\(device))...")
            print("[Not yet implemented] This will:")
            print("  1. Build the Native target for iOS simulator")
            print("  2. Boot the simulator if needed")
            print("  3. Install and launch the app")
            print("")
            print("For now, open the project in Xcode:")
            print("  open Package.swift")
        }
    }
}

// MARK: - harbor run server

extension Run {
    struct Server: AsyncParsableCommand {
        static let configuration = CommandConfiguration(
            abstract: "Build and run the Vapor server target"
        )

        @Option(name: .long, help: "Port for the server")
        var port: Int = 8081

        func run() async throws {
            print("harbor run server")
            print("Building and starting Vapor server on port \(port)...")
            print("[Not yet implemented] This will:")
            print("  1. Build the Server target")
            print("  2. Run the Vapor server executable")
            print("  3. Watch for changes and rebuild")
            print("")
            print("For now, run manually:")
            print("  swift run Server serve --port \(port)")
        }
    }
}
