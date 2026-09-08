# Antigravity Agent Rules for panta-go

These rules apply to ALL agents and ALL models working on this repository.
They are non-negotiable and must be followed at all times.

---

## Code Editing

- **NEVER use `sed`, `awk`, `perl -i`, or any shell find-and-replace to edit source code files.**
- Always use the proper file editing tools (`replace_file_content`, `write_to_file`) to make changes.
- This applies even when making bulk changes across multiple files — edit each file directly using the editor tools.
- Shell commands (`run_command`) are allowed for: running builds, tests, git operations, installing packages, and reading output. Not for modifying source files.

## Autonomy

- Make decisions and implement changes without asking for permission on straightforward tasks.
- Do not ask the user to confirm `sed` syntax, file paths, or command flags — just do it using the editor tools.
- Commit and push changes proactively after completing a task unless told otherwise.

## General

- Always run `flutter analyze` after modifying Dart files and fix any warnings before committing.
- Always write descriptive, conventional commit messages (`feat:`, `fix:`, `chore:`, etc.).
