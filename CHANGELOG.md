# Version 0.1.0

Renamed Compass to Harbor. Added `harbor run web`, `harbor build web` and `harbor install`.
Tailwind tree-shaking for production builds via source scanning (`extractClassesFromSource`);
dev mode keeps the full class list so new classes appear without a restart. Fixed the WASM
triple (`wasm32-unknown-wasip1`) and the missing PackageToJS artifact copy in `build web`.
The wasm Swift SDK is resolved from `swift sdk list` rather than hardcoded. Dependencies pinned. Test suite (36 tests) and GitHub Actions CI added.

# Version 0.0.4

Setup init command to scaffold new Sailor projects. Followed [https://www.polpiella.dev/how-to-make-an-interactive-picker-for-a-swift-command-line-tool]this tutorial for the interactive picker.

# Version 0.0.3

Basic CLI architecture, filesystem and git helpers.

# Version 0.0.2

Uploaded to brew at []. Removed Carton as a dependency of CLI.

# Version 0.0.1

Attempting to get a swift CLI uploaded to brew.