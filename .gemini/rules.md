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

## Way of Working (WoW)
- **Auto-Commit:** Always commit (and optionally push) your changes proactively the moment you finish a specific goal, fix, or task. Do not wait for the user to ask you to commit.
- **Notify on Completion:** Whenever a long-running background task (like a build, deployment, or compilation) finishes, ALWAYS notify the user with a sound and a desktop notification. 
  - Command: `notify-send "Task Complete" "The build/deploy has finished!" -i dialog-information && ffplay -f lavfi -i "aevalsrc='sin(440*2*PI*t)*exp(-4*t)':d=0.5" -autoexit -nodisp -volume 40 >/dev/null 2>&1`
- **Persistent Terminals:** When launching long-running processes (like dev servers, `flutter run`, or debuggers), ALWAYS use `RunPersistent: true` in the `run_command` tool to prevent the system framework from killing the background task after a timeout.
- **No Flutter Web Hot Reloads:** NEVER trigger a hot reload (`r`) when running `flutter run -d chrome`. The delta compilation causes a massive memory spike resulting in a Linux OOM Code 137 crash. Just read the logs while the user interacts, or do a full fresh restart if necessary.
