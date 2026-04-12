from __future__ import annotations

import argparse
import json
import os
import re
import subprocess
from pathlib import Path
from typing import Any, Optional, TypedDict

from langgraph.graph import END, StateGraph

try:
    from langchain_openai import ChatOpenAI
except ImportError:  # Optional at runtime when falling back to deterministic routing.
    ChatOpenAI = None


DEFAULT_PROJECT_PATH = Path(".").resolve()
DEFAULT_INSTRUCTIONS_FILE = Path(".github/copilot-instructions.md")
DEFAULT_MODEL = "gpt-4o-mini"
DEFAULT_BACKLOG_FILE = ".copilot/agent-backlog.txt"
DEFAULT_PLAN_FILE = ".copilot/agent-plan.md"
DEFAULT_DONE_FILE = ".copilot/agent-done.txt"
VALID_CATEGORIES = ("backend", "frontend", "both")
VALID_BACKLOG_STATUSES = ("pending", "approved", "in_progress", "done")
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
    summary: str
    targets: list[str]
    commands: list[str]


class BacklogItem(TypedDict):
    id: str
    category: str
    title: str
    details: str
    status: str


class State(TypedDict):
    repo_map: str
    instruction: str
    instructions_text: str
    tasks: list[AgentTask]
    reports: list[AgentReport]
    current_task: Optional[AgentTask]
    active_backlog_item: Optional[BacklogItem]
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
        help="Project-relative plan markdown file generated from approved backlog items.",
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
            }
            backlog.append(current_item)
            continue

        if current_item is not None and (line.startswith("  ") or line.startswith("\t")):
            detail_line = line.lstrip()
            current_item["details"] = (
                f"{current_item['details']}\n{detail_line}".strip()
                if current_item["details"]
                else detail_line
            )

    return backlog


def split_backlog_items(
    backlog: list[BacklogItem],
) -> tuple[list[BacklogItem], list[BacklogItem]]:
    active_items = [item for item in backlog if item["status"] != "done"]
    done_items = [item for item in backlog if item["status"] == "done"]
    return active_items, done_items


def render_backlog_text(backlog: list[BacklogItem]) -> str:
    active_items, _ = split_backlog_items(backlog)
    grouped = {category: [] for category in VALID_CATEGORIES}
    for item in active_items:
        grouped[item["category"]].append(item)

    lines = [
        "# Agent Backlog",
        "# Managed by langgraph_multi_agent.py.",
        "# Approve work by changing an item's status from pending to approved.",
        "# Active status values: pending, approved, in_progress",
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
            lines.append(f"{item['id']} | {item['status']} | {item['title']}")
            if item["details"]:
                for detail_line in item["details"].splitlines():
                    lines.append(f"  {detail_line}")
            lines.append("")
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
            lines.append(f"{item['id']} | {item['status']} | {item['title']}")
            if item["details"]:
                for detail_line in item["details"].splitlines():
                    lines.append(f"  {detail_line}")
            lines.append("")
    return "\n".join(lines).rstrip() + "\n"


def sync_project_workflow_files(
    backlog: list[BacklogItem], backlog_path: Path, done_path: Path
) -> None:
    backlog_path.parent.mkdir(parents=True, exist_ok=True)
    done_path.parent.mkdir(parents=True, exist_ok=True)
    backlog_path.write_text(render_backlog_text(backlog), encoding="utf-8")
    done_path.write_text(render_done_text(backlog), encoding="utf-8")


def load_or_create_project_backlog(
    project_path: Path, backlog_file: str, done_file: str, plan_file: str, backlog_seed: str
) -> tuple[list[BacklogItem], Path, Path, Path]:
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

    plan_path.parent.mkdir(parents=True, exist_ok=True)
    if not plan_path.exists():
        plan_path.write_text(
            "# Agent Plan\n\nCopy the current approved roadmap here and update it as work progresses.\n",
            encoding="utf-8",
        )

    sync_project_workflow_files(backlog, backlog_path, done_path)
    return backlog, backlog_path, done_path, plan_path


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


def build_work_instruction(state: State) -> str:
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
    active_backlog_item = state.get("active_backlog_item")

    tasks: list[AgentTask] = []

    if surfaces["frontend_dev"] and agent_enabled_for_item("frontend_dev", active_backlog_item):
        tasks.append(
            {
                "agent": "frontend_dev",
                "instruction": (
                    f"{instruction}\n\n"
                    "Frontend focus:\n"
                    "- Respect .github/copilot-instructions.md when deciding app targets.\n"
                    "- Prioritize my-app/mobile and web-friendly flows.\n"
                    f"- Relevant paths: {', '.join(surfaces['frontend_dev'])}.\n"
                    f"- Additional instructions context:\n{instructions_text or '(none)'}"
                ),
            }
        )

    if surfaces["backend_dev"] and agent_enabled_for_item("backend_dev", active_backlog_item):
        tasks.append(
            {
                "agent": "backend_dev",
                "instruction": (
                    f"{instruction}\n\n"
                    "Backend focus:\n"
                    "- Cover API, infra, and service-impacting changes when relevant.\n"
                    f"- Relevant paths: {', '.join(surfaces['backend_dev'])}.\n"
                    f"- Additional instructions context:\n{instructions_text or '(none)'}"
                ),
            }
        )

    if agent_enabled_for_item("tester", active_backlog_item):
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
    if ChatOpenAI is None or not has_openai_credentials():
        return None

    llm = ChatOpenAI(model=state["model"], temperature=0)
    active_backlog_item = state.get("active_backlog_item")
    allowed_agents = [
        agent
        for agent in ("backend_dev", "frontend_dev", "tester")
        if agent_enabled_for_item(agent, active_backlog_item)
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
                "Add or approve items in the backlog file to let the work loop continue."
            )
        else:
            message = (
                "The project backlog is ready. Approve work by editing the backlog text file "
                "and changing item statuses to approved. Completed work is moved to the done "
                "file automatically."
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

    active_backlog_item = next(
        (item for item in backlog if item["status"] == "in_progress"),
        None,
    ) or next(
        (item for item in backlog if item["status"] == "approved"),
        None,
    )
    if active_backlog_item is None:
        return {"next_step": "merge"}

    planning_state = {**state, "active_backlog_item": active_backlog_item}
    tasks = build_llm_tasks(planning_state) or build_deterministic_tasks(planning_state)
    if not tasks:
        return {"next_step": "merge"}

    return {
        "tasks": tasks,
        "current_task": None,
        "active_backlog_item": active_backlog_item,
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
    report: AgentReport = {
        "agent": "backend_dev",
        "instruction": task["instruction"],
        "summary": (
            "Backend agent reviewed the instruction set and mapped the likely implementation "
            "surfaces to my-app/backend/cmd/api/main.go and my-app/infra/lib/infra-stack.ts."
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
    }
    return {"reports": state["reports"] + [report], "next_step": "dispatch"}


def frontend_dev(state: State) -> dict[str, Any]:
    task = _task_or_default(state, "frontend_dev")
    report: AgentReport = {
        "agent": "frontend_dev",
        "instruction": task["instruction"],
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


def tester(state: State) -> dict[str, Any]:
    task = _task_or_default(state, "tester")
    project_path = Path(state["project_path"])
    test_results = run_detected_tests(project_path) if state["run_tests"] else []

    summary = (
        "Tester agent executed the detected validation commands."
        if state["run_tests"]
        else "Tester agent prepared the existing validation commands without running them."
    )

    report: AgentReport = {
        "agent": "tester",
        "instruction": task["instruction"],
        "summary": summary,
        "targets": ["my-app/mobile/test", "my-app/infra/test"],
        "commands": [
            "cd my-app/mobile && flutter test",
            "cd my-app/infra && npm test -- --runInBand",
        ],
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


def main() -> int:
    args = parse_args()
    project_path = Path(args.project_path).resolve()
    instructions_text = load_instructions(project_path, args.instructions_file)
    backlog, backlog_path, done_path, plan_path = load_or_create_project_backlog(
        project_path=project_path,
        backlog_file=args.backlog_file,
        done_file=args.done_file,
        plan_file=args.plan_file,
        backlog_seed=args.backlog_seed,
    )
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
            "last_result": None,
            "next_step": "manager",
            "iterations": 0,
            "project_path": str(project_path),
            "max_iterations": args.max_iterations,
            "run_tests": args.run_tests,
            "model": args.model,
            "final_summary": "",
            "backlog": backlog,
            "backlog_path": str(backlog_path),
            "done_path": str(done_path),
            "plan_path": str(plan_path),
            "approval_status": approval_status,
        }
    )

    summary = result.get("final_summary") or json.dumps(result, indent=2)
    print(summary)

    if args.output:
        output_path = Path(args.output).resolve()
        output_path.parent.mkdir(parents=True, exist_ok=True)
        output_path.write_text(summary + "\n", encoding="utf-8")

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
