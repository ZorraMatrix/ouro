"""Cron/scheduler tools: list, add, remove, toggle recurring tasks."""

from __future__ import annotations

import logging
from typing import Any, Dict, List

from ouro.tools.registry import ToolContext, ToolEntry

log = logging.getLogger(__name__)


def _cron_list(ctx: ToolContext, **kwargs) -> str:
    from supervisor.cron import list_crons
    crons = list_crons()
    if not crons:
        return "No crons configured."
    lines = []
    for c in crons:
        status = "ON" if c.get("enabled") else "OFF"
        last = c.get("last_fired_at") or "never"
        lines.append(
            f"[{c['id']}] {status} | {c['expression']} | fires={c.get('fire_count', 0)} "
            f"| last={last} | {c['description'][:80]}"
        )
    return "\n".join(lines)


def _cron_add(ctx: ToolContext, expression: str, description: str,
              notify: bool = False, **kwargs) -> str:
    from supervisor.cron import add_cron
    try:
        entry = add_cron(expression=expression, description=description, notify=notify)
        return f"OK: cron {entry['id']} created. Expression: {expression}, Description: {description}"
    except ValueError as e:
        return f"ERROR: {e}"


def _cron_remove(ctx: ToolContext, cron_id: str, **kwargs) -> str:
    from supervisor.cron import remove_cron
    ok = remove_cron(cron_id)
    return f"OK: cron {cron_id} removed." if ok else f"ERROR: cron {cron_id} not found."


def _cron_toggle(ctx: ToolContext, cron_id: str, enabled: bool = True, **kwargs) -> str:
    from supervisor.cron import toggle_cron
    result = toggle_cron(cron_id, enabled=enabled)
    if result is None:
        return f"ERROR: cron {cron_id} not found."
    state = "enabled" if result["enabled"] else "disabled"
    return f"OK: cron {cron_id} {state}."


def get_tools() -> List[ToolEntry]:
    return [
        ToolEntry("cron_list", {
            "name": "cron_list",
            "description": "List all scheduled crons with their status, expression, and fire history.",
            "parameters": {"type": "object", "properties": {}, "required": []},
        }, _cron_list, timeout_sec=10),
        ToolEntry("cron_add", {
            "name": "cron_add",
            "description": (
                "Add a recurring scheduled task. Uses standard cron expressions "
                "(5-field: min hour dom month dow) or aliases (@hourly, @daily, @weekly, @monthly). "
                "The description becomes the task text when fired."
            ),
            "parameters": {"type": "object", "properties": {
                "expression": {"type": "string", "description": "Cron expression (e.g. '0 */6 * * *', '@daily')"},
                "description": {"type": "string", "description": "Task description (becomes task text when fired)"},
                "notify": {"type": "boolean", "default": False, "description": "Send Telegram notification on fire"},
            }, "required": ["expression", "description"]},
        }, _cron_add, timeout_sec=10),
        ToolEntry("cron_remove", {
            "name": "cron_remove",
            "description": "Remove a scheduled cron by ID.",
            "parameters": {"type": "object", "properties": {
                "cron_id": {"type": "string", "description": "Cron ID to remove"},
            }, "required": ["cron_id"]},
        }, _cron_remove, timeout_sec=10),
        ToolEntry("cron_toggle", {
            "name": "cron_toggle",
            "description": "Enable or disable a cron without removing it.",
            "parameters": {"type": "object", "properties": {
                "cron_id": {"type": "string", "description": "Cron ID to toggle"},
                "enabled": {"type": "boolean", "description": "true to enable, false to disable"},
            }, "required": ["cron_id", "enabled"]},
        }, _cron_toggle, timeout_sec=10),
    ]
