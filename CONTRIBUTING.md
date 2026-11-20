# Contributing to Boswell

Boswell is a fictional-data prototype, **not for real patient use**.

## Boundaries

- `BoswellCore` imports Foundation only. Decisions about evidence colour, merging,
  omissions, review/sign-off and export content belong here and need public-behaviour tests.
- `App` is a thin SwiftUI/Apple-framework adapter: speech, model calls, storage,
  PDF drawing and screens. Do not put a second copy of Core rules in a view.
- Boswell is Mac only. Swift tools 5.9 and macOS 14 are Core's minimums. The app
  targets macOS 27 and requires Xcode 27. Do not enable Swift 6 language mode in this scaffold.
- Use XCTest for portable tests. No server or cloud AI is part of the app architecture.

## Local checks

From the repository root:

```sh
.agents/tests/setup_test.sh
.agents/setup --run-tests
shellcheck .agents/setup .agents/tests/setup_test.sh
```

On a Mac with Xcode 27 selected and XcodeGen installed:

```sh
xcodegen generate
xcodebuild test -project Boswell.xcodeproj -scheme Boswell \
  -destination 'platform=macOS' CODE_SIGNING_ALLOWED=NO
```

See [README](README.md) for installation and signing. Generated projects, build
output and local signing settings are not committed. No Apple SDK is available
on Linux; passing Core tests is not proof the app builds or renders.

## Tickets and branches

1. Draft tickets with the issue template: plain-English purpose and observable
   completion checks first, technical details and exclusions underneath.
2. Before posting, obtain independent reviews for value/scope, plain English and
   technical correctness. Record consequential changes, not just approval.
3. Create issues before PRs when exact issue numbering is needed. GitHub shares
   issue/PR numbers and does not recycle deleted numbers. Never claim a BW ID
   equals a GitHub issue number without checking; never recreate deleted issues
   without the owner's request.
4. Branch `feature/BW-<n>` from current `main`, after required dependencies merge.
   Write commit messages and PR titles as Conventional Commits:
   `<type>: <summary>`, such as `fix: stop model leaking system prompt into notes`.
   Types: feat, fix, docs, refactor, test, ci, chore. No `Co-authored-by` or
   other trailers.
   Write the PR body in plain text with no bold, headings or other formatting
   and no links, following `.github/pull_request_template.md`:

   ```text
   fix: stop model leaking system prompt into output notes

   - Summary of fix (one sentence)
   - How it was fixed (one sentence, more only if required)
   - Summary of potential downstream impact

   This PR addresses Issue 7 in GitHub issues
   ```
5. Every PR must build on its own after its prerequisites. Link future screens
   to explicit placeholders rather than referencing code that does not exist.
6. Squash-merge only after required CI checks pass. The workflows define the
   checks; repository protection must be configured separately by an owner.
   Do not bypass failing or unavailable checks to call a ticket done.

## Privacy and safety

- Fictional text only. Never commit patient conversations, audio, generated
  exports, signing credentials, private conversation links, thread IDs, internal
  session identifiers or machine-specific workspace paths.
- Check the complete outgoing content before committing or posting externally,
  including generated templates and other contributors' drafts.
- Keep public issues, PRs and documentation self-contained. Permission to publish
  project work is not permission to disclose private development context.
- `Verified` describes transcript evidence matching, **not clinical truth**.
  The transcript itself can be wrong. Clinician review remains mandatory.
- The sample's timestamps and word confidences are synthetic. Do not represent
  them as speech-recognition measurements or model performance.
- Sign-off enforcement, secure device storage and export gates are future work;
  the initial Codable models alone do not enforce them.
- Clinical safety case, DPIA, applicable DTAC/DCB0129/0160 and MHRA work remain
  prerequisites before any real patient use, not claims fulfilled by this scaffold.
