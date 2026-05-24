"""
Contoh: integrasi LeanCtx + RouteLLM untuk hemat token maksimal.
"""

from lean_ctx import LeanCtx, count_tokens

# Setup LeanCtx dengan budget 4096 token
ctx = LeanCtx(
    token_budget=4096,
    keep_last_n=6,
    system_prompt="Kamu adalah asisten AI yang membantu coding.",
)

# Simulasi percakapan panjang
conversation = [
    ("user", "Halo, saya butuh bantuan membuat REST API dengan FastAPI."),
    ("assistant", "Tentu! FastAPI adalah framework Python modern yang cepat. Mari mulai dengan instalasi: `pip install fastapi uvicorn`"),
    ("user", "Oke, sudah install. Sekarang bagaimana cara membuat endpoint GET?"),
    ("assistant", "Buat file `main.py` lalu tulis:\n\n```python\nfrom fastapi import FastAPI\n\napp = FastAPI()\n\n@app.get('/')\ndef read_root():\n    return {'Hello': 'World'}\n```\n\nJalankan dengan: `uvicorn main:app --reload`"),
    ("user", "Bagaimana cara tambah parameter di endpoint?"),
    ("assistant", "Gunakan path parameter atau query parameter:\n\n```python\n@app.get('/items/{item_id}')\ndef read_item(item_id: int, q: str = None):\n    return {'item_id': item_id, 'q': q}\n```"),
    ("user", "Sekarang saya butuh endpoint POST dengan request body."),
    ("assistant", "Pakai Pydantic model untuk request body:\n\n```python\nfrom pydantic import BaseModel\n\nclass Item(BaseModel):\n    name: str\n    price: float\n\n@app.post('/items/')\ndef create_item(item: Item):\n    return item\n```"),
    ("user", "Bagaimana cara tambah autentikasi JWT?"),
]

for role, content in conversation:
    ctx.add(role, content)

# Lihat statistik token
stats = ctx.token_usage()
print("=== LeanCtx Token Stats ===")
print(f"History asli  : {stats['history_len']} pesan")
print(f"Setelah kompak: {stats['compacted_len']} pesan")
print(f"Token dipakai : {stats['used']} / {stats['budget']}")
print(f"Token dihemat : {stats['saved']}")
print()

# Dapatkan messages yang sudah dikompres
messages = ctx.get_messages()
print("=== Messages yang dikirim ke API ===")
for i, msg in enumerate(messages, 1):
    tokens = count_tokens(msg["content"])
    preview = msg["content"][:60].replace("\n", " ")
    print(f"{i}. [{msg['role']:9}] {tokens:3} token | {preview}…")

# Integrasi dengan OpenAI/Anthropic client (uncomment jika pakai live API)
# import anthropic
# client = anthropic.Anthropic()
# response = client.messages.create(
#     model="claude-haiku-4-5",
#     max_tokens=1024,
#     system=ctx.system_prompt,
#     messages=messages,
# )
# print(response.content[0].text)
