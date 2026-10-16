# claim-q-context — aturan kerja

Repo dokumen proyek migrasi ClaimQ: Steering, keputusan bernomor, ADR, ticketing, analisis, dan korpus legacy. Tidak ada kode aplikasi di sini — kode ada di `../claim-q-backend` dan `../claim-q-frontend` (peta lengkap: `WORKSPACE.md`).

## Korpus legacy — read-only

`Bengkel/` `Klaim Partial/` `Klaim Stolen/` `Procurement/` `E-Klaim/` `Website/` `Database/` dan folder export Pega lainnya adalah **sumber kebenaran perilaku** (export rule Pega XML, halaman Classic ASP, dump Oracle). Bacalah, kutip, jangan diubah. Untuk membaca rule Pega pakai skill `pega-xml-analyzer`.

## Peta dokumen

| Mencari | Buka |
|---|---|
| Keputusan bernomor baru (Q346+) | `docs/decisions/` — cara menulis di `docs/decisions/README.md` |
| Keputusan lama (Q1–Q345) | `docs/decision-log.md` — **arsip 3,5 MB: grep `^## Q<nomor>`, jangan dibaca utuh** |
| Alasan arsitektural | `docs/adr/` (indeks: `docs/adr/README.md`) |
| Bukti perilaku sistem existing | `docs/understanding-findings.md` (disingkat UF) |
| Tiket implementasi per modul | `docs/ticketing/` |
| Analisis rule Pega per layar | `docs/pega-analysis/` |
| RBAC & otorisasi | `docs/authorization-rbac.md` |
| Register integrasi luar | `docs/register-integrasi.md` |

## Steering — `docs/STEERING_CLAIMQ.md`

Blueprint resmi (FINAL v2.0, disetujui 2 Sep 2026). Cari heading bagian dengan `grep -n "^## <nomor>\." docs/STEERING_CLAIMQ.md`, lalu baca bagian yang relevan.

| § | Topik | § | Topik |
|---|---|---|---|
| 0–1 | Ringkasan, business flow per modul | 15 | Security (5 celah) |
| 2–3 | Arsitektur as-is & to-be | 16 | Autentikasi (B-07, Q21) |
| 4 | Domain model, threshold bisnis | 17 | Otorisasi (Q22) |
| 5–6 | Bounded context, urutan modul + amendemen per modul | 18 | Database: kepemilikan, koneksi, penomoran, transaksi, prosedur |
| 7–8 | Strategi migrasi & teknis | 19–20 | Deployment, testing |
| 9 | Coding standards | 21–25 | Risiko, NFR, performa, skalabilitas |
| 10 | Struktur folder (+ amendemen pemecahan repo) | 27 | Analisis frontend + amendemen UI |
| 11–12 | API, error handling | 28–29 | Decision register, open items |
| 13–14 | Logging, konfigurasi | 31 | Ways of working |

**Steering hanya diubah lewat revisi versi** (v2.1, v2.2, …) yang disetujui pemilik proyek lewat MR (Q346). Keputusan sehari-hari ditulis di `docs/decisions/` saja — tidak ditempel ke Steering. Bila Steering dan keputusan bernomor bertentangan, keputusan terbaru yang berlaku. Keputusan Sep 2026 yang mengubah isi Steering ada sebagai blok "AMENDEMEN Qnnn" di `docs/arsip/steering-dengan-amendemen.md` (1,5 MB, arsip — grep `AMENDEMEN Q<nomor>`, jangan dibaca utuh).

## Menulis di repo ini

- Bahasa Indonesia untuk isi dokumen; nama berkas huruf kecil dengan tanda hubung.
- Setiap klaim tentang sistem existing menyebut sumbernya (rule Pega, berkas ASP, tabel/prosedur Oracle, atau UF).
- `docs/skill-usage-log.md` dibiarkan apa adanya sampai kegunaannya diputuskan.
