#!/usr/bin/env python3
"""Run PLAN.md tasks sequentially through Codex, GitHub review, and merge gates.

The script is intentionally dry-run by default. Use --execute to perform
branch, commit, push, pull-request, review-request, and test mutations. A real
merge additionally requires --allow-merge or ORCHESTRATOR_ALLOW_MERGE=1.
"""

from __future__ import annotations

import argparse
import hashlib
import json
import logging
import os
import re
import shlex
import shutil
import subprocess
import sys
import time
from dataclasses import dataclass
from datetime import datetime, timedelta, timezone
from pathlib import Path
from typing import Any, Iterable, Sequence


STATE_VERSION = 1
PAUSED_EXIT_CODE = 2
DEFAULT_IMPLEMENTATION_MODEL = "gpt-5.6-terra"
DEFAULT_FIX_MODEL = "gpt-5.6-luna"
DEFAULT_LIMIT_WINDOW_SECONDS = 5 * 60 * 60
DEFAULT_LIMIT_BUFFER_SECONDS = 60
DEFAULT_REVIEW_AUTHORS = (
    "chatgpt-codex-connector[bot]",
    "chatgpt-codex-connector",
    "codex[bot]",
    "codex",
)
TASK_HEADING_RE = re.compile(
    r"^##\s+(?P<task_id>TASK-[A-Za-z0-9][A-Za-z0-9._-]*)(?:"
    r"\s*(?:[:—-])\s*(?P<title_separator>.*)|"
    r"\s+(?P<title_whitespace>.+))?\s*$",
    re.IGNORECASE,
)
CLEAN_REVIEW_RE = re.compile(
    r"\b(no\s+(?:actionable\s+)?(?:findings?|issues?|problems?)|"
    r"did(?:n't| not)\s+find\s+any\s+(?:major\s+)?issues?|"
    r"nothing\s+to\s+fix|looks\s+good|lgtm|approved|all\s+checks?\s+pass)\b",
    re.IGNORECASE,
)
ACTIONABLE_REVIEW_RE = re.compile(
    r"\b(actionable|finding|findings|issue|issues|bug|regression|"
    r"must\s+fix|should\s+fix|change\s+requested|security)\b",
    re.IGNORECASE,
)
USAGE_LIMIT_RE = re.compile(
    r"(?:usage\s+limit|rate\s+limit|quota|too\s+many\s+requests|resource\s+exhausted|"
    r"credits?\s+(?:exhausted|depleted)|5[-\s]?hour(?:ly)?\s+limit|limit\s+reached)",
    re.IGNORECASE,
)
RETRY_AFTER_RE = re.compile(
    r"(?:retry(?:[- ]after)|try\s+again\s+in)\s*:?\s*"
    r"(?P<amount>\d+(?:\.\d+)?)\s*(?P<unit>seconds?|secs?|s|minutes?|mins?|m|hours?|hrs?|h)?",
    re.IGNORECASE,
)
DURATION_PART_RE = re.compile(
    r"(?P<amount>\d+(?:\.\d+)?)\s*(?P<unit>hours?|hrs?|h|minutes?|mins?|m|seconds?|secs?|s)",
    re.IGNORECASE,
)
ABSOLUTE_RETRY_RE = re.compile(
    r"try\s+again\s+at\s+(?P<hour>\d{1,2}):(?P<minute>\d{2})\s*(?P<period>am|pm)",
    re.IGNORECASE,
)
REVIEW_QUOTA_RE = re.compile(
    r"(?:reached|hit)\s+your\s+Codex\s+usage\s+limits?\s+for\s+code\s+reviews?",
    re.IGNORECASE,
)
FAILURE_BUCKETS = {"fail", "cancel"}
SUCCESS_BUCKETS = {"pass", "skipping"}


class OrchestratorError(RuntimeError):
    """An expected, user-actionable workflow failure."""


class PausedWorkflow(OrchestratorError):
    """The workflow reached a deliberate safety gate."""


@dataclass(frozen=True)
class PlanTask:
    task_id: str
    title: str
    body: str
    index: int


@dataclass(frozen=True)
class ReviewResult:
    clean: bool
    findings: str = ""
    quota_limited: bool = False


def utc_now() -> str:
    return datetime.now(timezone.utc).isoformat(timespec="seconds").replace("+00:00", "Z")


def parse_int(value: str, name: str) -> int:
    try:
        parsed = int(value)
    except ValueError as exc:
        raise argparse.ArgumentTypeError(f"{name} must be an integer") from exc
    if parsed < 0:
        raise argparse.ArgumentTypeError(f"{name} must be non-negative")
    return parsed


def parse_float(value: str, name: str) -> float:
    try:
        parsed = float(value)
    except ValueError as exc:
        raise argparse.ArgumentTypeError(f"{name} must be a number") from exc
    if parsed <= 0:
        raise argparse.ArgumentTypeError(f"{name} must be greater than zero")
    return parsed


def env_or_default(name: str, default: str) -> str:
    value = os.environ.get(name)
    return value if value not in (None, "") else default


def split_csv(value: str) -> list[str]:
    return [item.strip() for item in value.split(",") if item.strip()]


def strip_html_comments(text: str) -> str:
    return re.sub(r"<!--.*?-->", "", text, flags=re.DOTALL)


def parse_plan(path: Path, *, allow_empty: bool = False) -> list[PlanTask]:
    if not path.is_file():
        raise OrchestratorError(f"Plan file does not exist: {path}")

    visible_text = strip_html_comments(path.read_text(encoding="utf-8"))
    tasks: list[PlanTask] = []
    current_id: str | None = None
    current_title = ""
    current_body: list[str] = []

    def finish_task() -> None:
        nonlocal current_id, current_title, current_body
        if current_id is None:
            return
        tasks.append(
            PlanTask(
                task_id=current_id,
                title=current_title or current_id,
                body="\n".join(current_body).strip(),
                index=len(tasks),
            )
        )
        current_id = None
        current_title = ""
        current_body = []

    for line in visible_text.splitlines():
        match = TASK_HEADING_RE.match(line.strip())
        if match:
            finish_task()
            current_id = match.group("task_id").upper()
            current_title = (
                match.group("title_separator")
                or match.group("title_whitespace")
                or current_id
            ).strip()
            continue
        if current_id is not None:
            current_body.append(line)
    finish_task()

    seen: set[str] = set()
    duplicates: set[str] = set()
    for task in tasks:
        if task.task_id in seen:
            duplicates.add(task.task_id)
        seen.add(task.task_id)
    if duplicates:
        raise OrchestratorError(
            f"Duplicate task identifiers in {path}: {', '.join(sorted(duplicates))}"
        )
    if not tasks and not allow_empty:
        raise OrchestratorError(
            f"No executable TASK- sections found in {path}. Add a section such as "
            "'## TASK-001: Implement ...'."
        )
    return tasks


def plan_digest(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def default_state(
    plan_path: Path,
    repository: Path,
    main_branch: str,
    tasks: Sequence[PlanTask],
) -> dict[str, Any]:
    return {
        "version": STATE_VERSION,
        "plan": str(plan_path),
        "plan_sha256": plan_digest(plan_path),
        "repository": str(repository),
        "main_branch": main_branch,
        "created_at": utc_now(),
        "updated_at": utc_now(),
        "current_task_id": None,
        "repo_slug": None,
        "tasks": {
            task.task_id: {
                "title": task.title,
                "status": "pending",
                "branch": None,
                "pr_number": None,
                "pr_url": None,
                "review_iteration": 0,
            }
            for task in tasks
        },
    }


def load_state(
    path: Path,
    plan_path: Path,
    repository: Path,
    main_branch: str,
    tasks: Sequence[PlanTask],
    reset: bool,
) -> dict[str, Any]:
    if reset or not path.exists():
        return default_state(plan_path, repository, main_branch, tasks)

    try:
        state = json.loads(path.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as exc:
        raise OrchestratorError(f"Cannot read state file {path}: {exc}") from exc
    if state.get("version") != STATE_VERSION:
        raise OrchestratorError(
            f"Unsupported state version in {path}: {state.get('version')!r}; "
            "use --reset-state after reviewing the file"
        )
    if state.get("plan_sha256") != plan_digest(plan_path):
        raise OrchestratorError(
            f"{plan_path} changed since the state file was created; use --reset-state "
            "only if intentionally restarting the workflow"
        )
    if state.get("main_branch") != main_branch:
        raise OrchestratorError(
            f"State main branch is {state.get('main_branch')!r}, requested {main_branch!r}"
        )

    expected_ids = [task.task_id for task in tasks]
    state_ids = list((state.get("tasks") or {}).keys())
    if state_ids != expected_ids:
        raise OrchestratorError(
            "Task order or identifiers differ from the saved state; use --reset-state "
            "only after checking for duplicated or skipped work"
        )
    for task in tasks:
        state["tasks"][task.task_id]["title"] = task.title
    return state


def save_state(path: Path, state: dict[str, Any]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    state["updated_at"] = utc_now()
    temporary = path.with_name(f"{path.name}.tmp")
    temporary.write_text(
        json.dumps(state, ensure_ascii=False, indent=2) + "\n",
        encoding="utf-8",
    )
    os.replace(temporary, path)


def render_prompt(template_path: Path, replacements: dict[str, str]) -> str:
    try:
        prompt = template_path.read_text(encoding="utf-8")
    except OSError as exc:
        raise OrchestratorError(f"Cannot read prompt template {template_path}: {exc}") from exc
    for key, value in replacements.items():
        prompt = prompt.replace("{" + key + "}", value)
    return prompt


class CommandRunner:
    def __init__(self, dry_run: bool, logger: logging.Logger):
        self.dry_run = dry_run
        self.logger = logger

    @staticmethod
    def display(argv: Sequence[str]) -> str:
        return shlex.join(str(item) for item in argv)

    def run(
        self,
        argv: Sequence[str],
        cwd: Path,
        *,
        check: bool = True,
        capture_output: bool = True,
        stream_output: bool = False,
        input_text: str | None = None,
        env: dict[str, str] | None = None,
    ) -> subprocess.CompletedProcess[str]:
        command = [str(item) for item in argv]
        self.logger.info("$ %s", self.display(command))
        if self.dry_run:
            self.logger.info("dry-run: command not executed")
            return subprocess.CompletedProcess(command, 0, "", "")

        if stream_output:
            return self.run_streaming(
                command,
                cwd,
                check=check,
                input_text=input_text,
                env=env,
            )

        try:
            result = subprocess.run(
                command,
                cwd=str(cwd),
                input=input_text,
                text=True,
                capture_output=capture_output,
                env=env,
                check=False,
            )
        except OSError as exc:
            raise OrchestratorError(f"Cannot execute {command[0]!r}: {exc}") from exc
        if capture_output and result.returncode != 0:
            details = "\n".join(part for part in (result.stdout, result.stderr) if part).strip()
            if details:
                self.logger.error("Command output:\n%s", details[-12000:])
        if check and result.returncode != 0:
            raise OrchestratorError(
                f"Command failed with exit code {result.returncode}: {self.display(command)}"
            )
        return result

    def run_streaming(
        self,
        command: Sequence[str],
        cwd: Path,
        *,
        check: bool,
        input_text: str | None,
        env: dict[str, str] | None,
    ) -> subprocess.CompletedProcess[str]:
        try:
            process = subprocess.Popen(
                list(command),
                cwd=str(cwd),
                stdin=subprocess.PIPE if input_text is not None else None,
                stdout=subprocess.PIPE,
                stderr=subprocess.STDOUT,
                text=True,
                bufsize=1,
                env=env,
            )
        except OSError as exc:
            raise OrchestratorError(f"Cannot execute {command[0]!r}: {exc}") from exc

        if input_text is not None and process.stdin is not None:
            try:
                process.stdin.write(input_text)
                process.stdin.close()
            except BrokenPipeError:
                pass

        captured: list[str] = []
        captured_length = 0
        if process.stdout is not None:
            for line in process.stdout:
                self.logger.info("codex: %s", line.rstrip())
                captured.append(line)
                captured_length += len(line)
                if captured_length > 40000:
                    removed = captured.pop(0)
                    captured_length -= len(removed)
        return_code = process.wait()
        output = "".join(captured)
        if check and return_code != 0:
            raise OrchestratorError(
                f"Command failed with exit code {return_code}: {self.display(command)}"
            )
        return subprocess.CompletedProcess(command, return_code, output, "")


class Repository:
    def __init__(self, runner: CommandRunner, path: Path, remote: str, main_branch: str):
        self.runner = runner
        self.path = path
        self.remote = remote
        self.main_branch = main_branch
        self.git = "git"

    def git_output(self, args: Sequence[str], *, check: bool = True) -> str:
        result = self.runner.run([self.git, *args], self.path, check=check)
        return (result.stdout or "").strip()

    def ensure_repository(self) -> None:
        if not self.path.is_dir():
            raise OrchestratorError(f"Repository directory does not exist: {self.path}")
        root = Path(self.git_output(["rev-parse", "--show-toplevel"])).resolve()
        if root != self.path.resolve():
            raise OrchestratorError(f"--repo must point to the git root: {root}")

    def current_branch(self) -> str:
        branch = self.git_output(["symbolic-ref", "--quiet", "--short", "HEAD"], check=False)
        if not branch:
            raise OrchestratorError("Repository is in a detached HEAD state")
        return branch

    def is_clean(self) -> bool:
        return not bool(self.git_output(["status", "--porcelain=v1", "--untracked-files=all"]))

    def ensure_clean(self, reason: str) -> None:
        if self.is_clean():
            return
        status = self.git_output(["status", "--short", "--untracked-files=all"])
        raise OrchestratorError(
            f"Worktree must be clean before {reason}. Existing changes:\n{status}"
        )

    def sync_main(self) -> None:
        self.ensure_clean("synchronizing main")
        if self.current_branch() != self.main_branch:
            self.git_output(["checkout", self.main_branch])
        self.git_output(["fetch", self.remote])
        self.git_output(["pull", "--ff-only", self.remote, self.main_branch])

    def checkout_task_branch(self, branch: str, *, allow_dirty: bool = False) -> None:
        if not allow_dirty:
            self.ensure_clean(f"checking out {branch}")
        existing = self.runner.run(
            [self.git, "show-ref", "--verify", "--quiet", f"refs/heads/{branch}"],
            self.path,
            check=False,
        )
        if existing.returncode == 0:
            self.git_output(["checkout", branch])
            return
        if self.current_branch() != self.main_branch:
            raise OrchestratorError(
                f"Cannot create {branch} while current branch is {self.current_branch()}"
            )
        self.git_output(["checkout", "-b", branch])

    def commit_and_push(self, branch: str, message: str) -> None:
        self.git_output(["diff", "--check"])
        if not self.is_clean():
            self.git_output(["add", "--all"])
            self.git_output(["commit", "-m", message])
        ahead = self.git_output(["rev-list", "--count", f"{self.main_branch}..HEAD"])
        if ahead == "0":
            raise OrchestratorError(
                "Codex left no changes and the task branch has no commit ahead of main"
            )
        # Tests run explicitly before every call to commit_and_push, so invoking
        # the Git pre-push hook here would duplicate the same expensive gate.
        self.git_output(
            ["push", "--no-verify", "--set-upstream", self.remote, branch]
        )


class GitHub:
    def __init__(self, runner: CommandRunner, repository: Path, gh_bin: str):
        self.runner = runner
        self.repository = repository
        self.gh = gh_bin
        self.repo_slug: str | None = None

    def json_command(self, args: Sequence[str], *, check: bool = True) -> Any:
        result = self.runner.run([self.gh, *args], self.repository, check=check)
        output = (result.stdout or "").strip()
        if not output:
            return None
        try:
            return json.loads(output)
        except json.JSONDecodeError as exc:
            raise OrchestratorError(f"Expected JSON from gh, got: {output[:500]!r}") from exc

    def discover_repo_slug(self) -> str:
        data = self.json_command(["repo", "view", "--json", "nameWithOwner"])
        slug = str((data or {}).get("nameWithOwner", "")).strip()
        if not slug:
            raise OrchestratorError("gh did not return a repository name")
        self.repo_slug = slug
        return slug

    def pr_snapshot(self, pr_number: int) -> dict[str, Any]:
        data = self.json_command(
            [
                "pr",
                "view",
                str(pr_number),
                "--json",
                "number,url,state,headRefName,baseRefName,mergedAt,reviews,comments,"
                "reviewDecision,statusCheckRollup,mergeStateStatus",
            ]
        )
        if not isinstance(data, dict):
            raise OrchestratorError(f"gh returned no pull-request data for #{pr_number}")
        return data

    def find_open_pr(self, branch: str) -> dict[str, Any] | None:
        data = self.json_command(
            ["pr", "list", "--head", branch, "--state", "open", "--json", "number,url"]
        )
        if not data:
            return None
        if not isinstance(data, list):
            raise OrchestratorError("Unexpected gh response while searching for a pull request")
        return data[0] if data else None

    def create_pr(self, branch: str, title: str, body: str, base: str) -> dict[str, Any]:
        self.runner.run(
            [
                self.gh,
                "pr",
                "create",
                "--base",
                base,
                "--head",
                branch,
                "--title",
                title,
                "--body",
                body,
            ],
            self.repository,
        )
        pr = self.find_open_pr(branch)
        if not pr:
            raise OrchestratorError(f"Pull request was created but cannot be found for {branch}")
        return pr

    def request_review(self, pr_number: int, task_id: str, iteration: int) -> None:
        body = (
            "@codex review\n\n"
            "Review this pull request for actionable correctness, regression, test, "
            "security, and maintainability findings.\n\n"
            f"<!-- codex-orchestrator: task={task_id}; iteration={iteration} -->"
        )
        self.runner.run(
            [self.gh, "pr", "comment", str(pr_number), "--body", body],
            self.repository,
        )

    def review_comments(self, pr_number: int) -> list[dict[str, Any]]:
        if not self.repo_slug:
            self.discover_repo_slug()
        data = self.json_command(
            [
                "api",
                "--paginate",
                "--slurp",
                f"repos/{self.repo_slug}/pulls/{pr_number}/comments",
            ]
        )
        if not data:
            return []
        if isinstance(data, list) and all(isinstance(page, list) for page in data):
            return [item for page in data for item in page if isinstance(item, dict)]
        if isinstance(data, list):
            return [item for item in data if isinstance(item, dict)]
        raise OrchestratorError("Unexpected gh response while reading review comments")

    def checks(
        self, pr_number: int, required_names: Sequence[str]
    ) -> tuple[int, list[dict[str, Any]]]:
        args = [
            "pr",
            "checks",
            str(pr_number),
            "--json",
            "bucket,name,state,link,workflow",
        ]
        if not required_names:
            args.insert(3, "--required")
        result = self.runner.run([self.gh, *args], self.repository, check=False)
        output = (result.stdout or "").strip()
        if not output:
            error_output = (result.stderr or "").strip().lower()
            if not required_names and "no required checks reported" in error_output:
                return 0, []
            if result.returncode not in (0, 8):
                raise OrchestratorError("gh could not read pull-request checks")
            return result.returncode, []
        try:
            data = json.loads(output)
        except json.JSONDecodeError as exc:
            raise OrchestratorError(
                f"Expected JSON from gh pr checks, got: {output[:500]!r}"
            ) from exc
        if not isinstance(data, list):
            raise OrchestratorError("Unexpected gh response while reading pull-request checks")
        return result.returncode, [item for item in data if isinstance(item, dict)]

    def merge_squash(self, pr_number: int) -> None:
        self.runner.run(
            [self.gh, "pr", "merge", str(pr_number), "--squash", "--delete-branch"],
            self.repository,
        )


class FileLock:
    def __init__(self, path: Path):
        self.path = path
        self.acquired = False

    def __enter__(self) -> "FileLock":
        self.path.parent.mkdir(parents=True, exist_ok=True)
        try:
            descriptor = os.open(self.path, os.O_CREAT | os.O_EXCL | os.O_WRONLY, 0o600)
        except FileExistsError as exc:
            raise OrchestratorError(
                f"Another orchestrator appears to be running ({self.path}); "
                "remove the lock only after verifying no process is active"
            ) from exc
        with os.fdopen(descriptor, "w", encoding="utf-8") as stream:
            stream.write(f"pid={os.getpid()}\nstarted_at={utc_now()}\n")
        self.acquired = True
        return self

    def __exit__(self, exc_type: Any, exc_value: Any, traceback: Any) -> None:
        if self.acquired:
            try:
                self.path.unlink()
            except FileNotFoundError:
                pass


class Orchestrator:
    def __init__(self, args: argparse.Namespace, logger: logging.Logger):
        self.args = args
        self.logger = logger
        self.runner = CommandRunner(args.dry_run, logger)
        self.repository_path = args.repo.resolve()
        self.plan_path = args.plan.resolve()
        self.state_path = args.state_file.resolve()
        self.tasks = parse_plan(self.plan_path, allow_empty=args.dry_run)
        self.state = load_state(
            self.state_path,
            self.plan_path,
            self.repository_path,
            args.main_branch,
            self.tasks,
            args.reset_state,
        )
        self.repository = Repository(
            self.runner,
            self.repository_path,
            args.remote,
            args.main_branch,
        )
        self.github = GitHub(self.runner, self.repository_path, args.gh_bin)
        self.codex_bin = args.codex_bin
        self.review_authors = {author.lower() for author in args.review_authors}

    def persist(self) -> None:
        if not self.args.dry_run:
            save_state(self.state_path, self.state)

    def task_record(self, task: PlanTask) -> dict[str, Any]:
        return self.state["tasks"][task.task_id]

    def transition(self, task: PlanTask, status: str, **updates: Any) -> None:
        record = self.task_record(task)
        record["status"] = status
        record.update(updates)
        self.state["current_task_id"] = None if status == "merged" else task.task_id
        self.persist()
        self.logger.info("[%s] status=%s", task.task_id, status)

    def branch_name(self, task: PlanTask) -> str:
        record = self.task_record(task)
        if record.get("branch"):
            return str(record["branch"])
        slug = re.sub(
            r"[^a-z0-9]+", "-", f"{task.task_id}-{task.title}".lower()
        ).strip("-")
        branch = f"codex/{slug}"[:100].rstrip("-/.")
        record["branch"] = branch
        self.persist()
        return branch

    @staticmethod
    def usage_limit_detected(output: str) -> bool:
        return bool(USAGE_LIMIT_RE.search(output))

    def retry_seconds_from_output(self, output: str) -> int:
        retry_match = RETRY_AFTER_RE.search(output)
        if retry_match:
            amount = float(retry_match.group("amount"))
            unit = (retry_match.group("unit") or "seconds").lower()
            if unit.startswith("h"):
                return max(1, round(amount * 60 * 60))
            if unit.startswith("m"):
                return max(1, round(amount * 60))
            return max(1, round(amount))

        absolute_match = ABSOLUTE_RETRY_RE.search(output)
        if absolute_match:
            now = datetime.now().astimezone()
            hour = int(absolute_match.group("hour")) % 12
            if absolute_match.group("period").lower() == "pm":
                hour += 12
            candidate = now.replace(
                hour=hour,
                minute=int(absolute_match.group("minute")),
                second=0,
                microsecond=0,
            )
            seconds = (candidate - now).total_seconds()
            if seconds <= 0:
                candidate += timedelta(days=1)
                seconds = (candidate - now).total_seconds()
            # CLI reset times are always near-term. A clock time more than
            # twelve hours away is treated as already elapsed.
            if 0 < seconds <= 12 * 60 * 60:
                return max(1, round(seconds))
            return 1

        duration_matches = list(DURATION_PART_RE.finditer(output))
        if duration_matches and re.search(
            r"(?:reset|available|again|limit)", output, re.IGNORECASE
        ):
            seconds = 0.0
            for match in duration_matches:
                amount = float(match.group("amount"))
                unit = match.group("unit").lower()
                if unit.startswith("h"):
                    seconds += amount * 60 * 60
                elif unit.startswith("m"):
                    seconds += amount * 60
                else:
                    seconds += amount
            if seconds > 0:
                return max(1, round(seconds))
        return self.args.limit_window_seconds

    def wait_until(self, task: PlanTask, resume_epoch: float, reason: str) -> None:
        while True:
            remaining = resume_epoch - time.time()
            if remaining <= 0:
                return
            self.logger.warning(
                "[%s] %s; retry in %s (%.0fs remaining)",
                task.task_id,
                reason,
                datetime.fromtimestamp(resume_epoch).astimezone().isoformat(timespec="minutes"),
                remaining,
            )
            time.sleep(min(60, remaining))

    def resume_quota_wait(self, task: PlanTask) -> None:
        record = self.task_record(task)
        parsed_resume_epoch = time.time() + self.retry_seconds_from_output(
            str(record.get("quota_message") or "")
        ) + self.args.limit_buffer_seconds
        stored_resume_epoch = float(record.get("quota_resume_epoch") or parsed_resume_epoch)
        resume_epoch = min(stored_resume_epoch, parsed_resume_epoch)
        self.wait_until(task, resume_epoch, "Codex usage limit is active")
        previous_status = str(record.get("quota_previous_status") or "implementing")
        if previous_status == "fixing" and REVIEW_QUOTA_RE.search(
            str(record.get("review_findings") or "")
        ):
            previous_status = "pushed"
            record["review_iteration"] = max(
                0, int(record.get("review_iteration") or 0) - 1
            )
        self.transition(
            task,
            previous_status,
            quota_resumed_at=utc_now(),
            quota_resume_at=None,
            quota_resume_epoch=None,
        )

    def resume_review_quota_wait(self, task: PlanTask) -> None:
        record = self.task_record(task)
        resume_epoch = float(record.get("quota_resume_epoch") or time.time())
        self.wait_until(task, resume_epoch, "Codex code-review limit is active")
        self.transition(
            task,
            "pushed",
            quota_resumed_at=utc_now(),
            quota_resume_at=None,
            quota_resume_epoch=None,
        )

    def codex_command(
        self,
        task: PlanTask,
        prompt: str,
        model: str,
        previous_status: str,
    ) -> None:
        quota_attempts = int(self.task_record(task).get("quota_attempts") or 0)
        while True:
            self.logger.info(
                "[%s] running Codex model %s%s",
                task.task_id,
                model,
                " (retry after usage limit)" if quota_attempts else "",
            )
            command = [
                self.codex_bin,
                "exec",
                "--cd",
                str(self.repository_path),
                "--color",
                "never",
            ]
            if model:
                command.extend(["--model", model])
            command.extend(self.args.codex_args)
            command.append("-")
            result = self.runner.run(
                command,
                self.repository_path,
                check=False,
                capture_output=False,
                stream_output=True,
                input_text=prompt,
            )
            if result.returncode == 0:
                return
            output = result.stdout or ""
            if not self.usage_limit_detected(output):
                raise OrchestratorError(
                    f"Codex command failed with exit code {result.returncode} for "
                    f"{task.task_id}: {output[-4000:].strip()}"
                )

            quota_attempts += 1
            if self.args.max_quota_retries and quota_attempts > self.args.max_quota_retries:
                raise OrchestratorError(
                    f"Codex usage-limit retries exhausted for {task.task_id}: "
                    f"{self.args.max_quota_retries}"
                )
            wait_seconds = self.retry_seconds_from_output(output) + self.args.limit_buffer_seconds
            resume_epoch = time.time() + wait_seconds
            self.transition(
                task,
                "quota_wait",
                quota_previous_status=previous_status,
                quota_model=model,
                quota_attempts=quota_attempts,
                quota_resume_at=datetime.fromtimestamp(resume_epoch, timezone.utc).isoformat(),
                quota_resume_epoch=resume_epoch,
                quota_message=output[-4000:].strip(),
            )
            self.wait_until(task, resume_epoch, f"Codex usage limit for {model}")
            self.transition(
                task,
                previous_status,
                quota_resumed_at=utc_now(),
                quota_resume_at=None,
                quota_resume_epoch=None,
            )

    def run_codex_implementation(self, task: PlanTask) -> None:
        prompt = render_prompt(
            self.args.implement_prompt,
            {
                "task_id": task.task_id,
                "task_title": task.title,
                "task_body": task.body or "No additional task description was provided.",
                "test_command": self.args.test_command,
                "review_findings": "",
            },
        )
        self.codex_command(
            task,
            prompt,
            self.args.implementation_model,
            "implementing",
        )

    def run_codex_fix(self, task: PlanTask, findings: str) -> None:
        prompt = render_prompt(
            self.args.fix_prompt,
            {
                "task_id": task.task_id,
                "task_title": task.title,
                "task_body": task.body or "No additional task description was provided.",
                "test_command": self.args.test_command,
                "review_findings": findings,
            },
        )
        self.codex_command(task, prompt, self.args.fix_model, "fixing")

    def run_tests(self, task: PlanTask) -> None:
        if self.args.skip_tests:
            self.logger.warning("[%s] tests explicitly skipped", task.task_id)
            return
        self.runner.run(
            ["sh", "-c", self.args.test_command],
            self.repository_path,
            capture_output=False,
        )

    @staticmethod
    def author_login(value: Any) -> str:
        if isinstance(value, dict):
            return str(value.get("login") or "").lower()
        return str(value or "").lower()

    def is_codex_author(self, value: Any) -> bool:
        return self.author_login(value) in self.review_authors

    @staticmethod
    def object_id(item: dict[str, Any]) -> str:
        return str(item.get("id") or item.get("databaseId") or "")

    def review_baseline(self, pr_number: int) -> dict[str, list[str]]:
        snapshot = self.github.pr_snapshot(pr_number)
        reviews = snapshot.get("reviews") or []
        issue_comments = snapshot.get("comments") or []
        comments = self.github.review_comments(pr_number)
        return {
            "reviews": [self.object_id(item) for item in reviews if isinstance(item, dict)],
            "issue_comments": [
                self.object_id(item) for item in issue_comments if isinstance(item, dict)
            ],
            "comments": [self.object_id(item) for item in comments if isinstance(item, dict)],
        }

    def new_review_evidence(
        self,
        snapshot: dict[str, Any],
        inline_comments: Iterable[dict[str, Any]],
        baseline: dict[str, list[str]],
        requested_at: str,
    ) -> tuple[list[dict[str, Any]], list[dict[str, Any]], list[dict[str, Any]]]:
        baseline_reviews = set(baseline.get("reviews", []))
        baseline_issue_comments = set(baseline.get("issue_comments", []))
        baseline_comments = set(baseline.get("comments", []))
        reviews: list[dict[str, Any]] = []
        for item in snapshot.get("reviews") or []:
            if not isinstance(item, dict) or not self.is_codex_author(item.get("author")):
                continue
            item_id = self.object_id(item)
            submitted_at = str(item.get("submittedAt") or "")
            if item_id not in baseline_reviews and (not submitted_at or submitted_at >= requested_at):
                reviews.append(item)
        issue_comments: list[dict[str, Any]] = []
        for item in snapshot.get("comments") or []:
            if not isinstance(item, dict) or not self.is_codex_author(item.get("author")):
                continue
            item_id = self.object_id(item)
            created_at = str(item.get("createdAt") or "")
            if item_id not in baseline_issue_comments and (
                not created_at or created_at >= requested_at
            ):
                issue_comments.append(item)
        comments: list[dict[str, Any]] = []
        for item in inline_comments:
            if not isinstance(item, dict) or not self.is_codex_author(item.get("user")):
                continue
            item_id = self.object_id(item)
            created_at = str(item.get("created_at") or "")
            if item_id not in baseline_comments and (not created_at or created_at >= requested_at):
                comments.append(item)
        return reviews, issue_comments, comments

    @staticmethod
    def review_body_is_clean(body: str) -> bool:
        normalized = re.sub(r"[`*_#>\n\r]", " ", body).strip()
        if not normalized:
            return False
        if not CLEAN_REVIEW_RE.search(normalized):
            return False
        remaining = CLEAN_REVIEW_RE.sub("", normalized)
        return not ACTIONABLE_REVIEW_RE.search(remaining)

    @staticmethod
    def format_findings(
        reviews: Sequence[dict[str, Any]], comments: Sequence[dict[str, Any]]
    ) -> str:
        sections: list[str] = []
        for review in reviews:
            state = str(review.get("state") or "COMMENTED")
            body = str(review.get("body") or "").strip()
            if state == "CHANGES_REQUESTED" or body:
                sections.append(f"Codex review ({state}):\n{body or '(no summary)'}")
        for comment in comments:
            path = str(comment.get("path") or "unknown file")
            line = comment.get("line") or comment.get("original_line") or "?"
            body = str(comment.get("body") or "").strip()
            sections.append(f"Inline finding ({path}:{line}):\n{body or '(empty finding)'}")
        result = "\n\n".join(section for section in sections if section.strip())
        return result[:20000] or (
            "Codex requested changes but did not provide a readable finding. "
            "Inspect the PR review directly."
        )

    def classify_review(
        self,
        snapshot: dict[str, Any],
        inline_comments: Sequence[dict[str, Any]],
        baseline: dict[str, list[str]],
        requested_at: str,
    ) -> ReviewResult | None:
        reviews, issue_comments, comments = self.new_review_evidence(
            snapshot, inline_comments, baseline, requested_at
        )
        if not reviews and not issue_comments and not comments:
            return None
        if comments:
            return ReviewResult(clean=False, findings=self.format_findings(reviews, comments))

        if issue_comments:
            latest_comment = sorted(
                issue_comments,
                key=lambda item: str(item.get("createdAt") or ""),
            )[-1]
            body = str(latest_comment.get("body") or "").strip()
            if self.review_body_is_clean(body):
                return ReviewResult(clean=True)
            if REVIEW_QUOTA_RE.search(body):
                return ReviewResult(
                    clean=False,
                    findings=f"Codex PR comment:\n{body}",
                    quota_limited=True,
                )
            return ReviewResult(
                clean=False,
                findings=f"Codex PR comment:\n{body or '(empty finding)'}",
            )

        latest = sorted(
            reviews,
            key=lambda item: str(item.get("submittedAt") or item.get("createdAt") or ""),
        )[-1]
        state = str(latest.get("state") or "").upper()
        body = str(latest.get("body") or "").strip()
        if state == "APPROVED":
            return ReviewResult(clean=True)
        if state == "CHANGES_REQUESTED":
            return ReviewResult(clean=False, findings=self.format_findings(reviews, comments))
        if state == "COMMENTED" and self.review_body_is_clean(body):
            return ReviewResult(clean=True)
        return ReviewResult(clean=False, findings=self.format_findings(reviews, comments))

    def wait_for_review(self, task: PlanTask, pr_number: int) -> ReviewResult:
        record = self.task_record(task)
        requested_at = str(record.get("review_requested_at") or utc_now())
        baseline = record.get("review_baseline") or {"reviews": [], "comments": []}
        deadline = time.monotonic() + self.args.review_timeout
        while True:
            snapshot = self.github.pr_snapshot(pr_number)
            inline_comments = self.github.review_comments(pr_number)
            result = self.classify_review(snapshot, inline_comments, baseline, requested_at)
            if result is not None:
                return result
            remaining = deadline - time.monotonic()
            if remaining <= 0:
                raise OrchestratorError(
                    f"Timed out waiting for Codex review of PR #{pr_number} for {task.task_id}"
                )
            self.logger.info(
                "[%s] waiting for Codex review of PR #%s (%.0fs remaining)",
                task.task_id,
                pr_number,
                remaining,
            )
            time.sleep(min(self.args.poll_interval, remaining))

    def run_review_loop(self, task: PlanTask, pr_number: int, branch: str) -> None:
        while True:
            record = self.task_record(task)
            iteration = int(record.get("review_iteration") or 0)
            status = str(record.get("status") or "pr_open")
            if status == "reviewing" and record.get("review_requested_at"):
                next_iteration = iteration
                result = self.wait_for_review(task, pr_number)
            else:
                if iteration >= self.args.max_review_iterations:
                    raise OrchestratorError(
                        f"Maximum Codex review iterations reached for {task.task_id}: "
                        f"{self.args.max_review_iterations}"
                    )
                baseline = self.review_baseline(pr_number)
                next_iteration = iteration + 1
                requested_at = utc_now()
                self.transition(task, "pr_open")
                self.github.request_review(pr_number, task.task_id, next_iteration)
                self.transition(
                    task,
                    "reviewing",
                    review_iteration=next_iteration,
                    review_requested_at=requested_at,
                    review_baseline=baseline,
                )
                result = self.wait_for_review(task, pr_number)
            if result.clean:
                self.logger.info("[%s] Codex review is clean", task.task_id)
                return
            if result.quota_limited:
                quota_attempts = (
                    int(self.task_record(task).get("quota_attempts") or 0) + 1
                )
                if (
                    self.args.max_quota_retries
                    and quota_attempts > self.args.max_quota_retries
                ):
                    raise OrchestratorError(
                        f"Codex code-review quota retries exhausted for {task.task_id}: "
                        f"{self.args.max_quota_retries}"
                    )
                retry_at = time.time() + self.args.limit_window_seconds
                self.transition(
                    task,
                    "review_quota_wait",
                    review_iteration=max(0, next_iteration - 1),
                    quota_attempts=quota_attempts,
                    review_findings=result.findings,
                    quota_resume_epoch=retry_at,
                    quota_resume_at=datetime.fromtimestamp(
                        retry_at, timezone.utc
                    ).isoformat(),
                )
                self.wait_until(task, retry_at, "Codex code-review limit is active")
                self.transition(task, "pushed")
                continue
            if next_iteration >= self.args.max_review_iterations:
                self.transition(
                    task,
                    "review_limit_reached",
                    review_findings=result.findings,
                )
                raise OrchestratorError(
                    f"Codex review still has actionable findings after {next_iteration} "
                    f"iterations for {task.task_id}:\n{result.findings}"
                )
            self.logger.warning("[%s] actionable review findings; starting fix", task.task_id)
            self.transition(task, "fixing", review_findings=result.findings)
            self.run_codex_fix(task, result.findings)
            self.transition(task, "testing")
            self.run_tests(task)
            self.transition(task, "tested")
            self.repository.commit_and_push(branch, f"{task.task_id}: address Codex review")
            self.transition(task, "pushed")

    def wait_for_checks(self, task: PlanTask, pr_number: int) -> None:
        deadline = time.monotonic() + self.args.checks_timeout
        while True:
            return_code, checks = self.github.checks(pr_number, self.args.required_checks)
            if self.args.required_checks:
                by_name = {str(item.get("name")): item for item in checks}
                missing = [name for name in self.args.required_checks if name not in by_name]
                if missing:
                    passed = False
                    summary = f"waiting for required checks: {', '.join(missing)}"
                else:
                    selected = [by_name[name] for name in self.args.required_checks]
                    failed = [item for item in selected if item.get("bucket") in FAILURE_BUCKETS]
                    passed = all(item.get("bucket") in SUCCESS_BUCKETS for item in selected)
                    summary = self.check_summary(failed, selected)
            else:
                failed = [item for item in checks if item.get("bucket") in FAILURE_BUCKETS]
                passed = bool(checks) and all(
                    item.get("bucket") in SUCCESS_BUCKETS for item in checks
                )
                if not checks and return_code == 0:
                    self.logger.warning(
                        "[%s] no required GitHub checks are configured/reported", task.task_id
                    )
                    return
                summary = self.check_summary(failed, checks)

            if any(item.get("bucket") in FAILURE_BUCKETS for item in checks):
                raise OrchestratorError(
                    f"Required GitHub check failed for {task.task_id}: {summary}"
                )
            if passed:
                self.logger.info("[%s] required GitHub checks passed", task.task_id)
                return
            remaining = deadline - time.monotonic()
            if remaining <= 0:
                raise OrchestratorError(
                    f"Timed out waiting for required GitHub checks on PR #{pr_number}"
                )
            self.logger.info(
                "[%s] %s (%.0fs remaining)", task.task_id, summary, remaining
            )
            time.sleep(min(self.args.poll_interval, remaining))

    @staticmethod
    def check_summary(failed: Sequence[dict[str, Any]], checks: Sequence[dict[str, Any]]) -> str:
        if failed:
            return ", ".join(
                f"{item.get('name', 'unnamed')}={item.get('state', item.get('bucket', 'unknown'))}"
                for item in failed
            )
        if not checks:
            return "no checks reported"
        return ", ".join(
            f"{item.get('name', 'unnamed')}={item.get('state', item.get('bucket', 'unknown'))}"
            for item in checks
        )

    def pull_request_body(self, task: PlanTask) -> str:
        criteria = task.body or "No additional acceptance criteria provided."
        return (
            f"## {task.task_id}\n\n"
            f"{task.title}\n\n"
            "## Plan item\n\n"
            f"{criteria}\n\n"
            "## Workflow\n\n"
            "This pull request is managed by `scripts/orchestrator.py`. "
            "Codex review findings are addressed in this branch before merge.\n"
        )

    def ensure_pull_request(self, task: PlanTask, branch: str) -> int:
        record = self.task_record(task)
        if record.get("pr_number"):
            pr_number = int(record["pr_number"])
            snapshot = self.github.pr_snapshot(pr_number)
            state = str(snapshot.get("state") or "").upper()
            if state == "MERGED":
                self.transition(task, "merged", merged_at=snapshot.get("mergedAt"))
                return pr_number
            if state == "CLOSED":
                raise OrchestratorError(f"Saved pull request #{pr_number} is closed, not merged")
            if not record.get("pr_url"):
                record["pr_url"] = snapshot.get("url")
                self.persist()
            return pr_number
        existing = self.github.find_open_pr(branch)
        if existing:
            pr_number = int(existing["number"])
            pr_url = existing.get("url")
            self.logger.info("[%s] reusing existing PR #%s", task.task_id, pr_number)
        else:
            created = self.github.create_pr(
                branch,
                f"{task.task_id}: {task.title}",
                self.pull_request_body(task),
                self.args.main_branch,
            )
            pr_number = int(created["number"])
            pr_url = created.get("url")
            self.logger.info("[%s] created PR #%s: %s", task.task_id, pr_number, pr_url)
        self.transition(task, "pr_open", pr_number=pr_number, pr_url=pr_url)
        return pr_number

    def prepare_task_branch(self, task: PlanTask, branch: str) -> None:
        record = self.task_record(task)
        status = str(record.get("status") or "pending")
        resumable_dirty = self.args.allow_dirty_resume and status in {
            "implementing",
            "fixing",
            "testing",
        }
        if status == "pending" or (
            not record.get("pr_number") and status in {"pushed", "tested"}
        ):
            self.repository.sync_main()
            self.repository.checkout_task_branch(branch)
        else:
            self.repository.checkout_task_branch(branch, allow_dirty=resumable_dirty)

    def finish_pending_test_and_push(self, task: PlanTask, branch: str) -> None:
        status = str(self.task_record(task).get("status") or "pending")
        if status == "testing":
            self.run_tests(task)
            self.transition(task, "tested")
        if str(self.task_record(task).get("status")) == "tested":
            self.repository.commit_and_push(branch, f"{task.task_id}: {task.title}")
            self.transition(task, "pushed")

    def finish_pending_review_fix(self, task: PlanTask, branch: str) -> None:
        status = str(self.task_record(task).get("status") or "")
        if status == "fixing":
            findings = str(self.task_record(task).get("review_findings") or "")
            self.run_codex_fix(task, findings)
            self.transition(task, "testing")
        self.finish_pending_test_and_push(task, branch)

    def process_task(self, task: PlanTask) -> None:
        record = self.task_record(task)
        if str(record.get("status") or "") == "quota_wait":
            self.resume_quota_wait(task)
            record = self.task_record(task)
        if str(record.get("status") or "") == "review_quota_wait":
            self.resume_review_quota_wait(task)
            record = self.task_record(task)
        branch = self.branch_name(task)
        self.logger.info("[%s] starting task %d: %s", task.task_id, task.index + 1, task.title)
        self.prepare_task_branch(task, branch)

        if not record.get("pr_number"):
            status = str(record.get("status") or "pending")
            if status in {"pending", "implementing"}:
                self.transition(task, "implementing")
                self.run_codex_implementation(task)
                self.transition(task, "testing")
            self.finish_pending_test_and_push(task, branch)
            pr_number = self.ensure_pull_request(task, branch)
        else:
            self.finish_pending_review_fix(task, branch)
            pr_number = self.ensure_pull_request(task, branch)

        current_status = str(self.task_record(task).get("status"))
        if current_status == "review_limit_reached":
            record = self.task_record(task)
            iteration = int(record.get("review_iteration") or 0)
            if iteration >= self.args.max_review_iterations:
                raise OrchestratorError(
                    f"Task {task.task_id} reached {iteration} Codex review iterations. "
                    "Inspect review_findings in the state file and resume with a larger "
                    "--max-review-iterations value to continue."
                )
            # The saved findings are the outstanding fix. Re-enter the normal
            # fix path so resuming with a larger iteration limit changes the
            # commit before asking Codex for another review.
            self.transition(task, "fixing")
            self.finish_pending_review_fix(task, branch)
            current_status = str(self.task_record(task).get("status"))
        if current_status in {"pr_open", "reviewing", "pushed"}:
            self.run_review_loop(task, pr_number, branch)
            self.transition(task, "checks")
            self.wait_for_checks(task, pr_number)
            self.transition(task, "awaiting_merge")
        elif current_status == "checks":
            self.wait_for_checks(task, pr_number)
            self.transition(task, "awaiting_merge")
        elif current_status == "awaiting_merge":
            self.logger.info("[%s] review and checks already passed", task.task_id)
        elif current_status == "merged":
            return
        elif current_status == "fixing" or current_status == "testing":
            raise OrchestratorError(
                f"Task {task.task_id} has unfinished review fixes; resume with "
                "--allow-dirty-resume after inspecting the worktree"
            )
        else:
            raise OrchestratorError(f"Unsupported task state for {task.task_id}: {current_status}")

        if not self.args.allow_merge:
            raise PausedWorkflow(
                f"Paused before merging PR #{pr_number}. Re-run with --execute --allow-merge "
                "after verifying the pull request."
            )
        self.github.merge_squash(pr_number)
        self.transition(task, "merged", merged_at=utc_now())
        self.repository.sync_main()

    def dry_run(self) -> None:
        self.logger.info(
            "Dry run: no git, Codex, gh, test, state, push, or merge command will run."
        )
        if not self.tasks:
            self.logger.warning("Plan contains no executable TASK- sections yet.")
            return
        for task in self.tasks:
            record = self.task_record(task)
            status = str(record.get("status") or "pending")
            if status == "merged":
                self.logger.info("[%s] already merged; skip", task.task_id)
                continue
            branch = self.branch_name(task)
            self.logger.info("[%s] %s -> branch %s", task.task_id, task.title, branch)
            self.logger.info(
                "[%s] would run Codex implementation with %s and: %s",
                task.task_id,
                self.args.implementation_model,
                self.args.test_command,
            )
            self.logger.info(
                "[%s] review fixes would use Codex model %s",
                task.task_id,
                self.args.fix_model,
            )
            self.logger.info(
                "[%s] would push, create PR, request @codex review, and wait for checks",
                task.task_id,
            )
            self.logger.info("[%s] would squash-merge only with --allow-merge", task.task_id)

    def run(self) -> None:
        if self.args.dry_run:
            self.dry_run()
            return
        if self.args.reset_state:
            self.persist()
        self.repository.ensure_repository()
        for command in (self.args.gh_bin, self.codex_bin):
            if shutil.which(command) is None and not Path(command).exists():
                raise OrchestratorError(f"Required executable not found: {command}")

        with FileLock(self.state_path.with_name("orchestrator.lock")):
            self.github.discover_repo_slug()
            self.state["repo_slug"] = self.github.repo_slug
            self.persist()
            for task in self.tasks:
                if self.task_record(task).get("status") == "merged":
                    continue
                self.process_task(task)
            self.state["current_task_id"] = None
            self.persist()
        self.logger.info("All plan tasks are merged.")


def detect_test_command(repository: Path) -> str:
    configured = os.environ.get("ORCHESTRATOR_TEST_COMMAND")
    if configured:
        return configured
    hook = repository / ".githooks" / "pre-push"
    if hook.is_file():
        return "./.githooks/pre-push"
    if (repository / "gradlew").is_file():
        return "./gradlew test --no-daemon"
    if (repository / "package.json").is_file():
        return "npm test"
    if (repository / "pyproject.toml").is_file() or (repository / "pytest.ini").is_file():
        return "pytest"
    return "true"


def build_parser() -> argparse.ArgumentParser:
    script_root = Path(__file__).resolve().parents[1]
    parser = argparse.ArgumentParser(
        description="Execute PLAN.md sequentially through Codex, GitHub review, checks, and merge gates."
    )
    mode = parser.add_mutually_exclusive_group()
    mode.add_argument(
        "--dry-run",
        action="store_true",
        help="Preview actions without executing or writing state (default).",
    )
    mode.add_argument(
        "--execute",
        action="store_true",
        help="Execute workflow mutations except merge unless explicitly allowed.",
    )
    parser.add_argument(
        "--repo",
        type=Path,
        default=script_root,
        help="Git repository root (default: script's repository).",
    )
    parser.add_argument("--plan", type=Path, default=None)
    parser.add_argument(
        "--state-file",
        type=Path,
        default=None,
    )
    parser.add_argument(
        "--reset-state",
        action="store_true",
        help="Start a new state file after an intentional restart.",
    )
    parser.add_argument(
        "--allow-dirty-resume",
        action="store_true",
        help="Allow interrupted implementation/fix states to resume with edits present.",
    )
    parser.add_argument(
        "--main-branch",
        default=env_or_default("ORCHESTRATOR_MAIN_BRANCH", "main"),
    )
    parser.add_argument(
        "--remote",
        default=env_or_default("ORCHESTRATOR_REMOTE", "origin"),
    )
    parser.add_argument("--test-command", default=None)
    parser.add_argument("--skip-tests", action="store_true", help="Skip the configured test command explicitly.")
    parser.add_argument("--codex-bin", default=env_or_default("CODEX_BIN", "codex"))
    parser.add_argument(
        "--implementation-model",
        default=env_or_default(
            "ORCHESTRATOR_IMPLEMENTATION_MODEL", DEFAULT_IMPLEMENTATION_MODEL
        ),
        help="Codex model used for new task implementation.",
    )
    parser.add_argument(
        "--fix-model",
        default=env_or_default("ORCHESTRATOR_FIX_MODEL", DEFAULT_FIX_MODEL),
        help="Codex model used for review-fix iterations.",
    )
    parser.add_argument(
        "--codex-model",
        dest="legacy_codex_model",
        default=None,
        help=argparse.SUPPRESS,
    )
    parser.add_argument(
        "--codex-args",
        default=env_or_default(
            "ORCHESTRATOR_CODEX_ARGS",
            "--approve-for-me --ephemeral",
        ),
        help="Additional arguments passed to codex exec, parsed with shell-style quoting.",
    )
    parser.add_argument("--gh-bin", default=env_or_default("GH_BIN", "gh"))
    parser.add_argument(
        "--review-author",
        dest="review_authors",
        action="append",
        default=None,
        help="Codex GitHub author login; repeat for multiple logins.",
    )
    parser.add_argument(
        "--required-check",
        dest="required_checks",
        action="append",
        default=None,
        help="Required check name; repeat for multiple checks.",
    )
    parser.add_argument(
        "--max-review-iterations",
        type=lambda value: parse_int(value, "max-review-iterations"),
        default=parse_int(
            env_or_default("ORCHESTRATOR_MAX_REVIEW_ITERATIONS", "8"),
            "max-review-iterations",
        ),
    )
    parser.add_argument(
        "--review-timeout",
        type=lambda value: parse_int(value, "review-timeout"),
        default=parse_int(env_or_default("ORCHESTRATOR_REVIEW_TIMEOUT", "1800"), "review-timeout"),
    )
    parser.add_argument(
        "--checks-timeout",
        type=lambda value: parse_int(value, "checks-timeout"),
        default=parse_int(env_or_default("ORCHESTRATOR_CHECKS_TIMEOUT", "1800"), "checks-timeout"),
    )
    parser.add_argument(
        "--poll-interval",
        type=lambda value: parse_int(value, "poll-interval"),
        default=parse_int(env_or_default("ORCHESTRATOR_POLL_INTERVAL", "30"), "poll-interval"),
    )
    parser.add_argument(
        "--limit-window-hours",
        type=lambda value: parse_float(value, "limit-window-hours"),
        default=parse_float(
            env_or_default(
                "ORCHESTRATOR_LIMIT_WINDOW_HOURS",
                str(DEFAULT_LIMIT_WINDOW_SECONDS / (60 * 60)),
            ),
            "limit-window-hours",
        ),
        help="Fallback wait window after a usage-limit error (default: 5 hours).",
    )
    parser.add_argument(
        "--limit-buffer-seconds",
        type=lambda value: parse_int(value, "limit-buffer-seconds"),
        default=parse_int(
            env_or_default("ORCHESTRATOR_LIMIT_BUFFER_SECONDS", "60"),
            "limit-buffer-seconds",
        ),
        help="Extra buffer added after a reported usage-limit reset time.",
    )
    parser.add_argument(
        "--max-quota-retries",
        type=lambda value: parse_int(value, "max-quota-retries"),
        default=parse_int(
            env_or_default("ORCHESTRATOR_MAX_QUOTA_RETRIES", "0"),
            "max-quota-retries",
        ),
        help="Maximum quota retries; 0 means wait and retry indefinitely.",
    )
    parser.add_argument(
        "--implement-prompt",
        type=Path,
        default=None,
    )
    parser.add_argument(
        "--fix-prompt",
        type=Path,
        default=None,
    )
    parser.add_argument("--log-file", type=Path, default=None)
    parser.add_argument(
        "--allow-merge",
        action="store_true",
        help="Allow real squash merge; never implied by --execute.",
    )
    return parser


def configure_logging(log_file: Path | None) -> logging.Logger:
    logger = logging.getLogger("orchestrator")
    logger.setLevel(logging.INFO)
    logger.handlers.clear()
    formatter = logging.Formatter(
        "%(asctime)s %(levelname)s %(message)s", datefmt="%Y-%m-%dT%H:%M:%S%z"
    )
    stream = logging.StreamHandler(sys.stdout)
    stream.setFormatter(formatter)
    logger.addHandler(stream)
    if log_file:
        log_file.parent.mkdir(parents=True, exist_ok=True)
        file_handler = logging.FileHandler(log_file, encoding="utf-8")
        file_handler.setFormatter(formatter)
        logger.addHandler(file_handler)
    return logger


def normalize_args(args: argparse.Namespace) -> argparse.Namespace:
    args.dry_run = not args.execute
    if args.legacy_codex_model:
        args.implementation_model = args.legacy_codex_model
        args.fix_model = args.legacy_codex_model
    repository = args.repo.resolve()
    args.plan = args.plan or repository / "PLAN.md"
    args.state_file = args.state_file or repository / ".agent" / "orchestrator-state.json"
    args.test_command = args.test_command or detect_test_command(repository)
    args.implement_prompt = (
        args.implement_prompt or repository / ".agent" / "prompts" / "implement.md"
    )
    args.fix_prompt = args.fix_prompt or repository / ".agent" / "prompts" / "fix-review.md"
    if args.max_review_iterations == 0:
        raise OrchestratorError("max-review-iterations must be greater than zero")
    if args.review_timeout == 0 or args.checks_timeout == 0:
        raise OrchestratorError("review-timeout and checks-timeout must be greater than zero")
    if args.poll_interval == 0:
        raise OrchestratorError("poll-interval must be greater than zero")
    if args.limit_buffer_seconds < 0:
        raise OrchestratorError("limit-buffer-seconds must be non-negative")
    args.limit_window_seconds = max(1, round(args.limit_window_hours * 60 * 60))
    args.limit_buffer_seconds = int(args.limit_buffer_seconds)
    args.codex_args = shlex.split(args.codex_args)
    if args.review_authors is None:
        args.review_authors = split_csv(
            env_or_default("ORCHESTRATOR_REVIEW_AUTHORS", ",".join(DEFAULT_REVIEW_AUTHORS))
        )
    if args.required_checks is None:
        args.required_checks = split_csv(os.environ.get("ORCHESTRATOR_REQUIRED_CHECKS", ""))
    env_merge = os.environ.get("ORCHESTRATOR_ALLOW_MERGE", "").lower() in {
        "1",
        "true",
        "yes",
    }
    args.allow_merge = args.allow_merge or env_merge
    return args


def main(argv: Sequence[str] | None = None) -> int:
    parser = build_parser()
    parsed = parser.parse_args(argv)
    try:
        args = normalize_args(parsed)
        logger = configure_logging(args.log_file)
        if args.dry_run:
            logger.info("Starting in safe dry-run mode; use --execute to perform workflow actions.")
        orchestrator = Orchestrator(args, logger)
        orchestrator.run()
        return 0
    except PausedWorkflow as exc:
        logging.getLogger("orchestrator").warning("%s", exc)
        return PAUSED_EXIT_CODE
    except OrchestratorError as exc:
        logging.getLogger("orchestrator").error("%s", exc)
        return 1
    except KeyboardInterrupt:
        logging.getLogger("orchestrator").warning(
            "Interrupted; saved state remains available for resume."
        )
        return 130


if __name__ == "__main__":
    raise SystemExit(main())
