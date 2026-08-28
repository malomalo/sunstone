## [8.1.0] - 2026-08-27

### Changed
- Support both Rails 8.0 and 8.1. The ActiveRecord overrides in `ext/` had been
  synced to Rails 8.1 and used 8.1-only APIs; they now work against 8.0 as well.
- Require Ruby >= 3.3. The gemspec previously declared `>= 2.6`, which the
  `activerecord >= 8.0.1` dependency never actually permitted.
- Require `arel-extensions >= 9.0.0` and `activerecord-filter >= 9.0.0`; the
  previous `>= 7.x` floors predated Rails 8 support.

### Added
- Declare the MIT license in the gemspec.
- Add gemspec `metadata` (source code and changelog URIs, `rubygems_mfa_required`).

### Fixed
- Package `README.md` in the published gem. The gemspec referenced a
  non-existent `README.rdoc`, so the README was omitted from the built gem.

### Internal
- Modernized CI: test Rails 8.0 and 8.1 across Ruby 3.3–4.0, run the upstream
  ActiveRecord suites on Postgres 18, SQLite, and a MySQL service container,
  auto-resolve the latest Rails patch per series, and guard every upstream
  source patch so the build fails loudly if an anchor moves.

## Earlier releases

Prior versions tracked the matching Rails release. See the Git tags for the
full history; notable releases:

- [8.0.0] - 2025-01-24
- [7.1.0.1] - 2023-12-20
- [7.1.0] - 2023-12-15
- [6.1.0.2] - 2021-03-23
- [6.1.0] - 2021-01-14
- [6.0.0] - 2019-06-10

[8.1.0]: https://github.com/malomalo/sunstone/compare/v8.0.0...v8.1.0
[8.0.0]: https://github.com/malomalo/sunstone/releases/tag/v8.0.0
[7.1.0.1]: https://github.com/malomalo/sunstone/releases/tag/v7.1.0.1
[7.1.0]: https://github.com/malomalo/sunstone/releases/tag/v7.1.0
[6.1.0.2]: https://github.com/malomalo/sunstone/releases/tag/v6.1.0.2
[6.1.0]: https://github.com/malomalo/sunstone/releases/tag/v6.1.0
[6.0.0]: https://github.com/malomalo/sunstone/releases/tag/v6.0.0
