# TROUBLESHOOTING & self-healing

## iPhone hanya menampilkan layar HITAM
Penyebab paling umum: izin **Screen Recording** belum aktif untuk host —
atau diberikan ke binary CLI mentah, bukan ke `.app` wrapper.

macOS Sequoia/Tahoe **mengabaikan** permintaan Screen Recording dari binary
CLI mentah (prompt tak muncul, tak tampil di System Settings). Itu sebabnya
ada step 04 (bungkus `.app`).

Perbaikan:
1. `./scripts/04-app-bundle-wrap.sh`
2. Jalankan host **lewat .app**: `open "$(cat ~/.config/mac-monitor-app-path)"`
3. `./scripts/06-permissions.sh` → aktifkan Screen Recording untuk
   **MacMonitorHost.app**, lalu keluar & buka ulang host.
4. Reset bila masih bandel: `tccutil reset ScreenCapture` lalu beri izin lagi.

## Kontrol (klik/ketik dari iPhone) tidak bekerja
Izin **Accessibility** dan/atau **Input Monitoring** belum aktif untuk
`.app` host. Jalankan `./scripts/06-permissions.sh`, aktifkan keduanya,
restart host. Reset bila perlu: `tccutil reset Accessibility`.

## Latensi tinggi / patah-patah → status `relay`
`tailscale status` menampilkan `relay`, bukan `direct`. Trafik lewat server
relay Tailscale (tetap jalan tapi lebih lambat).
- Pastikan **Tailscale aktif di kedua perangkat**, versi terbaru.
- Coterminus: matikan VPN lain di iPhone yang bentrok.
- Turunkan beban: di Moonlight kecilkan Resolution/Bitrate/FPS.
- Pastikan codec **HEVC** aktif (web UI / `sunshine.conf` `hevc_mode = 2`);
  fallback H.264 bila iPhone lama.
- Jaringan sangat ketat (CGNAT ganda) kadang memang tak bisa direct —
  relay tetap berfungsi, hanya latensi naik.

## Moonlight tidak menemukan host
Normal — Tailscale tak meneruskan mDNS. **Add PC manual pakai Tailscale IP**
(`cat ~/.config/mac-monitor-tailscale-ip`). Pastikan host hidup & web UI
`https://localhost:47990` bisa dibuka di Mac.

## Web UI https://localhost:47990 tidak terbuka
Host tidak berjalan. Cek log: `~/Library/Logs/MacMonitor/host.err.log`.
Jalankan manual di terminal untuk lihat error:
`"$(cat ~/.config/mac-monitor-app-path)/Contents/MacOS/MacMonitorHost"`.

## Build Lumen (step 03) gagal
- Pastikan Command Line Tools: `xcode-select --install`.
- Update Homebrew: `brew update && brew doctor`.
- Ulang: hapus `~/.local/src/Lumen` lalu jalankan `03` lagi.
- Cek Issues upstream: https://github.com/trollzem/Lumen/issues

## Mac Intel atau macOS < 14 (fallback)
Lumen butuh Apple Silicon + macOS 14+ (CGVirtualDisplay API).
Alternatif: pasang **upstream Sunshine** untuk macOS
(https://docs.lizardbyte.dev/projects/sunshine/latest/) — fungsinya sama
(Moonlight + Tailscale tetap dipakai), tetapi kendala izin macOS lebih
banyak dan tidak ada virtual display. Skrip 02 & 05–07 tetap relevan;
ganti hanya step 03/04 sesuai instruksi Sunshine.

## Audio sistem tidak terdengar di iPhone
macOS melarang capture audio sistem langsung. Pasang BlackHole
(`brew install blackhole-2ch`), jadikan output di System Settings > Sound.
Opsional — tidak wajib untuk lihat + kontrol.

## Mau berhenti / uninstall
```bash
launchctl unload ~/Library/LaunchAgents/com.tokenrouter.macmonitor.host.plist
rm  ~/Library/LaunchAgents/com.tokenrouter.macmonitor.host.plist
rm -rf ~/Applications/MacMonitorHost.app ~/.local/src/Lumen ~/.local/share/lumen
# Cabut izin di System Settings > Privacy & Security secara manual.
```
