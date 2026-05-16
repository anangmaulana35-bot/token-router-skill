# SKILL — Remote Monitor + Control MacBook → iPhone (gratis, efisien)

Panduan eksekusi untuk **Codex** (Claude = planning, Codex = eksekusi di Mac).
Tujuan: pantau & kendalikan MacBook dari iPhone secara real-time, **lebih
efisien dari TeamViewer**, **biaya Rp 0**.

## Pendekatan

Bukan bikin app dari nol. Pakai komponen open-source/gratis yang terbukti:

| Lapisan | Komponen | Kenapa |
|---|---|---|
| Host (Mac) | **Lumen** (fork Sunshine, Apple Silicon) | ScreenCaptureKit + VideoToolbox HEVC hardware, latensi ~sub-16ms |
| Client (iPhone) | **Moonlight** (App Store, gratis) | Tanpa Xcode/Apple Developer, decode HEVC hardware, kontrol penuh |
| Transport | **Tailscale** (WireGuard, free tier) | Dari mana saja, E2E encrypted, NAT traversal otomatis, tanpa server |

## Prasyarat (cek dulu)

- Mac **Apple Silicon**, **macOS ≥ 14 (Sonoma)**.
- iPhone + app **Moonlight** + app **Tailscale** (akun gratis, sama dgn Mac).
- Tidak perlu: Xcode, Apple Developer, VPS, domain. Total biaya Rp 0.

## Eksekusi (di Mac)

Jalankan berurutan (atau `scripts/run-all.sh`):

```bash
scripts/01-prereqs.sh        # cek Apple Silicon + macOS 14+ , pasang Homebrew
scripts/02-tailscale.sh      # pasang Tailscale, login, tampilkan IP Mac
scripts/03-install-lumen.sh  # clone + build Lumen (./install.sh)
scripts/04-app-bundle-wrap.sh# bungkus .app (fix izin Screen Recording macOS modern)
scripts/05-configure.sh --mode monitor   # apps.json + sunshine.conf (monitor|virtual)
scripts/06-permissions.sh    # pandu izin: Screen Recording, Accessibility, Input Monitoring
scripts/07-autostart.sh      # (opsional) jalan otomatis saat login
```

Lalu pairing: lihat **docs/PAIRING.md**.

## Mode tampilan

- `--mode monitor` (default): iPhone melihat **layar Mac yang sedang dipakai**
  → memantau aktivitas nyata.
- `--mode virtual`: Lumen membuat virtual display seukuran iPhone → sesi
  kerja terpisah, layar Mac tidak terganggu.

## Self-healing / kalau gagal

Lihat **docs/TROUBLESHOOTING.md**. Yang paling umum:
- iPhone layar hitam → izin Screen Recording belum aktif untuk **.app wrapper**
  (bukan binary mentah). Re-run `04` lalu `06`.
- Latensi tinggi → `tailscale status` harus "direct", bukan "relay".
- Mac Intel / macOS < 14 → fallback upstream Sunshine (lihat troubleshooting).

## Referensi orang yang berhasil

Lihat **docs/REFERENCES.md**.
