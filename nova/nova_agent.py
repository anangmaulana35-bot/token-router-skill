"""
Nova Agent — AI personal assistant Anang.
Fixed: context overflow, stream timeout, auto-recovery.
"""

import os
import re
import sys
from pathlib import Path
from typing import Optional

from anthropic import Anthropic, APIError

# ── Config ────────────────────────────────────────────────────────────────────
MODEL           = os.getenv("NOVA_MODEL", "claude-haiku-4-5-20251001")
MAX_TOKENS      = int(os.getenv("NOVA_MAX_TOKENS", "2048"))
SYSTEM_PATH     = Path(__file__).parent / "system_prompt.txt"

# Berapa token max yang BOLEH dipakai history (sisakan ruang untuk system + reply)
# Haiku context = 200k, tapi kita batasi ketat agar tidak pernah overflow
HISTORY_BUDGET  = int(os.getenv("NOVA_HISTORY_BUDGET", "6000"))
# Berapa pesan terakhir yang selalu dipertahankan utuh
KEEP_LAST       = int(os.getenv("NOVA_KEEP_LAST", "8"))
# Max karakter system prompt (lebih dari ini → dikompres)
SYSTEM_MAX_CHARS = int(os.getenv("NOVA_SYSTEM_MAX_CHARS", "3000"))

client = Anthropic(api_key=os.environ["ANTHROPIC_API_KEY"])


# ── Token counting ─────────────────────────────────────────────────────────────
def _approx_tokens(text: str) -> int:
    return max(len(text.split()), len(text) // 4)


def _msg_tokens(msg: dict) -> int:
    return _approx_tokens(str(msg.get("content", ""))) + 4


# ── System prompt — load + compress ───────────────────────────────────────────
def _compress_system(text: str, max_chars: int) -> str:
    """Potong system prompt yang terlalu besar agar tidak overflow sendiri."""
    if len(text) <= max_chars:
        return text
    # Hapus baris kosong berlebih
    text = re.sub(r"\n{3,}", "\n\n", text)
    text = re.sub(r"[ \t]+\n", "\n", text)
    if len(text) <= max_chars:
        return text
    # Potong dari belakang per section
    sections = re.split(r"(?m)^(#{1,3} .+|---+)\s*$", text)
    result, used = [], 0
    for s in sections:
        if used + len(s) <= max_chars:
            result.append(s)
            used += len(s)
        else:
            remaining = max_chars - used
            if remaining > 200:
                result.append(s[:remaining].rsplit("\n", 1)[0])
                result.append("\n[...dipotong untuk hemat token...]")
            break
    return "\n".join(result)


def load_system_prompt() -> str:
    if SYSTEM_PATH.exists():
        raw = SYSTEM_PATH.read_text(encoding="utf-8")
    else:
        raw = "Kamu adalah Nova, AI personal assistant Anang Maulana."
    return _compress_system(raw, SYSTEM_MAX_CHARS)


# ── Context compaction ────────────────────────────────────────────────────────
def compact_history(history: list[dict]) -> list[dict]:
    """
    Potong history lama agar total token di bawah HISTORY_BUDGET.
    Selalu pertahankan KEEP_LAST pesan terakhir utuh.
    """
    total = sum(_msg_tokens(m) for m in history)
    if total <= HISTORY_BUDGET:
        return history

    protected = history[-KEEP_LAST:] if len(history) > KEEP_LAST else list(history)
    old = history[: max(0, len(history) - KEEP_LAST)]

    protected_tokens = sum(_msg_tokens(m) for m in protected)
    budget_left = HISTORY_BUDGET - protected_tokens

    result = []
    for msg in reversed(old):
        content = re.sub(r"\n{3,}", "\n\n", str(msg.get("content", ""))).strip()
        clean = {**msg, "content": content}
        t = _msg_tokens(clean)
        if t <= budget_left:
            result.insert(0, clean)
            budget_left -= t
        elif budget_left > 80:
            snippet = content[: budget_left * 3].rsplit(" ", 1)[0]
            truncated = {**msg, "content": f"[dipotong] {snippet}…"}
            result.insert(0, truncated)
            break
        else:
            break

    after = result + protected
    saved = total - sum(_msg_tokens(m) for m in after)
    if saved > 0:
        print(f"[Nova] Context compact: {len(history)}→{len(after)} pesan, ~{saved} token dihemat.")
    return after


# ── Chat ──────────────────────────────────────────────────────────────────────
_system_prompt: Optional[str] = None


def get_system() -> str:
    global _system_prompt
    if _system_prompt is None:
        _system_prompt = load_system_prompt()
    return _system_prompt


def chat(history: list[dict], user_message: str) -> tuple[str, list[dict]]:
    history = history + [{"role": "user", "content": user_message}]

    # Compact SEBELUM kirim ke API
    safe_history = compact_history(history)
    system = get_system()

    try:
        response = client.messages.create(
            model=MODEL,
            max_tokens=MAX_TOKENS,
            system=system,
            messages=safe_history,
        )
        reply = response.content[0].text

    except APIError as e:
        msg = str(e)
        if "context" in msg.lower() or "too long" in msg.lower() or "exceeds" in msg.lower():
            # Context masih overflow → drastis: buang semua kecuali 2 pesan terakhir
            print("[Nova] Context overflow! Membuang history lama...")
            minimal = safe_history[-2:] if len(safe_history) >= 2 else safe_history
            try:
                response = client.messages.create(
                    model=MODEL,
                    max_tokens=MAX_TOKENS,
                    system=system,
                    messages=minimal,
                )
                reply = response.content[0].text
                # Reset history ke yang minimal
                history = minimal + [{"role": "assistant", "content": reply}]
                print("[Nova] Recovery berhasil dengan history minimal.")
                return reply, history
            except APIError:
                reply = (
                    "Maaf, context terlalu penuh dan recovery gagal. "
                    "Ketik /clear untuk reset history, lalu coba lagi."
                )
                return reply, history[-KEEP_LAST:]
        raise

    history.append({"role": "assistant", "content": reply})
    return reply, history


# ── Main loop ─────────────────────────────────────────────────────────────────
def main():
    print("Nova online. Perintah: /clear (reset history), /status (cek token), quit.\n")
    history: list[dict] = []

    while True:
        try:
            user_input = input("Anang: ").strip()
        except (EOFError, KeyboardInterrupt):
            print("\nNova: Sampai nanti, Anang.")
            break

        if not user_input:
            continue

        if user_input.lower() in ("quit", "exit", "keluar"):
            print("Nova: Sampai nanti, Anang.")
            break

        if user_input == "/clear":
            history = []
            print("Nova: History direset. Kita mulai fresh.\n")
            continue

        if user_input == "/status":
            total = sum(_msg_tokens(m) for m in history)
            sys_tokens = _approx_tokens(get_system())
            print(f"Nova: History {len(history)} pesan (~{total} token) | "
                  f"System prompt ~{sys_tokens} token | "
                  f"Budget history {HISTORY_BUDGET} token\n")
            continue

        reply, history = chat(history, user_input)
        print(f"\nNova: {reply}\n")


if __name__ == "__main__":
    main()
