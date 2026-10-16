# ClaimQ — workspace tiga repo

Migrasi Pega ICMS + Pega GKM + E-Klaim MBU ke Go / Oracle / React. Claude Code dijalankan dari **folder induk** yang berisi tiga repo bersebelahan (berkas ini diimpor oleh `CLAUDE.md` folder induk; cara setup: `claim-q-context/docs/panduan-clone-repository.md` §3a).

| Repo | Isi | Aturan kerjanya |
|---|---|---|
| `claim-q-context/` | Steering, keputusan bernomor, ADR, ticketing, korpus legacy Pega/ASP/Oracle (**read-only**) | `claim-q-context/CLAUDE.md` |
| `claim-q-backend/` | Go 1.26 modular monolith, modul di `internal/<modul>/`, DDL di `migrations/` | `claim-q-backend/CLAUDE.md` |
| `claim-q-frontend/` | React 18.3 + TypeScript + Vite SPA, modul di `src/modules/<modul>/` | `claim-q-frontend/CLAUDE.md` |

Masing-masing repo punya git, branch, dan MR sendiri. Jalankan perintah git dengan `git -C <repo> ...`.

**Dilarang keras membuat branch sendiri.** Claude bekerja di branch yang sedang aktif di tiap repo. Jangan menjalankan `git branch <nama>`, `git checkout -b`, `git switch -c`, atau membuat worktree yang memunculkan branch baru — termasuk saat akan commit di branch default. Bila pekerjaan butuh branch lain, berhenti dan minta developer yang membuat atau memilihkannya.

**Cek branch sebelum mengubah berkas.** Sebelum mengubah berkas di sebuah repo, jalankan `git -C <repo> branch --show-current`. Bila hasilnya `dev` atau diawali `dev-backup-`, jangan ubah apa pun di repo itu — tampilkan peringatan ke developer bahwa repo tersebut sedang di branch `<nama>` dan minta mereka pindah ke branch kerja secara manual. Claude tidak memindahkan branch sendiri; lanjutkan hanya setelah developer mengonfirmasi sudah pindah.

Kedua aturan di atas juga ditegakkan hook `claim-q-context/.claude/hooks/jaga-branch.sh` (cara pasang: `claim-q-context/docs/panduan-clone-repository.md` §3a). Bila sebuah tool dibatalkan dengan pesan berawalan "BHAP", sampaikan pesannya ke developer — jangan mencari jalan memutar.

## Alur kerja

0. **Fitur baru atau perubahan perilaku: grilling dulu** (Q348). Sebelum menulis kode, jalankan skill `grilling` (plugin `mattpocock-skills`) bersama developer sampai setiap keputusan terjawab. Perbaikan kecil — ganti teks, bug yang jelas, rapikan kode tanpa ubah perilaku — langsung dikerjakan. Bila skill tidak tersedia, minta developer memasang plugin sesuai `claim-q-context/docs/panduan-clone-repository.md` §3a.
1. **Baca keputusan dulu.** Sebelum mengubah perilaku, cari keputusan yang mengaturnya: `claim-q-context/docs/decisions/` (baru), lalu arsip `claim-q-context/docs/decision-log.md` (grep, jangan dibaca utuh), lalu bagian Steering terkait — indeksnya ada di `claim-q-context/CLAUDE.md`.
2. **Parity dulu.** Perilaku harus sama persis dengan legacy. Setiap deviasi wajib punya keputusan bernomor — tidak ada deviasi diam-diam. Yang tidak terbukti ditulis "BELUM DIVERIFIKASI" beserta pemiliknya, bukan ditebak.
3. **Ubah backend dan/atau frontend** sesuai kebutuhan. Perubahan yang menyentuh keduanya = dua MR, satu keputusan bernomor yang dirujuk keduanya.
4. **Catat keputusan baru** satu berkas per keputusan — aturan penomorannya di `claim-q-context/docs/decisions/README.md`.

## Rujukan lintas repo — baca saat pemicunya terjadi

- **Memberi nama** berkas, identifier, rute, kelas CSS, env var: `claim-q-context/docs/aturan-penamaan.md` (ADR-0027).
- **Mengubah nama medan / rute / kontrak** antara backend↔frontend, atau hasil kerja "tidak jalan" tanpa error: `claim-q-context/docs/jebakan-terbukti.md`.
- **Merge antar cabang**: `claim-q-context/docs/aturan-merge.md`.
- **Restrukturisasi folder** sebuah context, atau merge `dev` yang folder context-nya sudah dipindah (ADR-0033): `claim-q-context/.claude/skills/restruktur-modul/SKILL.md`.

## Pengingat: refresh URL foto/dokumen

Saat mengerjakan fitur yang menampilkan atau mengunggah foto/dokumen, **periksa dulu apakah fitur itu sudah punya refresh URL kedaluwarsa** (URL diminta ulang ke backend saat dibuka, backend menerbitkan URL baru bila sudah kedaluwarsa). Contoh yang sudah ada: Inbox Bengkel — `claim-q-frontend/src/modules/bengkel/useOpenFoto.ts` dan `claim-q-backend/internal/bengkel/foto_url.go`. **Sampaikan hasil pemeriksaannya ke developer** — sudah ada atau belum — dan bila belum, tanyakan apakah perlu ditambahkan sebelum melanjutkan.

## Pengingat: teks pesan error & validasi

Teks pesan yang tampil ke user (error, validasi, konfirmasi) **berasal dari developer, bukan dikarang Claude**. Bila pesannya sudah ada di aplikasi legacy, pakai teks legacy verbatim (B-09). Bila pesannya baru, **berhenti dan minta developer menuliskan teksnya** — sebutkan kondisi pemicunya, layar/endpoint-nya, dan kode error-nya — lalu pakai teks dari developer apa adanya.

## Jalur pada dokumen lama

Dokumen sebelum 6 Okt 2026 menulis jalur monorepo. Baca `claimq/backend/…` atau `backend/…` sebagai `claim-q-backend/…`, `claimq/frontend/…` atau `frontend/…` sebagai `claim-q-frontend/…`, "CLAUDE.md (Steering)" sebagai `claim-q-context/docs/STEERING_CLAIMQ.md` (amendemen lamanya diarsip di `docs/arsip/steering-dengan-amendemen.md`), dan "`AGENTS.md`" sebagai `CLAUDE.md` repo terkait beserta `claim-q-context/docs/aturan-*.md` dan `jebakan-terbukti.md` (AGENTS.md dilebur ke sana).
