# ADR 0001: Multi-platform build pipeline for Tride

Status: Proposed
Date: 2026-06-20
Supersedes: -
Related: `.github/workflows/release.yml`, `build/azure-pipelines/product-release.yml`, `scripts/prepare-trinno.sh`

## Context

`open1s/tride` is a fork of `microsoft/vscode` shipping as "Tride IDE". The current
release workflow (`.github/workflows/release.yml`) only produces:

- `trinno-research.vsix` — bundled extension
- `tinymist-universal.vsix` — bundled extension
- `trinno-icon-256.png` — branding

Users who download v1.0.0 must download a separate VS Code / Code OSS / VSCodium
binary and install the VSIXes into it. This is friction; users expect a
standalone IDE binary per platform.

The fork contains the full VS Code build machinery
(`build/azure-pipelines/product-release.yml` + per-platform pipelines under
`build/azure-pipelines/{linux,darwin,win32}/`). However those pipelines are
designed for Microsoft's internal Azure DevOps environment and assume:

- An Azure DevOps `vscode` service connection for fetching secrets
- An ESRP (`ESRPClient`) signing endpoint for code-signing mac/win binaries
- Microsoft's internal `BUILDS_API_URL` and telemetry/CDN endpoints
- Internal VSCodeMarketplace publish tokens (`PUBLISH_AUTH_TOKENS`)
- `azure-pipelines/distro/download-distro.yml@self` mixing the distro archives

Re-implementing this on GitHub Actions is non-trivial.

## Decision

Build a separate, GitHub-native multi-platform release pipeline:

### Phase 1 — Linux x64 only (cheap, low risk)

Add a new `build-tride` job to `.github/workflows/release.yml`:

- Runs on `ubuntu-22.04` self-hosted or `ubuntu-latest`
- Invokes `yarn` or `npm ci` then `./scripts/code.sh` (or equivalently
  `./scripts/package-trinno.sh`) to package a Linux distributable
- Uses electron-builder or the upstream `gulp vscode-linux-x64-min` task
  (whichever builds first)
- Archives the resulting `VSCode-linux-x64/` directory as
  `tride-linux-x64.tar.gz` (matches upstream naming without using
  the trademarked word)

Expected CI cost: 20-40 minutes wall clock.

### Phase 2 — macOS + Windows (after Phase 1 is stable)

- Add `macos-14` runner jobs for darwin (universal if cross-compile works)
- Add `windows-2022` runner jobs for win32 x64
- Skip code-signing for both. Result: macOS Gatekeeper will reject unsigned
  apps (`xattr -d com.apple.quarantine` workaround); Windows SmartScreen
  will block. Document this in release notes.
- For real distributability, the project owner must acquire:
  - Apple Developer ID Application certificate + notarization token
  - WoSign / DigiCert EV code-signing certificate
  Both require paid accounts and registered businesses.

### Phase 3 — Code-signing + notarization (optional)

Add signing steps with secrets stored in GitHub Actions secrets:

- `MACOS_CERT_P12_BASE64`, `MACOS_CERT_PASSWORD`, `APPLE_ID`,
  `APPLE_APP_SPECIFIC_PASSWORD`, `APPLE_TEAM_ID`
- `WINDOWS_CERT_PFX_BASE64`, `WINDOWS_CERT_PASSWORD`

Blocker: requires the project owner to mint/own these certificates.

## Consequences

Positive:

- Standalone IDE download per platform replaces the VSIX-only workflow
- Smaller CI cost than rebuilding Microsoft's internal pipeline (skip telemetry,
  marketplace publish, distro source mixing)
- Backend-compatible with upstream — uses the same `gulp vscode-*` targets

Negative:

- Unofficial fork: cannot ship under the `Visual Studio Code` trademark
  (already mitigated: product.json branches `nameShort` from `Tride`)
- Unsigned binaries in Phase 2 will trigger OS warnings
- No `--telemetry` build variant by default; current upstream respects
  `VSCODE_QUALITY` env var but telemetry mixins are Microsoft-specific
- Drift risk: every sync with `microsoft/vscode` upstream rebase may require
  touching this ADR

Mitigations:

- Keep Phase 1 (linux-x64) as the first gate. Don't ship Phase 2 until
  Phase 1 has produced one successful artifact.
- Pin `microsoft/vscode` upstream tracking via a separate branch
  (`upstream/main`) rebased monthly

## Alternatives considered

1. **Ship nothing binary; require users to install Code OSS / VSCodium.**
   Status quo. Lowest cost. Highest user friction.

2. **Use `electron-builder` against upstream VSCodium source.** VSCodium
   ships exactly this — pre-built distributables per platform. Drop the
   fork-of-microsoft/vscode model entirely. Cleanest long-term but loses
   `microsoft/vscode`'s prompt updates.

3. **Re-implement Azure Pipelines on GitHub Actions verbatim.** Rejected.
   Weeks of effort for telemetry/CDN-side components that have no
   public-CI equivalent.

## Action items

- [ ] Verify `./scripts/package-trinno.sh` produces a linux-x64 distributable
      on the existing build host (Phase 0, before wiring CI)
- [ ] Confirm electron-builder is approved for this repo (license check)
- [ ] Decide whether to keep `microsoft/vscode` upstream tracking or migrate
      to `VSCodium/vscodium`
- [ ] Estimate CI cost: macos-14 @ $5/min × 40min × ~4 releases/month ≈ $800/mo
- [ ] Draft follow-up issue linking this ADR
