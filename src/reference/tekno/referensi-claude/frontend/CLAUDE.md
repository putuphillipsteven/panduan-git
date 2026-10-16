# claim-q-frontend — aturan kerja

Frontend ClaimQ: SPA statis React 18.3.1 + TypeScript + Vite (ADR-0013), Tailwind v4 + shadcn/ui di atas styling ClaimQ yang sudah ada (ADR-0028). Layar per modul di `src/modules/<modul>/`, pemanggil API di `src/api/`, komponen bersama di `src/components/`. Keputusan & Steering ada di `../claim-q-context` (alur kerja: `../claim-q-context/WORKSPACE.md`). Perintah ada di `package.json`; cara menjalankan bersama backend: `../claim-q-context/docs/panduan-menjalankan-aplikasi.md`.

## Aturan yang mengikat

- **Teks tampilan & pesan validasi verbatim Bahasa Indonesia** dari legacy (B-09) — tidak diterjemahkan, tidak "dirapikan".
- **Tidak ada logika bisnis di frontend.** Validasi hanya cermin aturan backend; gerbang yang menampilkan medan dan gerbang server yang menolaknya memakai aturan & data yang sama.
- **Pesan ke user tampil sebagai pop-up** lewat `MessageDialog`/`useDialog` (Q100); inline hanya validasi per-medan, status memuat, empty-state, dan keterangan tetap halaman. Setiap `useQuery` punya `useErrorQuery`-nya.
- **Komponen dulu, baru tulis sendiri** (Q184): komponen ClaimQ yang ada (katalog hidup di `/style-guide`) → shadcn (`npx shadcn@latest add`) → tulis sendiri memakai token `src/styles/tokens.css`, bukan warna/piksel mentah.
- **Komponen shadcn yang meneruskan `...props` ke kontrol form WAJIB `forwardRef`** — shadcn menargetkan React 19, proyek ini React 18 yang membuang `ref`; react-hook-form lalu diam-diam kehilangan nilai medan.
- **StrictMode memanggil pembaru state dua kali** (Q207): jangan mengubah ref/variabel modul di dalam `setX((prev) => …)`. Tangkap nilai lama ke variabel lokal sebelum `setX`, perbarui ref di luar pembaru.
- **Alamat**: jalur peramban hanya lewat `src/app/routes.ts` (`ROUTE`, `ROUTE_PATTERN`) — tidak ditulis langsung di layar (Q211). `const PREFIX` di `src/api/*.ts` ditulis **tanpa** `/api/v1` karena `callApi` menambahkannya (Q256).
- **Setiap tombol simpan/kirim menunjukkan isian yang belum lengkap** (Q347): tombol tetap aktif; saat diklik, medan yang kurang ditandai lewat prop `error` pada `Field`, ringkasan nama medan yang kurang tampil di dekat tombol, dan fokus bergulir ke medan pertama yang kurang. Rincian: `../claim-q-context/docs/decisions/Q347-cta-isian-yang-belum-lengkap.md`.
- **Format tampilan** (tanggal DD/MM/YYYY, uang `Rp.1.234.567,00`) lewat `src/app/format.ts` (Q116).
- Ikon dari `lucide-react` dengan nama kanoniknya, bukan emoji.

## Rujukan — baca saat pemicunya terjadi

- **Membuat atau mengubah layar** (tabel inbox, panel ringkasan, formulir, tombol, warna, verifikasi tampilan): `docs/aturan-ui.md`.
- **Memberi nama** komponen, berkas, kelas CSS: `../claim-q-context/docs/aturan-penamaan.md` — urutan kata Inggris, kata inti di belakang.
- **Mengubah nama medan, rute, atau kelas CSS yang dirakit**, atau layar "tidak jalan" tanpa error: `../claim-q-context/docs/jebakan-terbukti.md` — `tsc` dan `vite build` tidak menangkap satu pun.

## Gerbang sebelum menyatakan selesai

```
npm run format:check && npm run build && npm run coverage
```

Seluruh codebase sudah terformat Prettier (Q363), jadi `format:check` harus bersih. **Setiap perubahan kode wajib disertai test untuk kode yang disentuh** (Q363). Hook tidak lagi menjaganya, jadi jalankan gerbang di atas sendiri.

**Hook git (Q363, amendemen 12 Okt 2026):** aktif otomatis lewat `npm install` (script `prepare` → `core.hooksPath .githooks`).

- commit-msg: judul minimal 3 karakter yang menjelaskan fiturnya. Tidak ada syarat tanda tangan; merge/revert bawaan git tidak diperiksa.
- pre-push: hanya `npm run build`. Format check dan coverage dimatikan sementara; ambangnya tetap disimpan di `.githooks/coverage-min`.
- Tidak ada pre-commit.
