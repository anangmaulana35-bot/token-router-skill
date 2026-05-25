"""
system_guard.py — Kompres system prompt Nova yang terlalu besar.

Masalah: system prompt berisi USER_MEMORY_PROFILE + playbook + rules
= bisa 10.000+ token, melebihi context window model kecil.

CARA PAKAI:
    from nova_fixes.system_guard import SystemGuard

    sg = SystemGuard(model="claude-haiku-4-5", hard_limit=4000)
    safe_system = sg.compress(your_system_prompt)
    # Gunakan safe_system sebagai system prompt
"""

import re
from typing import Optional

# Token budget untuk system prompt (sisakan ruang untuk messages)
MODEL_SYSTEM_LIMITS = {
    "claude-opus-4-7":    8_000,
    "claude-opus-4-5":    8_000,
    "claude-sonnet-4-6":  8_000,
    "claude-haiku-4-5":   4_000,  # model kecil, limit ketat
    "gpt-4o":             8_000,
    "gpt-4o-mini":        4_000,
    "default":            4_000,
}


def _count_tokens(text: str) -> int:
    return max(len(text.split()), len(text) // 4)


def _remove_examples(text: str) -> str:
    """Hapus blok contoh/example yang verbose."""
    text = re.sub(r"(?i)(contoh|example|e\.g\.|misalnya)[^\n]*\n(.*\n){0,5}", "", text)
    return text


def _remove_duplicate_rules(text: str) -> str:
    """Deduplikasi baris yang mirip."""
    seen = set()
    lines = []
    for line in text.splitlines():
        key = re.sub(r"\W", "", line.lower())[:40]
        if key and key not in seen:
            seen.add(key)
            lines.append(line)
    return "\n".join(lines)


def _keep_sections(text: str, max_tokens: int) -> str:
    """
    Potong dari belakang section per section sampai muat.
    Prioritas: baris pertama (persona) > rules > memory > contoh.
    """
    if _count_tokens(text) <= max_tokens:
        return text

    # Split per section (## atau ---)
    sections = re.split(r"(?m)^(#{1,3} .+|---+)\s*$", text)
    result_sections = []
    used = 0

    for s in sections:
        t = _count_tokens(s)
        if used + t <= max_tokens:
            result_sections.append(s)
            used += t
        else:
            # Coba masukkan sepotong
            chars_left = (max_tokens - used) * 4
            if chars_left > 100:
                snippet = s[:chars_left].rsplit("\n", 1)[0]
                result_sections.append(snippet + "\n[...dipotong untuk hemat token...]")
            break

    return "\n".join(result_sections)


def compress(text: str, hard_limit: int = 4000) -> str:
    """
    Kompres system prompt sampai di bawah hard_limit token.
    Urutan: strip whitespace → hapus contoh → deduplikasi → potong section.
    """
    if _count_tokens(text) <= hard_limit:
        return text

    # Pass 1: strip whitespace berlebih
    text = re.sub(r"\n{3,}", "\n\n", text)
    text = re.sub(r"[ \t]+\n", "\n", text)
    text = re.sub(r" {2,}", " ", text)
    if _count_tokens(text) <= hard_limit:
        return text

    # Pass 2: hapus blok contoh
    text = _remove_examples(text)
    if _count_tokens(text) <= hard_limit:
        return text

    # Pass 3: deduplikasi rules
    text = _remove_duplicate_rules(text)
    if _count_tokens(text) <= hard_limit:
        return text

    # Pass 4: potong section dari belakang
    return _keep_sections(text, hard_limit)


class SystemGuard:
    def __init__(self, model: str = "default", hard_limit: Optional[int] = None):
        self.limit = hard_limit or MODEL_SYSTEM_LIMITS.get(model, MODEL_SYSTEM_LIMITS["default"])
        self.model = model

    def compress(self, system_prompt: str) -> str:
        original_tokens = _count_tokens(system_prompt)
        if original_tokens <= self.limit:
            return system_prompt
        result = compress(system_prompt, self.limit)
        after_tokens = _count_tokens(result)
        saved = original_tokens - after_tokens
        print(f"[SystemGuard] System prompt: {original_tokens}→{after_tokens} token (hemat {saved}, limit={self.limit})")
        return result

    def is_safe(self, system_prompt: str) -> bool:
        return _count_tokens(system_prompt) <= self.limit
