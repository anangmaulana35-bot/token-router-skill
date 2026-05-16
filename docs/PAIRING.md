# PAIRING — sambungkan iPhone ke Mac

Tailscale tidak meneruskan mDNS, jadi Moonlight **tidak** auto-discover host
lewat Tailscale. Tambah host **manual pakai Tailscale IP**.

## Langkah

### Di Mac
1. Pastikan host berjalan:
   - Autostart aktif (skrip 07), **atau**
   - Manual: `open "$(cat ~/.config/mac-monitor-app-path)"`
2. Buka **https://localhost:47990** (abaikan warning self-signed cert).
3. Pertama kali: buat **username & password** web UI.
4. Catat Tailscale IP Mac:
   ```bash
   cat ~/.config/mac-monitor-tailscale-ip   # mis. 100.x.y.z
   ```

### Di iPhone
5. Aktifkan **Tailscale** (toggle ON, akun sama dengan Mac).
6. Buka **Moonlight** → tap **“+”** (Add PC) → ketik **Tailscale IP Mac**.
7. Moonlight menampilkan **PIN 4 digit**.

### Kembali ke web UI Mac
8. Tab **PIN** → masukkan PIN dari iPhone → **Send/Pair**.
9. Di Moonlight muncul host → tap → pilih **Desktop** → streaming + kontrol mulai.

## Cek latensi optimal

Di Mac:
```bash
tailscale status
```
Baris perangkat iPhone harus berstatus **`direct`** (bukan `relay`).
`relay` = lewat server relay Tailscale (tetap jalan, latensi lebih tinggi).
Solusi bila `relay`: lihat docs/TROUBLESHOOTING.md.

## Kontrol dari iPhone (Moonlight)

- Sentuh = gerak/klik pointer; mode trackpad tersedia di overlay Moonlight.
- Tap dua jari = klik kanan; geser dua jari = scroll.
- Ikon keyboard di overlay = ketik.
- Bar atas Moonlight: ubah resolusi/FPS/bitrate, atau disconnect.
