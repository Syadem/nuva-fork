# Nuva data

YAML data for antigen types, diseases, valences and vaccines. English names live
in the base files. Additional languages (`fr`, `de`, `lv`, `gr`, `pl`) live in
`translations/<language>/<concept>/`.

## Validate the YAML

```sh
bundle install
bundle exec rspec
```

Currently the specs cover antigen types, valences, diseases, vaccines and their translations, following
`../vaccination_relevant_characteristics`. They check:

- Valid YAML, exact schemas and integer IDs matching `AGT-<id>.yml` and
  `VAL-<id>.yml`, `DIS-<id>.yml` and `VAC-<id>.yml` filenames.
- Nonempty English names and nonnegative integer Unix timestamps, with
  `updated_at >= created_at`.
- Unique IDs, existing parents and no cycles in the hierarchy.
- For valences: nonempty abbreviations, optional antigen type references to
  existing entries, and exactly one unique SYADEM UUID code.
- For diseases: unique integer valence references to existing entries and
  exactly one unique SYADEM UUID code.
- For vaccines: boolean `generic` and `immunoglobulin`, nullable string fields
  `description` and `notes`,
  string-array `other_names`, integer references to existing valences, one unique
  SYADEM UUID code, and `injection_methods` restricted to `intramuscular`,
  `subcutaneous`, `intradermal`, `intranasal` and `oral`.
- One translation per entry in each supported language, with only `name` (and
  nullable `description` for vaccines). Diseases require nonempty names in every
  language. Vaccines and valences require nonempty names in English and French;
  their other translations accept `name:` (null). Antigen type translations
  also accept `name:` (null).
- Supported language directories and no orphan translation files.

## Changelog on GitHub Pages

Pushing any new tag triggers `.github/workflows/build.yml`. The workflow retrieves
all Git history and tags, generates the changelog, and publishes `build/` to the
`gh-pages` branch using the same deployment action as the reference repository.
Keep GitHub Pages configured to publish from the root of `gh-pages`.

The site root and `changelog.html` show the changelog, with expandable file lists
collapsed by default. `changelog.md` is also generated. Each version lists its date, author, commits since the preceding tag
and files added, modified or deleted. The first tag includes all preceding
commits and all files present at that tag. Only tags reachable from the release
being built are included. Files are marked with Git's A/M/D/R status codes.

Generate locally with all reachable tags:

```sh
bundle install
bundle exec ruby scripts/build_changelog.rb
```

Or generate for a particular release:

```sh
bundle exec ruby scripts/build_changelog.rb v1.0.0
```

The generated `build/` directory is ignored by Git. Push the workflow and script
on `main` before creating and pushing the next release tag. The existing RSpec
workflow continues to validate data independently on every push.
