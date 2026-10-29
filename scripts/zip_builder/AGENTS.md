# AGENTS.md: zip-builder

zip-builder turns a Swift package into a release zip of `.xcframework`s; Firebase runs it on the
repo's `Package.swift` with `zip_builder.jsonc`. Read [README.md](README.md) for usage and
[docs/how-it-works.md](docs/how-it-works.md) for the rules it implements.

## Map

One executable target, `Sources/ZipBuilder`, in folders that follow the pipeline:

| Folder | Stage | Main entry point |
|---|---|---|
| `Commands/` | CLI, one file per subcommand | `ZipBuilderCommand`; shared stage steps in `SharedOptions.swift` |
| `Config/` | the config file | `Config.swift` → `Config.load(from:)`; defaults in `Default.swift`; `UnknownKeys.swift` → `warnAboutUnknownKeys` |
| `Model/` | the plan | `Plan.swift` → `Plan`; `BuildSettings.swift`, `Platform.swift` |
| `Planning/` | 1–2: load and plan | `LoadPackage.swift` → `loadPackage`; `MakePlan.swift` → `makePlan`; `DynamicFrameworks.swift` → `dynamicTargets`; `HeaderSearchPaths.swift` → `dependencyIncludeDirectories` |
| `Customizing/` | 3: apply the config | `Customize.swift` → `customize`; `Merge.swift` → aggregate, merge, rename; `Folders.swift` → `arrangingFolders` |
| `Building/` | 4: project and build | `MakeProject.swift` → `makeProject`; `BuildXCFrameworks.swift` → `buildXCFrameworks`; `Linking.swift` → linkage check (`checkDynamicFrameworksLinkNothingStatic`), `reachedDependencies`; `FrameworkCache.swift` → `fingerprints`, `FrameworkCache` |
| `Packaging/` | 5: the zip | `MakeZip.swift` → `makeZip`; `Metadata.swift` → `metadata` |
| `Inspecting/` | verify and diff | `Verify.swift` → `verify`; `Diff.swift` → `diffDistributions`; `RenderDiff.swift` → `renderText`, `renderMarkdown`, `renderGitHubComment`; `Distribution.swift` → `readDistribution`, `readXCFrameworks` |
| `Support/` | shell, logging, files | `Shell.swift` → `shell`, `runTool`; `Output.swift` → `warn` |

Tests in `Tests/ZipBuilderTests` mirror these folders. The fixture package is
`Fixtures/MiniPackage`; keep it free of `.build` and `Package.resolved`.

`ci/` holds the steps of `.github/workflows/infra.zip_diff.yml` in `zip_diff.sh`, one subcommand
per step. Its `diff` step writes the pull request comment with `diff --format github-comment`, and
`.github/actions/pr_comment` posts it. `tool_hash.sh` names CI's framework cache directories, for
`zip_diff.sh` and `infra.zip_quickstart.yml`. Keep logic there rather than inline in the workflow.

## Invariants

- **Firebase specifics live in `zip_builder.jsonc`, never in code.** No Firebase product, target or
  path names in `Sources/`. If Firebase needs a behavior, add a general config key.
- **The plan is the contract.** Only `makePlan` and `customize` make decisions. `makeProject` and
  `buildXCFrameworks` read no config; they carry out the plan. `makeZip` reads only `release`,
  `zip` and `products.base`; `verify` only `products.base` and `verify`.
- **Fingerprint text is byte-stable.** `FingerprintTests.goldenFingerprints` must pass unchanged.
  Changing the text invalidates every cache entry, CI's included; do it only on purpose, and bump
  `fingerprintFormat` with it.
- **`plan.json` stays deterministic.** Same input, same bytes: sort collections, encode sets
  sorted, keep paths relative to the package root.
- **A behavior change needs a test that pins it.** Pin the current behavior first, then change it.
- **Don't casually change `Package.resolved`.** AEXML is pinned below 4.7.2 on purpose (see
  `Package.swift`). CI builds with `--force-resolved-versions`.

## Conventions

- One file per stage or concern, named after its main function. Keep files under ~350 lines;
  split along a real seam, not by concatenating types.
- Plain functions over the plan. No managers, factories, protocols with one implementation, or
  forwarding wrappers.
- Natural-language names: `restrictingPlatforms`, `shippingPlatforms(of:)`, not abbreviations.
- Put why-comments next to the code they explain. Don't narrate what the code does.
- No dense regex: normalize the input, then match it simply.
- Use the dependencies' own models and constants (SwiftPM's `ResolvedModule`, XcodeProj's
  `Xcode.Default.*`, …) instead of copies or literals. Read the dependency's source when unsure.
- Log with `logger` and warn with `warn()`, never `print`: standard output is for results.
- A config name that doesn't match the plan is a warning (`warnSkipped`), not an error, so
  `--product` keeps working. An unknown config key is a warning too (`warnAboutUnknownKeys`).
- Tests use Swift Testing (`@Test`, `#expect`, `#require`). Check warnings with
  `Warnings.$collected.withValue(…)`.
- New files get the Apache license header. 2-space indentation, lines of at most 100 characters.
- Delete obsolete code and update its callers; don't keep aliases or compatibility shims. The tool
  has no external API to preserve.

## Commands

Run from the repository root.

```bash
swift build --package-path scripts/zip_builder --build-tests --force-resolved-versions
swift test --package-path scripts/zip_builder --force-resolved-versions
ZIP_BUILDER_E2E=1 swift test --package-path scripts/zip_builder --force-resolved-versions \
  --filter BuildEndToEnd
mint run swiftformat scripts/zip_builder/Sources scripts/zip_builder/Tests
.agents/skills/style_and_commit/scripts/pre_commit.sh
```

Real-release regression check, for changes to `Planning/`, `Customizing/`, `Building/` or
`Packaging/`. Fingerprints don't cover the tool's code, so the second run needs a fresh cache:

```bash
VERSION="$(sed -nE 's/^let firebaseVersion = "([^"]+)".*/\1/p' Package.swift)"
git stash  # or check out the commit before your change
./scripts/zip_builder.sh release --version "$VERSION" --work-dir /tmp/zb-before
git stash pop
./scripts/zip_builder.sh release --version "$VERSION" --work-dir /tmp/zb-after \
  --cache-dir "$(mktemp -d)"
./scripts/zip_builder.sh diff /tmp/zb-before/dist/Firebase /tmp/zb-after/dist/Firebase
```

An empty diff means the zip didn't change. Explain every difference you didn't intend to make.

## Before you finish

- [ ] Build with `--build-tests`: no new warnings.
- [ ] All tests pass, and the E2E suite too if you touched `Planning/`, `Customizing/` or
      `Building/`.
- [ ] New behavior and new helpers have tests; changed behavior has a test that pins it.
- [ ] `goldenFingerprints` passes unchanged, or `fingerprintFormat` is bumped on purpose.
- [ ] Code that can change a built framework without changing its fingerprint is covered by
      `ci/tool_hash.sh` (today `Building/`, except `FrameworkCache.swift` and `Layout.swift`, and
      `Model/`), so CI doesn't reuse stale cache entries.
- [ ] Changed files are formatted with swiftformat.
- [ ] Config changes (keys, defaults, meaning) are in `docs/configuration.md`.
- [ ] Rule changes (what the tool derives, or how) are in `docs/how-it-works.md`.
- [ ] CLI changes (commands, flags, options) are in `README.md`, including any affected
      common tasks.
- [ ] Added, moved or renamed files are in the [Map](#map) above.
- [ ] `Fixtures/MiniPackage` has no `.build` or `Package.resolved`.

## Don'ts

- Don't add Firebase names or Firebase-only behavior to `Sources/`.
- Don't make a decision outside planning and `customize`, or read config in `Building/`.
- Don't change fingerprint text by accident, e.g. by reordering or renaming fields it hashes.
- Don't add heuristics: public headers come from SwiftPM's include directory, wrappers from the
  code-free rule, and everything else from explicit config.
- Don't `print` diagnostics, and don't make an unknown config name fatal.
- Don't update dependencies or `Package.resolved` as a side effect of another change.
- Don't commit build output (`build/`, `.build/`).
