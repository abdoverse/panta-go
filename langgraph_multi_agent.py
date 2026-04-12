from __future__ import annotations

import argparse
import hashlib
import json
import os
import re
import signal
import shutil
import subprocess
import time
from datetime import datetime, timezone
from pathlib import Path
from typing import Any, Optional, TypedDict

from langgraph.graph import END, StateGraph

try:
    from langchain_openai import ChatOpenAI
except ImportError:  # Optional at runtime when falling back to deterministic routing.
    ChatOpenAI = None


DEFAULT_PROJECT_PATH = Path(".").resolve()
DEFAULT_INSTRUCTIONS_FILE = Path(".github/copilot-instructions.md")
DEFAULT_MODEL = "gpt-5.4"
DEFAULT_BACKLOG_FILE = ".copilot/agent-backlog.txt"
DEFAULT_PLAN_FILE = ".copilot/agent-plan.md"
DEFAULT_DONE_FILE = ".copilot/agent-done.txt"
DEFAULT_WORKER_STATE_FILE = ".copilot/worker-state.json"
DEFAULT_AGENT_LOG_DIR = ".copilot/agent-logs"
VALID_CATEGORIES = ("backend", "frontend", "both")
VALID_PLAN_STATUSES = ("planned", "approved")
VALID_BACKLOG_STATUSES = ("pending", "approved", "in_progress", "done")
VALID_PRIORITIES = ("high", "medium", "low")
VALID_COMPLEXITIES = ("small", "medium", "large")
STALE_PROGRESS_MINUTES = 15
CLAIM_TIMEOUT_MINUTES = 5
NO_LOCAL_CHANGE_BLOCK_MINUTES = 2
MAX_QUIET_LOG_POLLS = 3
INITIAL_WORKER_STARTUP_QUIET_POLLS = 8
WORKER_REPORT_PREFIX = "ORCH_REPORT|"
WORKER_STEP_PREFIX = "ORCH_STEP|"
MAX_UNREPORTED_WORKER_ATTEMPTS = 3
IGNORED_DIRECTORIES = {
    ".git",
    ".dart_tool",
    ".idea",
    ".venv",
    "__pycache__",
    "build",
    "dist",
    "node_modules",
}


class AgentTask(TypedDict):
    agent: str
    instruction: str


class AgentReport(TypedDict):
    agent: str
    instruction: str
    phase: str
    activity: str
    next_command: str
    summary: str
    targets: list[str]
    commands: list[str]
    outcome: str


class AgentUpdate(TypedDict):
    agent: str
    updated_at: str
    phase: str
    activity: str
    next_command: str


class BacklogItem(TypedDict):
    id: str
    category: str
    title: str
    details: str
    status: str
    priority: str
    complexity: str
    dependencies: list[str]
    owner_agent: str
    started_at: str
    last_heartbeat_at: str
    last_progress_at: str
    progress_note: str
    blocked_reason: str
    agent_updates: list[AgentUpdate]


class WorkerLaunch(TypedDict):
    item_id: str
    agent_key: str
    pid: int
    started_at: str
    status: str
    log_path: str
    log_offset: int
    attempt_count: int
    last_log_at: str
    last_log_line: str
    last_log_signature: str
    last_report_state: str
    last_report_summary: str
    last_report_next: str
    last_step_action: str
    last_step_detail: str
    quiet_polls: int


class PlanItem(TypedDict):
    id: str
    category: str
    title: str
    details: str
    status: str
    priority: str
    complexity: str
    dependencies: list[str]


class State(TypedDict):
    repo_map: str
    instruction: str
    instructions_text: str
    tasks: list[AgentTask]
    reports: list[AgentReport]
    current_task: Optional[AgentTask]
    active_backlog_item: Optional[BacklogItem]
    active_backlog_items: list[BacklogItem]
    last_result: Optional[str]
    next_step: str
    iterations: int
    project_path: str
    max_iterations: int
    run_tests: bool
    model: str
    final_summary: str
    backlog: list[BacklogItem]
    backlog_path: str
    plan_path: str
    done_path: str
    approval_status: str
    heartbeat_only: bool


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description=(
            "Orchestrate backend, frontend, and tester agents with LangGraph "
            "using this repository's Copilot instructions."
        )
    )
    parser.add_argument(
        "--instruction",
        default=(
            "Follow .github/copilot-instructions.md and coordinate the backend_dev, "
            "frontend_dev, and tester agents for this repository."
        ),
        help="High-level orchestration instruction.",
    )
    parser.add_argument(
        "--project-path",
        default=str(DEFAULT_PROJECT_PATH),
        help="Repository path to inspect and orchestrate.",
    )
    parser.add_argument(
        "--instructions-file",
        default=str(DEFAULT_INSTRUCTIONS_FILE),
        help="Path to the Copilot instruction file relative to the project path.",
    )
    parser.add_argument(
        "--backlog-file",
        default=DEFAULT_BACKLOG_FILE,
        help="Project-relative backlog text file managed by the agent.",
    )
    parser.add_argument(
        "--plan-file",
        default=DEFAULT_PLAN_FILE,
        help="Project-relative current plan markdown file.",
    )
    parser.add_argument(
        "--done-file",
        default=DEFAULT_DONE_FILE,
        help="Project-relative text file that stores completed backlog items.",
    )
    parser.add_argument(
        "--backlog-seed",
        default="",
        help="Optional markdown plan file to import if the project backlog file does not exist yet.",
    )
    parser.add_argument(
        "--max-iterations",
        type=int,
        default=3,
        help="Maximum manager iterations before stopping.",
    )
    parser.add_argument(
        "--model",
        default=DEFAULT_MODEL,
        help="OpenAI model name when OPENAI_API_KEY is available.",
    )
    parser.add_argument(
        "--run-tests",
        action="store_true",
        help="Run detected validation commands in the tester agent.",
    )
    parser.add_argument(
        "--output",
        default="",
        help="Optional path to write the final orchestration JSON summary.",
    )
    parser.add_argument(
        "--recover-stalled",
        action="store_true",
        help="Recover claimed/stale tasks back to approved when they have no trustworthy progress.",
    )
    parser.add_argument(
        "--watch",
        action="store_true",
        help="Continuously watch the plan/backlog files and react to approval changes.",
    )
    parser.add_argument(
        "--poll-interval",
        type=int,
        default=10,
        help="Polling interval in seconds when --watch is enabled.",
    )
    return parser.parse_args()


def load_instructions(project_path: Path, instructions_file: str) -> str:
    candidate = (project_path / instructions_file).resolve()
    if not candidate.exists():
        return ""
    return candidate.read_text(encoding="utf-8").strip()


def get_repo_map(project_path: Path) -> str:
    files: list[str] = []
    for path in project_path.rglob("*"):
        if not path.is_file():
            continue
        if any(part in IGNORED_DIRECTORIES for part in path.parts):
            continue
        if path.suffix.lower() not in {
            ".dart",
            ".go",
            ".js",
            ".json",
            ".md",
            ".py",
            ".sh",
            ".ts",
            ".tsx",
            ".txt",
            ".yaml",
            ".yml",
        }:
            continue
        files.append(path.relative_to(project_path).as_posix())
    return "\n".join(sorted(files))


def extract_json(text: str) -> Optional[dict[str, Any]]:
    try:
        start = text.index("{")
        end = text.rindex("}") + 1
        return json.loads(text[start:end])
    except Exception:
        return None


def _extract_plan_section(content: str, heading: str) -> str:
    match = re.search(
        rf"^##\s+{re.escape(heading)}\s*$([\s\S]*?)(?=^##\s+|\Z)",
        content,
        flags=re.MULTILINE,
    )
    return match.group(1).strip() if match else ""


def _extract_numbered_plan_section(content: str, heading: str) -> str:
    match = re.search(
        rf"^##\s+\d+\.\s+{re.escape(heading)}\s*$([\s\S]*?)(?=^##\s+|\Z)",
        content,
        flags=re.MULTILINE,
    )
    return match.group(1).strip() if match else ""


def infer_category(title: str, details: str) -> str:
    title_text = title.lower()
    details_text = details.lower()
    frontend_hit_title = any(
        token in title_text
        for token in ("mobile", "flutter", "frontend", "screen", "web", "client")
    )
    backend_hit_title = any(
        token in title_text
        for token in (
            "backend",
            "api",
            "infra",
            "cdk",
            "dynamo",
            "cognito",
            "ecs",
            "fargate",
            "service",
            "go.mod",
        )
    )
    if frontend_hit_title and backend_hit_title:
        return "both"
    if frontend_hit_title:
        return "frontend"
    if backend_hit_title:
        return "backend"

    haystack = f"{title_text}\n{details_text}"
    frontend_hit = any(
        token in haystack
        for token in ("mobile", "flutter", "frontend", "screen", "web", "client")
    )
    backend_hit = any(
        token in haystack
        for token in (
            "backend",
            "api",
            "infra",
            "cdk",
            "dynamo",
            "cognito",
            "ecs",
            "fargate",
            "service",
            "go.mod",
        )
    )
    if frontend_hit and backend_hit:
        return "both"
    if frontend_hit:
        return "frontend"
    if backend_hit:
        return "backend"
    return "both"


def parse_dependencies(value: str) -> list[str]:
    stripped = value.strip()
    if not stripped or stripped.lower() in {"none", "-"}:
        return []
    return [part.strip() for part in stripped.split(",") if part.strip()]


def parse_agent_update(detail_line: str) -> Optional[AgentUpdate]:
    if not detail_line.lower().startswith("agent activity:"):
        return None
    payload = detail_line.split(":", 1)[1].strip()
    parts = [part.strip() for part in payload.split(" | ", 4)]
    if len(parts) != 5:
        return None
    return {
        "agent": parts[0],
        "updated_at": parts[1],
        "phase": parts[2],
        "activity": parts[3],
        "next_command": parts[4],
    }


def format_dependencies(dependencies: list[str]) -> str:
    return ",".join(dependencies) if dependencies else "none"


def priority_rank(priority: str) -> int:
    order = {"high": 0, "medium": 1, "low": 2}
    return order.get(priority, 1)


def complexity_rank(complexity: str) -> int:
    order = {"small": 0, "medium": 1, "large": 2}
    return order.get(complexity, 1)


def now_iso() -> str:
    return datetime.now(timezone.utc).isoformat()


def format_duration(started_at: str) -> str:
    if not started_at:
        return "unknown"
    try:
        started = datetime.fromisoformat(started_at)
        elapsed = datetime.now(timezone.utc) - started
        total_minutes = int(elapsed.total_seconds() // 60)
        hours, minutes = divmod(total_minutes, 60)
        if hours:
            return f"{hours}h {minutes}m"
        return f"{minutes}m"
    except Exception:
        return "unknown"


def elapsed_minutes(timestamp: str) -> Optional[int]:
    if not timestamp:
        return None
    try:
        started = datetime.fromisoformat(timestamp)
        return int((datetime.now(timezone.utc) - started).total_seconds() // 60)
    except Exception:
        return None


def assigned_agent_for_item(item: BacklogItem) -> str:
    if item["category"] == "backend":
        return "backend_dev"
    if item["category"] == "frontend":
        return "frontend_dev"
    return "backend_dev+frontend_dev"


def task_execution_state(item: BacklogItem) -> str:
    if item["blocked_reason"]:
        return "blocked"
    progress_age_minutes = elapsed_minutes(item["last_progress_at"])
    if progress_age_minutes is not None and progress_age_minutes > STALE_PROGRESS_MINUTES:
        return "stale"
    note = item["progress_note"].strip().lower()
    if not note or "awaiting next progress checkpoint" in note:
        return "claimed_no_checkpoint"
    return "progressing"


def should_recover_item(item: BacklogItem) -> bool:
    state = task_execution_state(item)
    if state == "claimed_no_checkpoint":
        age = elapsed_minutes(item["started_at"]) or 0
        return age >= CLAIM_TIMEOUT_MINUTES
    if state == "stale":
        return True
    return False


def load_backlog_from_seed(plan_path: str) -> list[BacklogItem]:
    if not plan_path:
        return []

    path = Path(plan_path).resolve()
    if not path.exists():
        return []

    content = path.read_text(encoding="utf-8")
    problem = _extract_plan_section(content, "Problem")
    approach = _extract_plan_section(content, "Approach")
    shared_context_parts = []
    if problem:
        shared_context_parts.append(f"Problem:\n{problem}")
    if approach:
        shared_context_parts.append(f"Approach:\n{approach}")
    shared_context = "\n\n".join(shared_context_parts).strip()
    suggested_features = _extract_numbered_plan_section(content, "Suggested features list")

    backlog: list[BacklogItem] = []
    if suggested_features:
        feature_matches = list(
            re.finditer(
                r"^\s*(\d+)\.\s+\*\*(.+?)\*\*\s*$",
                suggested_features,
                flags=re.MULTILINE,
            )
        )
        for index, match in enumerate(feature_matches):
            start = match.end()
            end = (
                feature_matches[index + 1].start()
                if index + 1 < len(feature_matches)
                else len(suggested_features)
            )
            details = suggested_features[start:end].strip()
            title = match.group(2).strip()
            backlog.append(
                {
                    "id": f"feature-{match.group(1)}",
                    "category": infer_category(title, details),
                    "title": title,
                    "details": details,
                    "status": "pending",
                    "priority": "medium",
                    "complexity": "medium",
                    "dependencies": [],
                    "owner_agent": "",
                    "started_at": "",
                    "last_heartbeat_at": "",
                    "last_progress_at": "",
                    "progress_note": "",
                    "blocked_reason": "",
                    "agent_updates": [],
                }
            )
        return backlog

    heading_matches = list(
        re.finditer(r"^###\s+(\d+)\.\s+(.+)$", content, flags=re.MULTILINE)
    )
    if heading_matches:
        for index, match in enumerate(heading_matches):
            start = match.end()
            end = (
                heading_matches[index + 1].start()
                if index + 1 < len(heading_matches)
                else len(content)
            )
            details = "\n\n".join(
                part for part in (shared_context, content[start:end].strip()) if part
            ).strip()
            title = match.group(2).strip()
            backlog.append(
                {
                    "id": match.group(1),
                    "category": infer_category(title, details),
                    "title": title,
                    "details": details,
                    "status": "pending",
                    "priority": "medium",
                    "complexity": "medium",
                    "dependencies": [],
                    "owner_agent": "",
                    "started_at": "",
                    "last_heartbeat_at": "",
                    "last_progress_at": "",
                    "progress_note": "",
                    "blocked_reason": "",
                    "agent_updates": [],
                }
            )
        return backlog

    todos = _extract_plan_section(content, "Todos")
    if not todos:
        return []

    for line in todos.splitlines():
        match = re.match(r"^\s*(\d+)\.\s+(.+?)\s*$", line)
        if not match:
            continue
        title = match.group(2).strip()
        backlog.append(
            {
                "id": match.group(1),
                "category": infer_category(title, shared_context),
                "title": title,
                "details": shared_context,
                "status": "pending",
                "priority": "medium",
                "complexity": "medium",
                "dependencies": [],
                "owner_agent": "",
                "started_at": "",
                "last_heartbeat_at": "",
                "last_progress_at": "",
                "progress_note": "",
                "blocked_reason": "",
                "agent_updates": [],
            }
        )
    return backlog


def parse_backlog_text(content: str) -> list[BacklogItem]:
    backlog: list[BacklogItem] = []
    current_category: Optional[str] = None
    current_item: Optional[BacklogItem] = None

    for raw_line in content.splitlines():
        line = raw_line.rstrip()
        section_match = re.match(r"^##\s+(backend|frontend|both)\s*$", line, re.IGNORECASE)
        if section_match:
            current_category = section_match.group(1).lower()
            current_item = None
            continue

        rich_item_match = re.match(
            r"^([A-Za-z0-9_-]+)\s*\|\s*(pending|approved|in_progress|done)\s*\|\s*"
            r"(high|medium|low)\s*\|\s*(small|medium|large)\s*\|\s*([^|]+?)\s*\|\s*(.+?)\s*$",
            line,
            re.IGNORECASE,
        )
        if rich_item_match and current_category in VALID_CATEGORIES:
            current_item = {
                "id": rich_item_match.group(1),
                "category": current_category,
                "title": rich_item_match.group(6).strip(),
                "details": "",
                "status": rich_item_match.group(2).lower(),
                "priority": rich_item_match.group(3).lower(),
                "complexity": rich_item_match.group(4).lower(),
                "dependencies": parse_dependencies(rich_item_match.group(5)),
                "owner_agent": "",
                "started_at": "",
                "last_heartbeat_at": "",
                "last_progress_at": "",
                "progress_note": "",
                "blocked_reason": "",
                "agent_updates": [],
            }
            backlog.append(current_item)
            continue

        item_match = re.match(
            r"^([A-Za-z0-9_-]+)\s*\|\s*(pending|approved|in_progress|done)\s*\|\s*(.+?)\s*$",
            line,
            re.IGNORECASE,
        )
        if item_match and current_category in VALID_CATEGORIES:
            current_item = {
                "id": item_match.group(1),
                "category": current_category,
                "title": item_match.group(3).strip(),
                "details": "",
                "status": item_match.group(2).lower(),
                "priority": "medium",
                "complexity": "medium",
                "dependencies": [],
                "owner_agent": "",
                "started_at": "",
                "last_heartbeat_at": "",
                "last_progress_at": "",
                "progress_note": "",
                "blocked_reason": "",
                "agent_updates": [],
            }
            backlog.append(current_item)
            continue

        if current_item is not None and (line.startswith("  ") or line.startswith("\t")):
            detail_line = line.lstrip()
            if detail_line.lower().startswith("owner agent:"):
                current_item["owner_agent"] = detail_line.split(":", 1)[1].strip()
                continue
            if detail_line.lower().startswith("started at:"):
                current_item["started_at"] = detail_line.split(":", 1)[1].strip()
                continue
            if detail_line.lower().startswith("last heartbeat at:"):
                current_item["last_heartbeat_at"] = detail_line.split(":", 1)[1].strip()
                continue
            if detail_line.lower().startswith("last progress at:"):
                current_item["last_progress_at"] = detail_line.split(":", 1)[1].strip()
                continue
            if detail_line.lower().startswith("progress note:"):
                current_item["progress_note"] = detail_line.split(":", 1)[1].strip()
                continue
            if detail_line.lower().startswith("assignment status:"):
                continue
            if detail_line.lower().startswith("blocked reason:"):
                current_item["blocked_reason"] = detail_line.split(":", 1)[1].strip()
                continue
            agent_update = parse_agent_update(detail_line)
            if agent_update is not None:
                current_item["agent_updates"].append(agent_update)
                continue
            current_item["details"] = (
                f"{current_item['details']}\n{detail_line}".strip()
                if current_item["details"]
                else detail_line
            )

    return backlog


def parse_plan_text(content: str) -> list[PlanItem]:
    plan_items: list[PlanItem] = []
    current_category: Optional[str] = None
    current_item: Optional[PlanItem] = None

    for raw_line in content.splitlines():
        line = raw_line.rstrip()
        section_match = re.match(r"^##\s+(backend|frontend|both)\s*$", line, re.IGNORECASE)
        if section_match:
            current_category = section_match.group(1).lower()
            current_item = None
            continue

        rich_item_match = re.match(
            r"^([A-Za-z0-9_-]+)\s*\|\s*(planned|approved)\s*\|\s*"
            r"(high|medium|low)\s*\|\s*(small|medium|large)\s*\|\s*([^|]+?)\s*\|\s*(.+?)\s*$",
            line,
            re.IGNORECASE,
        )
        if rich_item_match and current_category in VALID_CATEGORIES:
            current_item = {
                "id": rich_item_match.group(1),
                "category": current_category,
                "title": rich_item_match.group(6).strip(),
                "details": "",
                "status": rich_item_match.group(2).lower(),
                "priority": rich_item_match.group(3).lower(),
                "complexity": rich_item_match.group(4).lower(),
                "dependencies": parse_dependencies(rich_item_match.group(5)),
            }
            plan_items.append(current_item)
            continue

        item_match = re.match(
            r"^([A-Za-z0-9_-]+)\s*\|\s*(planned|approved)\s*\|\s*(.+?)\s*$",
            line,
            re.IGNORECASE,
        )
        if item_match and current_category in VALID_CATEGORIES:
            current_item = {
                "id": item_match.group(1),
                "category": current_category,
                "title": item_match.group(3).strip(),
                "details": "",
                "status": item_match.group(2).lower(),
                "priority": "medium",
                "complexity": "medium",
                "dependencies": [],
            }
            plan_items.append(current_item)
            continue

        if current_item is not None and (line.startswith("  ") or line.startswith("\t")):
            detail_line = line.lstrip()
            current_item["details"] = (
                f"{current_item['details']}\n{detail_line}".strip()
                if current_item["details"]
                else detail_line
            )

    return plan_items


def split_backlog_items(
    backlog: list[BacklogItem],
) -> tuple[list[BacklogItem], list[BacklogItem]]:
    active_items = [item for item in backlog if item["status"] != "done"]
    done_items = [item for item in backlog if item["status"] == "done"]
    return active_items, done_items


def move_approved_plan_items_to_backlog(
    plan_items: list[PlanItem], backlog: list[BacklogItem]
) -> tuple[list[PlanItem], list[BacklogItem]]:
    existing_ids = {item["id"] for item in backlog}
    remaining_plan: list[PlanItem] = []
    updated_backlog = list(backlog)

    for item in plan_items:
        if item["status"] == "approved":
            if item["id"] not in existing_ids:
                updated_backlog.append(
                    {
                        "id": item["id"],
                        "category": item["category"],
                        "title": item["title"],
                        "details": item["details"],
                        "status": "pending",
                        "priority": item["priority"],
                        "complexity": item["complexity"],
                        "dependencies": list(item["dependencies"]),
                        "owner_agent": "",
                        "started_at": "",
                        "last_heartbeat_at": "",
                        "last_progress_at": "",
                        "progress_note": "",
                        "blocked_reason": "",
                        "agent_updates": [],
                    }
                )
                existing_ids.add(item["id"])
            continue
        remaining_plan.append(item)

    return remaining_plan, updated_backlog


def dependencies_satisfied(item: BacklogItem, backlog: list[BacklogItem]) -> bool:
    items_by_id = {entry["id"]: entry for entry in backlog}
    for dependency in item["dependencies"]:
        dependency_item = items_by_id.get(dependency)
        if dependency_item is None or dependency_item["status"] != "done":
            return False
    return True


def collides_with_active(item: BacklogItem, active_items: list[BacklogItem]) -> bool:
    if not active_items:
        return False
    if item["category"] == "both":
        return True
    if any(active["category"] == "both" for active in active_items):
        return True
    return any(active["category"] == item["category"] for active in active_items)


def promote_ready_backlog_items(
    backlog: list[BacklogItem], project_path: Path
) -> list[BacklogItem]:
    launches = refresh_worker_launches(project_path)
    active_items = [item for item in backlog if item["status"] == "in_progress"]
    available_slots = max(0, 3 - len(active_items))
    if available_slots == 0:
        return backlog

    ready_items = [
        item
        for item in backlog
        if item["status"] == "approved"
        and dependencies_satisfied(item, backlog)
    ]
    ready_items.sort(
        key=lambda item: (
            priority_rank(item["priority"]),
            complexity_rank(item["complexity"]),
            item["id"],
        )
    )

    for item in ready_items:
        if available_slots == 0:
            break
        if collides_with_active(item, active_items):
            continue
        if not relevant_changed_paths(project_path, item):
            item["progress_note"] = (
                "Approved and ready, but still waiting for a real worker to begin task-relevant repository edits."
            )
            continue
        if item["blocked_reason"].startswith("Validation failed"):
            continue
        launch = launches.get(item["id"])
        if launch is None or launch["status"] != "running":
            continue
        item["status"] = "in_progress"
        item["owner_agent"] = assigned_agent_for_item(item)
        if not item["started_at"]:
            item["started_at"] = now_iso()
        item["last_heartbeat_at"] = now_iso()
        item["last_progress_at"] = now_iso()
        if not item["progress_note"]:
            item["progress_note"] = f"Claimed by {item['owner_agent']}; awaiting next progress checkpoint."
        active_items.append(item)
        available_slots -= 1
    return backlog


def normalize_active_backlog_metadata(backlog: list[BacklogItem]) -> list[BacklogItem]:
    for item in backlog:
        if item["status"] != "in_progress":
            continue
        if not item["owner_agent"]:
            item["owner_agent"] = assigned_agent_for_item(item)
        if not item["started_at"]:
            item["started_at"] = now_iso()
        if not item["last_heartbeat_at"]:
            item["last_heartbeat_at"] = item["started_at"]
        if not item["last_progress_at"]:
            item["last_progress_at"] = item["started_at"]
        if not item["progress_note"]:
            item["progress_note"] = f"Claimed by {item['owner_agent']}; awaiting next progress checkpoint."
    return backlog


def reset_item_to_approved(item: BacklogItem, progress_note: str) -> None:
    item["status"] = "approved"
    item["owner_agent"] = ""
    item["started_at"] = ""
    item["last_heartbeat_at"] = ""
    item["last_progress_at"] = now_iso()
    item["blocked_reason"] = ""
    item["agent_updates"] = []
    item["progress_note"] = progress_note


def requeue_item_for_follow_up(
    item: BacklogItem, progress_note: str, blocked_reason: str
) -> None:
    item["status"] = "approved"
    item["owner_agent"] = ""
    item["started_at"] = ""
    item["last_heartbeat_at"] = ""
    item["last_progress_at"] = now_iso()
    item["blocked_reason"] = blocked_reason
    item["agent_updates"] = []
    item["progress_note"] = progress_note


def item_has_worker_reporting_failure(item: BacklogItem) -> bool:
    return item["blocked_reason"].startswith("Worker reporting failure:")


def recover_stalled_items(backlog: list[BacklogItem]) -> list[BacklogItem]:
    recovered_at = now_iso()
    for item in backlog:
        if item["status"] != "in_progress":
            continue
        if not should_recover_item(item):
            continue
        previous_owner = item["owner_agent"] or assigned_agent_for_item(item)
        reset_item_to_approved(
            item,
            f"Recovered stale claim from {previous_owner} at {recovered_at}; "
            "awaiting explicit re-approval or reassignment.",
        )
    return backlog


def render_backlog_text(backlog: list[BacklogItem]) -> str:
    active_items, done_items = split_backlog_items(backlog)
    pending_items = [item for item in backlog if item["status"] == "pending"]
    approved_items = [item for item in backlog if item["status"] == "approved"]
    in_progress_items = [item for item in backlog if item["status"] == "in_progress"]
    ready_approved = ready_approved_items(backlog)
    launched_workers = sum(
        1
        for item in backlog
        if item["progress_note"].startswith("Real worker ")
        or item["progress_note"].startswith("Previous real worker")
    )
    active_agents = active_agent_count(backlog) + launched_workers
    grouped = {category: [] for category in VALID_CATEGORIES}
    for item in active_items:
        grouped[item["category"]].append(item)

    if in_progress_items or launched_workers:
        loop_status = "active"
    elif ready_approved:
        loop_status = "ready"
    else:
        loop_status = "idle"

    lines = [
        "# Agent Backlog",
        "# Managed by langgraph_multi_agent.py.",
        f"# Last heartbeat at: {now_iso()}",
        (
            "# Loop status: "
            f"{loop_status} | active_agents={active_agents} | "
            f"approved={len(approved_items)} | ready_approved={len(ready_approved)} | "
            f"pending={len(pending_items)} | in_progress={len(in_progress_items)} | "
            f"done={len(done_items)}"
        ),
        "# Approve work by changing an item's status from pending to approved.",
        "# Active status values: pending, approved, in_progress",
        "# Fields: id | status | priority | complexity | dependencies | title",
        "",
    ]

    for category in VALID_CATEGORIES:
        lines.append(f"## {category}")
        items = grouped[category]
        if not items:
            lines.append("(empty)")
            lines.append("")
            continue
        for item in items:
            lines.append(
                f"{item['id']} | {item['status']} | {item['priority']} | "
                f"{item['complexity']} | {format_dependencies(item['dependencies'])} | "
                f"{item['title']}"
            )
            if item["owner_agent"]:
                lines.append(f"  Owner agent: {item['owner_agent']}")
            if item["started_at"]:
                lines.append(f"  Started at: {item['started_at']}")
            if item["last_heartbeat_at"]:
                lines.append(f"  Last heartbeat at: {item['last_heartbeat_at']}")
            if item["last_progress_at"]:
                lines.append(f"  Last progress at: {item['last_progress_at']}")
            if item["progress_note"]:
                lines.append(f"  Progress note: {item['progress_note']}")
            if item["blocked_reason"]:
                lines.append(f"  Blocked reason: {item['blocked_reason']}")
            for update in item["agent_updates"]:
                lines.append(
                    "  Agent activity: "
                    f"{update['agent']} | {update['updated_at']} | {update['phase']} | "
                    f"{update['activity']} | {update['next_command']}"
                )
            if item["details"]:
                for detail_line in item["details"].splitlines():
                    lines.append(f"  {detail_line}")
            lines.append("")

    if done_items:
        lines.extend(
            [
                "# Recently completed (read-only summary; canonical archive is .copilot/agent-done.txt)",
                "# Fields: id | status | priority | complexity | dependencies | title",
                "#",
            ]
        )
        for item in sorted(
            done_items,
            key=lambda done_item: (
                done_item["last_progress_at"] or done_item["last_heartbeat_at"] or done_item["started_at"],
                done_item["id"],
            ),
            reverse=True,
        )[:5]:
            lines.append(
                "# "
                f"{item['id']} | {item['status']} | {item['priority']} | "
                f"{item['complexity']} | {format_dependencies(item['dependencies'])} | "
                f"{item['title']}"
            )
            if item["progress_note"]:
                lines.append(f"#   Progress note: {item['progress_note']}")
            if item["last_progress_at"]:
                lines.append(f"#   Last progress at: {item['last_progress_at']}")
            lines.append("#")
    return "\n".join(lines).rstrip() + "\n"


def render_done_text(backlog: list[BacklogItem]) -> str:
    _, done_items = split_backlog_items(backlog)
    grouped = {category: [] for category in VALID_CATEGORIES}
    for item in done_items:
        grouped[item["category"]].append(item)

    lines = [
        "# Agent Done",
        "# Completed backlog items moved here automatically by langgraph_multi_agent.py.",
        "# Status values: done",
        "# Fields: id | status | priority | complexity | dependencies | title",
        "",
    ]

    for category in VALID_CATEGORIES:
        lines.append(f"## {category}")
        items = grouped[category]
        if not items:
            lines.append("(empty)")
            lines.append("")
            continue
        for item in items:
            lines.append(
                f"{item['id']} | {item['status']} | {item['priority']} | "
                f"{item['complexity']} | {format_dependencies(item['dependencies'])} | "
                f"{item['title']}"
            )
            if item["owner_agent"]:
                lines.append(f"  Owner agent: {item['owner_agent']}")
            if item["started_at"]:
                lines.append(f"  Started at: {item['started_at']}")
            if item["last_heartbeat_at"]:
                lines.append(f"  Last heartbeat at: {item['last_heartbeat_at']}")
            if item["last_progress_at"]:
                lines.append(f"  Last progress at: {item['last_progress_at']}")
            if item["progress_note"]:
                lines.append(f"  Progress note: {item['progress_note']}")
            if item["blocked_reason"]:
                lines.append(f"  Blocked reason: {item['blocked_reason']}")
            for update in item["agent_updates"]:
                lines.append(
                    "  Agent activity: "
                    f"{update['agent']} | {update['updated_at']} | {update['phase']} | "
                    f"{update['activity']} | {update['next_command']}"
                )
            if item["details"]:
                for detail_line in item["details"].splitlines():
                    lines.append(f"  {detail_line}")
            lines.append("")
    return "\n".join(lines).rstrip() + "\n"


def render_plan_text(plan_items: list[PlanItem]) -> str:
    grouped = {category: [] for category in VALID_CATEGORIES}
    for item in plan_items:
        grouped[item["category"]].append(item)

    lines = [
        "# Agent Plan",
        "# First gate: mark a plan item as approved to move it into the backlog.",
        "# Once moved, it leaves this file and enters `.copilot/agent-backlog.txt` as pending.",
        "# Plan status values: planned, approved",
        "# Fields: id | status | priority | complexity | dependencies | title",
        "",
    ]

    for category in VALID_CATEGORIES:
        lines.append(f"## {category}")
        items = grouped[category]
        if not items:
            lines.append("(empty)")
            lines.append("")
            continue
        for item in items:
            lines.append(
                f"{item['id']} | {item['status']} | {item['priority']} | "
                f"{item['complexity']} | {format_dependencies(item['dependencies'])} | "
                f"{item['title']}"
            )
            if item["details"]:
                for detail_line in item["details"].splitlines():
                    lines.append(f"  {detail_line}")
            lines.append("")
    return "\n".join(lines).rstrip() + "\n"


def apply_agent_reports_to_backlog(
    backlog: list[BacklogItem], reports: list[AgentReport], project_path: Path
) -> tuple[list[BacklogItem], Optional[str]]:
    if not reports:
        return backlog, None

    update_time = now_iso()
    delivery_candidate_id: Optional[str] = None
    for item in backlog:
        if item["status"] != "in_progress":
            continue

        relevant_reports = [
            report for report in reports if agent_enabled_for_item(report["agent"], item)
        ]
        if not relevant_reports:
            continue

        item["last_heartbeat_at"] = update_time

        item["agent_updates"] = sorted(
            [
                {
                    "agent": report["agent"],
                    "updated_at": update_time,
                    "phase": report["phase"],
                    "activity": report["activity"],
                    "next_command": report["next_command"],
                }
                for report in relevant_reports
            ],
            key=lambda update: update["updated_at"],
            reverse=True,
        )

        owner = item["owner_agent"] or assigned_agent_for_item(item)
        owner_report = next(
            (report for report in relevant_reports if report["agent"] == owner),
            relevant_reports[0],
        )
        progress_note = (
            f"{owner_report['agent']} [{owner_report['phase']}]: "
            f"{owner_report['activity']}"
        )
        if item["progress_note"] != progress_note:
            item["progress_note"] = progress_note
            item["last_progress_at"] = update_time

        tester_report = next(
            (report for report in relevant_reports if report["agent"] == "tester"),
            None,
        )
        if tester_report is None:
            continue

        if tester_report.get("outcome") == "failed":
            failure_summary = tester_report["summary"].strip() or (
                "Validation failed; commit delivery was not attempted until tests pass."
            )
            requeue_item_for_follow_up(
                item,
                "Validation failed; relaunching a real worker with tester feedback.",
                failure_summary,
            )
            continue

        if (
            tester_report.get("outcome") == "passed"
            and delivery_candidate_id is None
            and relevant_changed_paths(project_path, item)
        ):
            item["blocked_reason"] = ""
            item["progress_note"] = (
                "tester [validated]: Validation passed; preparing commit, push, and deploy."
            )
            item["last_progress_at"] = update_time
            delivery_candidate_id = item["id"]

    return backlog, delivery_candidate_id


def changed_paths_within(project_path: Path, paths: list[str]) -> list[str]:
    if not paths:
        return []
    completed = subprocess.run(
        ["git", "--no-pager", "status", "--porcelain", "--", *paths],
        cwd=project_path,
        capture_output=True,
        text=True,
        timeout=30,
    )
    if completed.returncode != 0:
        return []
    changed: list[str] = []
    for line in completed.stdout.splitlines():
        if len(line) < 4:
            continue
        path = line[3:].strip()
        if " -> " in path:
            path = path.split(" -> ", 1)[1].strip()
        if path:
            changed.append(path)
    return changed


def commit_completed_item(
    project_path: Path,
    item: BacklogItem,
    backlog_path: Path,
    done_path: Path,
    plan_path: Path,
) -> tuple[bool, str]:
    relevant_paths = relevant_changed_paths(project_path, item)
    metadata_paths = [
        os.path.relpath(path, project_path)
        for path in (backlog_path, done_path, plan_path)
    ]
    commit_paths = changed_paths_within(
        project_path,
        sorted(dict.fromkeys(relevant_paths + metadata_paths)),
    )
    if not commit_paths:
        return False, "No task-relevant local changes were available to commit."

    add_completed = subprocess.run(
        ["git", "add", "--", *commit_paths],
        cwd=project_path,
        capture_output=True,
        text=True,
        timeout=30,
    )
    if add_completed.returncode != 0:
        return False, (add_completed.stderr or add_completed.stdout).strip()

    commit_message = (
        f"Complete {item['id']}: {item['title']}\n\n"
        "Co-authored-by: Copilot <223556219+Copilot@users.noreply.github.com>\n"
    )
    commit_completed = subprocess.run(
        ["git", "commit", "--only", "-F", "-", "--", *commit_paths],
        cwd=project_path,
        input=commit_message,
        capture_output=True,
        text=True,
        timeout=60,
    )
    if commit_completed.returncode != 0:
        return False, (commit_completed.stderr or commit_completed.stdout).strip()

    push_completed = subprocess.run(
        ["git", "push", "origin", "HEAD:main"],
        cwd=project_path,
        capture_output=True,
        text=True,
        timeout=120,
    )
    if push_completed.returncode != 0:
        return False, f"git push failed: {(push_completed.stderr or push_completed.stdout).strip()}"

    deploy_script = project_path / "my-app/infra/deploy.sh"
    if not deploy_script.exists():
        return False, f"Deployment script not found: {deploy_script}"

    deploy_completed = subprocess.run(
        ["bash", str(deploy_script)],
        cwd=project_path,
        capture_output=True,
        text=True,
        timeout=1800,
    )
    if deploy_completed.returncode != 0:
        deploy_output = (deploy_completed.stderr or deploy_completed.stdout).strip()
        return False, f"deployment failed: {deploy_output}"

    sha_completed = subprocess.run(
        ["git", "rev-parse", "HEAD"],
        cwd=project_path,
        capture_output=True,
        text=True,
        timeout=10,
    )
    if sha_completed.returncode != 0:
        return True, "committed, pushed, and deployed"
    return True, f"{sha_completed.stdout.strip()} (pushed and deployed)"


def ready_approved_items(backlog: list[BacklogItem]) -> list[BacklogItem]:
    return [
        item
        for item in backlog
        if item["status"] == "approved"
        and not item_has_worker_reporting_failure(item)
        and dependencies_satisfied(item, backlog)
    ]


def active_agent_count(backlog: list[BacklogItem]) -> int:
    agents: set[str] = set()
    for item in backlog:
        if item["status"] != "in_progress":
            continue
        if item["agent_updates"]:
            agents.update(update["agent"] for update in item["agent_updates"])
            continue
        agents.add(item["owner_agent"] or assigned_agent_for_item(item))
    return len(agents)


def mark_no_change_stalls(
    backlog: list[BacklogItem], project_path: Path
) -> list[BacklogItem]:
    for item in backlog:
        if item["status"] != "in_progress":
            continue
        relevant_paths = relevant_changed_paths(project_path, item)
        age = elapsed_minutes(item["started_at"]) or 0
        if relevant_paths:
            if item["blocked_reason"].startswith("No task-relevant local code changes detected"):
                item["blocked_reason"] = ""
            continue
        if age < NO_LOCAL_CHANGE_BLOCK_MINUTES:
            continue
        reset_item_to_approved(
            item,
            "Approved and ready, but returned from a synthetic claim because no real worker started task-relevant repository edits.",
        )
    return backlog


def demote_inactive_in_progress_items(
    backlog: list[BacklogItem], project_path: Path
) -> list[BacklogItem]:
    launches = refresh_worker_launches(project_path)
    running_item_ids = {
        item_id for item_id, launch in launches.items() if launch["status"] == "running"
    }
    for item in backlog:
        if item["status"] != "in_progress":
            continue
        if relevant_changed_paths(project_path, item):
            continue
        if item["id"] in running_item_ids:
            continue
        reset_item_to_approved(
            item,
            "Previous real worker no longer has live task-relevant repository edits; relaunching automatically.",
        )
    return backlog


def sync_project_workflow_files(
    backlog: list[BacklogItem],
    backlog_path: Path,
    done_path: Path,
    plan_items: list[PlanItem],
    plan_path: Path,
) -> None:
    backlog_path.parent.mkdir(parents=True, exist_ok=True)
    done_path.parent.mkdir(parents=True, exist_ok=True)
    plan_path.parent.mkdir(parents=True, exist_ok=True)
    backlog_path.write_text(render_backlog_text(backlog), encoding="utf-8")
    done_path.write_text(render_done_text(backlog), encoding="utf-8")
    plan_path.write_text(render_plan_text(plan_items), encoding="utf-8")


def build_runtime_summary(
    backlog: list[BacklogItem],
    plan_items: list[PlanItem],
    backlog_path: Path,
    done_path: Path,
    plan_path: Path,
) -> dict[str, Any]:
    active_items = [item for item in backlog if item["status"] == "in_progress"]
    pending_items = [item for item in backlog if item["status"] == "pending"]
    approved_items = [item for item in backlog if item["status"] == "approved"]
    done_items = [item for item in backlog if item["status"] == "done"]
    ready_approved = ready_approved_items(backlog)
    launched_workers = sum(
        1
        for item in backlog
        if item["progress_note"].startswith("Real worker ")
        or item["progress_note"].startswith("Previous real worker")
    )

    agents: dict[str, dict[str, Any]] = {}
    complexity_points = {"small": 1, "medium": 2, "large": 3}

    for item in active_items:
        load_points = complexity_points.get(item["complexity"], 2)
        progress_age_minutes = elapsed_minutes(item["last_progress_at"])
        heartbeat_age_minutes = elapsed_minutes(item["last_heartbeat_at"])
        execution_state = task_execution_state(item)
        stale = execution_state == "stale"
        agent_updates = item["agent_updates"] or [
            {
                "agent": item["owner_agent"] or assigned_agent_for_item(item),
                "updated_at": item["last_heartbeat_at"] or item["last_progress_at"] or item["started_at"],
                "phase": execution_state,
                "activity": item["progress_note"] or "No activity checkpoint recorded.",
                "next_command": "",
            }
        ]

        for update in agent_updates:
            agent_summary = agents.setdefault(
                update["agent"],
                {"task_count": 0, "load_points": 0, "tasks": []},
            )
            agent_summary["task_count"] += 1
            agent_summary["load_points"] += load_points
            agent_summary["tasks"].append(
                {
                    "id": item["id"],
                    "title": item["title"],
                    "priority": item["priority"],
                    "complexity": item["complexity"],
                    "dependencies": item["dependencies"],
                    "started_at": item["started_at"],
                    "elapsed": format_duration(item["started_at"]),
                    "last_heartbeat_at": item["last_heartbeat_at"],
                    "heartbeat_age_minutes": heartbeat_age_minutes,
                    "last_progress_at": item["last_progress_at"],
                    "progress_age_minutes": progress_age_minutes,
                    "progress_note": item["progress_note"],
                    "blocked_reason": item["blocked_reason"],
                    "execution_state": execution_state,
                    "phase": update["phase"],
                    "activity": update["activity"],
                    "next_command": update["next_command"],
                    "updated_at": update["updated_at"],
                    "stale": stale,
                }
            )

    return {
        "snapshot_at": now_iso(),
        "stale_progress_threshold_minutes": STALE_PROGRESS_MINUTES,
        "plan_file": str(plan_path),
        "backlog_file": str(backlog_path),
        "done_file": str(done_path),
        "counts": {
            "planned": len(plan_items),
            "backlog_pending": len(pending_items),
            "backlog_approved": len(approved_items),
            "backlog_ready_approved": len(ready_approved),
            "backlog_in_progress": len(active_items),
            "done": len(done_items),
            "active_agents": len(agents) + launched_workers,
            "stale_active_tasks": sum(
                1
                for item in active_items
                if task_execution_state(item) == "stale"
            ),
            "blocked_active_tasks": sum(
                1
                for item in active_items
                if task_execution_state(item) == "blocked"
            ),
            "claimed_without_checkpoint": sum(
                1
                for item in active_items
                if task_execution_state(item) == "claimed_no_checkpoint"
            ),
        },
        "active_tasks": [
            {
                "id": item["id"],
                "title": item["title"],
                "owner_agent": item["owner_agent"] or assigned_agent_for_item(item),
                "category": item["category"],
                "priority": item["priority"],
                "complexity": item["complexity"],
                "dependencies": item["dependencies"],
                "started_at": item["started_at"],
                "elapsed": format_duration(item["started_at"]),
                "last_heartbeat_at": item["last_heartbeat_at"],
                "heartbeat_age_minutes": elapsed_minutes(item["last_heartbeat_at"]),
                "last_progress_at": item["last_progress_at"],
                "progress_age_minutes": elapsed_minutes(item["last_progress_at"]),
                "progress_note": item["progress_note"],
                "blocked_reason": item["blocked_reason"],
                "agent_updates": item["agent_updates"],
                "execution_state": task_execution_state(item),
                "stale": task_execution_state(item) == "stale",
            }
            for item in active_items
        ],
        "agents": agents,
    }


def load_or_create_project_backlog(
    project_path: Path,
    backlog_file: str,
    done_file: str,
    plan_file: str,
    backlog_seed: str,
    recover_stalled: bool = False,
) -> tuple[list[BacklogItem], list[PlanItem], Path, Path, Path]:
    backlog_path = (project_path / backlog_file).resolve()
    done_path = (project_path / done_file).resolve()
    plan_path = (project_path / plan_file).resolve()

    if backlog_path.exists():
        backlog = parse_backlog_text(backlog_path.read_text(encoding="utf-8"))
        if not backlog and backlog_seed:
            backlog = load_backlog_from_seed(backlog_seed)
    else:
        backlog = load_backlog_from_seed(backlog_seed)

    if done_path.exists():
        backlog.extend(parse_backlog_text(done_path.read_text(encoding="utf-8")))

    if plan_path.exists():
        plan_items = parse_plan_text(plan_path.read_text(encoding="utf-8"))
    else:
        plan_items = []

    plan_items, backlog = move_approved_plan_items_to_backlog(plan_items, backlog)
    if recover_stalled:
        backlog = recover_stalled_items(backlog)
    backlog = promote_ready_backlog_items(backlog, project_path)
    backlog = normalize_active_backlog_metadata(backlog)
    backlog = mark_no_change_stalls(backlog, project_path)

    sync_project_workflow_files(backlog, backlog_path, done_path, plan_items, plan_path)
    return backlog, plan_items, backlog_path, done_path, plan_path


def derive_approval_status(backlog: list[BacklogItem]) -> str:
    active_items, _ = split_backlog_items(backlog)
    if not active_items:
        return "no_backlog"
    if any(item["status"] in {"approved", "in_progress"} for item in active_items):
        return "approved"
    return "awaiting_manual_approval"


def has_openai_credentials() -> bool:
    return bool(os.environ.get("OPENAI_API_KEY"))


def available_surfaces(project_path: Path) -> dict[str, list[str]]:
    surfaces = {
        "backend_dev": [],
        "frontend_dev": [],
        "tester": [],
    }

    if (project_path / "my-app/backend").exists():
        surfaces["backend_dev"].extend(
            [
                "my-app/backend/cmd/api/main.go",
                "my-app/backend/go.mod",
            ]
        )
    if (project_path / "my-app/infra").exists():
        surfaces["backend_dev"].append("my-app/infra/lib/infra-stack.ts")
        surfaces["tester"].append("cd my-app/infra && npm test -- --runInBand")
    if (project_path / "my-app/mobile").exists():
        surfaces["frontend_dev"].extend(
            [
                "my-app/mobile/lib",
                "my-app/mobile/test",
            ]
        )
        surfaces["tester"].append("cd my-app/mobile && flutter test")

    return surfaces


def agent_enabled_for_item(agent: str, item: Optional[BacklogItem]) -> bool:
    if item is None:
        return True
    if agent == "tester":
        return True
    if item["category"] == "both":
        return agent in {"backend_dev", "frontend_dev"}
    if item["category"] == "backend":
        return agent == "backend_dev"
    if item["category"] == "frontend":
        return agent == "frontend_dev"
    return True


def agent_enabled_for_items(agent: str, items: list[BacklogItem]) -> bool:
    if not items:
        return True
    return any(agent_enabled_for_item(agent, item) for item in items)


def latest_agent_update(
    item: Optional[BacklogItem], agent: str
) -> Optional[AgentUpdate]:
    if item is None:
        return None
    for update in item.get("agent_updates", []):
        if update["agent"] == agent:
            return update
    return None


def changed_repo_paths(project_path: Path) -> list[str]:
    git_dir = project_path / ".git"
    if not git_dir.exists():
        return []
    completed = subprocess.run(
        ["git", "--no-pager", "status", "--porcelain"],
        cwd=project_path,
        capture_output=True,
        text=True,
        timeout=30,
    )
    if completed.returncode != 0:
        return []
    paths: list[str] = []
    for line in completed.stdout.splitlines():
        if len(line) < 4:
            continue
        path = line[3:].strip()
        if " -> " in path:
            path = path.split(" -> ", 1)[1].strip()
        if path:
            paths.append(path)
    return paths


def worker_state_path(project_path: Path) -> Path:
    return (project_path / DEFAULT_WORKER_STATE_FILE).resolve()


def agent_log_dir(project_path: Path) -> Path:
    return (project_path / DEFAULT_AGENT_LOG_DIR).resolve()


def worker_agent_key(item: BacklogItem) -> str:
    return assigned_agent_for_item(item)


def display_log_path(project_path: Path, log_path: str) -> str:
    try:
        return os.path.relpath(log_path, project_path)
    except ValueError:
        return log_path


def normalize_worker_protocol_line(line: str) -> str:
    return re.sub(r"^[\s>*\-●]+", "", line.strip())


def iter_worker_protocol_chunks(line: str) -> list[str]:
    normalized = normalize_worker_protocol_line(line)
    indexes: list[tuple[int, str]] = []
    for prefix in (WORKER_REPORT_PREFIX, WORKER_STEP_PREFIX):
        start = normalized.find(prefix)
        while start != -1:
            indexes.append((start, prefix))
            start = normalized.find(prefix, start + len(prefix))
    if not indexes:
        return []
    indexes.sort(key=lambda item: item[0])
    chunks: list[str] = []
    for idx, (start, _) in enumerate(indexes):
        end = indexes[idx + 1][0] if idx + 1 < len(indexes) else len(normalized)
        chunk = normalized[start:end].strip()
        if chunk:
            chunks.append(chunk)
    return chunks


def parse_worker_report_line(line: str) -> Optional[dict[str, str]]:
    if not line.startswith(WORKER_REPORT_PREFIX):
        return None
    payload: dict[str, str] = {}
    for part in line[len(WORKER_REPORT_PREFIX) :].split("|"):
        key, sep, value = part.partition("=")
        if not sep:
            continue
        payload[key.strip()] = value.strip()
    state = payload.get("state", "")
    if not state:
        return None
    return {
        "state": state,
        "summary": payload.get("summary", ""),
        "next": payload.get("next", ""),
    }


def parse_worker_step_line(line: str) -> Optional[dict[str, str]]:
    if not line.startswith(WORKER_STEP_PREFIX):
        return None
    payload: dict[str, str] = {}
    for part in line[len(WORKER_STEP_PREFIX) :].split("|"):
        key, sep, value = part.partition("=")
        if not sep:
            continue
        payload[key.strip()] = value.strip()
    detail = payload.get("detail", "")
    if not detail:
        return None
    return {
        "action": payload.get("action", ""),
        "detail": detail,
    }


def count_recent_unreported_launches(log_path: Path, item_id: str) -> int:
    if not log_path.exists():
        return 0
    try:
        lines = log_path.read_text(encoding="utf-8", errors="replace").splitlines()
    except OSError:
        return 0

    launch_marker = f"orchestrator: launched item {item_id} "
    count = 0
    for raw_line in reversed(lines):
        line = raw_line.strip()
        if not line:
            continue
        report = parse_worker_report_line(line)
        if report is not None and report["state"] not in {"assigned", ""}:
            break
        if launch_marker in line:
            count += 1
    return count


def load_worker_launches(project_path: Path) -> dict[str, WorkerLaunch]:
    path = worker_state_path(project_path)
    if not path.exists():
        return {}
    try:
        data = json.loads(path.read_text(encoding="utf-8"))
    except Exception:
        return {}
    launches: dict[str, WorkerLaunch] = {}
    if not isinstance(data, dict):
        return launches
    for item_id, payload in data.items():
        if not isinstance(payload, dict):
            continue
        try:
            launches[str(item_id)] = {
                "item_id": str(payload["item_id"]),
                "agent_key": str(payload.get("agent_key", "")),
                "pid": int(payload["pid"]),
                "started_at": str(payload["started_at"]),
                "status": str(payload["status"]),
                "log_path": str(payload["log_path"]),
                "log_offset": int(payload.get("log_offset", 0)),
                "attempt_count": int(payload.get("attempt_count", 1)),
                "last_log_at": str(payload.get("last_log_at", "")),
                "last_log_line": str(payload.get("last_log_line", "")),
                "last_log_signature": str(payload.get("last_log_signature", "")),
                "last_report_state": str(payload.get("last_report_state", "")),
                "last_report_summary": str(payload.get("last_report_summary", "")),
                "last_report_next": str(payload.get("last_report_next", "")),
                "last_step_action": str(payload.get("last_step_action", "")),
                "last_step_detail": str(payload.get("last_step_detail", "")),
                "quiet_polls": int(payload.get("quiet_polls", 0)),
            }
        except Exception:
            continue
    return launches


def save_worker_launches(project_path: Path, launches: dict[str, WorkerLaunch]) -> None:
    path = worker_state_path(project_path)
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(launches, indent=2) + "\n", encoding="utf-8")


def pid_is_running(pid: int) -> bool:
    if pid <= 0:
        return False
    try:
        os.killpg(pid, 0)
        return True
    except ProcessLookupError:
        pass
    except PermissionError:
        return True
    except OSError:
        pass
    try:
        os.kill(pid, 0)
    except OSError:
        return False
    return True


def stop_pid(pid: int) -> None:
    if pid <= 0:
        return
    try:
        os.killpg(pid, signal.SIGTERM)
        return
    except ProcessLookupError:
        pass
    except PermissionError:
        return
    except OSError:
        pass
    try:
        os.kill(pid, signal.SIGTERM)
    except OSError:
        return


def stop_worker_launch(project_path: Path, item_id: str) -> None:
    launches = load_worker_launches(project_path)
    launch = launches.pop(item_id, None)
    if launch is None:
        return
    if launch["status"] == "running" or pid_is_running(launch["pid"]):
        stop_pid(launch["pid"])
    save_worker_launches(project_path, launches)


def read_worker_log_snapshot(
    launch: WorkerLaunch,
) -> tuple[str, str, str, str, str, str, str, str]:
    path = Path(launch["log_path"])
    if not path.exists():
        return "", "", "", "", "", "", "", ""
    try:
        stat = path.stat()
        updated_at = datetime.fromtimestamp(stat.st_mtime, timezone.utc).isoformat()
        signature = f"{stat.st_mtime_ns}:{stat.st_size}:{launch['log_offset']}"
        with path.open("rb") as handle:
            handle.seek(max(0, launch["log_offset"]))
            content = handle.read().decode("utf-8", errors="replace")
    except OSError:
        return "", "", "", "", "", "", "", ""

    lines = [line.strip() for line in content.splitlines() if line.strip()]
    last_line = lines[-1] if lines else ""
    last_report_state = launch["last_report_state"]
    last_report_summary = launch["last_report_summary"]
    last_report_next = launch["last_report_next"]
    last_step_action = launch["last_step_action"]
    last_step_detail = launch["last_step_detail"]
    for line in lines:
        chunks = iter_worker_protocol_chunks(line)
        if not chunks:
            chunks = [normalize_worker_protocol_line(line)]
        for chunk in chunks:
            report = parse_worker_report_line(chunk)
            if report is None:
                step = parse_worker_step_line(chunk)
                if step is None:
                    continue
                last_step_action = step["action"]
                last_step_detail = step["detail"]
                continue
            last_report_state = report["state"]
            last_report_summary = report["summary"]
            last_report_next = report["next"]
    if len(last_line) > 240:
        last_line = last_line[:237] + "..."
    return (
        signature,
        updated_at,
        last_line,
        last_report_state,
        last_report_summary,
        last_report_next,
        last_step_action,
        last_step_detail,
    )


def worker_log_note(launch: WorkerLaunch) -> str:
    step_detail = launch["last_step_detail"].strip()
    if step_detail:
        step_action = launch["last_step_action"].strip()
        if step_action:
            return f"{step_action}: {step_detail}"
        return step_detail
    report_state = launch["last_report_state"].strip()
    report_summary = launch["last_report_summary"].strip()
    if report_state and report_summary:
        if report_state in {"ready_for_validation", "done"}:
            return f"Worker reported completion: {report_summary}"
        if report_state == "blocked":
            return f"Worker reported blocker: {report_summary}"
        return f"Worker reported {report_state}: {report_summary}"
    line = launch["last_log_line"].strip()
    if line:
        return line
    if launch["status"] == "running":
        return "Worker process is running; awaiting its first per-agent log line."
    return "Worker exited without a usable log summary."


def refresh_worker_launches(
    project_path: Path, increment_quiet_polls: bool = False
) -> dict[str, WorkerLaunch]:
    launches = load_worker_launches(project_path)
    for launch in launches.values():
        launch["status"] = "running" if pid_is_running(launch["pid"]) else "finished"
        (
            signature,
            updated_at,
            last_line,
            last_report_state,
            last_report_summary,
            last_report_next,
            last_step_action,
            last_step_detail,
        ) = read_worker_log_snapshot(launch)
        if signature and signature != launch["last_log_signature"]:
            launch["last_log_signature"] = signature
            launch["last_log_at"] = updated_at
            launch["last_log_line"] = last_line
            launch["last_report_state"] = last_report_state
            launch["last_report_summary"] = last_report_summary
            launch["last_report_next"] = last_report_next
            launch["last_step_action"] = last_step_action
            launch["last_step_detail"] = last_step_detail
            launch["quiet_polls"] = 0
        elif increment_quiet_polls and launch["status"] == "running":
            launch["quiet_polls"] = launch.get("quiet_polls", 0) + 1
    save_worker_launches(project_path, launches)
    return launches


def running_launch_for_item(
    project_path: Path, item: Optional[BacklogItem]
) -> Optional[WorkerLaunch]:
    if item is None:
        return None
    launch = refresh_worker_launches(project_path).get(item["id"])
    if launch and launch["status"] == "running":
        return launch
    return None


def item_needs_follow_up_worker(item: BacklogItem) -> bool:
    return item["blocked_reason"].startswith("Validation failed")


def worker_missing_structured_report(launch: WorkerLaunch) -> bool:
    return launch["last_report_state"].strip() in {"", "assigned"}


def worker_in_startup_grace(launch: WorkerLaunch) -> bool:
    return worker_missing_structured_report(launch) and not launch[
        "last_step_action"
    ].strip()


def worker_reported_completion(launch: WorkerLaunch) -> bool:
    return launch["last_report_state"].strip() in {"ready_for_validation", "done"}


def sync_item_with_launch(
    project_path: Path, item: BacklogItem, launch: WorkerLaunch
) -> None:
    progress_note = worker_log_note(launch)
    log_path = display_log_path(project_path, launch["log_path"])
    if launch["status"] == "running":
        progress_note = (
            f"Real worker active (pid {launch['pid']}; log {log_path}): {progress_note}"
        )
    else:
        progress_note = f"Real worker finished (log {log_path}): {progress_note}"
    if item["progress_note"] != progress_note:
        item["progress_note"] = progress_note
    if launch["last_log_at"]:
        item["last_progress_at"] = launch["last_log_at"]
        item["last_heartbeat_at"] = launch["last_log_at"]
    report_state = launch["last_report_state"].strip()
    if report_state:
        item["agent_updates"] = [
            {
                "agent": launch["agent_key"],
                "updated_at": launch["last_log_at"] or launch["started_at"],
                "phase": report_state,
                "activity": launch["last_report_summary"] or worker_log_note(launch),
                "next_command": launch["last_report_next"],
            }
        ]


def mark_worker_reporting_failure(
    project_path: Path, item: BacklogItem, launch: WorkerLaunch
) -> None:
    log_path = display_log_path(project_path, launch["log_path"])
    requeue_item_for_follow_up(
        item,
        "Worker failed to emit a structured completion/progress report; automatic relaunch paused.",
        (
            "Worker reporting failure: "
            f"{launch['agent_key']} exited or stayed quiet without any progress/completion "
            f"checkpoint beyond `state=assigned` after {launch['attempt_count']} launches. "
            f"Inspect {log_path}."
        ),
    )


def running_worker_count(project_path: Path, backlog: list[BacklogItem]) -> int:
    launches = refresh_worker_launches(project_path)
    backlog_ids = {item["id"] for item in backlog if item["status"] != "done"}
    return sum(
        1
        for item_id, launch in launches.items()
        if item_id in backlog_ids and launch["status"] == "running"
    )


def reconcile_worker_launches(project_path: Path, backlog: list[BacklogItem]) -> dict[str, WorkerLaunch]:
    launches = refresh_worker_launches(project_path, increment_quiet_polls=True)
    items_by_id = {item["id"]: item for item in backlog}
    changed = False
    for item_id, launch in list(launches.items()):
        item = items_by_id.get(item_id)
        if item is None or item["status"] == "done":
            if launch["status"] == "running":
                stop_pid(launch["pid"])
            launches.pop(item_id, None)
            changed = True
            continue
        if launch["status"] != "running" and item_needs_follow_up_worker(item):
            launches.pop(item_id, None)
            changed = True
            continue
        if launch["status"] == "running":
            sync_item_with_launch(project_path, item, launch)
            if relevant_changed_paths(project_path, item):
                continue
            quiet_poll_limit = (
                INITIAL_WORKER_STARTUP_QUIET_POLLS
                if worker_in_startup_grace(launch)
                else MAX_QUIET_LOG_POLLS
            )
            if launch["quiet_polls"] < quiet_poll_limit:
                continue
            stop_pid(launch["pid"])
            launch["status"] = "stalled"
            if (
                worker_missing_structured_report(launch)
                and launch["attempt_count"] >= MAX_UNREPORTED_WORKER_ATTEMPTS
            ):
                mark_worker_reporting_failure(project_path, item, launch)
                launches.pop(item_id, None)
                changed = True
                continue
            item["progress_note"] = (
                "Real worker stopped after repeated watcher polls without new log activity or task-relevant edits; relaunching automatically."
            )
            item["last_progress_at"] = now_iso()
            item["last_heartbeat_at"] = item["last_progress_at"]
            launches.pop(item_id, None)
            if item["status"] == "in_progress":
                reset_item_to_approved(
                    item,
                    "Previous real worker stopped after no new log activity and no task-relevant edits; relaunching automatically.",
                )
            changed = True
            continue
        if launch["last_report_state"] == "blocked":
            requeue_item_for_follow_up(
                item,
                "Worker reported a blocker and returned the task for follow-up.",
                launch["last_report_summary"] or "Worker reported a blocker without a summary.",
            )
            launches.pop(item_id, None)
            changed = True
            continue
        if worker_reported_completion(launch):
            if relevant_changed_paths(project_path, item):
                if item["status"] != "in_progress":
                    item["status"] = "in_progress"
                    item["owner_agent"] = assigned_agent_for_item(item)
                    if not item["started_at"]:
                        item["started_at"] = launch["started_at"] or now_iso()
                    changed = True
                sync_item_with_launch(project_path, item, launch)
                launches.pop(item_id, None)
                changed = True
                continue
            if launch["last_report_state"] == "done":
                item["status"] = "done"
                item["owner_agent"] = ""
                item["blocked_reason"] = ""
                sync_item_with_launch(project_path, item, launch)
                launches.pop(item_id, None)
                changed = True
                continue
        if (
            worker_missing_structured_report(launch)
            and not relevant_changed_paths(project_path, item)
            and launch["attempt_count"] >= MAX_UNREPORTED_WORKER_ATTEMPTS
        ):
            mark_worker_reporting_failure(project_path, item, launch)
            launches.pop(item_id, None)
            changed = True
            continue
        if relevant_changed_paths(project_path, item):
            if item["status"] != "in_progress":
                item["status"] = "in_progress"
                item["owner_agent"] = assigned_agent_for_item(item)
                if not item["started_at"]:
                    item["started_at"] = launch["started_at"] or now_iso()
                changed = True
            sync_item_with_launch(project_path, item, launch)
            item["agent_updates"] = []
            launches.pop(item_id, None)
            changed = True
            continue
        if item["status"] == "in_progress":
            item["status"] = "approved"
            item["owner_agent"] = ""
            item["started_at"] = ""
            item["last_heartbeat_at"] = ""
            item["blocked_reason"] = ""
            item["agent_updates"] = []
            item["progress_note"] = (
                "Previous real worker exited without task-relevant repository edits or a completion report; relaunching automatically."
            )
            item["last_progress_at"] = now_iso()
            changed = True
    if changed:
        save_worker_launches(project_path, launches)
    return launches


def build_worker_prompt(item: BacklogItem, instructions_text: str) -> str:
    dependency_text = format_dependencies(item["dependencies"])
    blocked_reason = item["blocked_reason"].strip()
    failure_context = (
        f"Current blocker to resolve before finishing:\n{blocked_reason}\n\n"
        if blocked_reason
        else ""
    )
    return (
        f"You are the autonomous coding worker for backlog item {item['id']} "
        f"({item['category']}): {item['title']}.\n\n"
        f"Priority: {item['priority']}\n"
        f"Complexity: {item['complexity']}\n"
        f"Dependencies: {dependency_text}\n\n"
        f"{failure_context}"
        f"{item['details']}\n\n"
        "Requirements:\n"
        "- Inspect at most 3 likely files before the first edit.\n"
        "- Make real repository edits for this backlog item.\n"
        "- Start editing task-relevant files quickly; do not spend the session only investigating.\n"
        "- Make the first code edit within the first minute of work.\n"
        "- Make the first code edit before running validation commands.\n"
        "- Keep pre-edit investigation minimal and focused on the listed likely files.\n"
        "- Run only existing relevant validation commands, and only after the first code edit exists.\n"
        "- Do not ask the user questions.\n"
        "- Do not commit or push; leave validated edits in the working tree for the orchestrator.\n"
        "- Prefer task-relevant paths only.\n"
        "- Silent waiting is not allowed. If you reach a point where there is no further useful work, emit a final completion or blocker checkpoint and exit.\n"
        "- If the task is already complete or no additional task-relevant edit is needed after your short inspection, emit `ORCH_REPORT|state=done|...` immediately instead of idling.\n\n"
        "Reporting protocol:\n"
        f"- Emit single-line status checkpoints prefixed exactly with `{WORKER_REPORT_PREFIX}`.\n"
        "- Use this format exactly: "
        f"`{WORKER_REPORT_PREFIX}state=<assigned|working|ready_for_validation|done|blocked>"
        "|summary=<short single line>|next=<short single line>`.\n"
        "- Emit one checkpoint immediately after you understand the task, whenever the state meaningfully changes, "
        "and as your final line before exiting.\n"
        "- Never end the session without a final `ORCH_REPORT` line. Use `ready_for_validation`, `done`, or `blocked`; do not silently stop.\n"
        "- If you believe the assigned task is implemented and ready for tester handoff, your final checkpoint must use "
        "`state=ready_for_validation`.\n"
        "- If you believe the assigned task is already effectively complete and needs no more code changes, your final "
        "checkpoint must use `state=done` and explain why.\n"
        "- If you are blocked, emit `state=blocked` with the blocker and the next action needed.\n"
        f"- Emit literal step lines prefixed exactly with `{WORKER_STEP_PREFIX}`.\n"
        f"- Use this format exactly: `{WORKER_STEP_PREFIX}action=<read|edit|command|test|decision|result>"
        "|detail=<exact file path, command, diff target, or failure line>`.\n"
        "- Your first output after the initial assigned checkpoint must be an `ORCH_STEP` line, unless the correct immediate final action is a `done` or `blocked` report.\n"
        "- Emit a literal step line before each important read/edit/command and after any meaningful command result.\n"
        "- Keep step details literal and concrete: exact file paths, exact shell commands, exact test names, or exact error lines when they fit.\n"
        "- Do not use vague narration like 'checking things' or 'working on the task'. Prefer concrete lines such as:\n"
        f"  `{WORKER_STEP_PREFIX}action=read|detail=my-app/mobile/lib/providers/panta_provider.dart`\n"
        f"  `{WORKER_STEP_PREFIX}action=command|detail=cd my-app/mobile && flutter test test/widget_test.dart`\n"
        f"  `{WORKER_STEP_PREFIX}action=result|detail=flutter test failed: Expected 1 widget with text Login`\n"
        f"  `{WORKER_STEP_PREFIX}action=edit|detail=my-app/mobile/lib/services/auth_service.dart`\n\n"
        "Use `.github/copilot-instructions.md` for repo conventions if needed, but do not spend the session restating or re-reading unrelated sections.\n"
    ).strip()


def launch_copilot_worker(
    project_path: Path,
    item: BacklogItem,
    instructions_text: str,
    attempt_count: int,
) -> Optional[WorkerLaunch]:
    copilot_path = shutil.which("copilot")
    if not copilot_path:
        return None
    log_dir = agent_log_dir(project_path)
    log_dir.mkdir(parents=True, exist_ok=True)
    agent_key = worker_agent_key(item)
    safe_agent_key = re.sub(r"[^A-Za-z0-9_.+-]+", "_", agent_key)
    log_path = log_dir / f"{safe_agent_key}.log"
    existing_size = log_path.stat().st_size if log_path.exists() else 0
    attempt_count = max(
        attempt_count,
        count_recent_unreported_launches(log_path, item["id"]) + 1,
    )
    log_handle = open(log_path, "a", encoding="utf-8")
    started_at = now_iso()
    log_handle.write(
        f"[{started_at}] orchestrator: launched item {item['id']} ({item['title']}) "
        f"for agent {agent_key}\n"
    )
    log_handle.write(
        f"{WORKER_REPORT_PREFIX}state=assigned|summary=Task {item['id']} assigned to {agent_key}; "
        "worker process started.|next=emit a worker progress checkpoint or begin the first task-relevant edit\n"
    )
    log_handle.flush()
    worker_command = [
        copilot_path,
        "-p",
        build_worker_prompt(item, instructions_text),
        "--allow-all",
        "--no-ask-user",
        "--effort",
        "low",
        "--model",
        DEFAULT_MODEL,
        "--add-dir",
        str(project_path),
        "--no-color",
        "--stream",
        "off",
    ]
    try:
        process = subprocess.Popen(
            worker_command,
            cwd=project_path,
            stdout=log_handle,
            stderr=subprocess.STDOUT,
            stdin=subprocess.DEVNULL,
            start_new_session=True,
            text=True,
        )
    finally:
        log_handle.close()
    return {
        "item_id": item["id"],
        "agent_key": agent_key,
        "pid": process.pid,
        "started_at": started_at,
        "status": "running",
        "log_path": str(log_path),
        "log_offset": existing_size,
        "attempt_count": attempt_count,
        "last_log_at": "",
        "last_log_line": "",
        "last_log_signature": "",
        "last_report_state": "assigned",
        "last_report_summary": f"Task {item['id']} assigned to {agent_key}; worker process started.",
        "last_report_next": "emit a worker progress checkpoint or begin the first task-relevant edit",
        "last_step_action": "",
        "last_step_detail": "",
        "quiet_polls": 0,
    }


def launch_ready_workers(
    backlog: list[BacklogItem], project_path: Path, instructions_text: str
) -> list[BacklogItem]:
    launches = reconcile_worker_launches(project_path, backlog)
    active_items = [item for item in backlog if item["status"] == "in_progress"]
    launched_items = {
        item_id: launch
        for item_id, launch in launches.items()
        if launch["status"] == "running"
    }
    occupied_items = list(active_items) + [
        item for item in backlog if item["id"] in launched_items
    ]
    available_slots = max(0, 3 - len(occupied_items))
    if available_slots == 0:
        return backlog

    ready_items = ready_approved_items(backlog)
    ready_items.sort(
        key=lambda item: (
            priority_rank(item["priority"]),
            complexity_rank(item["complexity"]),
            item["id"],
        )
    )

    for item in ready_items:
        launch = launches.get(item["id"])
        if launch and launch["status"] == "running":
            sync_item_with_launch(project_path, item, launch)
            continue
        if collides_with_active(item, occupied_items):
            continue
        has_local_changes = bool(relevant_changed_paths(project_path, item))
        if has_local_changes and not item_needs_follow_up_worker(item):
            continue
        attempts = 1 if launch is None else launch["attempt_count"] + 1
        new_launch = launch_copilot_worker(project_path, item, instructions_text, attempts)
        if new_launch is None:
            continue
        launches[item["id"]] = new_launch
        save_worker_launches(project_path, launches)
        sync_item_with_launch(project_path, item, new_launch)
        if has_local_changes:
            item["blocked_reason"] = ""
        if not item["last_progress_at"]:
            item["last_progress_at"] = new_launch["started_at"]
        if not item["last_heartbeat_at"]:
            item["last_heartbeat_at"] = new_launch["started_at"]
        occupied_items.append(item)
        available_slots -= 1
        if available_slots == 0:
            break
    return backlog


def relevant_change_prefixes(item: Optional[BacklogItem]) -> tuple[str, ...]:
    if item is None:
        return ()
    if item["category"] == "backend":
        return ("my-app/backend/", "my-app/infra/")
    if item["category"] == "frontend":
        return ("my-app/mobile/",)
    return ("my-app/backend/", "my-app/infra/", "my-app/mobile/")


def relevant_changed_paths(project_path: Path, item: Optional[BacklogItem]) -> list[str]:
    prefixes = relevant_change_prefixes(item)
    if not prefixes:
        return []
    return [
        path
        for path in changed_repo_paths(project_path)
        if any(path.startswith(prefix) for prefix in prefixes)
    ]


def backend_phase_payload(
    item: Optional[BacklogItem], project_path: Path
) -> tuple[str, str, str]:
    relevant_paths = relevant_changed_paths(project_path, item)
    if not relevant_paths:
        return (
            "scoping",
            "No local backend implementation changes detected yet; code edits have not started.",
            "edit my-app/backend/cmd/api/main.go and create backend package files",
        )
    latest = latest_agent_update(item, "backend_dev")
    if latest is None:
        return (
            "implementing",
            "Applying backend code changes across the identified module boundaries.",
            "edit my-app/backend/cmd/api/main.go and create backend package files",
        )
    if latest["phase"] == "scoping":
        return (
            "implementing",
            "Extracting backend responsibilities out of main.go into clearer module boundaries.",
            "edit my-app/backend/cmd/api/main.go and create backend package files",
        )
    if latest["phase"] == "implementing":
        return (
            "ready_for_validation",
            "Backend implementation slice is prepared and ready for tester validation handoff.",
            "cd my-app/infra && npm test -- --runInBand",
        )
    return (
        "ready_for_validation",
        "Staying available for validation feedback and backend follow-up fixes.",
        "review tester feedback and patch backend issues if needed",
    )


def tester_ready_for_item(project_path: Path, item: BacklogItem) -> bool:
    if item["status"] != "in_progress":
        return False
    if running_launch_for_item(project_path, item) is not None:
        return False
    return bool(relevant_changed_paths(project_path, item))


def tester_ready_for_items(project_path: Path, items: list[BacklogItem]) -> bool:
    return any(tester_ready_for_item(project_path, item) for item in items)


def build_work_instruction(state: State) -> str:
    active_backlog_items = state.get("active_backlog_items", [])
    if active_backlog_items:
        if len(active_backlog_items) == 1:
            item = active_backlog_items[0]
            dependency_text = format_dependencies(item["dependencies"])
            return (
                f"Execute backlog item {item['id']} ({item['category']}): {item['title']}\n\n"
                f"Priority: {item['priority']}\n"
                f"Complexity: {item['complexity']}\n"
                f"Dependencies: {dependency_text}\n\n"
                f"{item['details']}"
            ).strip()

        lines = [
            "Execute the current in-progress backlog set in parallel where safe.",
            "Respect dependencies and avoid file-level collisions.",
            "",
        ]
        for item in active_backlog_items:
            lines.extend(
                [
                    f"- {item['id']} ({item['category']}): {item['title']}",
                    f"  Priority: {item['priority']}",
                    f"  Complexity: {item['complexity']}",
                    f"  Dependencies: {format_dependencies(item['dependencies'])}",
                ]
            )
            if item["details"]:
                for detail_line in item["details"].splitlines():
                    lines.append(f"  {detail_line}")
        return "\n".join(lines).strip()

    active_backlog_item = state.get("active_backlog_item")
    if active_backlog_item is None:
        return state["instruction"].strip()
    return (
        f"Execute backlog item {active_backlog_item['id']} ({active_backlog_item['category']}): "
        f"{active_backlog_item['title']}\n\n{active_backlog_item['details']}"
    ).strip()


def build_deterministic_tasks(state: State) -> list[AgentTask]:
    project_path = Path(state["project_path"])
    surfaces = available_surfaces(project_path)
    instruction = build_work_instruction(state)
    instructions_text = state["instructions_text"].strip()
    active_backlog_items = state.get("active_backlog_items", [])
    if state.get("heartbeat_only"):
        return []

    tasks: list[AgentTask] = []

    if (
        agent_enabled_for_items("tester", active_backlog_items)
        and tester_ready_for_items(project_path, active_backlog_items)
    ):
        tasks.append(
            {
                "agent": "tester",
                "instruction": (
                    f"{instruction}\n\n"
                    "Tester focus:\n"
                    "- Validate the existing project test surfaces only.\n"
                    f"- Candidate commands: {', '.join(surfaces['tester']) or 'none detected'}.\n"
                    "- Summarize what would be run when tests are disabled."
                ),
            }
        )

    return tasks


def build_llm_tasks(state: State) -> Optional[list[AgentTask]]:
    if state.get("heartbeat_only"):
        return []
    if ChatOpenAI is None or not has_openai_credentials():
        return None

    llm = ChatOpenAI(model=state["model"], temperature=0)
    allowed_agents = [
        agent
        for agent in ("tester",)
        if agent_enabled_for_items(agent, state.get("active_backlog_items", []))
        and (
            agent != "tester"
            or tester_ready_for_items(
                Path(state["project_path"]), state.get("active_backlog_items", [])
            )
        )
    ]
    prompt = f"""
You are a senior engineering manager orchestrating repository work.

Repository file map:
{state["repo_map"]}

Copilot instructions:
{state["instructions_text"] or "(none)"}

Backlog file: {state["backlog_path"]}
Done file: {state["done_path"]}
Plan file: {state["plan_path"]}

User instruction:
{build_work_instruction(state)}

Allowed agents:
{os.linesep.join(f"- {agent}" for agent in allowed_agents)}

Return JSON only:
{{
  "tasks": [
    {{"agent": "{allowed_agents[0] if allowed_agents else 'tester'}", "instruction": "..." }}
  ]
}}
"""
    response = llm.invoke(prompt).content
    data = extract_json(response)
    if not data or "tasks" not in data:
        return None
    tasks: list[AgentTask] = []
    for task in data["tasks"]:
        if not isinstance(task, dict):
            continue
        agent = str(task.get("agent", "")).strip()
        instruction = str(task.get("instruction", "")).strip()
        if agent in allowed_agents and instruction:
            tasks.append({"agent": agent, "instruction": instruction})
    return tasks or None


def manager(state: State) -> dict[str, Any]:
    if state["iterations"] >= state["max_iterations"]:
        return {"next_step": "merge"}

    backlog = state["backlog"]
    active_backlog, _ = split_backlog_items(backlog)
    if state["approval_status"] != "approved":
        if state["approval_status"] == "no_backlog":
            message = (
                "The current project plan is in place, but the active backlog is empty. "
                "First mark plan items approved to move them into the backlog, then mark "
                "backlog items approved to let execution start."
            )
        else:
            message = (
                "The project backlog is ready. This is the second gate: mark backlog items "
                "approved to let execution start. Completed work is moved to the done file "
                "automatically."
            )
        summary = json.dumps(
            {
                "status": state["approval_status"],
                "message": message,
                "backlog_file": state["backlog_path"],
                "done_file": state["done_path"],
                "plan_file": state["plan_path"],
                "backlog": active_backlog,
            },
            indent=2,
        )
        return {"final_summary": summary, "next_step": "merge"}

    active_backlog_items = sorted(
        [item for item in backlog if item["status"] == "in_progress"],
        key=lambda item: (
            priority_rank(item["priority"]),
            complexity_rank(item["complexity"]),
            item["id"],
        ),
    )[:3]
    if not active_backlog_items:
        return {"next_step": "merge"}
    active_backlog_item = active_backlog_items[0]

    planning_state = {
        **state,
        "active_backlog_item": active_backlog_item,
        "active_backlog_items": active_backlog_items,
    }
    tasks = build_llm_tasks(planning_state) or build_deterministic_tasks(planning_state)
    if not tasks:
        return {"next_step": "merge"}

    return {
        "tasks": tasks,
        "current_task": None,
        "active_backlog_item": active_backlog_item,
        "active_backlog_items": active_backlog_items,
        "next_step": "dispatch",
        "iterations": state["iterations"] + 1,
    }


def dispatcher(state: State) -> dict[str, Any]:
    remaining = list(state.get("tasks", []))
    if not remaining:
        return {"next_step": "merge", "current_task": None}

    current = remaining.pop(0)
    return {
        "tasks": remaining,
        "current_task": current,
        "next_step": current["agent"],
    }


def _task_or_default(state: State, agent: str) -> AgentTask:
    task = state.get("current_task")
    if task and task["agent"] == agent:
        return task
    return {"agent": agent, "instruction": state["instruction"]}


def backend_dev(state: State) -> dict[str, Any]:
    task = _task_or_default(state, "backend_dev")
    active_item = state.get("active_backlog_item")
    phase, activity, next_command = backend_phase_payload(
        active_item, Path(state["project_path"])
    )
    report: AgentReport = {
        "agent": "backend_dev",
        "instruction": task["instruction"],
        "phase": phase,
        "activity": activity,
        "next_command": next_command,
        "summary": (
            "Backend agent advanced the active backend task and updated its current phase, "
            "activity, and next command."
        ),
        "targets": [
            "my-app/backend/cmd/api/main.go",
            "my-app/backend/go.mod",
            "my-app/infra/lib/infra-stack.ts",
        ],
        "commands": [
            "cd my-app/backend && docker build -t panta-go-backend-verify .",
            "cd my-app/infra && npm test -- --runInBand && npm run build",
        ],
        "outcome": "working",
    }
    return {"reports": state["reports"] + [report], "next_step": "dispatch"}


def frontend_dev(state: State) -> dict[str, Any]:
    task = _task_or_default(state, "frontend_dev")
    report: AgentReport = {
        "agent": "frontend_dev",
        "instruction": task["instruction"],
        "phase": "frontend-alignment",
        "activity": (
            "Checking whether the active task touches the mobile/web surface and keeping the "
            "web-first workflow aligned with the repo instructions."
        ),
        "next_command": "cd my-app/mobile && flutter test",
        "summary": (
            "Frontend agent aligned work with .github/copilot-instructions.md and kept the "
            "focus on my-app/mobile plus the web-first workflow."
        ),
        "targets": [
            "my-app/mobile/lib",
            "my-app/mobile/test",
            ".github/copilot-instructions.md",
        ],
        "commands": [
            "cd my-app/mobile && flutter test",
            "cd my-app/mobile && flutter run -d web-server --web-hostname 127.0.0.1 --web-port 3000",
        ],
        "outcome": "working",
    }
    return {"reports": state["reports"] + [report], "next_step": "dispatch"}


def run_detected_tests(project_path: Path) -> list[dict[str, str]]:
    commands = []
    if (project_path / "my-app/mobile").exists():
        commands.append("cd my-app/mobile && flutter test")
    if (project_path / "my-app/infra").exists():
        commands.append("cd my-app/infra && npm test -- --runInBand")

    results: list[dict[str, str]] = []
    for command in commands:
        completed = subprocess.run(
            ["bash", "-lc", command],
            cwd=project_path,
            capture_output=True,
            text=True,
            timeout=300,
        )
        output = (completed.stdout + completed.stderr).strip()
        results.append(
            {
                "command": command,
                "status": "passed" if completed.returncode == 0 else "failed",
                "output": output,
            }
        )
    return results


def summarize_test_results(results: list[dict[str, str]], ran_tests: bool) -> str:
    if not ran_tests:
        return "Tester agent prepared the existing validation commands without running them."
    if not results:
        return "Validation did not run any detected test commands."

    failures = [result for result in results if result["status"] != "passed"]
    if not failures:
        commands = ", ".join(result["command"] for result in results)
        return f"Validation passed for: {commands}"

    snippets = []
    for result in failures:
        output_lines = result["output"].strip().splitlines()
        tail = output_lines[-1].strip() if output_lines else "command failed without output"
        snippets.append(f"{result['command']} -> {tail[:240]}")
    return "Validation failed: " + " | ".join(snippets)


def tester(state: State) -> dict[str, Any]:
    task = _task_or_default(state, "tester")
    project_path = Path(state["project_path"])
    test_results = run_detected_tests(project_path) if state["run_tests"] else []
    active_item = state.get("active_backlog_item")
    outcome = "skipped"

    if state["run_tests"]:
        if test_results and all(result["status"] == "passed" for result in test_results):
            outcome = "passed"
        elif test_results:
            outcome = "failed"

    summary = summarize_test_results(test_results, state["run_tests"])
    has_relevant_changes = bool(relevant_changed_paths(project_path, active_item))

    report: AgentReport = {
        "agent": "tester",
        "instruction": task["instruction"],
        "phase": "validation" if state["run_tests"] else "validation-prep",
        "activity": (
            "Running the existing validation commands after backend implementation handoff."
            if state["run_tests"]
            else (
                "Validation commands are available, but this pass is heartbeat-only."
                if has_relevant_changes
                else "Waiting for task-relevant implementation changes before validation."
            )
        ),
        "next_command": (
            "cd my-app/mobile && flutter test"
            if has_relevant_changes
            else "wait for task-relevant repository edits"
        ),
        "summary": summary,
        "targets": ["my-app/mobile/test", "my-app/infra/test"],
        "commands": [
            "cd my-app/mobile && flutter test",
            "cd my-app/infra && npm test -- --runInBand",
        ],
        "outcome": outcome,
    }
    return {
        "reports": state["reports"] + [report],
        "last_result": json.dumps(test_results, indent=2) if test_results else summary,
        "next_step": "dispatch",
    }


def merge(state: State) -> dict[str, Any]:
    if state.get("final_summary"):
        return {
            "final_summary": state["final_summary"],
            "next_step": END,
        }

    payload = {
        "instruction": state["instruction"],
        "iterations": state["iterations"],
        "active_backlog_item": state.get("active_backlog_item"),
        "active_backlog_items": state.get("active_backlog_items", []),
        "approval_status": state["approval_status"],
        "backlog_file": state["backlog_path"],
        "done_file": state["done_path"],
        "plan_file": state["plan_path"],
        "reports": state["reports"],
        "last_result": state.get("last_result"),
    }
    return {
        "final_summary": json.dumps(payload, indent=2),
        "next_step": END,
    }


def router(state: State) -> str:
    return state["next_step"]


def build_graph():
    builder = StateGraph(State)
    builder.add_node("manager", manager)
    builder.add_node("dispatch", dispatcher)
    builder.add_node("backend_dev", backend_dev)
    builder.add_node("frontend_dev", frontend_dev)
    builder.add_node("tester", tester)
    builder.add_node("merge", merge)

    builder.set_entry_point("manager")
    builder.add_conditional_edges(
        "manager",
        router,
        {
            "dispatch": "dispatch",
            "merge": "merge",
        },
    )
    builder.add_conditional_edges(
        "dispatch",
        router,
        {
            "backend_dev": "backend_dev",
            "frontend_dev": "frontend_dev",
            "tester": "tester",
            "merge": "merge",
        },
    )
    builder.add_edge("backend_dev", "dispatch")
    builder.add_edge("frontend_dev", "dispatch")
    builder.add_edge("tester", "dispatch")
    builder.add_edge("merge", END)
    return builder.compile()


def write_summary_output(output: str, summary: str) -> None:
    if not output:
        return
    output_path = Path(output).resolve()
    output_path.parent.mkdir(parents=True, exist_ok=True)
    output_path.write_text(summary + "\n", encoding="utf-8")


def workflow_signature_bytes(path: Path, relative_path: str) -> bytes:
    if not path.exists():
        return b"<missing>"
    content = path.read_text(encoding="utf-8")
    if relative_path == DEFAULT_BACKLOG_FILE:
        filtered_lines = [
            line
            for line in content.splitlines()
            if not line.startswith("# Last heartbeat at:")
            and not line.startswith("# Loop status:")
        ]
        content = "\n".join(filtered_lines) + "\n"
    return content.encode("utf-8")


def compute_workflow_signature(
    project_path: Path, backlog_file: str, plan_file: str, done_file: str
) -> str:
    digest = hashlib.sha256()
    for relative_path in (plan_file, backlog_file, done_file):
        path = (project_path / relative_path).resolve()
        digest.update(relative_path.encode("utf-8"))
        digest.update(workflow_signature_bytes(path, relative_path))
    return digest.hexdigest()


def run_once(
    args: argparse.Namespace, emit: bool = True, heartbeat_only: bool = False
) -> str:
    project_path = Path(args.project_path).resolve()
    instructions_text = load_instructions(project_path, args.instructions_file)
    backlog, plan_items, backlog_path, done_path, plan_path = load_or_create_project_backlog(
        project_path=project_path,
        backlog_file=args.backlog_file,
        done_file=args.done_file,
        plan_file=args.plan_file,
        backlog_seed=args.backlog_seed,
        recover_stalled=args.recover_stalled,
    )
    backlog = launch_ready_workers(backlog, project_path, instructions_text)
    sync_project_workflow_files(backlog, backlog_path, done_path, plan_items, plan_path)
    approval_status = derive_approval_status(backlog)
    graph = build_graph()

    result = graph.invoke(
        {
            "repo_map": get_repo_map(project_path),
            "instruction": args.instruction,
            "instructions_text": instructions_text,
            "tasks": [],
            "reports": [],
            "current_task": None,
            "active_backlog_item": None,
            "active_backlog_items": [],
            "last_result": None,
            "next_step": "manager",
            "iterations": 0,
            "project_path": str(project_path),
            "max_iterations": args.max_iterations,
            "run_tests": (args.run_tests or args.watch) and not heartbeat_only,
            "model": args.model,
            "final_summary": "",
            "backlog": backlog,
            "backlog_path": str(backlog_path),
            "done_path": str(done_path),
            "plan_path": str(plan_path),
            "approval_status": approval_status,
            "heartbeat_only": heartbeat_only,
        }
    )

    payload = result.get("final_summary")
    if payload:
        try:
            base_summary = json.loads(payload)
        except Exception:
            base_summary = {"result": payload}
    else:
        base_summary = result

    backlog, delivery_candidate_id = apply_agent_reports_to_backlog(
        backlog,
        result.get("reports", []),
        project_path,
    )
    backlog = demote_inactive_in_progress_items(backlog, project_path)
    delivery_item = None
    if delivery_candidate_id is not None:
        delivery_item = next(
            (
                item
                for item in backlog
                if item["id"] == delivery_candidate_id and item["status"] == "in_progress"
            ),
            None,
        )
        if delivery_item is not None:
            stop_worker_launch(project_path, delivery_item["id"])
            delivery_item["status"] = "done"
            delivery_item["blocked_reason"] = ""
            delivery_item["progress_note"] = (
                "tester [done]: Validation passed and the task was committed, pushed, and deployed."
            )
            delivery_item["last_progress_at"] = now_iso()
            delivery_item["last_heartbeat_at"] = delivery_item["last_progress_at"]
    sync_project_workflow_files(backlog, backlog_path, done_path, plan_items, plan_path)
    if delivery_item is not None:
        delivered, delivery_message = commit_completed_item(
            project_path,
            delivery_item,
            backlog_path,
            done_path,
            plan_path,
        )
        if not delivered and delivery_candidate_id is not None:
            delivery_item["status"] = "in_progress"
            delivery_item["blocked_reason"] = (
                f"Validation passed, but commit/push/deploy delivery failed: {delivery_message}"
            )
            delivery_item["progress_note"] = (
                "tester [blocked]: Validation passed, but commit/push/deploy delivery failed."
            )
            delivery_item["last_progress_at"] = now_iso()
            delivery_item["last_heartbeat_at"] = delivery_item["last_progress_at"]
            sync_project_workflow_files(
                backlog,
                backlog_path,
                done_path,
                plan_items,
                plan_path,
            )

    runtime_summary = build_runtime_summary(
        backlog=backlog,
        plan_items=plan_items,
        backlog_path=backlog_path,
        done_path=done_path,
        plan_path=plan_path,
    )
    summary = json.dumps(
        {
            **runtime_summary,
            "loop_result": base_summary,
        },
        indent=2,
    )
    if emit:
        print(summary)
    write_summary_output(args.output, summary)
    return summary


def main() -> int:
    args = parse_args()
    if not args.watch:
        run_once(args)
        return 0

    project_path = Path(args.project_path).resolve()
    last_signature: Optional[str] = None
    while True:
        backlog, plan_items, backlog_path, done_path, plan_path = load_or_create_project_backlog(
            project_path=project_path,
            backlog_file=args.backlog_file,
            done_file=args.done_file,
            plan_file=args.plan_file,
            backlog_seed=args.backlog_seed,
            recover_stalled=args.recover_stalled,
        )
        runtime_summary = build_runtime_summary(
            backlog=backlog,
            plan_items=plan_items,
            backlog_path=backlog_path,
            done_path=done_path,
            plan_path=plan_path,
        )
        write_summary_output(args.output, json.dumps(runtime_summary, indent=2))

        signature = compute_workflow_signature(
            project_path=project_path,
            backlog_file=args.backlog_file,
            plan_file=args.plan_file,
            done_file=args.done_file,
        )
        has_active_backlog = any(item["status"] == "in_progress" for item in backlog)
        has_running_workers = running_worker_count(project_path, backlog) > 0
        if signature != last_signature:
            run_once(args)
            last_signature = compute_workflow_signature(
                project_path=project_path,
                backlog_file=args.backlog_file,
                plan_file=args.plan_file,
                done_file=args.done_file,
            )
        elif has_active_backlog or has_running_workers:
            run_once(args, emit=False, heartbeat_only=True)
        time.sleep(max(args.poll_interval, 1))


if __name__ == "__main__":
    raise SystemExit(main())
