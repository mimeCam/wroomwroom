## Coding & Development

Assume these guidelines when writting code in a development environment:
- do not add comments to a new functionality - we (developers) understand code just fine.
- *NEVER* edit existing comments that are separate from the code you are changing as these may be needed later (to toggle features in the future).

Quick-check new (just written) code:
- no function can be longer than 10 lines - refactor otherwise.
- use defensive programming best standards: constants over variables, `private` over default access for internals, `final` classes over default, etc...

Mimic the style (formatting, naming), structure, framework choices, typing, and architectural patterns of existing code in the project.
