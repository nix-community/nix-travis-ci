# Changelog

## [Unreleased]

## [v5] - September 10, 2020

Fix (hopefully) install failures on macOS which spontaneously started 
occurring sometime in the past couple days.

## [v4] - September 1, 2020

Fixed problem with (currently undocumented) auto-install of cachix (if
CACHIX_CACHE is set) not working when NIX_PATH was overriden.

## [v3] - August 30, 2020
- Fix recovery from rare issue on macOS 10.14+
- Fix leaky ansi color in macOS builds
- Fix account issue causing cachix test fail

## [v2] - August 30, 2020

Added a `use_nix` alias for merging with specific jobs.

## [v1] - August 29, 2020

Initial release.

[unreleased]: https://github.com/nix-community/nix-travis-ci/compare/v5...HEAD
[v4]: https://github.com/nix-community/nix-travis-ci/compare/v4...v5
[v3]: https://github.com/nix-community/nix-travis-ci/compare/v3...v4
[v3]: https://github.com/nix-community/nix-travis-ci/compare/v2...v3
[v2]: https://github.com/nix-community/nix-travis-ci/compare/v1...v2
[v1]: https://github.com/nix-community/nix-travis-ci/releases/tag/v1
