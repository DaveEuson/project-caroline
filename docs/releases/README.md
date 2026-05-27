# Release Notes

Project: Caroline keeps human-readable release notes in this folder.

## Current Draft

- [Unreleased](unreleased.md)
- [Beta 1.0 draft](beta-1.0-draft.md)

## Published Notes

- [v0.3.0-beta.4](v0.3.0-beta.4.md)
- [v0.3.0-beta.3](v0.3.0-beta.3.md)
- [v0.3.0-beta.2](v0.3.0-beta.2.md)
- [v0.3.0-beta.1](v0.3.0-beta.1.md)

## How To Keep Them

Add user-facing changes to [Unreleased](unreleased.md) as they land on `master` or `nightly`.

Use these headings when they fit:

- `Added` for new features.
- `Changed` for behavior, defaults, copy, or docs changes.
- `Fixed` for bugs.
- `Removed` for deleted features, assets, or workflows.
- `Known Issues` for things users may hit before the next release.

When cutting a release, copy the unreleased notes into a new versioned file, update this index, and reset [Unreleased](unreleased.md) to an empty draft.
