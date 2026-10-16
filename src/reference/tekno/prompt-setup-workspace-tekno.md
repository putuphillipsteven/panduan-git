> Berkas ini adalah instruksi untuk Claude Code. Developer cukup meminta: "baca dan kerjakan `tekno\prompt-setup-workspace-tekno.md`". Kerjakan isinya sebagai permintaan developer tersebut — "saya" di bawah berarti developer yang menjalankanmu.

Tolong siapkan instruksi Claude Code untuk proyek TEKNO (migrasi e-BENGKEL ASP.NET VB.NET → Go + React, Oracle dipertahankan dengan SQL portabel PostgreSQL) dengan pola yang sama seperti proyek ClaimQ.

## Workspace

Folder induk: `D:\intan-migrasi\Tekno\gitlab` — Claude dijalankan dari sini. Isinya tiga repo bersebelahan:

| Repo | Peran |
|---|---|
| `tekno-app-context/` | dokumen: Steering, keputusan, ADR, glosarium, korpus legacy (read-only) |
| `tekno-app-be/` | backend Go |
| `tekno-app-fe/` | frontend React |

## Bahan

Folder `tekno\` tempat berkas ini berada — seharusnya `D:\intan-migrasi\Tekno\gitlab\tekno\`, di luar ketiga repo. Bila ternyata di tempat lain, pakai lokasi sebenarnya dan sebutkan di laporan.

- `tekno\context\` — dokumen TEKNO yang sudah ada: `CLAUDE.md`, `CONTEXT.md` (glosarium), `STEERING.md` (v1.2). Ini **sumber kebenaran** isi. Bandingkan dengan isi `tekno-app-context/` — bila berkas yang sama sudah ada di repo dan isinya berbeda, laporkan ke saya, jangan pilih sendiri.
- `tekno\referensi-claude\` — contoh dari ClaimQ. Ini **contoh bentuk**, bukan isi:
  - `context\WORKSPACE.md` — peta workspace multi-repo, diimpor oleh `CLAUDE.md` di folder induk
  - `context\CLAUDE.md`, `backend\CLAUDE.md`, `frontend\CLAUDE.md` — aturan kerja per repo
  - `context\.claude\hooks\jaga-branch.sh` — hook Claude Code penjaga branch (menolak Claude membuat branch, menolak perubahan saat repo di branch `dev`/`dev-backup-*`)
  - `context\docs\panduan-clone-repository.md` — §3a: cara memasang `CLAUDE.md` induk, plugin skill, dan hook penjaga branch lewat `.claude\settings.json` folder induk. Bila hook dipakai, sesuaikan nama repo dan nama branch terlarang untuk TEKNO, dan tulis panduan setara untuk TEKNO.
  - `backend\.githooks\`, `frontend\.githooks\` — hook git: `commit-msg` (judul commit minimal 3 karakter), `pre-push` (backend `go build ./...` dengan ulang otomatis untuk galat folder temp Windows; frontend `npm run build`), `coverage-min` (ambang coverage, saat ini tidak dipakai). Backend diaktifkan dengan `git config core.hooksPath .githooks`; frontend otomatis lewat script `"prepare": "git config core.hooksPath .githooks || exit 0"` di `package.json`. Bila dipakai: salin ke `tekno-app-be\.githooks\` dan `tekno-app-fe\.githooks\`, ganti rujukan Q363 dan pesan yang tampil dengan milik TEKNO (tanyakan teksnya ke saya), sesuaikan perintah build dengan repo, dan pastikan bit eksekusinya ter-commit (`git update-index --chmod=+x .githooks/commit-msg .githooks/pre-push`).
  - `context\CONTEXT.md`, `context\docs\STEERING_CLAIMQ.md` — untuk membandingkan gaya saja

## Hasil yang diminta

| Berkas | Isi |
|---|---|
| `D:\intan-migrasi\Tekno\gitlab\CLAUDE.md` | satu baris: `@tekno-app-context/WORKSPACE.md` |
| `tekno-app-context/WORKSPACE.md` | tabel repo, aturan git lintas repo (`git -C <repo> ...`), alur kerja (grilling dulu → baca keputusan → parity dengan legacy → ubah kode → catat keputusan), rujukan yang dibaca "saat pemicunya terjadi" |
| `tekno-app-context/CLAUDE.md` | aturan repo dokumen: korpus legacy read-only, peta dokumen, cara membaca/mengubah STEERING, cara menulis keputusan |
| `tekno-app-be/CLAUDE.md` | cara menjalankan, aturan backend yang mengikat, gerbang sebelum menyatakan selesai |
| `tekno-app-fe/CLAUDE.md` | aturan frontend yang mengikat, rujukan berpemicu, gerbang sebelum menyatakan selesai |

Setiap `CLAUDE.md` pendek (panjang setara referensi, bukan lebih), dan setiap aturan menyebut sumbernya (Qnn / ADR / §STEERING).

## Aturan pengerjaan

- **Isi diambil dari dokumen TEKNO, bukan disalin dari ClaimQ.** Nomor keputusan ClaimQ (Q346, B-09, ADR-0027, dst.), nama modul, Pega, Go 1.26, Tailwind/shadcn, dan perintah ClaimQ tidak boleh muncul sebagai aturan TEKNO. Bila sebuah aturan ClaimQ tampak berguna tapi TEKNO belum punya keputusannya, **jangan ditulis sebagai aturan** — masukkan ke daftar pertanyaan untuk saya.
- **Jangan merujuk berkas yang tidak ada.** ClaimQ punya `aturan-penamaan.md`, `jebakan-terbukti.md`, `panduan-*.md`, hook `jaga-branch.sh`; TEKNO belum tentu. Setiap jalur yang ditulis harus dicek ada; yang belum ada masuk daftar "perlu dibuat", bukan dirujuk.
- **Perintah gerbang (build/test/format/lint) diambil dari repo** — `go.mod`, `Makefile`, `package.json`, `.githooks/`, CI — bukan dari referensi ClaimQ. Bila belum ada, tanyakan.
- **Perhatikan perbedaan TEKNO yang sudah tercatat**, antara lain:
  - Bila STEERING dan ADR bertentangan, **ADR yang berlaku** (STEERING §0, §32) — di ClaimQ aturannya lain.
  - Amendemen STEERING ditulis inline sebagai blok "⟢ AMENDMENT" yang diindeks di §0 — bukan revisi versi seperti ClaimQ.
  - Keputusan ada di `docs/decision-log.md` (Qnn) dan ADR di `docs/adr/`; glosarium di `CONTEXT.md`.
  - Tidak ada pemanggilan stored procedure sama sekali (ADR-0003); SQL wajib portabel PostgreSQL (STEERING §3.3, §9, §18); database link boleh (§18.1).
  - Ways of Working di STEERING §31 (klaim beda harus kutip dua sisi, "BELUM DIPUTUSKAN — pertanyaan terbuka" + pemilik, dll.) — kandidat utama isi `WORKSPACE.md`.
  - STEERING §10 masih menaruh frontend di `/web` dalam satu repo — kenyataannya sekarang tiga repo; sebutkan ketidakcocokan ini di laporan.
  - `tekno\context\CLAUDE.md` berisi daftar skill dan bagian "Agent skills" (issue tracker `.scratch/`, label triage, `docs/agents/*.md`) hasil `/setup-matt-pocock-skills` — bagian "Agent skills" dipakai skill tersebut, jadi pertahankan atau pindahkan dengan sengaja, jangan hilang diam-diam.

## Langkah

1. **Inventaris dulu, jangan menulis apa pun.** Baca semua berkas di `tekno\context\` dan `tekno\referensi-claude\`. Untuk tiap repo, lihat: branch aktif (`git -C <repo> branch --show-current`), `CLAUDE.md` yang sudah ada, struktur folder utama, perintah build/test yang tersedia, dan apakah `docs/decision-log.md`, `docs/adr/`, `docs/agents/` ada di `tekno-app-context`.
2. **Laporkan ke saya**: tabel bagian demi bagian dari referensi ClaimQ → padanannya di TEKNO (dengan sumber) / "tidak ada padanan" / "bertentangan". Lalu jalankan skill `grilling` untuk menanyakan yang belum jelas, satu pertanyaan per giliran, misalnya:
   - Perlu aturan "dilarang membuat branch sendiri" + "jangan ubah repo yang sedang di branch `dev`/default" seperti ClaimQ? Perlu hook penjaganya?
   - Hook git (`commit-msg`, `pre-push`) dipasang di backend dan frontend? Gerbang pre-push apa saja, dan teks pesan yang tampil?
   - Bahasa instruksi: Indonesia (seperti ClaimQ) atau Inggris (seperti STEERING/CONTEXT TEKNO)?
   - Gerbang sebelum selesai untuk backend dan frontend bila belum terlihat di repo.
   - Daftar skill di `CLAUDE.md` lama dipertahankan atau dibuang (Claude sudah melihat daftar skill sendiri)?
   - Berkas `tekno\context\` dipindah ke `tekno-app-context/` atau sudah ada di sana?
3. **Sebelum menulis ke sebuah repo, cek branch aktifnya.** Bila `main`, `master`, `dev`, atau branch default lain, berhenti dan minta saya pindah ke branch kerja. Jangan membuat atau memindah branch sendiri.
4. **Setelah saya jawab, tulis draf** semua berkas di tabel "Hasil yang diminta". Pakai skill `writing-for-agents`.
5. **Verifikasi sebelum menyerahkan**: setiap jalur yang dirujuk ada; setiap aturan punya sumber TEKNO; tidak ada sisa istilah ClaimQ (grep `ClaimQ`, `claim-q`, `Pega`, dan nomor Q/ADR yang bukan milik TEKNO). Tampilkan daftar berkas yang dibuat/diubah dan daftar "perlu dibuat / BELUM DIPUTUSKAN" beserta pemiliknya.
6. **Jangan commit/push** — saya yang review dan commit.
