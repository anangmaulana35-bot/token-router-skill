import json
import os
import anthropic

CONFIG_PATH = os.path.join(os.path.dirname(__file__), "config.json")

with open(CONFIG_PATH) as f:
    CONFIG = json.load(f)

STRONG_MODEL = CONFIG["strong_model"]
WEAK_MODEL = CONFIG["weak_model"]
DEFAULT_MODEL = CONFIG["api"]["default_model"]
THRESHOLD = CONFIG["threshold"]


def _is_complex(prompt: str) -> bool:
    """Heuristic: long or code-heavy prompts go to strong model."""
    return len(prompt) > 300 or any(
        kw in prompt.lower()
        for kw in ("debug", "refactor", "explain", "architect", "optimize")
    )


def route(prompt: str) -> str:
    """Return model name based on prompt complexity."""
    return STRONG_MODEL if _is_complex(prompt) else WEAK_MODEL


def chat(messages: list[dict], model: str | None = None) -> str:
    """
    Send messages to Claude.  Always includes `model` to avoid
    the 'Missing model' / bad_request error from the Codex UI.
    """
    if not messages:
        raise ValueError("messages must not be empty")

    # Determine model — caller can override, otherwise auto-route
    if model is None:
        last_user = next(
            (m["content"] for m in reversed(messages) if m.get("role") == "user"),
            "",
        )
        model = route(last_user)

    client = anthropic.Anthropic()
    response = client.messages.create(
        model=model,          # always set — fixes "Missing model" error
        max_tokens=1024,
        messages=messages,
    )
    return response.content[0].text


if __name__ == "__main__":
    reply = chat([{"role": "user", "content": "Halo, apa kabar?"}])
    print(reply)
