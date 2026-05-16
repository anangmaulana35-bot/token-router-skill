# SETUP — langkah lengkap

## 0. Prasyarat (gratis)

| Butuh | Detail |
|---|---|
| Mac | Apple Silicon (M1/M2/M3/M4), macOS 14 Sonoma+ |
| iPhone | iOS modern, app **Moonlight** (gratis di App Store) |
| Akun | **Tailscale** gratis (login Google/GitHub/email) |
| TIDAK perlu | Xcode, Apple Developer ($99), VPS/server, domain |

Biaya total: **Rp 0**.

## 1. Jalankan setup di Mac

Clone repo ini ke Mac, lalu:

```bash
cd token-router-skill
chmod +x scripts/*.sh
./scripts/run-all.sh --mode monitor
```

Atau langkah per langkah (lihat SKILL.md). Skrip akan:

1. **01** cek Apple Silicon + macOS ≥ 14, pasang Homebrew bila perlu.
2. **02** pasang Tailscale → kamu login di Mac & iPhone (akun sama) → IP Mac ditampilkan & disimpan ke `~/.config/mac-monitor-tailscale-ip`.
3. **03** clone & build **Lumen** (`./install.sh`, beberapa menit).
4. **04** bungkus host jadi `.app` (wajib agar izin Screen Recording muncul di macOS modern).
5. **05** tulis `~/.config/sunshine/apps.json` + `sunshine.conf` (mode monitor/virtual).
6. **06** pandu pemberian izin macOS (manual — tak bisa otomatis).
7. **07** (opsional) autostart saat login.

## 2. Pairing

Lihat **docs/PAIRING.md** (ringkas: web UI `https://localhost:47990` → set akun; di iPhone Moonlight Add PC pakai Tailscale IP → masukkan PIN).

## 3. Mode tampilan

- **monitor** (default): lihat layar Mac yang sedang aktif (pemantauan).
- **virtual**: sesi terpisah seukuran iPhone (kerja remote, layar Mac tak terganggu).
  Ganti dengan: `./scripts/05-configure.sh --mode virtual`.

## 4. Kualitas / efisiensi

Atur dari **iPhone → Moonlight → Settings**: Resolution, FPS, Bitrate.
Server (Lumen) mengikuti adaptif, encode **HEVC hardware** (VideoToolbox).
Untuk latensi terendah pastikan koneksi Tailscale **direct** (lihat troubleshooting).

## 5. Verifikasi (di Mac/iPhone)

1. Skrip 01–07 selesai tanpa error; `cat ~/.config/mac-monitor-tailscale-ip` keluar IP.
2. iPhone pakai **data seluler** (bukan WiFi Mac) untuk membuktikan jalur internet.
3. Moonlight pair sukses → pilih **Desktop** → layar Mac tampil real-time.
4. Uji kontrol: klik, drag, scroll, ketik (keyboard layar Moonlight).
5. Di Mac: `tailscale status` → baris device iPhone berstatus **direct**.
6. Reboot Mac → host hidup sendiri (bila autostart dipasang).
