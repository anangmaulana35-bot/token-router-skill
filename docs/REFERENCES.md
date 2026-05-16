# REFERENCES — orang/proyek yang sudah berhasil

Pendekatan ini bukan eksperimen — sudah terbukti dipakai komunitas luas.

## Komponen inti
- **Lumen** — fork Sunshine khusus macOS Apple Silicon (ScreenCaptureKit +
  VideoToolbox H.264/HEVC, virtual display, mouse/keyboard):
  https://github.com/trollzem/Lumen
- **Sunshine** (upstream, dokumentasi host & config):
  https://docs.lizardbyte.dev/projects/sunshine/latest/md_docs_2getting__started.html
- **Moonlight** (client gratis, panduan resmi):
  https://github.com/moonlight-stream/moonlight-docs/wiki/Setup-Guide
- **Tailscale** (mesh WireGuard, free tier, app iOS & macOS resmi):
  https://github.com/tailscale/tailscale

## Panduan komunitas (orang yang berhasil)
- "How I Built a Free AnyDesk Alternative Using Sunshine, Moonlight &
  Tailscale" — DEV:
  https://dev.to/thevenice/how-i-built-a-free-anydesk-alternative-using-sunshine-moonlight-tailscale-3lh8
- "Sunshine + Moonlight + Tailscale Game Streaming Guide 2026" — Carthage
  Electronics: https://carthageelectronics.com/sunshine-moonlight-tailscale-game-streaming-guide/
- "How I Fixed Sunshine Screen Sharing on macOS Tahoe (The Native Wrapper
  Method)" — dasar step 04 (.app wrapper untuk izin Screen Recording):
  https://medium.com/@sanjayajosep/how-i-fixed-sunshine-screen-sharing-on-macos-tahoe-the-native-wrapper-method-c6fc45aa1ec6

## Kenapa lebih efisien dari TeamViewer
- HEVC hardware encode/decode (VideoToolbox Apple Silicon) — kompresi lebih
  baik per-bitrate; pipeline Sunshine/Moonlight dirancang game-streaming
  (target sub-16ms), referensi: WWDC21 "Explore low-latency video encoding
  with VideoToolbox" https://developer.apple.com/videos/play/wwdc2021/10158/
- ScreenCaptureKit hanya memproses frame berubah → CPU rendah.
- Koneksi WireGuard **direct P2P** (tanpa server perantara berbayar) vs
  relay cloud TeamViewer → latensi & privasi lebih baik, biaya Rp 0.
