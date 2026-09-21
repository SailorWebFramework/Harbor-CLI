# Harbor CLI

Command-line tool for building and running [Sailor](https://github.com/SailorWebFramework/Sailor) web apps.

```bash
harbor init MyApp        # scaffold a new project from the template
cd MyApp
harbor run web           # build to WASM, watch Tailwind, serve on :8080
harbor build web         # production build into dist/
```

## Install

From source (macOS 13+, Swift 6):

```bash
git clone https://github.com/SailorWebFramework/Harbor-CLI
cd Harbor-CLI
make install             # builds in release and copies `harbor` to /usr/local/bin
```

Requires a Swift SDK for WebAssembly — either the
[swift.org one](https://www.swift.org/documentation/articles/wasm-getting-started.html)
(`swift-6.x-RELEASE_wasm`) or the [swiftwasm](https://book.swiftwasm.org/getting-started/setup.html)
one (`wasm32-unknown-wasi`). Harbor picks whichever `swift sdk list` shows. Xcode's bundled
toolchain cannot target wasm; use the matching swift.org toolchain (`TOOLCHAINS=...`).

## Commands

| Command | What it does |
|---|---|
| `harbor init [name]` | Clones the project template, strips its `.git`, and renames the package. |
| `harbor run web [--port 8080]` | `swift package --swift-sdk wasm32-unknown-wasi js`, then serves with Vite (if a `vite.config.js` exists) or `python3 -m http.server`. |
| `harbor build web [--output dist]` | Release WASM build, minified Tailwind CSS, and copies the PackageToJS bundle into the output directory. |
| `harbor install <pkg> [--url] [--version]` | Adds an SPM dependency to `Package.swift`, resolving the URL from `.harbor/fleet.json` when present. |
| `harbor run ios` / `harbor run server` | Placeholders for the native and Vapor targets — print the manual steps for now. |

## Tailwind integration

If `Package.swift` depends on [Fleet-Tailwind](https://github.com/SailorWebFramework/Fleet-Tailwind),
Harbor drives the standalone `tailwindcss` binary (expected at `./tailwindcss` in the project root):

- **`harbor run web`** writes every class from `TW.swift` to `.tailwind-classes.txt` and runs
  `tailwindcss --watch`, so a new `TW.*` reference shows up without restarting.
- **`harbor build web`** scans `Sources/**/*.swift` for `TW.identifier` references and writes only
  those classes, then runs a single minified build. On the Sailor site this shrinks the CSS from
  ~1.5 MB (16,954 classes) to ~8 KB (84 classes).

`tailwind.config.js` and `input.css` are generated on first run if missing and never overwritten.

## Development

```bash
swift test               # HarborUtilsTests + HarborCLITests
```

CI runs the test suite on macOS for every push and pull request.
