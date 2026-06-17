---
name: terminal-error-diagnostics
description: >
  Guides the agent to systematically verify, capture, and diagnose terminal compilation, linting,
  or runtime errors. Explains how to execute target tests, parse stack traces, and isolate issues
  in terminal execution logs.
---

Use this skill when you encounter terminal compilation failures, runtime test crashes, script execution errors, or linting warnings. It details the steps to troubleshoot program state, examine return codes, and isolate failure points.

## Diagnostic Workflow

1. **Capture raw output**:
   - Run commands capturing both Standard Output and Standard Error.
   - Guard against truncation in long console outputs.
   
2. **Determine language-specific test commands**:
   - **Flutter / Dart**: `flutter analyze`, `flutter test`
   - **PHP**: `php -l <filename>` (syntax check)
   - **Python**: `python -m pytest`, `python <script>`
   - **Node.js**: `npm run test`, `node <script>`

3. **Locate source and trace lines**:
   - Search stack traces for path references inside the workspace.
   - Use absolute file links matching the exact error location (e.g. `[filename](file:///path/to/file#L123)`).

4. **Iterate on Fixes**:
   - Re-run the diagnostic command to verify if compile error/warning is resolved.
