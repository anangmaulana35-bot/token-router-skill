# INSTRUKSI UNTUK CODEX — Upgrade IG Highlight Sorter dengan Claude Vision AI

Disusun oleh: Claude (planning/reasoning)
Untuk dieksekusi oleh: Codex (coding/execution)
Workspace target: `/Users/anangmaulana/Documents/Automation/IG_Portfolio_Highlights`
Tanggal: 2026-05-16

---

## 1. Ringkasan Tugas

Kamu (Codex) **sudah** membangun `ig_highlight_sorter.py` — web app lokal yang
bagus dengan galeri visual, ingest ZIP, dan build folder GENERATED. **Jangan
rebuild apa pun dari itu.**

Satu-satunya kelemahan: fitur **"Isi saran otomatis"** berbasis heuristik
(tanggal / nama file / tipe media), bukan pemahaman isi gambar. Akibatnya untuk
ribuan archived story sejak 2022, user tetap harus review berat secara manual —
ini akar masalah user ("melelahkan cek satu-satu").

**Tugasmu: tambahkan otak AI (Claude Vision) ke fitur auto-suggest, tanpa
mengubah arsitektur, galeri, atau workflow yang sudah ada.**

---

## 2. Yang HARUS Dipertahankan (jangan disentuh)

- Galeri visual web UI di localhost:8787
- Ingest ZIP/folder dari `00_INBOX_ARSIP_IG`
- Sifat non-destruktif (copy, bukan move/delete)
- Build `02_HIGHLIGHT_READY/GENERATED`
- State persistence (`99_LOGS/sorter_state.json`)
- Manifest CSV, cover PNG, template caption
- 8 kategori highlight: START, WORKS, VIDEO, EVENTS, BTS, RESULTS, ABOUT, CONTACT

---

## 3. File Baru: `ai_classifier.py`

Buat modul terpisah agar `ig_highlight_sorter.py` tetap rapi.

### Fungsi utama

```python
def classify_image(image_path: str, caption: str = "") -> dict:
    """
    Return: {
        "category": "WORKS" | "VIDEO" | "EVENTS" | "BTS" | "RESULTS" | "UNKNOWN",
        "confidence": float,   # 0.0 - 1.0
        "reasoning": str       # 1 kalimat bahasa Indonesia
    }
    """
```

### Spesifikasi

- SDK: `anthropic` (Anthropic Python SDK). Model: `claude-haiku-4-5-20251001`
  (murah & cepat — cocok untuk ribuan gambar).
- `max_tokens`: 200. Suhu default.
- Gambar: baca file → encode base64 → kirim sebagai image content block.
  Resize sisi terpanjang ke maks 1024px sebelum encode (hemat token, pakai
  Pillow). Format dukung: jpg/jpeg/png/webp. HEIC/HEIF: konversi ke JPEG dulu
  (pakai `pillow-heif` kalau perlu) — kalau gagal, return UNKNOWN confidence 0.
- Video (.mp4/.mov/.m4v/.webm): JANGAN kirim ke API. Klasifikasi via metadata:
  default kategori `VIDEO`, confidence 0.6, reasoning "File video — default ke VIDEO".
- Retry: 3x dengan exponential backoff (2s, 4s, 8s) jika API error/timeout.
- Kalau `ANTHROPIC_API_KEY` tidak ada di environment → raise error yang jelas
  supaya pemanggil bisa fallback ke heuristik lama.

### System prompt (pakai persis ini, bahasa Indonesia)

```
Kamu adalah asisten kurasi konten untuk seorang fotografer/videografer
profesional bernama Anang. Tugasmu mengkategorikan satu gambar story Instagram
ke SATU kategori highlight portfolio.

Kategori:
- WORKS    : hasil foto/video yang sudah diedit profesional (portrait, wedding,
             produk, prewedding, foto formal client). Fokus pada KARYA jadi.
- VIDEO    : frame yang jelas dari klip video/reels/motion/dokumentasi gerak.
- EVENTS   : liputan acara/kegiatan (wedding event, gathering, seminar, panggung).
- BTS      : behind the scenes — proses shooting, alat kamera, lighting, tim
             bekerja, kru di lokasi.
- RESULTS  : bukti dipercaya — screenshot chat/DM client, tulisan testimoni,
             review, ucapan terima kasih, angka/statistik hasil.
- UNKNOWN  : tidak jelas / tidak relevan / repost / meme / teks tidak terkait.

Prioritaskan akurasi tertinggi untuk WORKS, RESULTS, dan BTS.

Balas HANYA dengan JSON valid satu baris, tanpa teks lain:
{"category":"...","confidence":0.0,"reasoning":"satu kalimat singkat"}
```

User message: lampirkan gambar + teks `Caption story: "<caption>"` (kalau caption kosong, tulis `Caption story: (kosong)`).

Parse JSON dari respons. Kalau parsing gagal → return UNKNOWN, confidence 0,
reasoning "Gagal parse respons AI".

---

## 4. Cache — `99_LOGS/ai_classification_cache.json`

- Sebelum panggil API, hitung `sha1` dari **isi file** gambar/video.
- Kalau hash sudah ada di cache → pakai hasil cache, JANGAN panggil API.
- Setelah dapat hasil baru → simpan ke cache. Tulis cache secara atomik
  (tulis ke file temp lalu rename) supaya tidak korup kalau proses dihentikan.
- Struktur: `{ "<sha1>": {"category":..., "confidence":..., "reasoning":..., "ts": <unix>} }`

---

## 5. Integrasi ke `ig_highlight_sorter.py`

Pada endpoint/handler tombol **"Isi saran otomatis"**:

1. Untuk tiap media yang belum punya kategori final dari user:
   - Coba `ai_classifier.classify_image(...)`.
   - Kalau modul AI raise (mis. API key tidak ada) → **fallback** ke heuristik
     lama yang sudah ada. Jangan sampai fitur lama rusak.
2. Petakan hasil AI ke state sorter dengan aturan **confidence**:
   - `confidence > 0.85` → set kategori = hasil AI, tandai badge `AUTO` (hijau).
   - `0.6 ≤ confidence ≤ 0.85` → set kategori = hasil AI, badge `SARAN` (kuning),
     minta user konfirmasi di galeri.
   - `confidence < 0.6` atau `UNKNOWN` → JANGAN auto-set. Badge `CEK MANUAL`
     (merah). Biarkan user yang pilih di galeri.
3. Proses **bertahap/batched** (mis. 10 file per putaran) dan kirim update
   progress ke UI (counter "X / total diproses") supaya UI tidak hang untuk
   ribuan story. Boleh pakai polling endpoint progress sederhana.
4. Simpan badge + reasoning ke state supaya tampil di kartu galeri
   (tooltip / teks kecil di bawah thumbnail: alasan AI).

### Mapping ke 8 kategori highlight Codex

AI hanya mengklasifikasi 5 kategori bulk. Pemetaan ke highlight final:

| Output AI | Highlight Codex |
|-----------|-----------------|
| WORKS     | WORKS           |
| VIDEO     | VIDEO           |
| EVENTS    | EVENTS          |
| BTS       | BTS             |
| RESULTS   | RESULTS         |
| UNKNOWN   | (kosong, user pilih manual) |

`START`, `ABOUT`, `CONTACT` = kurasi manual oleh user (jumlah sedikit, bukan
masalah bulk archive). Jangan dipaksa di-AI.

Prioritas user (dari konfirmasi): **Hasil Foto/Video → WORKS+VIDEO**,
**Testimoni Client → RESULTS**, **BTS → BTS**. Tiga ini yang paling penting akurat.

---

## 6. Config & Environment

- Buat `.env.example`:
  ```
  ANTHROPIC_API_KEY=isi_api_key_disini
  AI_MODEL=claude-haiku-4-5-20251001
  AI_CONF_AUTO=0.85
  AI_CONF_SUGGEST=0.6
  ```
- Baca `.env` kalau ada (pakai `python-dotenv`, atau baca manual sederhana —
  jangan tambah dependency berat tanpa perlu).
- `requirements.txt` (buat/update): tambahkan
  ```
  anthropic>=0.40.0
  pillow>=10.0.0
  pillow-heif>=0.16.0
  python-dotenv>=1.0.0
  ```

---

## 7. Update `README.md`

Tambahkan seksi baru:

- **"Setup AI (opsional tapi sangat disarankan)"**: cara dapat
  `ANTHROPIC_API_KEY`, cara isi `.env`, `pip install -r requirements.txt`.
- **"Cara kerja saran AI"**: jelaskan badge AUTO/SARAN/CEK MANUAL.
- **"Estimasi biaya"**: claude-haiku sangat murah untuk gambar; sekitar
  beberapa dollar saja untuk ribuan story, dan hanya sekali (hasil di-cache,
  jalan ulang gratis). Tegaskan: tanpa API key, sorter tetap jalan pakai
  heuristik lama (fallback otomatis).
- Tegaskan ulang: tahap memasukkan story final ke Highlight tetap manual di
  app Instagram (batasan Instagram, tidak bisa diotomasi dari luar).

---

## 8. Verifikasi (lakukan setelah implementasi)

1. `pip install -r requirements.txt` → sukses tanpa error.
2. **Tanpa** `ANTHROPIC_API_KEY`: jalankan sorter, klik "Isi saran otomatis"
   → harus tetap jalan via heuristik lama (fallback), tidak crash.
3. **Dengan** API key + sample export di INBOX: klik "Isi saran otomatis"
   → tiap kartu punya kategori + reasoning AI (bukan sekadar tebak tanggal).
4. Cek badge: confidence tinggi = AUTO, sedang = SARAN, rendah/UNKNOWN = CEK MANUAL.
5. Klik "Isi saran otomatis" lagi → harus pakai cache (tidak panggil API,
   selesai jauh lebih cepat, log tidak ada request baru).
6. Ubah beberapa kategori manual di galeri → "Buat folder final" →
   `02_HIGHLIGHT_READY/GENERATED` terisi sesuai pilihan final.
7. File asli di INBOX tidak berubah/terhapus.

---

## 9. Prinsip Eksekusi

- Perubahan minimal, tepat sasaran. Jangan refactor yang tidak diminta.
- Fitur lama tidak boleh rusak (fallback heuristik wajib jalan tanpa API key).
- Non-destruktif tetap dijaga.
- Kalau ada keputusan ambigu (mis. struktur state berubah), pilih opsi yang
  paling tidak mengganggu workflow existing, dan catat di README.
