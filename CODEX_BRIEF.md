# BRIEF UNTUK CODEX — Eksekusi Remote Monitor MacBook → iPhone

> Dari **Claude** (planning) untuk **Codex** (execution). Baca penuh sebelum mulai.
> Semua perintah di bawah dijalankan **DI MACBOOK milik user** (bukan di container).

## Misi

Pasang & jalankan sistem agar **iPhone bisa melihat dan mengendalikan layar
MacBook secara real-time dari mana saja**, gratis, lebih efisien dari
TeamViewer. Kode/automasi sudah disiapkan di repo ini — tugasmu **menjalankan,
memverifikasi, dan menuntaskan pairing**, bukan menulis ulang.

## Konteks (sudah diputuskan, jangan diubah tanpa konfirmasi user)

- Strategi: **Lumen** (host Mac) + **Moonlight** (app iPhone, gratis App Store) + **Tailscale** (transport WireGuard, gratis).
- Bukan bikin app Swift dari nol. Repo = skrip automasi + konfig + dokumen.
- Biaya harus tetap **Rp 0**. Tanpa Xcode, Apple Developer, VPS, domain.

## Prasyarat — cek dulu, hentikan bila gagal

- Mac **Apple Silicon** (M1/M2/M3/M4), **macOS ≥ 14 (Sonoma)**.
- iPhone + app **Moonlight** + app **Tailscale** (akun gratis, sama dgn Mac).
- Jika Mac Intel / macOS < 14 → **STOP**, lapor user, lihat fallback di
  `docs/TROUBLESHOOTING.md` (upstream Sunshine).

## Langkah eksekusi (urut)

```bash
cd token-router-skill
chmod +x scripts/*.sh
./scripts/run-all.sh --mode monitor
```

`run-all.sh` menjalankan 01→07 berurutan. Yang penting kamu perhatikan:

| Step | Aksi | Yang harus kamu pastikan |
|---|---|---|
| 01 | cek HW/OS, pasang Homebrew | lolos Apple Silicon + macOS ≥14 |
| 02 | pasang Tailscale | **user login Tailscale di Mac DAN iPhone (akun sama)**; IP Mac tampil |
| 03 | clone + build Lumen | build sukses, binary terdeteksi (bisa beberapa menit) |
| 04 | bungkus `.app` | wrapper dibuat (fix izin Screen Recording macOS modern) |
| 05 | tulis config | mode = `monitor` (lihat layar nyata) |
| 06 | izin macOS (manual) | **Screen Recording + Accessibility + Input Monitoring** aktif untuk `.app` wrapper |
| 07 | autostart | LaunchAgent termuat |

> Step 02 & 06 butuh aksi manual user (login & toggle izin). Pandu user
> dengan jelas, tunggu konfirmasi, jangan lewati.

## Pairing (wajib, manual — lihat `docs/PAIRING.md`)

1. Mac: buka `https://localhost:47990` → set username/password web UI.
2. Ambil IP: `cat ~/.config/mac-monitor-tailscale-ip`.
3. iPhone: Tailscale **ON** → Moonlight → **+ Add PC** → ketik IP itu.
4. Moonlight tampilkan **PIN** → masukkan di web UI Mac → Pair.
5. Moonlight → pilih **Desktop** → streaming + kontrol jalan.

## Verifikasi akhir (laporkan hasilnya ke user)

- [ ] Skrip 01–07 selesai tanpa error.
- [ ] iPhone pakai **data seluler** (bukan WiFi Mac) → tetap konek (bukti jalur internet).
- [ ] Layar Mac tampil real-time di iPhone.
- [ ] Kontrol jalan: klik, drag, scroll, ketik keyboard.
- [ ] Di Mac: `tailscale status` → device iPhone berstatus **`direct`** (bukan `relay`).
- [ ] Reboot Mac → host hidup sendiri (autostart).

## Kalau ada yang gagal

Rujuk **`docs/TROUBLESHOOTING.md`** (sudah lengkap). Yang paling sering:
- iPhone layar **hitam** → izin Screen Recording belum aktif untuk `.app`
  wrapper. Ulang step 04 lalu 06; `tccutil reset ScreenCapture` bila bandel.
- Kontrol mati → izin Accessibility/Input Monitoring belum aktif.
- Lambat/patah → `tailscale status` `relay` (bukan `direct`); kecilkan
  bitrate/FPS di Moonlight; pastikan HEVC aktif.

## Aturan kerja Codex

- **Jangan** ubah strategi/arsitektur tanpa konfirmasi user.
- Perubahan kecil/perbaikan bug skrip: silakan langsung perbaiki & commit.
- Hal ambigu atau menyangkut keputusan desain: **tanya user dulu**.
- Hemat token: tugas sederhana pakai model lemah (lihat `README.md`).
- Setelah selesai, **laporkan checklist verifikasi di atas** apa adanya
  (yang lolos & yang belum), jangan klaim sukses tanpa bukti.
