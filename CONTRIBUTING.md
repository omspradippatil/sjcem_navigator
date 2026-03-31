# Contributing

## Development Setup

1. Install dependencies:

```bash
flutter pub get
```

2. Ensure platform tooling is available (Android Studio / Xcode).

3. Configure project environment values used by Supabase/Firebase.

## Branching

- Use short feature branches from the main integration branch.
- Keep changes focused and atomic.

## Code Guidelines

- Follow existing project style and naming.
- Prefer small provider/service changes over large coupled edits.
- Keep UI state in providers where applicable.

## Validation Before PR

Run at least:

```bash
flutter analyze
flutter test
```

If your change is scoped to navigation, run:

```bash
flutter analyze lib/providers/navigation_provider.dart lib/screens/navigation/navigation_screen.dart
```

## PR Checklist

- [ ] Code compiles and analyzer is clean
- [ ] Relevant tests pass
- [ ] Docs updated when behavior changes
- [ ] No unrelated file changes
