import os
from pathlib import Path
from anthropic import Anthropic

SYSTEM_PROMPT_PATH = Path(__file__).parent / "system_prompt.txt"

client = Anthropic(api_key=os.environ["ANTHROPIC_API_KEY"])


def load_system_prompt() -> str:
    return SYSTEM_PROMPT_PATH.read_text(encoding="utf-8")


def chat(history: list[dict], user_message: str) -> tuple[str, list[dict]]:
    history.append({"role": "user", "content": user_message})

    response = client.messages.create(
        model="claude-haiku-4-5-20251001",
        max_tokens=4096,
        system=load_system_prompt(),
        messages=history,
    )

    reply = response.content[0].text
    history.append({"role": "assistant", "content": reply})
    return reply, history


def main():
    print("Nova online. Ketik 'quit' untuk keluar.\n")
    history: list[dict] = []

    while True:
        user_input = input("Anang: ").strip()
        if not user_input:
            continue
        if user_input.lower() in ("quit", "exit", "keluar"):
            print("Nova: Sampai nanti, Anang.")
            break

        reply, history = chat(history, user_input)
        print(f"\nNova: {reply}\n")


if __name__ == "__main__":
    main()
