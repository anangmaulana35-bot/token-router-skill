"""
ctx_guard.py — Fix context window overflow Nova.

CARA PAKAI (tempel di bot_main.py atau conversation_handler.py):

    from nova_fixes.ctx_guard import CtxGuard
    guard = CtxGuard(model="claude-opus-4-7")  # sesuaikan model

    # Sebelum kirim ke LLM:
    safe_messages = guard.compact(messages)
    response = client.messages.create(messages=safe_messages, ...)
"""

import re
from typing import List, Dict, Optional

# Batas context per model (pakai 80% dari max untuk safety margin)
MODEL_LIMITS = {
    "claude-opus-4-7":    160_000,
    "claude-opus-4-5":    200_000,
    "claude-sonnet-4-6":  200_000,
    "claude-haiku-4-5":   200_000,
    "gpt-4o":             100_000,
    "gpt-4o-mini":        100_000,
    "default":             60_000,
}

SAFETY_RATIO = 0.80  # pakai max 80% dari limit


def _count_tokens(text: str) -> int:
    return max(len(text.split()), len(text) // 4)


def _tokens_in(msg: Dict) -> int:
    content = msg.get("content", "")
    if isinstance(content, list):  # Anthropic format
        content = " ".join(
            b.get("text", "") for b in content if isinstance(b, dict)
        )
    return _count_tokens(str(content)) + 4


def _strip(text: str) -> str:
    text = re.sub(r"\n{3,}", "\n\n", text)
    text = re.sub(r"[ \t]+\n", "\n", text)
    return text.strip()


def _truncate(msg: Dict, max_chars: int) -> Dict:
    content = msg.get("content", "")
    if isinstance(content, str) and len(content) > max_chars:
        snippet = content[:max_chars].rsplit(" ", 1)[0]
        return {**msg, "content": f"[dipotong] {snippet}…"}
    return msg


def compact(
    messages: List[Dict],
    budget: int,
    keep_last: int = 8,
    system: Optional[str] = None,
) -> List[Dict]:
    """Potong history lama agar total token muat dalam budget."""
    base = _count_tokens(system) if system else 0
    protected = messages[-keep_last:] if len(messages) > keep_last else list(messages)
    old = messages[: max(0, len(messages) - keep_last)]

    used = base + sum(_tokens_in(m) for m in protected)
    remaining = budget - used

    if remaining <= 0 or not old:
        return protected

    result = []
    for msg in reversed(old):
        clean = {**msg, "content": _strip(str(msg.get("content", "")))}
        t = _tokens_in(clean)
        if t <= remaining:
            result.insert(0, clean)
            remaining -= t
        elif remaining > 80:
            truncated = _truncate(clean, remaining * 3)
            t2 = _tokens_in(truncated)
            if t2 <= remaining:
                result.insert(0, truncated)
                remaining -= t2

    return result + protected


class CtxGuard:
    """Drop-in wrapper: panggil guard.compact(messages) sebelum kirim ke LLM."""

    def __init__(self, model: str = "default", keep_last: int = 8, system: Optional[str] = None):
        limit = MODEL_LIMITS.get(model, MODEL_LIMITS["default"])
        self.budget = int(limit * SAFETY_RATIO)
        self.keep_last = keep_last
        self.system = system
        self.model = model

    def compact(self, messages: List[Dict]) -> List[Dict]:
        total = sum(_tokens_in(m) for m in messages)
        if total <= self.budget:
            return messages
        result = compact(messages, self.budget, self.keep_last, self.system)
        saved = total - sum(_tokens_in(m) for m in result)
        print(f"[CtxGuard] {len(messages)}→{len(result)} msgs, ~{saved} token dipangkas (budget={self.budget})")
        return result

    def fits(self, messages: List[Dict]) -> bool:
        return sum(_tokens_in(m) for m in messages) <= self.budget
