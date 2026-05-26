# Troubleshooting — iPad Mirroring Error

## Gejala (screenshot)

- Layar "Select Host" di Moonlight menampilkan **2 entry "MacMonitor"**:
  - Entry 1 → ikon **segitiga kuning !** (error/koneksi gagal)
  - Entry 2 → ikon **spinner** (sedang mencoba connect)
- Tidak bisa masuk ke sesi mirroring

---

## Penyebab Paling Umum

| Penyebab | Tanda | Fix Cepat |
|----------|-------|-----------|
| **Duplikat host** — IP Tailscale berubah | 2 entry nama sama | Hapus entry lama di Moonlight |
| **Lumen tidak jalan** | Spinner terus, lalu error | Buka/restart Lumen.app di Mac |
| **Izin Screen Recording dicabut** | Error di log Lumen: `permission denied` | System Settings → Privacy → Screen Recording |
| **Tailscale mati** | Semua entry error setelah beberapa menit | `tailscale up` di Mac |
| **Lumen berjalan 2 instance** | 2 entry, keduanya muncul bersamaan | `pkill -x lumen`, restart sekali |

---

## Cara Baca Log

### 1. Jalankan diagnostic otomatis (dari repo ini)

```bash
bash scripts/diagnose_ipad_mirror.sh
```

Script memeriksa: proses Lumen, port, Tailscale, izin, dan menampilkan log error secara otomatis.

### 2. Baca log Lumen manual

```bash
# Cari file log Lumen/Sunshine
find "$HOME" -name "sunshine.log" -o -name "lumen.log" 2>/dev/null

# Baca 100 baris terakhir
tail -100 ~/.cache/sunshine/sunshine.log

# Filter error saja
grep -iE "error|fail|denied|refused|timeout" ~/.cache/sunshine/sunshine.log | tail -30
```

### 3. Log macOS Console

```bash
# Error Lumen di system log (10 menit terakhir)
log show --predicate 'process == "lumen" OR process == "sunshine"' \
         --last 10m --style compact
```

---

## Langkah Fix — Urutan

### Step 1 — Restart Lumen (Mac)

```bash
pkill -x lumen 2>/dev/null || pkill -x sunshine 2>/dev/null
sleep 3
open /Applications/Lumen.app
```

Tunggu hingga ikon Lumen muncul di menu bar.

### Step 2 — Pastikan Tailscale aktif

```bash
tailscale status   # harus muncul "This device: ..."
tailscale ip -4    # catat IP ini, contoh: 100.x.x.x
```

Jika belum aktif:
```bash
tailscale up
```

### Step 3 — Bersihkan entry di Moonlight (iPad)

1. Tekan lama entry **MacMonitor** dengan ikon error → **Delete**
2. Ulangi sampai semua entry lama terhapus
3. Ketuk **"+ Add Host"**
4. Masukkan IP Tailscale dari Step 2
5. Ketuk **Connect** → masukkan PIN yang muncul di Mac

### Step 4 — Izin Screen Recording (jika masih error)

```
System Settings → Privacy & Security → Screen Recording
→ Pastikan Lumen (atau Sunshine) dicentang ✓
→ Jika belum muncul: drag Lumen.app ke daftar ini
```

Setelah mengubah izin, **restart Lumen** wajib dilakukan.

---

## Error Spesifik di Log

### `[Error] Screen capture permission denied`
→ Lumen tidak punya izin Screen Recording → lihat Step 4

### `[Error] Failed to bind to port 47984`
→ Port dipakai proses lain atau Lumen instance ganda
```bash
lsof -i TCP:47984
pkill -x lumen
open /Applications/Lumen.app
```

### `[Error] Client certificate verification failed`
→ Pairing kadaluarsa → hapus entry di Moonlight + pair ulang (Step 3)

### `[Warn] No display found` / blank screen
→ Mode virtual display aktif padahal ingin mirror layar nyata
→ Di config Lumen: pastikan mode = `mirror` bukan `virtual`

---

## Cek Status Lengkap (1 command)

```bash
echo "=== Lumen ===" && pgrep -x lumen || echo "TIDAK JALAN"
echo "=== Port ===" && lsof -iTCP:47984 -sTCP:LISTEN -n -P 2>/dev/null || echo "Port 47984 tidak terbuka"
echo "=== Tailscale ===" && tailscale status 2>/dev/null | head -3
echo "=== Log errors ===" && grep -iE "error|fail" ~/.cache/sunshine/sunshine.log 2>/dev/null | tail -10
```

---

## Referensi

- Setup awal: [`docs/SETUP.md`](docs/SETUP.md) (dari PR #2)
- Pairing: [`docs/PAIRING.md`](docs/PAIRING.md)
- Moonlight issues: github.com/moonlight-stream/moonlight-ios/issues
- Lumen (fork Sunshine): github.com/tez-m/lumen
