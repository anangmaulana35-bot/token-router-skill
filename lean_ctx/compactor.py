"""
LeanCtx — context compactor untuk hemat token.

Strategi:
1. Hitung token setiap pesan
2. Jika context melebihi budget, ringkas pesan lama
3. Selalu pertahankan system prompt + N pesan terakhir utuh
"""

import re
from typing import List, Dict, Optional


def count_tokens(text: str) -> int:
    # Approximasi: ~4 karakter per token (mendekati cl100k_base untuk teks campuran)
    # Hitung kata + overhead untuk kode/simbol
    words = len(text.split())
    chars = len(text)
    return max(words, chars // 4)


def _tokens_in_message(msg: Dict) -> int:
    return count_tokens(msg.get("content", "")) + 4  # overhead per message


def _strip_whitespace(text: str) -> str:
    text = re.sub(r"\n{3,}", "\n\n", text)
    text = re.sub(r"[ \t]+\n", "\n", text)
    text = re.sub(r" {2,}", " ", text)
    return text.strip()


def _summarize_message(msg: Dict, max_chars: int = 200) -> Dict:
    content = msg.get("content", "")
    if len(content) <= max_chars:
        return msg
    snippet = content[:max_chars].rsplit(" ", 1)[0]
    return {**msg, "content": f"[ringkas] {snippet}…"}


def compact_messages(
    messages: List[Dict],
    token_budget: int = 4096,
    keep_last_n: int = 6,
    system_prompt: Optional[str] = None,
) -> List[Dict]:
    """
    Kembalikan versi messages yang sudah dikompres agar muat dalam token_budget.

    Args:
        messages: List pesan format OpenAI/Anthropic.
        token_budget: Batas token total (default 4096).
        keep_last_n: Jumlah pesan terakhir yang selalu dipertahankan utuh.
        system_prompt: Jika ada, dihitung ke total token.

    Returns:
        List pesan yang sudah dikompres.
    """
    base_tokens = count_tokens(system_prompt) if system_prompt else 0

    # Pisah: pesan yang dilindungi (N terakhir) vs kandidat kompres
    protected = messages[-keep_last_n:] if len(messages) > keep_last_n else messages
    compressible = messages[: max(0, len(messages) - keep_last_n)]

    protected_tokens = sum(_tokens_in_message(m) for m in protected)
    remaining_budget = token_budget - base_tokens - protected_tokens

    if remaining_budget <= 0 or not compressible:
        return protected

    # Coba masukkan pesan compressible dari yang terbaru, ringkas jika perlu
    result = []
    budget_left = remaining_budget

    for msg in reversed(compressible):
        original = {**msg, "content": _strip_whitespace(msg.get("content", ""))}
        tokens = _tokens_in_message(original)

        if tokens <= budget_left:
            result.insert(0, original)
            budget_left -= tokens
        elif budget_left > 50:
            # Ringkas agar muat
            summarized = _summarize_message(original, max_chars=budget_left * 3)
            tokens_after = _tokens_in_message(summarized)
            if tokens_after <= budget_left:
                result.insert(0, summarized)
                budget_left -= tokens_after

    return result + protected


class LeanCtx:
    """
    Wrapper stateful — tambahkan pesan satu per satu,
    dapatkan context yang sudah dikompres kapan saja.

    Contoh:
        ctx = LeanCtx(token_budget=8192, system_prompt="Kamu asisten AI.")
        ctx.add("user", "Halo!")
        ctx.add("assistant", "Halo! Ada yang bisa saya bantu?")
        messages = ctx.get_messages()
    """

    def __init__(
        self,
        token_budget: int = 8192,
        keep_last_n: int = 6,
        system_prompt: Optional[str] = None,
    ):
        self.token_budget = token_budget
        self.keep_last_n = keep_last_n
        self.system_prompt = system_prompt
        self._history: List[Dict] = []

    def add(self, role: str, content: str) -> None:
        self._history.append({"role": role, "content": content})

    def get_messages(self) -> List[Dict]:
        return compact_messages(
            self._history,
            token_budget=self.token_budget,
            keep_last_n=self.keep_last_n,
            system_prompt=self.system_prompt,
        )

    def token_usage(self) -> Dict[str, int]:
        compacted = self.get_messages()
        used = sum(_tokens_in_message(m) for m in compacted)
        if self.system_prompt:
            used += count_tokens(self.system_prompt)
        return {
            "used": used,
            "budget": self.token_budget,
            "saved": sum(_tokens_in_message(m) for m in self._history) - used,
            "history_len": len(self._history),
            "compacted_len": len(compacted),
        }

    def reset(self) -> None:
        self._history.clear()
