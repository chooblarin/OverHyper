# Swift Style Checklist (Google Swift Style Guide)

Use this checklist in code review for newly added or edited Swift files.

1. Line length is 100 columns or less (except allowed import/documentation cases).
2. No semicolons.
3. Imports are minimal and explicit.
4. `guard` is used for early exits when it reduces nesting.
5. No forced unwrap (`!`) or forced cast (`as!`) unless justified.
6. Documentation comments use `///` style.
7. `public`/`open` declarations include doc comments.
8. Access control is explicit only where necessary.
9. Non-doc comments use `//`.
10. Naming and API shape are clear and Swifty.
