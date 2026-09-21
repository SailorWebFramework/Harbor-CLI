import Testing
@testable import HarborUtils

@Suite("SwiftSDK — wasm SDK selection")
struct SwiftSDKTests {

    @Test("prefers the non-embedded wasm SDK from swift sdk list output")
    func prefersNonEmbedded() {
        let list = """
        swift-6.2.3-RELEASE_wasm
        swift-6.2.3-RELEASE_wasm-embedded
        """
        #expect(SwiftSDK.pickWasmSDK(from: list) == "swift-6.2.3-RELEASE_wasm")
    }

    @Test("falls back to an embedded SDK when it is the only wasm entry")
    func embeddedOnly() {
        #expect(SwiftSDK.pickWasmSDK(from: "swift-6.2.3-RELEASE_wasm-embedded\n") == "swift-6.2.3-RELEASE_wasm-embedded")
    }

    @Test("accepts the older swiftwasm triple-style id")
    func swiftwasmTriple() {
        #expect(SwiftSDK.pickWasmSDK(from: "wasm32-unknown-wasi\n") == "wasm32-unknown-wasi")
    }

    @Test("ignores non-wasm SDKs and tolerates whitespace")
    func ignoresOthers() {
        let list = "  static-linux-sdk \n\n  swift-6.2.3-RELEASE_wasm  \n"
        #expect(SwiftSDK.pickWasmSDK(from: list) == "swift-6.2.3-RELEASE_wasm")
    }

    @Test("returns nil when no wasm SDK is listed")
    func none() {
        #expect(SwiftSDK.pickWasmSDK(from: "static-linux-sdk\n") == nil)
        #expect(SwiftSDK.pickWasmSDK(from: "") == nil)
    }

    @Test("resolveWasmSDK always yields a usable identifier")
    func resolveNeverEmpty() {
        #expect(!SwiftSDK.resolveWasmSDK().isEmpty)
    }
}
