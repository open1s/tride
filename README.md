# Trinno Research IDE

> A research-oriented IDE built on the [Visual Studio Code - Open Source](https://github.com/microsoft/vscode) ("Code - OSS") base, with the **Trinno Research** extension bundled for TRIZ-driven innovation workflows.

[![Trinno Research](https://img.shields.io/badge/Trinno-Research%20IDE-0F4C81)](https://github.com/open1s/tride)
[![Built on Code - OSS](https://img.shields.io/badge/base-Code--OSS-blue)](https://github.com/microsoft/vscode)
[![MIT License](https://img.shields.io/badge/license-MIT-green)](LICENSE.txt)

---

## What is this

`open1s/tride` is a maintained fork of Microsoft's `vscode` (Code - OSS) that ships as **Trinno Research IDE**. The product is rebranded, the binaries are signed under the **Trinno** name, and the built-in TRIZ research assistant extension ([`open1s.trinno-research`](https://github.com/open1s/trinno)) is bundled at build time.

Everything else stays stock Code - OSS: the editor, workbench, extensions API, settings, keybindings, and core engineering are unchanged from upstream. We do not add private telemetry, authentication handshakes, or product-specific code beyond the rebranding layer and the bundled research extension.

## Bundled Extensions

The release ships the following built-in extensions in every platform build:

| Extension | Purpose |
|-----------|---------|
| `open1s.trinno-research` | TRIZ research assistant: chat panel, contradiction analysis, paper download, BOS agent (`tride-darwin-arm64.zip`, `tride-linux-x64.tar.gz`, `tride-win32-x64.zip`) |
| `myriad-dreamin.tinymist` | Typst language service — preview, formatting, LSP |
| `vscode.mermaid-markdown-features` | Mermaid diagram rendering in the markdown preview |

Plus the full set of upstream Code - OSS built-in extensions (git, languages, themes, etc.).

## Releases

Pre-built binaries are published as GitHub Releases:

| Platform | Asset |
|----------|-------|
| Linux x64 | `tride-linux-x64.tar.gz` |
| macOS (Apple Silicon) | `tride-darwin-arm64.zip` |
| Windows x64 | `tride-win32-x64.zip` |
| macOS (Intel) | _not currently built — `macos-13` runner capacity is limited_ |

Download the latest release from the [Releases](../../releases) tab.

To get insider-style pre-releases every build, see [`.github/workflows/release.yml`](.github/workflows/release.yml).

## Building from source

Tride follows the upstream build instructions. The only prerequisites are the usual VS Code ones ([Node.js 24.x](https://nodejs.org/) matches `.nvmrc`, C/C++ toolchain on Linux/Windows, Xcode CLT on macOS).

```bash
git clone https://github.com/open1s/tride.git
cd tride

# 1. Bootstrap (downloads Node toolchain and a few support modules)
npm ci

# 2. Build all of the built-in extensions (including trinno-research if sourced locally)
npm run gulp compile-extensions-build

# 3. Compile the main IDE
npm run gulp core-ci

# 4. Package for your current platform/arch
npm run gulp vscode-<platform>-<arch>-min-ci
# e.g. npm run gulp vscode-linux-x64-min-ci
```

The packaged IDE lands in `../VSCode-<platform>-<arch>/` (a sibling of the repo root). On Windows the same command produces a `.zip` via 7-Zip; on Linux a `.tar.gz`; on macOS a `.zip`.

### Adding the Trinno Research extension locally

To develop against the Trinno Research extension from its own checkout:

```bash
export TRINNO_PATH=/path/to/trinno   # ~/.agents-style locations work too
npm run compile-extension-media-build
npm run watch   # auto-recompile on file changes
```

The repo's [`scripts/setup-trinno-dev.sh`](scripts/setup-trinno-dev.sh) automates this: it verifies the sibling `trinno` repo and registers its compiled output as a local override in `.vscode/settings.json`.

## Repository layout

```
tride/
├── build/
│   ├── azure-pipelines/   # Upstream Azure pipeline definitions (kept for reference)
│   ├── branding/          # Trinno SVG/PNG, app icons, splash screens
│   ├── extensions/        # Trinno engineering scripts
│   ├── gulpfile.*.ts      # Build orchestration
│   ├── .moduleignore      # node_modules cleanup rules for packaged IDE
│   └── lib/copilot.ts     # Trinno-specific build steps (ripgrep shim, etc.)
├── extensions/            # All built-in extension sources
├── scripts/
│   ├── install-branding.sh    # Apply Trinno branding to resources/
│   ├── prepare-trinno.sh      # Build pipeline pre-bundle step
│   ├── package-trinno.sh      # Pack the trinno-research VSIX
│   └── ...
├── .github/workflows/
│   └── release.yml        # Trinno Research IDE release pipeline (GitHub Actions)
├── product.json           # Trinno product metadata (applicationName, icons, etc.)
└── package.json
```

## Trademark notice

**Visual Studio Code**, **VS Code**, and **Code - OSS** are trademarks of Microsoft Corporation. Trinno Research IDE is an independent fork and is not affiliated with, endorsed by, or sponsored by Microsoft. All upstream Code - OSS code remains under the [MIT License](https://github.com/microsoft/vscode/blob/main/LICENSE.txt).

## License

Copyright (c) The Trinno project authors. All rights reserved.

Licensed under the [MIT](LICENSE.txt) license. Source code in this repository is derivative of Microsoft's [vscode](https://github.com/microsoft/vscode) and inherits its license.

## Related projects

- [microsoft/vscode](https://github.com/microsoft/vscode) — upstream Code - OSS
- [open1s/trinno](https://github.com/open1s/trinno) — `trinno-research` extension (the bundled TRIZ research assistant)
- [myriad-dreamin/tinymist](https://github.com/myriad-dreamin/tinymist) — Typst language service
