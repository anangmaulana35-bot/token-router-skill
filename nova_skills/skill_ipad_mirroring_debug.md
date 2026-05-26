# Skill: Debug iPad Mirroring Error (Moonlight + Lumen + Tailscale)

**Dibuat dari:** sesi debug langsung bersama Anang — 26 Mei 2026  
**Konteks:** MacBook Pro milik Anang, iPad Pro 11 gen-3, setup Moonlight + Lumen + Tailscale

---

## Apa yang Dipelajari

Saat Anang kirim screenshot iPad dengan **2 entry "MacMonitor" berikon error** di Moonlight, aku langsung diagnosa dari visual saja (tanpa akses ke Mac). Ini pendekatan yang terbukti berhasil.

---

## Langkah Diagnosa dari Screenshot Saja

### 1. Baca ikon status di Moonlight
| Ikon | Arti |
|------|------|
| Segitiga kuning ! | Host pernah terdaftar tapi sekarang tidak bisa dihubungi |
| Spinner/loading | Sedang mencoba connect |
| Dua entry nama sama | IP Tailscale berubah atau Lumen pernah di-reset |

### 2. Minta screenshot Tailscale
Langsung minta user buka **Tailscale app** dan screenshot daftar device. Dari situ bisa tahu:
- Apakah Mac online (titik hijau)
- IP Tailscale Mac yang aktif saat ini

Contoh yang kita dapat:
```
macbook-pro-8  ● online  100.106.207.21
ipad-pro-11-gen-3  ● online  100.79.114.71
iphone171  ○ offline  100.80.60.75
```

### 3. Konfirmasi Lumen jalan di Mac
Tanya: "Ada ikon Lumen di menu bar kanan atas Mac?"  
Jika tidak tahu → instruksikan restart Lumen dulu.

---

## Fix yang Terbukti Berhasil

### Untuk error "2 entry MacMonitor"

**Di iPad (Moonlight):**
1. Tekan lama entry MacMonitor → Delete (semua entry lama)
2. "+ Add Host" → masukkan IP Tailscale Mac (`100.106.207.21`)
3. Connect → masukkan PIN yang muncul di Mac

**Di Mac (jika Lumen belum jalan):**
```bash
pkill -x lumen 2>/dev/null; sleep 3; open /Applications/Lumen.app
```

### Untuk layar hitam / tidak muncul setelah connect
```bash
# Buka izin Screen Recording
open "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture"
# Pastikan Lumen dicentang
```

### Untuk touch/mouse tidak bisa digerakkan
Ini terjadi setelah layar Mac berhasil tampil di iPad.

**Fix di Moonlight saat streaming:**
1. Swipe dari **tepi kiri** layar → overlay menu
2. Settings (gear) → **Touch Mode** → pilih **"Trackpad"**

Mode Trackpad:
- Geser 1 jari = gerak cursor
- Tap = klik kiri
- Tap 2 jari = klik kanan
- Geser 2 jari = scroll

---

## Urutan Bertanya ke User (Efisien)

Jangan tanya satu per satu. Tanya 3 hal sekaligus:
1. Sudah coba langkah apa saja?
2. Apa yang terjadi sekarang di iPad? (connect/error/layar hitam/touch tidak jalan)
3. Di Mac, Lumen sudah berjalan? (ada ikon di menu bar?)

Dari 3 jawaban itu sudah cukup untuk diagnosa.

---

## Yang Tidak Bisa Dilakukan Nova (atau Claude)

- Tidak bisa akses Mac/iPad user secara langsung
- Tidak bisa restart Lumen dari jauh
- Tidak bisa ubah setting Moonlight di iPad

→ Selalu instruksikan user dengan command yang bisa dijalankan sendiri.

---

## Script Diagnostic Tersedia

```bash
# Jalankan di Mac untuk diagnosa otomatis
bash scripts/diagnose_ipad_mirror.sh
```

Script ini memeriksa: proses Lumen, port 47984/47989/47998, Tailscale, izin Screen Recording, firewall, dan log error.

---

## Pola Umum di Setup Anang

- **Tailscale account:** anang.maulana35@gmail.com
- **Mac:** macbook-pro-8 — IP Tailscale: `100.106.207.21`
- **iPad:** ipad-pro-11-gen-3 — IP Tailscale: `100.79.114.71`
- **iPhone:** iphone171 — sering offline
- **Host name di Moonlight:** MacMonitor

Jika IP Tailscale berubah, cukup hapus entry lama di Moonlight dan tambah ulang dengan IP baru.
