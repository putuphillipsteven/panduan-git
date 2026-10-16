# Panduan Clone Repository ClaimQ

Untuk developer yang baru bergabung. Panduan ini berhenti tepat setelah repo ada di komputer Anda — cara menjalankan aplikasinya ada di [panduan-menjalankan-aplikasi.md](panduan-menjalankan-aplikasi.md).

---

## 0. Yang dibutuhkan

| Yang dibutuhkan | Cara memeriksa |
|---|---|
| Git | `git --version` |
| Akses ke grup GitLab `it-aidev3/claim-q` | buka https://gitlab.sinarmas.co.id/it-aidev3/claim-q — kalau 404, akses Anda belum diberikan |

Go, Node, dan akses Oracle **belum** dibutuhkan di tahap ini. Itu urusan panduan menjalankan aplikasi.

---

## 1. Buat direktori kerja Anda

Formatnya **`namadeveloper-migrasi`**, huruf kecil semua:

```bash
mkdir putu-migrasi
cd putu-migrasi
```

PowerShell:

```powershell
New-Item -ItemType Directory putu-migrasi
cd putu-migrasi
```

Ganti `putu` dengan nama Anda.

**Kenapa satu folder per developer.** Repo ini dikerjakan beberapa orang, dan tidak jarang satu orang perlu dua salinan sekaligus (mis. satu di `main` untuk membandingkan, satu di branch yang sedang dikerjakan). Dengan folder bernama developer, salinan-salinan itu tidak saling menimpa dan jelas siapa pemiliknya di komputer bersama.

---

## 2. Perkenalkan diri Anda ke Git

Ini menentukan nama & email yang menempel pada **setiap commit** Anda — dan tidak bisa diubah belakangan tanpa menulis ulang riwayat.

```bash
git config --global user.name "Nama Anda"
git config --global user.email "email.anda@claimq.id"
```

> ⚠️ **Perhatikan baris kedua: `user.email`, bukan `user.name`.**
>
> Menuliskan `user.name` dua kali adalah salah ketik yang mudah terjadi, dan akibatnya tidak langsung terlihat: perintah kedua **menimpa** nama Anda dengan alamat email, sedangkan emailnya sendiri tidak pernah tersetel. Commit Anda lalu muncul atas nama alamat email, dan GitHub tidak bisa menautkannya ke akun Anda.

Periksa hasilnya sebelum lanjut:

```bash
git config --global user.name
git config --global user.email
```

Keduanya harus menjawab nilai yang berbeda. Kalau keduanya menjawab email, Anda terkena salah ketik di atas — jalankan ulang perintah `user.name`.

### Catatan soal `--global`

`--global` berlaku untuk **semua** repo di komputer itu. Kalau Anda juga mengerjakan proyek lain dengan identitas berbeda (mis. akun pribadi), setel per-repo saja: masuk ke folder repo lalu jalankan perintah yang sama **tanpa** `--global`.

---

## 3. Clone ketiga repo-nya

Sejak Oktober 2026 ClaimQ dipecah menjadi **tiga repo terpisah**. Ketiganya WAJIB di-clone **bersebelahan di dalam satu folder induk** — dokumen dan konfigurasi Claude Code merujuk repo lain lewat jalur relatif `../claim-q-...`, jadi letak yang berbeda membuat rujukannya putus.

Dari dalam `namadeveloper-migrasi`:

```bash
mkdir claimq && cd claimq
git clone https://gitlab.sinarmas.co.id/it-aidev3/claim-q/claim-q-context.git
git clone https://gitlab.sinarmas.co.id/it-aidev3/claim-q/claim-q-backend.git
git clone https://gitlab.sinarmas.co.id/it-aidev3/claim-q/claim-q-frontend.git
```

Hasilnya:

```
putu-migrasi/
└── claimq/                 <- folder induk (BUKAN repo)
    ├── CLAUDE.md           <- dibuat sendiri, langkah 3a
    ├── claim-q-context/    steering, keputusan, ADR, korpus Pega (termasuk berkas ini)
    ├── claim-q-backend/    Go
    └── claim-q-frontend/   React + Vite
```

### 3a. Siapkan Claude Code (sekali saja)

Claude Code dijalankan dari **folder induk**, supaya ketiga repo terlihat sekaligus. Folder induk bukan repo, jadi berkas penghubungnya dibuat sendiri. Buat `CLAUDE.md` di folder induk dengan isi satu baris ini:

```
@claim-q-context/WORKSPACE.md
```

PowerShell (dari folder induk):

```powershell
Set-Content -Encoding utf8 CLAUDE.md '@claim-q-context/WORKSPACE.md'
```

Isi sebenarnya (peta repo & alur kerja) ada di `claim-q-context/WORKSPACE.md` dan ikut ter-update setiap `git pull` — berkas satu baris ini tidak perlu diubah lagi. Saat pertama menjalankan `claude`, Claude Code meminta persetujuan untuk impor tersebut; setujui.

Pasang juga plugin skill yang dipakai alur kerja tim (skill `grilling` wajib untuk fitur baru / perubahan perilaku, Q348). Di dalam Claude Code ketik:

```
/plugin install mattpocock-skills@claude-plugins-official
```

Aktifkan juga **hook git** (Q363) yang memformat kode saat commit dan menjalankan build + test + ambang coverage sebelum push. Dari folder induk:

```bash
git -C claim-q-backend config core.hooksPath .githooks
git -C claim-q-frontend config core.hooksPath .githooks   # otomatis juga saat npm install
```

Hook bisa dilewati dengan `git push --no-verify`, tetapi pipeline Sonar di merge request tetap menilai hal yang sama.

Pasang juga **hook Claude Code penjaga branch** (`claim-q-context/.claude/hooks/jaga-branch.sh`). Hook ini menolak Claude membuat branch sendiri (`git checkout -b`, `git switch -c`, `git branch <nama>`, `git worktree add`, tool EnterWorktree), dan menolak edit berkas atau perintah git yang mengubah repo selama repo itu di branch `dev` atau `dev-backup-*`. Buat berkas `.claude/settings.json` di folder induk (bila sudah ada, gabungkan bagian `hooks`-nya):

```json
{
  "hooks": {
    "PreToolUse": [
      {
        "matcher": "Edit|Write|MultiEdit|NotebookEdit|Bash|PowerShell|EnterWorktree",
        "hooks": [
          {
            "type": "command",
            "command": "bash \"$CLAUDE_PROJECT_DIR/claim-q-context/.claude/hooks/jaga-branch.sh\"",
            "timeout": 15
          }
        ]
      }
    ]
  }
}
```

Di Windows hook ini butuh Git Bash (ikut Git for Windows). Setelah berkas dibuat, buka `/hooks` sekali di Claude Code atau mulai ulang sesi agar terbaca.

Izin perintah pribadi (allowlist) taruh di `.claude/settings.local.json` di folder induk — **jangan** di dalam repo, dan jangan pernah menaruh kredensial di berkas yang di-commit.

---

## 4. Samakan akhiran baris (Windows)

Jalankan **di setiap repo hasil clone**:

```bash
cd claim-q-context && git config core.autocrlf true && cd ..
cd claim-q-backend && git config core.autocrlf true && cd ..
cd claim-q-frontend && git config core.autocrlf true && cd ..
```

**Kenapa perlu.** Repo ini menyimpan berkasnya dengan akhiran baris **LF**, sementara salinan kerja di Windows memakai **CRLF**. Setelan di atas yang menjembataninya: Git mengubah LF→CRLF saat checkout dan CRLF→LF saat commit.

Tanpa setelan itu, begitu Anda menyimpan berkas lewat editor Windows, Git akan melihat **seluruh baris berubah** — satu perubahan satu kata bisa tampil sebagai diff ratusan baris, dan review menjadi mustahil.

Sejak Q363, `claim-q-backend` dan `claim-q-frontend` punya `.gitattributes` (`* text=auto eol=lf`), sehingga folder kerja kedua repo selalu LF, juga di Windows. Ini perlu karena `gofmt` menganggap berkas ber-CRLF belum rapi. Clone baru langsung benar. Untuk salinan lama yang folder kerjanya masih CRLF, checkout ulang setelah pull, **hanya bila tidak ada perubahan yang belum di-commit**:

```bash
git rm --cached -r -q . && git reset --hard
```

(Di macOS/Linux lewati langkah ini — akhiran barisnya sudah LF.)

---

## 5. Pastikan hasilnya benar

```bash
git status
```

Jawaban yang sehat: **`nothing to commit, working tree clean`**.

Kalau `git status` langsung menampilkan berkas yang berubah padahal Anda belum menyentuh apa pun, hampir pasti langkah 4 terlewat. Perbaiki begini:

```bash
git config core.autocrlf true
git rm --cached -r .
git reset --hard
```

Perintah itu membuang salinan kerja dan mengambil ulang dari repo memakai setelan yang benar. **Jangan dijalankan kalau Anda sudah punya perubahan yang belum di-commit** — perubahan itu akan hilang.

Lalu lihat branch mana yang sedang aktif:

```bash
git branch
```

Bawaannya `main`. Untuk mulai bekerja, buat branch sendiri — format nama dan pesan commit ada di [git-cheatsheet.md](git-cheatsheet.md).

---

## 6. Selanjutnya

| Mau apa | Baca |
|---|---|
| Menjalankan backend & frontend | [panduan-menjalankan-aplikasi.md](panduan-menjalankan-aplikasi.md) |
| Aturan penamaan branch & commit | [git-cheatsheet.md](git-cheatsheet.md) |
| Peta repo & alur kerja lintas repo | [../WORKSPACE.md](../WORKSPACE.md) |
| Aturan kerja per repo (penamaan kode, jebakan yang sudah terbukti) | `CLAUDE.md` di masing-masing repo |
| Acuan utama proyek & keputusan bernomor | [STEERING_CLAIMQ.md](STEERING_CLAIMQ.md) · [decisions/](decisions/) · arsip [decision-log.md](decision-log.md) |

Satu hal yang perlu diketahui sejak awal: **berkas konfigurasi berisi kredensial tidak ikut masuk repo.** Sesudah clone, `claim-q-backend/config/claimq.dev.env` belum ada — Anda menyalinnya dari `claimq.dev.env.example` lalu mengisinya sendiri. Caranya ada di panduan menjalankan aplikasi §1.1.

---

## 7. Kalau tersangkut

| Gejala | Sebabnya biasanya |
|---|---|
| `repository not found` saat clone | akses ke grup GitLab `it-aidev3/claim-q` belum diberikan, atau Anda login sebagai akun yang salah |
| Diminta username & password, lalu ditolak | pakai Personal Access Token GitLab sebagai password, atau clone lewat SSH |
| Claude tidak tahu letak repo lain / meminta Anda menyebut folder | `CLAUDE.md` di folder induk belum dibuat, atau `claude` dijalankan dari dalam salah satu repo — lihat §3a |
| `git status` penuh berkas berubah padahal belum diapa-apakan | akhiran baris — lihat §4 dan §5 |
| Commit muncul atas nama orang lain / email saja | salah ketik `user.name` pada langkah 2 — periksa dengan `git config --global user.email` |

-- david ganteng