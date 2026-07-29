# automated_localization

A new Flutter project.

## Documentation

- [Localization guide for developers](docs/LOCALIZATION_DEVELOPERS.md)
- [Localization guide for translators](docs/LOCALIZATION_TRANSLATORS.md)

## Publish localizations

Translations are published through GitHub Actions:

```text
Google Sheet
-> GitHub Actions
-> sheety_localization
-> ARB validation
-> flutter analyze / flutter test
-> GitHub production approval
-> Shorebird Android patch
```

Required GitHub repository secrets:

```text
GOOGLE_SERVICE_ACCOUNT_JSON
LOCALIZATION_SHEET_ID
SHOREBIRD_TOKEN
```

Before the first production patch, run `shorebird init`, commit `shorebird.yaml`,
and replace debug Android signing with production signing/secrets.
Configure the GitHub `production` environment with required reviewers.

Run it from GitHub Actions with the `Publish localizations` workflow. The
workflow generates localization files from Google Sheet, uploads the generated
diff as an artifact, waits for the `production` environment approval, and then
publishes a Shorebird Android patch.

Google Sheet remains the source of truth. Prefer adding and editing keys in the
sheet. If a developer creates a key in ARB first, run the `Export ARB to Google
Sheet` workflow before `Publish localizations`:

1. Run it with `apply` disabled and inspect the proposed additions in the log.
2. Run it again with `apply` enabled to append missing keys.
3. Run `Publish localizations` to regenerate ARB and Dart files from the sheet.

The export workflow never overwrites non-empty Sheet values. It only appends
missing keys, adds missing locale columns, and fills empty translation cells.
The Google service account must have `Editor` access to the spreadsheet for
this workflow; `Viewer` access is enough only for localization generation.

## Merge protection

The `Validate localization` workflow runs on every pull request and reports
three checks:

```text
ARB consistency
Plural forms
Flutter checks
```

To block merging when one of them fails, create an active branch ruleset for
`main` in GitHub under `Settings -> Rules -> Rulesets`. Enable `Require a pull
request before merging` and `Require status checks to pass before merging`,
then add all three checks above. Enable `Require branches to be up to date
before merging` if every pull request must be tested against the latest `main`.

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Lab: Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Cookbook: Useful Flutter samples](https://docs.flutter.dev/cookbook)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.
