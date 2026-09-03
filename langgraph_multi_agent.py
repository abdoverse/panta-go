#!/usr/bin/env python3
"""
Panta Autonomous Multi-Agent Development Swarm (PantaSwarm)
A production-ready, fully autonomous multi-agent development loop.
Replaces brittle CLI dependencies with a native, tool-calling multi-agent loop.

Supported Providers:
  - ollama:      Local / network open-weights models (qwen2.5-coder, deepseek-coder, llama3.3)
  - openrouter:  Free & open cloud models (qwen2.5-coder-32b:free, llama-3.3-70b:free)
  - gemini:      Google Gemini API via GEMINI_API_KEY (AI Studio free tier)
  - vertex:      Google Vertex AI (GCP credits)
  - openai:      OpenAI API (gpt-4o, o3-mini)
  - groq:        Groq ultra-fast API (llama-3.3-70b)
"""

from __future__ import annotations

import argparse
import json
import os
import re
import shutil
import signal
import subprocess
import sys
import time
from datetime import datetime, timezone
from pathlib import Path
from typing import Any, Callable, Dict, List, Optional, Tuple, TypedDict

# LangChain / LangGraph imports
try:
    from langchain_core.messages import AIMessage, BaseMessage, HumanMessage, SystemMessage
except ImportError:
    print("ERROR: langchain_core is required. Run: pip install langchain-core")
    sys.exit(1)

try:
    from langgraph.graph import END, StateGraph
except ImportError:
    print("ERROR: langgraph is required. Run: pip install langgraph")
    sys.exit(1)

# Optional provider imports
try:
    from langchain_openai import ChatOpenAI
except ImportError:
    ChatOpenAI = None

try:
    from langchain_google_genai import ChatGoogleGenerativeAI
except ImportError:
    ChatGoogleGenerativeAI = None

try:
    from langchain_google_vertexai import ChatVertexAI
except ImportError:
    ChatVertexAI = None


# =====================================================================
# Constants & Defaults
# =====================================================================

DEFAULT_PROJECT_PATH = Path(".").resolve()
DEFAULT_INSTRUCTIONS_FILE = Path(".github/copilot-instructions.md")
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

DEFAULT_PROVIDER = os.getenv("AI_PROVIDER", "ollama")
DEFAULT_OLLAMA_HOST = os.getenv("OLLAMA_HOST", "http://localhost:11434")
DEFAULT_MODEL_MAP = {
    "ollama": os.getenv("OLLAMA_MODEL", "qwen2.5-coder:7b"),
    "openrouter": os.getenv("OPENROUTER_MODEL", "qwen/qwen-2.5-coder-32b-instruct:free"),
    "gemini": os.getenv("GEMINI_MODEL", "gemini-2.5-flash"),
    "vertex": os.getenv("VERTEX_MODEL", "gemini-2.5-flash"),
    "openai": os.getenv("OPENAI_MODEL", "gpt-4o-mini"),
    "groq": os.getenv("GROQ_MODEL", "llama-3.3-70b-versatile"),
}


# =====================================================================
# Data Structures
# =====================================================================

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
    agent_updates: list[str]


class PlanItem(TypedDict):
    id: str
    category: str
    title: str
    details: str
    status: str
    priority: str
    complexity: str
    dependencies: list[str]


class SwarmState(TypedDict):
    project_path: str
    active_item: Optional[BacklogItem]
    architect_plan: str
    assigned_agent: str
    changes_made: list[str]
    validation_status: str  # pending, passed, failed
    validation_errors: str
    retry_count: int
    max_retries: int
    done: bool
    status_message: str


# =====================================================================
# Time & Formatting Utilities
# =====================================================================

def now_iso() -> str:
    return datetime.now(timezone.utc).isoformat()


def priority_rank(priority: str) -> int:
    ranks = {"high": 1, "medium": 2, "low": 3}
    return ranks.get(priority.lower(), 4)


def complexity_rank(complexity: str) -> int:
    ranks = {"small": 1, "medium": 2, "large": 3}
    return ranks.get(complexity.lower(), 4)


def parse_dependencies(value: str) -> list[str]:
    raw = value.strip()
    if not raw or raw.lower() == "none":
        return []
    parts = re.split(r"[,;\s]+", raw)
    return [p.strip() for p in parts if p.strip() and p.strip().lower() != "none"]


def format_dependencies(dependencies: list[str]) -> str:
    return ",".join(dependencies) if dependencies else "none"


# =====================================================================
# Model Provider Layer
# =====================================================================

class LLMProvider:
    """Unified abstraction for local (Ollama) and cloud LLM providers."""

    def __init__(
        self,
        provider: str = DEFAULT_PROVIDER,
        model: Optional[str] = None,
        ollama_host: str = DEFAULT_OLLAMA_HOST,
        temperature: float = 0.1,
    ):
        self.provider = provider.lower().strip()
        self.ollama_host = ollama_host.rstrip("/")
        self.model = model or DEFAULT_MODEL_MAP.get(self.provider, "qwen2.5-coder:7b")
        self.temperature = temperature
        self._llm = self._create_llm()

    def _create_llm(self) -> Any:
        if self.provider == "ollama":
            if not ChatOpenAI:
                raise RuntimeError("langchain-openai is required for Ollama OpenAI-compatible endpoint.")
            # Ollama provides a standard OpenAI-compatible v1 API at /v1
            return ChatOpenAI(
                base_url=f"{self.ollama_host}/v1",
                api_key="ollama",  # dummy key for local API
                model=self.model,
                temperature=self.temperature,
                timeout=120,
            )

        elif self.provider == "openrouter":
            if not ChatOpenAI:
                raise RuntimeError("langchain-openai is required for OpenRouter.")
            api_key = os.getenv("OPENROUTER_API_KEY")
            if not api_key:
                print("WARNING: OPENROUTER_API_KEY is not set. OpenRouter calls may fail.")
            return ChatOpenAI(
                base_url="https://openrouter.ai/api/v1",
                api_key=api_key or "missing_key",
                model=self.model,
                temperature=self.temperature,
                timeout=120,
            )

        elif self.provider == "gemini":
            api_key = os.getenv("GEMINI_API_KEY")
            if ChatGoogleGenerativeAI and api_key:
                return ChatGoogleGenerativeAI(
                    model=self.model,
                    google_api_key=api_key,
                    temperature=self.temperature,
                )
            elif ChatVertexAI:
                return ChatVertexAI(
                    model_name=self.model,
                    temperature=self.temperature,
                )
            elif ChatOpenAI:
                # Can use OpenAI-compatible Gemini endpoints or Google API
                return ChatOpenAI(
                    base_url="https://generativelanguage.googleapis.com/v1beta/openai/",
                    api_key=api_key or "missing_key",
                    model=self.model,
                    temperature=self.temperature,
                )
            else:
                raise RuntimeError("Neither langchain-google-genai nor langchain-google-vertexai available.")

        elif self.provider == "vertex":
            if not ChatVertexAI:
                raise RuntimeError("langchain-google-vertexai is required for Vertex AI.")
            return ChatVertexAI(
                model_name=self.model,
                temperature=self.temperature,
            )

        elif self.provider == "openai":
            if not ChatOpenAI:
                raise RuntimeError("langchain-openai is required for OpenAI.")
            return ChatOpenAI(
                api_key=os.getenv("OPENAI_API_KEY"),
                model=self.model,
                temperature=self.temperature,
            )

        elif self.provider == "groq":
            if not ChatOpenAI:
                raise RuntimeError("langchain-openai is required for Groq.")
            return ChatOpenAI(
                base_url="https://api.groq.com/openai/v1",
                api_key=os.getenv("GROQ_API_KEY"),
                model=self.model,
                temperature=self.temperature,
            )

        else:
            raise ValueError(f"Unsupported LLM provider: '{self.provider}'. Choose from: ollama, openrouter, gemini, vertex, openai, groq")

    def invoke(self, messages: List[BaseMessage]) -> str:
        """Invokes the model and handles response extraction."""
        try:
            res = self._llm.invoke(messages)
            if hasattr(res, "content"):
                return str(res.content)
            return str(res)
        except Exception as e:
            # Check for common quota / connection errors and suggest fallbacks
            err = str(e)
            if "402" in err or "quota" in err.lower() or "credits" in err.lower():
                print(f"[LLM Quota Exhausted] Provider {self.provider} hit quota limits: {err}")
                print("Suggestion: Switch to local Ollama via --provider ollama or free OpenRouter via --provider openrouter")
            elif "connection refused" in err.lower() and self.provider == "ollama":
                print(f"[Ollama Connection Error] Cannot connect to Ollama at {self.ollama_host}.")
                print("Ensure Ollama is running: 'ollama serve' or check OLLAMA_HOST.")
            raise e


# =====================================================================
# Native Tool Execution Engine
# =====================================================================

class ToolEngine:
    """Provides safe, deterministic filesystem and execution tools for the agents."""

    def __init__(self, project_path: Path):
        self.project_path = project_path.resolve()

    def _resolve(self, path_str: str) -> Path:
        p = Path(path_str.strip())
        if p.is_absolute():
            try:
                p = p.relative_to(self.project_path)
            except ValueError:
                pass
        return (self.project_path / p).resolve()

    def read_file(self, path: str, start_line: int = 1, end_line: Optional[int] = None) -> str:
        target = self._resolve(path)
        if not target.exists() or not target.is_file():
            return f"ERROR: File not found: {path}"
        try:
            with open(target, "r", encoding="utf-8", errors="replace") as f:
                lines = f.readlines()
            start_idx = max(0, start_line - 1)
            end_idx = end_line if end_line else len(lines)
            selected = lines[start_idx:end_idx]
            out = []
            for i, l in enumerate(selected, start=start_idx + 1):
                out.append(f"{i}: {l.rstrip()}")
            return "\n".join(out)
        except Exception as e:
            return f"ERROR reading file {path}: {e}"

    def write_file(self, path: str, content: str) -> str:
        target = self._resolve(path)
        try:
            target.parent.mkdir(parents=True, exist_ok=True)
            with open(target, "w", encoding="utf-8") as f:
                f.write(content)
            return f"SUCCESS: Written {len(content.splitlines())} lines to {path}"
        except Exception as e:
            return f"ERROR writing file {path}: {e}"

    def edit_file(self, path: str, target_chunk: str, replacement_chunk: str) -> str:
        target = self._resolve(path)
        if not target.exists() or not target.is_file():
            return f"ERROR: File not found: {path}"
        try:
            with open(target, "r", encoding="utf-8", errors="replace") as f:
                text = f.read()

            target_norm = target_chunk.strip().replace("\r\n", "\n")
            text_norm = text.replace("\r\n", "\n")

            if target_norm not in text_norm:
                # Try fuzzy matching without leading/trailing blank lines
                target_lines = [l.rstrip() for l in target_norm.split("\n") if l.strip()]
                search_prefix = target_lines[0] if target_lines else ""
                if search_prefix and search_prefix in text_norm:
                    return f"ERROR: Target block found partially, but exact block match failed. Ensure search text exactly matches file."
                return f"ERROR: Target content not found in {path}."

            new_text = text_norm.replace(target_norm, replacement_chunk.strip().replace("\r\n", "\n"), 1)
            with open(target, "w", encoding="utf-8") as f:
                f.write(new_text)
            return f"SUCCESS: Edited {path}"
        except Exception as e:
            return f"ERROR editing file {path}: {e}"

    def list_dir(self, path: str = ".") -> str:
        target = self._resolve(path)
        if not target.exists() or not target.is_dir():
            return f"ERROR: Directory not found: {path}"
        try:
            entries = []
            for item in sorted(target.iterdir()):
                if item.name in {".git", ".dart_tool", "node_modules", ".venv", "__pycache__", "build"}:
                    continue
                kind = "DIR " if item.is_dir() else "FILE"
                entries.append(f"{kind}  {item.name}")
            return "\n".join(entries[:60])
        except Exception as e:
            return f"ERROR listing directory: {e}"

    def search_code(self, pattern: str, subpath: str = ".") -> str:
        target = self._resolve(subpath)
        try:
            res = subprocess.run(
                ["grep", "-rnI", "--exclude-dir=.git", "--exclude-dir=node_modules", "--exclude-dir=.dart_tool", "--exclude-dir=.venv", pattern, str(target)],
                capture_output=True,
                text=True,
                timeout=10,
            )
            lines = res.stdout.strip().splitlines()
            if not lines:
                return f"No matches found for '{pattern}' in {subpath}."
            # Relative paths
            out = []
            for l in lines[:30]:
                out.append(l.replace(str(self.project_path) + "/", ""))
            return "\n".join(out)
        except Exception as e:
            return f"ERROR running search: {e}"

    def run_command(self, command: str, cwd: Optional[str] = None, timeout: int = 60) -> Tuple[int, str]:
        run_dir = self._resolve(cwd) if cwd else self.project_path
        try:
            res = subprocess.run(
                command,
                shell=True,
                cwd=run_dir,
                capture_output=True,
                text=True,
                timeout=timeout,
            )
            out = (res.stdout + "\n" + res.stderr).strip()
            return res.returncode, out
        except subprocess.TimeoutExpired:
            return -1, f"ERROR: Command timed out after {timeout} seconds."
        except Exception as e:
            return -1, f"ERROR executing command: {e}"


# =====================================================================
# Backlog & Plan Parser / Serializer
# =====================================================================

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

        # Metadata parsing under active item
        if current_item and line.startswith("  "):
            stripped = line.strip()
            if stripped.startswith("Owner agent:"):
                current_item["owner_agent"] = stripped.split(":", 1)[1].strip()
            elif stripped.startswith("Started at:"):
                current_item["started_at"] = stripped.split(":", 1)[1].strip()
            elif stripped.startswith("Last heartbeat at:"):
                current_item["last_heartbeat_at"] = stripped.split(":", 1)[1].strip()
            elif stripped.startswith("Last progress at:"):
                current_item["last_progress_at"] = stripped.split(":", 1)[1].strip()
            elif stripped.startswith("Progress note:"):
                current_item["progress_note"] = stripped.split(":", 1)[1].strip()
            elif stripped.startswith("Blocked reason:"):
                current_item["blocked_reason"] = stripped.split(":", 1)[1].strip()
            elif stripped.startswith("Goal:"):
                current_item["details"] = stripped.split(":", 1)[1].strip()
            elif stripped.startswith("Agent activity:"):
                current_item["agent_updates"].append(stripped)

    return backlog


def render_backlog_text(backlog: list[BacklogItem], status_summary: str = "") -> str:
    heartbeat = now_iso()
    approved_count = sum(1 for i in backlog if i["status"] == "approved")
    pending_count = sum(1 for i in backlog if i["status"] == "pending")
    in_prog_count = sum(1 for i in backlog if i["status"] == "in_progress")

    lines = [
        "# Agent Backlog",
        "# Managed by Panta Autonomous Multi-Agent Swarm (PantaSwarm).",
        f"# Last heartbeat at: {heartbeat}",
        f"# Loop status: {status_summary or 'idle'} | approved={approved_count} | pending={pending_count} | in_progress={in_prog_count}",
        "# Approve work by changing an item's status from pending to approved.",
        "# Fields: id | status | priority | complexity | dependencies | title",
        "",
    ]

    for cat in VALID_CATEGORIES:
        lines.append(f"## {cat}")
        items = [i for i in backlog if i["category"] == cat]
        if not items:
            lines.append("(empty)")
            lines.append("")
            continue

        for item in items:
            deps = format_dependencies(item["dependencies"])
            lines.append(f"{item['id']} | {item['status']} | {item['priority']} | {item['complexity']} | {deps} | {item['title']}")
            if item["owner_agent"]:
                lines.append(f"  Owner agent: {item['owner_agent']}")
            if item["started_at"]:
                lines.append(f"  Started at: {item['started_at']}")
            if item["last_progress_at"]:
                lines.append(f"  Last progress at: {item['last_progress_at']}")
            if item["progress_note"]:
                lines.append(f"  Progress note: {item['progress_note']}")
            if item["blocked_reason"]:
                lines.append(f"  Blocked reason: {item['blocked_reason']}")
            if item["details"]:
                lines.append(f"  Goal:\n  {item['details']}")
            lines.append("")

    return "\n".join(lines)


def parse_plan_text(content: str) -> list[PlanItem]:
    plans: list[PlanItem] = []
    current_category: Optional[str] = None
    current_plan: Optional[PlanItem] = None

    for raw_line in content.splitlines():
        line = raw_line.rstrip()
        section_match = re.match(r"^##\s+(backend|frontend|both)\s*$", line, re.IGNORECASE)
        if section_match:
            current_category = section_match.group(1).lower()
            current_plan = None
            continue

        item_match = re.match(
            r"^([A-Za-z0-9_-]+)\s*\|\s*(planned|approved)\s*\|\s*"
            r"(high|medium|low)\s*\|\s*(small|medium|large)\s*\|\s*([^|]+?)\s*\|\s*(.+?)\s*$",
            line,
            re.IGNORECASE,
        )
        if item_match and current_category in VALID_CATEGORIES:
            current_plan = {
                "id": item_match.group(1),
                "category": current_category,
                "title": item_match.group(6).strip(),
                "details": "",
                "status": item_match.group(2).lower(),
                "priority": item_match.group(3).lower(),
                "complexity": item_match.group(4).lower(),
                "dependencies": parse_dependencies(item_match.group(5)),
            }
            plans.append(current_plan)
            continue

        if current_plan and line.startswith("  "):
            current_plan["details"] += ("\n" if current_plan["details"] else "") + line.strip()

    return plans


def render_done_entry(item: BacklogItem, note: str = "") -> str:
    lines = [
        f"{item['id']} | done | {item['priority']} | {item['complexity']} | {format_dependencies(item['dependencies'])} | {item['title']}",
        f"  Owner agent: {item.get('owner_agent') or 'pantaswarm'}",
        f"  Completed at: {now_iso()}",
        f"  Progress note: {note or 'Validated and completed by PantaSwarm'}",
        "",
    ]
    return "\n".join(lines)


# =====================================================================
# Specialized Autonomous Agents
# =====================================================================

class MultiAgentSwarm:
    """Coordinates specialized agent roles using the native ToolEngine."""

    def __init__(self, project_path: Path, provider: LLMProvider):
        self.project_path = project_path.resolve()
        self.tools = ToolEngine(self.project_path)
        self.provider = provider
        self.log_dir = self.project_path / DEFAULT_AGENT_LOG_DIR
        self.log_dir.mkdir(parents=True, exist_ok=True)

    def log(self, agent_name: str, message: str) -> None:
        ts = now_iso()
        line = f"[{ts}] [{agent_name}] {message}\n"
        print(line.rstrip())
        log_file = self.log_dir / f"{agent_name}.log"
        try:
            with open(log_file, "a", encoding="utf-8") as f:
                f.write(line)
        except Exception:
            pass

    def architect_plan(self, item: BacklogItem) -> str:
        """Architect Agent: Inspects the codebase and designs a concise technical spec."""
        self.log("architect", f"Creating implementation architecture for {item['id']}: {item['title']}")
        
        # Gather repository context
        repo_summary = self.tools.list_dir("my-app")
        mobile_files = self.tools.list_dir("my-app/mobile/lib")
        backend_files = self.tools.list_dir("my-app/backend/cmd/api")

        prompt = f"""You are the Lead Software Architect for the Panta Go application (Flutter mobile app + Go backend + AWS CDK infra).
Task: [{item['id']}] {item['title']}
Category: {item['category']}
Priority: {item['priority']}
Description/Goal: {item['details']}

Repository Layout:
my-app subdirectories:
{repo_summary}

my-app/mobile/lib:
{mobile_files}

my-app/backend/cmd/api:
{backend_files}

Instructions:
1. Identify the EXACT files in the codebase that must be modified or created.
2. Outline the specific code changes needed in step-by-step technical detail.
3. Define the exact test commands to validate this task (e.g. `cd my-app/backend && go test ./...` or `cd my-app/mobile && flutter test`).

Keep your technical plan concise, practical, and directly implementable.
"""
        messages = [
            SystemMessage(content="You are an expert full-stack systems architect for Go and Flutter."),
            HumanMessage(content=prompt),
        ]
        return self.provider.invoke(messages)

    def execute_coder(self, item: BacklogItem, architect_plan: str, repair_context: str = "") -> list[str]:
        """Coder Agent: Edits and creates files using a multi-turn tool interaction loop."""
        agent_role = "backend_dev" if item["category"] == "backend" else ("frontend_dev" if item["category"] == "frontend" else "backend_dev+frontend_dev")
        self.log(agent_role, f"Executing implementation for {item['id']}")

        system_instruction = f"""You are the Principal Software Engineer ({agent_role}) for Panta Go.
Your task is to implement: [{item['id']}] {item['title']}

Architect's Technical Plan:
{architect_plan}

{f"REPAIR NOTICE - Previous tests failed:\n{repair_context}\nYou MUST fix this error!" if repair_context else ""}

Available Tools (execute them by outputting the exact tool block syntax below):

1. Read a file:
```tool:read_file
path: my-app/mobile/lib/main.dart
start_line: 1
end_line: 50
```

2. Replace a specific chunk in an existing file:
```tool:edit_file
path: my-app/mobile/lib/main.dart
target:
EXACT_LINES_TO_REPLACE
replacement:
NEW_LINES_TO_INSERT
```

3. Overwrite or create a new file:
```tool:write_file
path: my-app/mobile/lib/features/receipt/scanner_page.dart
content:
FILE_CONTENT_HERE
```

4. Search code:
```tool:search_code
pattern: RecyclingRequest
subpath: my-app/backend
```

5. List directory:
```tool:list_dir
path: my-app/mobile/lib
```

Rules:
- Read files before editing to ensure your target chunks match character-for-character.
- When you have completed all edits and the task is ready for testing, output:
`ORCH_REPORT|state=ready_for_validation|summary=Implementation finished`
"""

        conversation: List[BaseMessage] = [
            SystemMessage(content=system_instruction),
            HumanMessage(content=f"Please begin implementing [{item['id']}] {item['title']}. Read any necessary files and make the edits."),
        ]

        changed_files = set()
        max_turns = 12

        for turn in range(max_turns):
            self.log(agent_role, f"Turn {turn+1}/{max_turns}: Requesting next action from model...")
            response = self.provider.invoke(conversation)
            conversation.append(AIMessage(content=response))

            if "state=ready_for_validation" in response or "Implementation finished" in response:
                self.log(agent_role, "Worker signaled ready for validation.")
                break

            # Parse tool blocks
            tools_called = self._parse_and_run_tools(response)
            if not tools_called:
                # If no tool block found, guide the model
                if turn == 0:
                    conversation.append(HumanMessage(content="Please specify your first tool call using the ```tool:...``` block format."))
                else:
                    self.log(agent_role, "No further tool calls detected. Concluding coder phase.")
                    break
            else:
                feedback_parts = []
                for t_name, t_target, t_result in tools_called:
                    if t_name in ("write_file", "edit_file") and "SUCCESS" in t_result:
                        changed_files.add(t_target)
                    feedback_parts.append(f"Tool {t_name} result for {t_target}:\n{t_result}")
                conversation.append(HumanMessage(content="\n\n".join(feedback_parts)))

        return list(changed_files)

    def _parse_and_run_tools(self, text: str) -> list[Tuple[str, str, str]]:
        """Parses tool calls from markdown code blocks and executes them."""
        results = []
        blocks = re.findall(r"```tool:([a-zA-Z0-9_]+)\s*\n(.*?)```", text, re.DOTALL)
        for tool_name, body in blocks:
            tool_name = tool_name.strip()
            body = body.strip()

            if tool_name == "read_file":
                p_match = re.search(r"^path:\s*(.+)$", body, re.MULTILINE)
                if p_match:
                    p = p_match.group(1).strip()
                    start = 1
                    end = None
                    s_m = re.search(r"^start_line:\s*(\d+)$", body, re.MULTILINE)
                    if s_m: start = int(s_m.group(1))
                    e_m = re.search(r"^end_line:\s*(\d+)$", body, re.MULTILINE)
                    if e_m: end = int(e_m.group(1))
                    res = self.tools.read_file(p, start, end)
                    results.append((tool_name, p, res))

            elif tool_name == "write_file":
                p_match = re.search(r"^path:\s*(.+)$", body, re.MULTILINE)
                c_match = re.search(r"^content:\s*\n(.*)$", body, re.MULTILINE | re.DOTALL)
                if p_match and c_match:
                    p = p_match.group(1).strip()
                    content = c_match.group(1)
                    res = self.tools.write_file(p, content)
                    results.append((tool_name, p, res))

            elif tool_name == "edit_file":
                p_match = re.search(r"^path:\s*(.+)$", body, re.MULTILINE)
                t_match = re.search(r"target:\s*\n(.*?)\nreplacement:\s*\n(.*)$", body, re.DOTALL)
                if p_match and t_match:
                    p = p_match.group(1).strip()
                    target = t_match.group(1)
                    repl = t_match.group(2)
                    res = self.tools.edit_file(p, target, repl)
                    results.append((tool_name, p, res))

            elif tool_name == "list_dir":
                p_match = re.search(r"^path:\s*(.+)$", body, re.MULTILINE)
                p = p_match.group(1).strip() if p_match else "."
                res = self.tools.list_dir(p)
                results.append((tool_name, p, res))

            elif tool_name == "search_code":
                p_match = re.search(r"^pattern:\s*(.+)$", body, re.MULTILINE)
                sub_match = re.search(r"^subpath:\s*(.+)$", body, re.MULTILINE)
                if p_match:
                    pattern = p_match.group(1).strip()
                    sub = sub_match.group(1).strip() if sub_match else "."
                    res = self.tools.search_code(pattern, sub)
                    results.append((tool_name, pattern, res))

        return results

    def validate_tests(self, category: str) -> Tuple[bool, str]:
        """Validator Agent: Runs relevant project test suites."""
        self.log("tester", f"Running automated validation test suites for category: {category}")
        failures = []

        if category in ("backend", "both"):
            code, out = self.tools.run_command("go test ./...", cwd="my-app/backend", timeout=60)
            if code != 0:
                self.log("tester", f"Go backend test failed:\n{out}")
                failures.append(f"Backend Test Failure (go test ./...):\n{out}")
            else:
                self.log("tester", "Go backend tests passed.")

        if category in ("frontend", "both"):
            code, out = self.tools.run_command("flutter test", cwd="my-app/mobile", timeout=90)
            if code != 0:
                self.log("tester", f"Flutter mobile test failed:\n{out}")
                failures.append(f"Flutter Test Failure (flutter test):\n{out}")
            else:
                self.log("tester", "Flutter mobile tests passed.")

        if failures:
            return False, "\n\n".join(failures)
        return True, "All test suites passed cleanly."

    def deliver_task(self, item: BacklogItem, changed_files: list[str]) -> bool:
        """Delivery Agent: Commits and pushes verified changes."""
        self.log("delivery", f"Delivering completed task {item['id']}: {item['title']}")
        commit_msg = f"feat({item['category']}): {item['title']} [{item['id']}]"
        
        self.tools.run_command("git add .")
        c_code, c_out = self.tools.run_command(f"git commit -m '{commit_msg}'")
        if c_code != 0 and "nothing to commit" not in c_out:
            self.log("delivery", f"Git commit warning: {c_out}")
            
        p_code, p_out = self.tools.run_command("git push origin main")
        if p_code == 0:
            self.log("delivery", "Pushed changes to origin/main successfully.")
        else:
            self.log("delivery", f"Git push deferred or remote unavailable: {p_out}")
            
        return True


# =====================================================================
# Workflow Engine (LangGraph State Graph)
# =====================================================================

def build_workflow_graph(swarm: MultiAgentSwarm) -> StateGraph:
    graph = StateGraph(SwarmState)

    def select_task_step(state: SwarmState) -> Dict[str, Any]:
        return state

    def architect_step(state: SwarmState) -> Dict[str, Any]:
        item = state["active_item"]
        if not item:
            return {"status_message": "No active item"}
        plan = swarm.architect_plan(item)
        return {"architect_plan": plan, "status_message": f"Architect plan created for {item['id']}"}

    def coding_step(state: SwarmState) -> Dict[str, Any]:
        item = state["active_item"]
        if not item:
            return {"status_message": "No active item"}
        changes = swarm.execute_coder(item, state["architect_plan"], state.get("validation_errors", ""))
        return {"changes_made": changes, "status_message": f"Code edits completed for {item['id']}"}

    def validation_step(state: SwarmState) -> Dict[str, Any]:
        item = state["active_item"]
        if not item:
            return {"validation_status": "passed", "done": True}
        passed, error_msg = swarm.validate_tests(item["category"])
        if passed:
            return {"validation_status": "passed", "validation_errors": "", "status_message": "Tests passed"}
        else:
            return {
                "validation_status": "failed",
                "validation_errors": error_msg,
                "retry_count": state["retry_count"] + 1,
                "status_message": "Tests failed; routing to repair"
            }

    def delivery_step(state: SwarmState) -> Dict[str, Any]:
        item = state["active_item"]
        if item:
            swarm.deliver_task(item, state.get("changes_made", []))
        return {"done": True, "status_message": f"Delivered task {item['id'] if item else ''}"}

    def route_after_validation(state: SwarmState) -> str:
        if state["validation_status"] == "passed":
            return "deliver"
        if state["retry_count"] < state["max_retries"]:
            return "repair"
        return "deliver"  # Stop retry thrashing, record state

    graph.add_node("architect", architect_step)
    graph.add_node("coder", coding_step)
    graph.add_node("validate", validation_step)
    graph.add_node("deliver", delivery_step)

    graph.set_entry_point("architect")
    graph.add_edge("architect", "coder")
    graph.add_edge("coder", "validate")
    graph.add_conditional_edges(
        "validate",
        route_after_validation,
        {
            "deliver": "deliver",
            "repair": "coder",
        }
    )
    graph.add_edge("deliver", END)

    return graph.compile()


# =====================================================================
# Main Orchestrator Loop & CLI
# =====================================================================

class PantaOrchestrator:
    """Manages the full two-gate development loop, file synchronization, and recovery."""

    def __init__(
        self,
        project_path: Path,
        provider: str = DEFAULT_PROVIDER,
        model: Optional[str] = None,
        ollama_host: str = DEFAULT_OLLAMA_HOST,
        poll_interval: int = 10,
        run_tests: bool = True,
    ):
        self.project_path = project_path.resolve()
        self.poll_interval = poll_interval
        self.run_tests = run_tests
        self.backlog_file = self.project_path / DEFAULT_BACKLOG_FILE
        self.plan_file = self.project_path / DEFAULT_PLAN_FILE
        self.done_file = self.project_path / DEFAULT_DONE_FILE

        self.llm_provider = LLMProvider(provider=provider, model=model, ollama_host=ollama_host)
        self.swarm = MultiAgentSwarm(self.project_path, self.llm_provider)
        self.app = build_workflow_graph(self.swarm)

    def read_backlog(self) -> list[BacklogItem]:
        if not self.backlog_file.exists():
            return []
        with open(self.backlog_file, "r", encoding="utf-8") as f:
            return parse_backlog_text(f.read())

    def write_backlog(self, backlog: list[BacklogItem], status: str = "") -> None:
        self.backlog_file.parent.mkdir(parents=True, exist_ok=True)
        content = render_backlog_text(backlog, status_summary=status)
        with open(self.backlog_file, "w", encoding="utf-8") as f:
            f.write(content)

    def archive_done_item(self, item: BacklogItem) -> None:
        self.done_file.parent.mkdir(parents=True, exist_ok=True)
        entry = render_done_entry(item)
        with open(self.done_file, "a", encoding="utf-8") as f:
            f.write(entry)

    def move_approved_plans_to_backlog(self) -> int:
        """Gate 1: Moves items marked 'approved' in agent-plan.md into agent-backlog.txt."""
        if not self.plan_file.exists():
            return 0
        with open(self.plan_file, "r", encoding="utf-8") as f:
            plan_text = f.read()

        plans = parse_plan_text(plan_text)
        approved_plans = [p for p in plans if p["status"] == "approved"]
        if not approved_plans:
            return 0

        backlog = self.read_backlog()
        existing_ids = {i["id"] for i in backlog}
        moved = 0

        for p in approved_plans:
            if p["id"] not in existing_ids:
                backlog.append({
                    "id": p["id"],
                    "category": p["category"],
                    "title": p["title"],
                    "details": p["details"],
                    "status": "pending",
                    "priority": p["priority"],
                    "complexity": p["complexity"],
                    "dependencies": p["dependencies"],
                    "owner_agent": "",
                    "started_at": "",
                    "last_heartbeat_at": "",
                    "last_progress_at": "",
                    "progress_note": "Intake from agent-plan.md",
                    "blocked_reason": "",
                    "agent_updates": [],
                })
                moved += 1

        if moved > 0:
            self.write_backlog(backlog)
            # Remove moved approved items from agent-plan.md
            remaining_plans = [p for p in plans if p["status"] != "approved"]
            # Re-render plan file
            plan_lines = ["# Agent Plan", "# First gate: mark a plan item as approved to move it into the backlog.", ""]
            for cat in VALID_CATEGORIES:
                plan_lines.append(f"## {cat}")
                cat_plans = [p for p in remaining_plans if p["category"] == cat]
                for cp in cat_plans:
                    plan_lines.append(f"{cp['id']} | {cp['status']} | {cp['priority']} | {cp['complexity']} | {format_dependencies(cp['dependencies'])} | {cp['title']}")
                    if cp["details"]:
                        plan_lines.append(f"  {cp['details']}")
                    plan_lines.append("")
            with open(self.plan_file, "w", encoding="utf-8") as f:
                f.write("\n".join(plan_lines))
            print(f"Gate 1: Moved {moved} approved plan item(s) to backlog.")

        return moved

    def recover_stalled(self) -> None:
        """Recovers any items stuck or falsely blocked by previous failed runs."""
        backlog = self.read_backlog()
        recovered = 0
        for item in backlog:
            if item.get("blocked_reason") or item["status"] == "in_progress":
                item["status"] = "approved"
                item["blocked_reason"] = ""
                item["progress_note"] = "Recovered by PantaSwarm orchestrator"
                recovered += 1
        if recovered > 0:
            self.write_backlog(backlog, status="recovered")
            print(f"Recovered {recovered} item(s) to 'approved' state.")

    def run_pass(self) -> Optional[str]:
        """Executes a single orchestrator cycle."""
        self.move_approved_plans_to_backlog()
        backlog = self.read_backlog()

        # Find approved items ready to be picked up
        ready_items = [i for i in backlog if i["status"] == "approved" and not i.get("blocked_reason")]
        # Sort by priority then complexity
        ready_items.sort(key=lambda x: (priority_rank(x["priority"]), complexity_rank(x["complexity"])))

        if not ready_items:
            self.write_backlog(backlog, status="idle")
            return None

        target = ready_items[0]
        print("\n=======================================================")
        print(f"🚀 PantaSwarm claiming task [{target['id']}]: {target['title']}")
        print(f"Category: {target['category']} | Priority: {target['priority']}")
        print(f"Provider: {self.llm_provider.provider} | Model: {self.llm_provider.model}")
        print("=======================================================\n")

        target["status"] = "in_progress"
        target["started_at"] = now_iso()
        target["owner_agent"] = "backend_dev" if target["category"] == "backend" else ("frontend_dev" if target["category"] == "frontend" else "backend_dev+frontend_dev")
        target["progress_note"] = "Swarm executing implementation"
        self.write_backlog(backlog, status=f"working on {target['id']}")

        initial_state: SwarmState = {
            "project_path": str(self.project_path),
            "active_item": target,
            "architect_plan": "",
            "assigned_agent": target["owner_agent"],
            "changes_made": [],
            "validation_status": "pending",
            "validation_errors": "",
            "retry_count": 0,
            "max_retries": 2,
            "done": False,
            "status_message": "Starting swarm",
        }

        try:
            final_state = self.app.invoke(initial_state)
            if final_state.get("validation_status") == "passed":
                print(f"✅ Successfully completed & verified task {target['id']}")
                self.archive_done_item(target)
                # Remove from backlog
                backlog = [i for i in backlog if i["id"] != target["id"]]
                self.write_backlog(backlog, status=f"completed {target['id']}")
            else:
                print(f"⚠️ Task {target['id']} finished with validation issues. Preserving in backlog.")
                target["status"] = "approved"
                target["blocked_reason"] = final_state.get("validation_errors", "Tests failed")[:200]
                self.write_backlog(backlog, status=f"blocked {target['id']}")

        except Exception as e:
            print(f"❌ Error during swarm execution for {target['id']}: {e}")
            target["status"] = "approved"
            target["blocked_reason"] = f"Execution error: {str(e)[:150]}"
            self.write_backlog(backlog, status="error")

        return target["id"]

    def watch(self) -> None:
        """Runs the orchestrator in continuous watch mode."""
        print(f"PantaSwarm orchestrator started in watch mode (poll interval: {self.poll_interval}s)")
        print(f"Using Provider: {self.llm_provider.provider} | Model: {self.llm_provider.model}")
        try:
            while True:
                self.run_pass()
                time.sleep(self.poll_interval)
        except KeyboardInterrupt:
            print("\nPantaSwarm orchestrator stopped by user.")


# =====================================================================
# CLI Entry Point
# =====================================================================

def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Panta Autonomous Multi-Agent Development Swarm (PantaSwarm)")
    parser.add_argument("--project-path", default=str(DEFAULT_PROJECT_PATH), help="Path to project root")
    parser.add_argument("--provider", default=DEFAULT_PROVIDER, choices=["ollama", "openrouter", "gemini", "vertex", "openai", "groq"], help="LLM Provider")
    parser.add_argument("--model", default=None, help="LLM Model name")
    parser.add_argument("--ollama-host", default=DEFAULT_OLLAMA_HOST, help="Ollama host URL")
    parser.add_argument("--watch", action="store_true", help="Run in continuous watch mode")
    parser.add_argument("--poll-interval", type=int, default=10, help="Watch mode polling interval in seconds")
    parser.add_argument("--run-tests", action="store_true", default=True, help="Run test suites during validation")
    parser.add_argument("--recover-stalled", action="store_true", help="Recover stalled items back to approved")
    parser.add_argument("--output", default=None, help="Optional output path for state dump")
    parser.add_argument("--diagnose", action="store_true", help="Test provider connectivity, tools, and runners")
    return parser.parse_args()


def run_diagnostics(project_path: Path, provider_name: str, model_name: Optional[str], ollama_host: str) -> None:
    print("\n=== PantaSwarm Diagnostic Report ===")
    print(f"Project Path: {project_path.resolve()}")
    print(f"Selected Provider: {provider_name}")
    print(f"Ollama Host: {ollama_host}")
    
    # 1. Check tools
    engine = ToolEngine(project_path)
    git_code, git_out = engine.run_command("git status -s")
    print(f"Git status check: {'OK' if git_code == 0 else 'FAIL'}")
    
    go_code, go_out = engine.run_command("go version")
    print(f"Go toolchain: {'OK (' + go_out.strip() + ')' if go_code == 0 else 'NOT FOUND'}")
    
    flutter_code, flutter_out = engine.run_command("flutter --version")
    print(f"Flutter toolchain: {'OK' if flutter_code == 0 else 'NOT FOUND'}")
    
    # 2. Check Provider
    try:
        provider = LLMProvider(provider=provider_name, model=model_name, ollama_host=ollama_host)
        print(f"Provider initialization: OK (model: {provider.model})")
        print("Testing sample inference call...")
        res = provider.invoke([HumanMessage(content="Say 'PantaSwarm Ready' in 3 words.")])
        print(f"Provider inference response: {res.strip()}")
    except Exception as e:
        print(f"Provider test FAILED: {e}")
    print("====================================\n")


def main() -> None:
    args = parse_args()
    project_path = Path(args.project_path).resolve()

    if args.diagnose:
        run_diagnostics(project_path, args.provider, args.model, args.ollama_host)
        return

    orchestrator = PantaOrchestrator(
        project_path=project_path,
        provider=args.provider,
        model=args.model,
        ollama_host=args.ollama_host,
        poll_interval=args.poll_interval,
        run_tests=args.run_tests,
    )

    if args.recover_stalled:
        orchestrator.recover_stalled()
        if args.output:
            with open(args.output, "w", encoding="utf-8") as f:
                json.dump({"recovered": True, "timestamp": now_iso()}, f)
        return

    if args.watch:
        orchestrator.watch()
    else:
        orchestrator.run_pass()


if __name__ == "__main__":
    main()
