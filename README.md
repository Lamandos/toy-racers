# Toy Racers

Toy Racers is an original arcade 2D top-down racing game about toy cars on compact tracks built around everyday objects. The MVP targets Android and includes one track, a player car, three AI opponents, three laps, a starting countdown, pause, results, best-time persistence, and basic audio.

The project does not use names, artwork, tracks, audio, characters, or other protected assets from existing racing games.

## Technology

- Kotlin
- libGDX
- Gradle
- Android Studio
- Desktop LWJGL3 and Android launchers

## Project status

The repository currently contains the project documentation. The libGDX modules will be generated in the next setup step with GDX-Liftoff.

## Run

After the Gradle project is generated:

```sh
./gradlew lwjgl3:run
./gradlew android:installDebug
```

The Android task requires an Android SDK and a connected device or running emulator.

## Test and verify

```sh
./gradlew unitTest
./gradlew behavioralTest
./gradlew qualityCheck
./gradlew lwjgl3:test
./gradlew android:assembleDebug
```

Task names may be adjusted to match the generated GDX-Liftoff project. Before completing a change, run the relevant tests, the desktop task, and the Android debug build.

## Assets

Runtime assets will live in `assets/`, which is shared by the platform launchers according to the generated libGDX configuration. Only original, licensed, or public-domain assets may be added. Record licenses and attribution alongside third-party assets.

## Build rules

- Use a JDK version compatible with the checked-in Gradle wrapper and Android Gradle Plugin.
- Build through the checked-in Gradle wrapper; do not rely on a system Gradle installation.
- Keep gameplay logic in `core` and platform integration in platform modules.
- Do not access Android APIs from `core`.
- Add tests for gameplay logic where practical.
- Do not add dependencies without documenting the need and trade-offs.

See [game design](docs/GAME_DESIGN.md), [architecture](docs/ARCHITECTURE.md), [tasks](docs/TASKS.md), and
[code quality](docs/CODE_QUALITY.md).

## Sequential Codex/GitHub orchestrator

The repository includes `scripts/orchestrator.py`, a restartable workflow that
executes `PLAN.md` one task at a time:

1. update local `main`;
2. create a task branch;
3. run Codex CLI to implement the task;
4. run the configured local test command;
5. commit, push, and create a GitHub pull request;
6. request `@codex review`, wait for the result, and send actionable findings back to Codex;
7. wait for required GitHub checks, then squash-merge and delete the branch;
8. update local `main` before starting the next task.

The default mode is a no-op dry run. Real repository changes require
`--execute`, and a real merge additionally requires `--allow-merge` (or the
explicit `ORCHESTRATOR_ALLOW_MERGE=1` environment setting).

### Prerequisites

- a clean git checkout with a `main` branch and an `origin` remote;
- authenticated `gh` (`gh auth status`);
- authenticated Codex CLI (`codex`);
- the tools required by the configured test command.

Add executable task sections to [PLAN.md](PLAN.md), then preview the workflow:

```sh
python3 scripts/orchestrator.py --dry-run
```

Run the workflow with all mutations except merge:

```sh
python3 scripts/orchestrator.py --execute
```

That command pauses at the merge gate and stores its progress in
`.agent/orchestrator-state.json`. Resume after reviewing the PR with:

```sh
python3 scripts/orchestrator.py --execute --allow-merge
```

For unattended execution, use the explicit merge flag only after verifying the
branch protection and review policy for the repository. The state file is
updated atomically after each workflow transition, so rerunning the same command
resumes the first unfinished task. Use `--reset-state` only when intentionally
starting the plan over.

### Configuration

CLI options override environment variables. The most useful settings are:

| CLI option | Environment variable | Default |
| --- | --- | --- |
| `--main-branch` | `ORCHESTRATOR_MAIN_BRANCH` | `main` |
| `--remote` | `ORCHESTRATOR_REMOTE` | `origin` |
| `--test-command` | `ORCHESTRATOR_TEST_COMMAND` | `./.githooks/pre-push` when present |
| `--max-review-iterations` | `ORCHESTRATOR_MAX_REVIEW_ITERATIONS` | `3` |
| `--review-timeout` | `ORCHESTRATOR_REVIEW_TIMEOUT` | `1800` seconds |
| `--checks-timeout` | `ORCHESTRATOR_CHECKS_TIMEOUT` | `1800` seconds |
| `--poll-interval` | `ORCHESTRATOR_POLL_INTERVAL` | `30` seconds |
| `--implementation-model` | `ORCHESTRATOR_IMPLEMENTATION_MODEL` | `gpt-5.6-sol` |
| `--fix-model` | `ORCHESTRATOR_FIX_MODEL` | `gpt-5.6-luna` |
| `--codex-args` | `ORCHESTRATOR_CODEX_ARGS` | workspace-write, automatic approvals, ephemeral session |
| `--review-author` | `ORCHESTRATOR_REVIEW_AUTHORS` | common Codex GitHub bot logins |
| `--required-check` | `ORCHESTRATOR_REQUIRED_CHECKS` | GitHub branch-protection required checks |
| `--limit-window-hours` | `ORCHESTRATOR_LIMIT_WINDOW_HOURS` | `5` hours |
| `--limit-buffer-seconds` | `ORCHESTRATOR_LIMIT_BUFFER_SECONDS` | `60` seconds |
| `--max-quota-retries` | `ORCHESTRATOR_MAX_QUOTA_RETRIES` | `0` (unlimited) |

For this repository, the default test command runs the pre-push quality gate.
To choose a shorter or more targeted command, for example:

```sh
python3 scripts/orchestrator.py --execute \
  --test-command './gradlew quickQualityCheck --no-daemon'
```

If no required checks are configured on the base branch, `gh pr checks --required`
reports an empty set and the script logs that there was no required check gate.
Use `--required-check` to enforce named checks explicitly. A failed check stops
the task for manual diagnosis; review findings are the only findings the worker
automatically fixes.

### Codex usage-limit handling

New task implementation runs use `gpt-5.6-sol`; review-fix runs use the cheaper
`gpt-5.6-luna`. These are the model IDs passed to `codex exec` and can be
overridden independently. OpenAI describes Sol as the flagship model for complex
coding and Luna as the cost-sensitive model for high-volume work.

If Codex exits with a recognizable usage, quota, rate-limit, or five-hour-limit
error, the orchestrator does not discard the task. It records `quota_wait` and a
resume timestamp in `.agent/orchestrator-state.json`, waits in short intervals,
and retries the same prompt with the same model after the reset window. If Codex
reports a retry duration, that duration is used; otherwise the configured
five-hour fallback plus a one-minute buffer is used. Restarting the orchestrator
while it is waiting resumes from the saved timestamp.

The Codex CLI does not expose the account's remaining five-hour allowance as a
portable local metric, so the watcher reacts to the limit signal returned by the
CLI rather than guessing token usage in advance.

Set `--max-quota-retries` to a positive number to bound these retries. The
default `0` keeps waiting indefinitely, which is suitable for a long unattended
run but should be changed for a bounded CI job.

Useful recovery options:

```sh
python3 scripts/orchestrator.py --execute --allow-dirty-resume
python3 scripts/orchestrator.py --execute --reset-state
```

Use `--allow-dirty-resume` only after inspecting edits left by an interrupted
Codex run. It permits resuming an implementation/fix state with uncommitted
files; normal starts still require a clean worktree.
