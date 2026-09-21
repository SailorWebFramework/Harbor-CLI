import Foundation

/// Resolves which Swift SDK to pass to `swift build --swift-sdk` for WebAssembly builds.
///
/// SDK ids differ between releases (`wasm32-unknown-wasi` for the swiftwasm SDKs,
/// `swift-6.2.3-RELEASE_wasm` for the swift.org ones), so instead of hardcoding a
/// triple we ask `swift sdk list` and pick the first wasm entry.
public enum SwiftSDK {

    /// Used when `swift sdk list` cannot be run or lists no wasm SDK.
    public static let defaultWasmTriple = "wasm32-unknown-wasip1"

    /// Picks a wasm SDK id from `swift sdk list` output.
    /// Prefers a non-embedded entry; returns nil when no entry mentions wasm.
    public static func pickWasmSDK(from sdkList: String) -> String? {
        let ids = sdkList
            .split(whereSeparator: \.isNewline)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
        let wasm = ids.filter { $0.lowercased().contains("wasm") }
        return wasm.first { !$0.lowercased().contains("embedded") } ?? wasm.first
    }

    /// Runs `swift sdk list` and picks a wasm SDK, falling back to `defaultWasmTriple`.
    public static func resolveWasmSDK() -> String {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        process.arguments = ["swift", "sdk", "list"]
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = FileHandle.nullDevice

        do {
            try process.run()
        } catch {
            return defaultWasmTriple
        }
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()

        return pickWasmSDK(from: String(decoding: data, as: UTF8.self)) ?? defaultWasmTriple
    }
}
