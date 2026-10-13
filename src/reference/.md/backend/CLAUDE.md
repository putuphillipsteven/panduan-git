# claim-q-backend — aturan kerja

Backend Go ClaimQ: modular monolith (ADR-0005), satu entrypoint `cmd/claimq`, modul bisnis di `internal/<modul>/`, infrastruktur bersama di `internal/platform/`. Keputusan & Steering ada di `../claim-q-context` (alur kerja: `../claim-q-context/WORKSPACE.md`).

## Menjalankan

- Konfigurasi `config/claimq.dev.env` tidak masuk repo — salin dari `config/claimq.dev.env.example`. Jalankan dari **akar repo ini**: `CLAIMQ_ENV=DEV go run ./cmd/claimq` (berkas konfigurasi dicari relatif terhadap folder kerja).
- Test integrasi Oracle membaca DSN dari env `CLAIMQ_TEST_ORACLE_DSN` dan `CLAIMQ_TEST_ORACLE_MBU_DSN`. Kredensial hanya hidup di env atau `.env` lokal — tidak pernah di berkas yang di-commit, termasuk `.claude/settings.json`.
- Panduan lengkap: `../claim-q-context/docs/panduan-menjalankan-aplikasi.md`; membaca trace code error: `../claim-q-context/docs/panduan-membaca-trace-code.md`.

## Aturan yang mengikat

- **SQL selalu berparameter.** Tidak pernah dirangkai string — termasuk nama kolom & operator (Steering §15 celah #1).
- **Migrasi additive-only.** Boleh TAMBAH kolom nullable; tidak pernah mengubah/menghapus kolom existing (Steering B-04, ADR-0002). Nama tabel/kolom/prosedur Oracle dan isi + nama berkas `migrations/*.sql` mengikuti objek DB, bukan aturan penamaan Inggris.
- **Nomor migrasi**: sebelum membuat migrasi baru, periksa nomor tertinggi di cabang sendiri **dan** cabang yang akan digabung — `006` pernah dipakai dua berkas.
- **Batas transaksi di lapisan use-case**, satu transaksi per aksi bisnis. Panggilan integrasi dilakukan di LUAR transaksi DB (Steering D-5).
- **Tidak ada logika bisnis di HTTP handler.** Handler memetakan request/response dan error bertipe ke status HTTP; envelope respons `{kode, pesan, detail?, trace_id}` (Steering §11–12).
- **Setiap modul baru WAJIB mendaftarkan role-nya ke RBAC** (Q212): tambahkan `role.Module` beserta judul layar & barisnya di `internal/platform/role/policy.go`, lalu pasang lewat `guard(role.ModuleX, cfg, manager, logger)` di `cmd/claimq/main.go` — bukan merakit ulang `manager.Middleware(...)`. Module yang tidak ada di policy = default deny.
- **Kontrak integrasi luar beku** (Steering B-10, ADR-0012): `internal/integration/**` dan fixture jawaban AI/OCR tidak diubah bentuk payload-nya.
- **Pesan validasi & bisnis verbatim Bahasa Indonesia** dari legacy (B-09) — terikat acceptance test parity.
- Batas modul = batas paket Go: tabel/tipe internal sebuah modul tidak di-import langsung modul lain — lewat interface terekspor, dirangkai di `cmd/claimq` (Steering §9). Error dibungkus konteks (`fmt.Errorf("...: %w", err)`), tidak ada panic di jalur request.

Sebelum memberi nama apa pun: `../claim-q-context/docs/aturan-penamaan.md`. Saat mengubah nama medan JSON, rute, atau kunci env: `../claim-q-context/docs/jebakan-terbukti.md` — `go build` tidak menangkap ketidakcocokan dengan frontend.

## Gerbang sebelum menyatakan selesai

```
gofmt -l . && go vet ./... && go build ./... && go test ./...
```

`gofmt -l` harus kosong. **Setiap perubahan kode wajib disertai test untuk kode yang disentuh** (Q363). Hook tidak lagi menjaganya, jadi jalankan gerbang di atas sendiri (uji berkas DEV lokal dilewati lewat `CLAIMQ_SKIP_DEV_ENV_FILE_TEST=1`).

**Hook git (Q363, amendemen 12 Okt 2026):** aktifkan sekali per clone dengan `git config core.hooksPath .githooks`.
- commit-msg: judul minimal 3 karakter yang menjelaskan fiturnya. Tidak ada syarat tanda tangan; merge/revert bawaan git tidak diperiksa.
- pre-push: hanya `go build ./...`. Coverage dimatikan sementara; ambangnya tetap disimpan di `.githooks/coverage-min`.
- Tidak ada pre-commit.

Bila `go` tidak ada di `PATH`, cek instalasi SDK lokal (mis. `~/sdk/go1.26.0/bin`). Setelah mengubah aturan validasi atau kunci env, **jalankan ulang backend** dan pastikan tidak ada proses lama di port yang sama sebelum menguji dari frontend — gejala backend basi persis seperti bug aturan (Q216, Q219).
