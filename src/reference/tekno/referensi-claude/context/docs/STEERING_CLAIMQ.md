STEERING DOCUMENT

MIGRASI ClaimQ

Penggabungan Pega ICMS + Pega GKM + E-Klaim MBU ke Golang / Oracle / React — Blueprint & Tata Kelola

FINAL v2.0 — DISETUJUI 2 September 2026

Klasifikasi: RAHASIA — Penggunaan Internal. Dokumen ini adalah blueprint migrasi. Dokumen ini sengaja TIDAK memuat source code, skema API, atau skrip migrasi database — semuanya dikerjakan setelah Steering ini direview dan disetujui (B-14).

Pemilik: Alfin — proyek migrasi ClaimQ, PT Asuransi Sinar Mas.
Disusun: 1 September 2026.

Ketertelusuran: setiap keputusan bernomor — B-nn (terkunci dari brief tugas), Q-nn (discovery sesi ini: pertanyaan → opsi → jawaban → keputusan), D-nn (keputusan turunan). Semua tercatat lengkap di `docs/decision-log.md`. Setiap klaim teknis tentang sistem existing bersumber dari pembacaan langsung korpus 1 September 2026 dan terdokumentasi di `docs/understanding-findings.md` (disingkat UF). Yang belum bisa dibuktikan ditulis sebagai BELUM DIVERIFIKASI / Open Item dengan pemiliknya, bukan diisi tebakan.

Catatan posisi terhadap steering terdahulu: sesi ini memutuskan MEMULAI DARI NOL (Q1). Dokumen `Sample_Docs/STEERING_CLAIMQ_OLD.docx` (steering ClaimQ v2.2 untuk ICMS+GKM) diperlakukan sebagai referensi bacaan saja; tidak ada keputusan lama yang diwarisi otomatis. Perbedaan terbesar dengan dokumen lama: (1) E-Klaim MBU masuk scope penuh dan ikut di-shutdown; (2) state flow disimpan sebagai kolom pada tabel flat tanpa tabel engine terpisah; (3) prosedur & trigger yang tersentuh alur diporting total ke Go (dengan pengecualian yang dinyatakan).

STATUS: **DISETUJUI — baseline v2.0, 2 September 2026 (persetujuan: Alfin, pemilik proyek — verbatim: "oke disetujui jadikan final steering")**. Gerbang implementasi B-14 TERBUKA: pengembangan kode, API, skema, dan folder project resmi boleh dimulai dengan dokumen ini sebagai acuan. Sejak baseline ini, setiap perubahan masuk sebagai AMENDEMEN bernomor (keputusan Q-nn baru di decision-log) di bawah heading terkait — teks yang disetujui tidak dihapus; bila Steering dan keputusan baru bertentangan, keputusan bernomor terbaru yang berlaku sampai rewrite disetujui.

[[PAGEBREAK]]

# Daftar Isi

BAGIAN I — KONTEKS & BISNIS
- 0. Ringkasan Eksekutif
- 1. Business Understanding
- 2. Current Architecture (As-Is)

BAGIAN II — ARSITEKTUR MASA DEPAN
- 3. Future Architecture (To-Be)
- 4. Domain Model
- 5. Bounded Contexts
- 6. Module Breakdown & Urutan Pengerjaan

BAGIAN III — STRATEGI MIGRASI & TEKNIS
- 7. Migration Strategy
- 8. Technical Strategy
- 9. Coding Standards
- 10. Folder Structure
- 11. API Strategy
- 12. Error Handling
- 13. Logging
- 14. Configuration

BAGIAN IV — KEAMANAN & DATA
- 15. Security
- 16. Authentication
- 17. Authorization
- 18. Database Strategy

BAGIAN V — OPERASIONAL & KUALITAS
- 19. Deployment Strategy
- 20. Testing Strategy
- 21. Risk Analysis
- 22. Non-Functional Requirements
- 23. Performance Strategy
- 24. Scalability
- 25. Maintainability
- 26. Future Enhancement

BAGIAN VI — ANALISIS & REGISTER
- 27. Analisis & Rekomendasi Frontend
- 28. Decision Register
- 29. Open Items Register
- 30. Catatan Penggunaan Skills
- 31. Ways of Working
- 32. Document Control

[[PAGEBREAK]]

# BAGIAN I — KONTEKS & BISNIS

## 0. Ringkasan Eksekutif

ClaimQ menggabungkan TIGA aplikasi existing menjadi satu aplikasi berbasis Golang + Oracle + React, multi-asuransi dan multi-cabang, untuk 100–200 user aktif harian dengan target ketersediaan 24/7:

- **Pega ICMS** — registrasi klaim partial (kerusakan sebagian) & CTL (kerusakan parah), plus flow & login bengkel.
- **Pega GKM** — registrasi klaim stolen (kehilangan kendaraan), plus procurement sparepart (Quotation Unit → Order Unit → Delivery Unit).
- **E-Klaim MBU** — aplikasi Classic ASP berisi modul lanjutan SETELAH cetak SPK dari Pega ICMS & GKM: akseptasi pembayaran (hit API ke Kasir), view history, adjustment klaim, estimator, salvage & lelang, buka proteksi, master data, dan puluhan modul inbox/report/KPI (±90 modul).

Di ClaimQ, pada awal registrasi user memilih jenis klaim — partial (kerusakan sebagian) atau kehilangan (stolen) — lalu masuk flow masing-masing (B-02). ClaimQ melayani registrasi baru DAN data lama (B-11): klaim lama yang masih berjalan di Pega diambil alih (takeover) sehingga dapat dilihat dan dilanjutkan di ClaimQ.

Keputusan-keputusan penentu bentuk (ringkas; rincian di §28 dan decision-log):

- **Lepas total dari Pega**: database bawaan Pega (DATAPEGA) tidak dipakai; full flat table Oracle; kolom/flag DATAPEGA yang masih dipakai ditambahkan sebagai kolom baru pada tabel flat existing — additive-only (B-04).
- **Nomor case via Oracle sequence**, format identik dengan existing; sequence di-seed di atas nilai MAX gabungan (B-05).
- **Tulis ke tabel flat existing yang sama** (icms., mbu., pooldata.), sehingga SQL existing bisa direuse dan laporan gabungan lama+baru berjalan di atas data yang sama (Q9).
- **State flow disimpan sebagai kolom pada tabel flat** — tanpa tabel engine terpisah; worklist/inbox dibangun dari query; definisi transisi = state machine di kode Go (Q10, Q14).
- **Stored procedure & trigger diporting total ke Go** (B-06, Q11), dengan dua pengecualian yang dinyatakan: trigger pada tabel yang masih ditulis sistem lain tetap aktif (Q15), dan fungsi skalar read-only yang tertanam di SQL reuse tetap dipakai (Q16).
- **Dua koneksi Oracle** (instance PROD_CLAIMQ untuk eks-Pega, instance ASMD/MBU untuk eks-E-Klaim), db-link warisan tetap bekerja (Q12).
- **Autentikasi dua jalur**: user internal via API HCC/HCQ; user external (bengkel, supplier/mitra, klien reasuradur) via tabel existing + password hash modern (B-07, Q21).
- **Kontrak integrasi dibekukan** — parameter/payload sama persis, hanya URL berubah dan berasal dari konfigurasi (B-10).
- **Frontend React SPA + TypeScript + Vite** (statis), **backend modular monolith Go**, **on-premise Docker Compose** (Q24, Q26, Q27).
- **Parity perilaku, tampilan modern**: perilaku & urutan field sama persis; visual dibangun ulang lebih modern dan user friendly (B-09).
- **Cutover big-bang** satu tanggal untuk semua asuransi/cabang/modul; Pega ICMS, Pega GKM, dan E-Klaim di-shutdown bersamaan setelah gerbang kualitas (2 minggu internal + 4 minggu UAT paralel) terlewati (Q6, Q7, Q8).

## 1. Business Understanding

### 1.1 Apa itu ClaimQ

Aplikasi registrasi dan pemrosesan klaim kendaraan bermotor untuk perusahaan asuransi, multi-asuransi & multi-cabang (B-03). Model identitas multi-asuransi mengikuti tiga tabel existing (Q55, UF §13): PROFIL_ASURANSI (master asuransi+cabang sekaligus konfigurasi perilaku per-asuransi; kantor pusat ber-sourcecode sendiri, cabang memakai sourcecode pusatnya), MST_LOGIN (user + access group), MST_LOGIN_CABANG (mapping user→asuransi/cabang yang di-handle). User yang menangani lebih dari satu asuransi mendapat fitur **Switch Portal** (§3.5). Seluruhnya berbasis web (diakses dari browser; tidak ada aplikasi native sebagai bagian ClaimQ — Q25). Kanal pelaporan mobile (mobile app tertanggung, mobile surveyor) tetap sistem eksternal terpisah yang memanggil API inbound ClaimQ.

Di sistem existing, fungsinya terbelah di tiga aplikasi (UF §1):

| Aplikasi asal | Fungsi | Basis |
|---|---|---|
| Pega ICMS | Registrasi klaim partial & CTL; proses perbaikan pada flow & login bengkel | class ASM-FW-ICMS-Work-Claim |
| Pega GKM | Registrasi klaim stolen; procurement sparepart QU/OU/DU | class ASM-FW-GKM-Work-Claim / -Procurement |
| E-Klaim MBU | Modul lanjutan setelah cetak SPK (Pega ICMS & GKM): akseptasi pembayaran via API Kasir; view/adjustment/estimator; salvage & lelang; buka proteksi; master data; ±90 modul | Classic ASP, APP_ID=22, schema mbu/general |

Di ClaimQ ketiganya menjadi satu aplikasi: di awal registrasi user memilih jenis klaim (partial vs kehilangan) lalu masuk flow masing-masing (B-02).

### 1.2 Aktor

Terverifikasi dari swimlane FLOW_REGISTER_COMPLETE.xml dan modul E-Klaim (UF §3, §6):
Tertanggung; kanal pelaporan online (Mobile App, ASM Online, Barcode, Customer Service, Email, Website, WhatsApp, dll); Surveyor (termasuk surveyor independen); Estimator; Checker (mapping panel); layanan AI (deteksi panel, OCR — integrasi yang sudah ada); Kabas; Korwil; Tim Teknis; Komite; Compliance; Akseptor; Kadiv BAS; Kadiv Teknis; Direktur Teknis; Bengkel (rekanan/non-rekanan/reciprocal/vendor VELG); Procurement (QU/OU/DU); Supplier (Autopro/non-Autopro); Divisi Arsip; Divisi GA (salvage); klien reasuradur eksternal (mis. Transjakarta).

### 1.3 Core business flow

Ringkasan alur (rincian di UF §3 & §10; bersumber dari FLOW_REGISTER_COMPLETE.xml [5 halaman, 950 simpul / 712 relasi], 9 rule Flow Pega, dua workbook case type, checklist Proteksi_ICMS_GKM.xlsx, dan deep-dive rule Q38). Kosakata status adalah nilai existing yang wajib dipertahankan (Q10, termasuk varian ejaan Resolved-Completed vs Resolve-Complete).

Alur end-to-end:

```
   LAPOR ONLINE                          LAPOR LANGSUNG
   (mobile/web/barcode/CS/WA)            (cetak formulir klaim)
        │ API inbound (3 endpoint)            │
        ▼                                     ▼
   icms.t_pelaporan                    icms.t_cetak_frm_clm
        └────────────────┬────────────────────┘
                         ▼
              PILIH JENIS KLAIM (B-02)
        ┌────────────────┼─────────────────────┐
        ▼                ▼                     ▼
 REGISTER PARTIAL   REGISTER CTL        REGISTER STOLEN
     (1.3.1)          (1.3.2)               (1.3.3)
        └────────┬───────┘                     │
                 ▼                             ▼
  REVIEW KLAIM (partial/CTL):          SURVEY & ANALISIS
  AI → KABAS ∥ COMPLIANCE (paralel)    SURVEYOR
    → KORWIL → TIM TEKNIS                      ▼
                 ▼                     REVIEW KLAIM (stolen,
  EX-GRATIA? ─ya─► <100jt Kadiv /      non ex-gratia) paralel:
                   ≥100jt Direktur     COMPLIANCE ∥ KABAS ∥ KORWIL
                 ▼                             ▼
  KEPUTUSAN WO                         KOMITE BERJENJANG
  (Ganti / Jasa / Tolak)               (Kabas→Korwil→Kadiv BAS;
        │ setuju                        ex-gratia: Kadiv/Direktur)
        ▼                                      ▼
    CETAK SPK ─────────────────┐       KEPUTUSAN KOMITE
        │                      ▼               │ setuju
        ▼               PROCUREMENT (1.3.5)    │
    BENGKEL (1.3.4)     QU → OU → DU           │
        │ ◄── sparepart ───────┘               │
        ▼                                      ▼
   REKAP + KWITANSI ─────────► AKSEPTASI & PEMBAYARAN (1.3.6)
                                     │ hit API Kasir (Q39)
                                     ▼
                      Resolved-Completed / Resolved-Rejected
```

#### 1.3.1 Register Partial

323 simpul / 238 relasi (flowchart); lane: Tertanggung, Mobile App, Surveyor, AI, Komite, Compliance, Kabas, Korwil, Tim Teknis, Checker, Akseptor, Kadiv Teknis, Direktur Teknis.

```
LAPOR ONLINE (OCR dok + AI panel)     LAPOR LANGSUNG (formulir)
        └───────────────┬─────────────────────┘
                        ▼
        VALIDASI KELENGKAPAN ──tidak──► kembalikan / tolak
                        ▼ lengkap
                REGISTER KLAIM (CLM-)
                        ▼
        UPLOAD FOTO SISI + KERUSAKAN (+dokumen TJH bila ada)
                        ▼
        AI MAPPING PANEL ──► CHECKER ──tolak──► ulangi mapping
                        ▼ setuju
        DATA PELAPOR → KEJADIAN → PANEL → BENGKEL
          • SIM perpanjangan / usia <21 → kali OR bertambah
          • treatment: Ganti / Ganti+Cat / Ketok+Cat
          • panel support otomatis; penanda fast moving
          • panel bernilai >3 juta → approval Kabas
          • >20 panel / panel di master rusak parah → otomatis CTL
          • semua panel fast moving → bengkel NONE
          • panel velg → bengkel vendor VELG
          • pindah bengkel: OCR form + approval
                        ▼
        INDIKASI CTL / RUSAK PARAH? ──ya──► jalur CTL (1.3.2)
                        ▼ tidak
        REVIEW KLAIM:
            AI (otomatis) ──► KABAS ∥ COMPLIANCE (paralel/sejajar)
                                  ▼
                               KORWIL ──► TIM TEKNIS
          (Korwil dapat kembalikan ke surveyor / tolak klaim)
                        ▼
        EX-GRATIA? ──ya──► <100jt Kadiv / ≥100jt Direktur Teknis
                        ▼
        KEPUTUSAN WO: setujui Ganti / jadikan Jasa / tolak
             │ tolak                   │ setuju
             ▼                         ▼
        Resolved-Rejected       CETAK SPK (service ASM)
                                       ▼
                        BENGKEL (1.3.4) + PROCUREMENT (1.3.5)
                                       ▼ seluruh proses selesai
                        AKSEPTASI & PEMBAYARAN (1.3.6)
                                       ▼
                               Resolved-Completed
```

Empat blok data berurutan (urutan field wajib sama — B-09): Data Pelapor; Data Kejadian (pengemudi, SIM, kondisi, kronologis, TJH, data polisi); Data Panel (katalog panel, mapping foto-panel, stiker, salvage, liability, treatment); Data Bengkel (otomatis dari panel + prioritas cabang + vendor VELG).

#### 1.3.2 Register CTL

287 simpul / 217 relasi — varian Partial dengan perbedaan terverifikasi:

```
REGISTER PARTIAL (alur 1.3.1 berjalan sama)
        │
        ├── coverage polis hanya CTL?
        │        └──ya──► panel otomatis CTLO + bengkel = NONE
        ▼
INDIKASI CTL / RUSAK PARAH
  (>20 panel / panel di master rusak parah / estimasi > TSI)
        ▼
KEPUTUSAN PROTEKSI CTL ── oleh KORWIL
        ▼
   ┌────┴────────────────────────────┐
   ▼                                 ▼
LANJUT SEBAGAI CTL            KONVERSI CTL ↔ PARTIAL
                              (hapus panel CTLO, isi panel
                               normal — tanpa registrasi ulang)
   └────────────────┬────────────────┘
                    ▼
REVIEW KLAIM (kedua cabang sama-sama direview):
   AI (otomatis) → KABAS ∥ COMPLIANCE (paralel) → KORWIL
   → TIM TEKNIS  (+ ex-gratia seperti 1.3.1)
                    ▼
   ┌────────────────┴────────────────┐
   ▼ tetap CTL                       ▼ hasil konversi → Partial
CETAK SPGR CTL                 lanjut alur 1.3.1
   ▼                           (keputusan WO → CETAK SPK →
SALVAGE / LELANG                bengkel + procurement)
(modul eks-E-Klaim)
   ▼
AKSEPTASI & PEMBAYARAN (1.3.6)
```

#### 1.3.3 Register Stolen

188 simpul / 142 relasi; dekomposisi 5 flow GKM: 1. Registrasi Klaim → 2. Stolen Case → 3. Stolen Survey → 4. Komite Stolen → 5. Reject Stolen.

```
LAPOR ──► UPLOAD DOKUMEN (polis, plat, mesin, KTP/SIM/STNK/
        │                  STPL, form klaim, FOTO KUNCI)
        ▼
DATA: PELAPOR → KEJADIAN → PENGEMUDI → POLISI → BAP → SAKSI
        ▼
ISI ANALISIS SURVEYOR + CEK DOUBLE CLAIM (mbu.f_cek_double_klaim)
        ▼
SURVEY TKP ──atau── SURVEY BY PHONE (butuh approval)
        ▼
APAKAH KLAIM EX-GRATIA?
   │
   ├── ya ──► JALUR EX-GRATIA: <100jt Kadiv Teknis /
   │          ≥100jt Direktur Teknis
   │          (Apakah Pengajuan Ex-Gratia Disetujui?)
   ▼ tidak (non ex-gratia)
KOMITE NON-AI
        ▼
REVIEW KLAIM — paralel/sejajar per divisi:
   COMPLIANCE ∥ KABAS ∥ KORWIL
   masing-masing decision "Apakah Review Klaim Sesuai?"
        │ tidak sesuai ──► kembali / perbaiki
        ▼ REVIEW SESUAI (ketiganya)
KOMITE BERJENJANG (nilai pengajuan × jenis kendaraan):
   motor <15jt ────────────► jenjang Kabas
   motor ≥15jt ────────────► Korwil; ≥30jt → Kadiv
   mobil ≤200jt ───────────► Kabas→Korwil; >200jt → Kadiv BAS
   keyless ────────────────► selalu eskalasi ke jenjang atas
   ("Apakah Komite Disetujui?" — approval bertingkat
    KABAS → KORWIL → KADIV BAS sesuai jenjang)
        ▼
   ┌────┴──────────────────────────────┐
   ▼ setuju                            ▼ tolak
SPGR STOLEN                    FLOW REJECT STOLEN:
   ▼                           review komite → checker surtol
AKSEPTASI & PEMBAYARAN (1.3.6)   → approval → SURAT TOLAK terbit
   (recovery bila unit
    ditemukan: tarik/jual)
```

Tahap Review Klaim stolen terverifikasi dari sumber (Q59/Q60): pada flowchart Register Stolen, TIGA simpul "Review Klaim" berada SEJAJAR pada baris yang sama (paralel) di kolom divisi berbeda, masing-masing dengan decision "Apakah Review Klaim Sesuai?" → "Review Sesuai", lalu mengalir ke "Komite Berjenjang" dengan "Apakah Komite Disetujui?" bertingkat pada kolom KABAS → KORWIL → KADIV BAS; divisi review = Compliance ∥ Kabas ∥ Korwil (arahan pemilik, Q60). Rule XML pendukung: GetDataReviewCompliance (flow Survey/Komite/Reject), GetJawabanReviewKomite, CountPertanyaanReviewCabang, GetTipeKunciReview.

#### 1.3.4 Bengkel

92 simpul / 71 relasi; tanpa rule Flow — orkestrasi murni flag flat-table (status kolom + query).

```
INBOX BENGKEL ──► TGL AKTUAL MASUK ──► FOTO RANGKA ──► OCR RANGKA
   │ no rangka beda dengan polis? ──ya──► BUKA PROTEKSI (Kabas)
   ▼
UPDATE PROGRESS
   (urutan: BONGKAR → KETOK → DEMPUL → CAT → PASANG →
    FINISHING → QC FINAL → SELESAI; janji selesai maks 45 hari
    kerja; RAWAT JALAN: tgl keluar & masuk kembali wajib berurutan)
   │
   ├── PANEL GANTI ◄── sparepart tiba dari PROCUREMENT/DU (1.3.5)
   │     PENERIMAAN SPAREPART: cek fisik (kasat mata), upload
   │     foto + OCR, update status (SUDAH TERIMA + SESUAI)
   │     ──► pemasangan ──► salvage / gandeng
   │
   └── PANEL JASA: pengajuan PREMIUM REPAIR → approval Korwil
         (jenjang TSI 300jt/400jt); banding harga: harga jasa
         baru >50% harga sparepart → approval Korwil;
         jasa dapat berubah Ganti → memicu PROCUREMENT (1.3.5)
   ▼
PANEL TAMBAHAN (deteksi AI) → approval Kabas/Korwil
   ▼
REKAP — syarat: SEMUA sparepart diterima & sesuai; foto EPOXY
   untuk WO jasa; foto SALVAGE + PEMASANGAN untuk WO ganti
   → surat puas + tanda terima salvage → cetak dokumen rekap
   ▼
CETAK + UPLOAD KWITANSI ──► AKSEPTASI & PEMBAYARAN (1.3.6)
```

(Threshold terverifikasi UF §10.2–§10.3; split persis approval per jenis panel-tambahan BELUM DIVERIFIKASI penuh.)

#### 1.3.5 Procurement

60 simpul / 44 relasi; QU → OU → DU; + sub-lingkup Cash Advance (work class ASM-FW-GKM-Work-CashAdvance).

```
CETAK WO (ganti) ──► BUAT QUOTATION (PC-)
   ▼
INQUIRY / PENAWARAN SUPPLIER (AutoPro / TAP e-part)
   ▼
AUTO CHOOSE ──atau── PILIH PEMENANG MANUAL
   │  prioritas autochoose: (1) ganti tunai tertanggung;
   │  (2) stok internal; (3) tender reguler (CHEAPEST,
   │  multi-penawaran lokal-semua = FASTEST)
   │  hasil kosong? ──► pencarian ulang + input effort /
   │                    kategori / action plan
   ▼
SYARAT PO: komite approve + update bongkar + tgl estimasi masuk
   ▼
SUPPLIER REKANAN? ──ya──► AUTO PO
             └──tidak──► HIT API ORDER (TAP) → konfirmasi
                          → PO / batal
   ▼
DU: MONITORING PENGIRIMAN
   (janji kirim = tgl PO + TOD; SLA; ambil dokumen DO /
    resi / indent dari AutoPro)
   ▼
TERIMA SPAREPART ── salah/rusak? ──► BATAL ORDER → RETURN /
   ▼ ok (kondisi: Sesuai)            REFUND (dengan approval);
LANJUT PEMASANGAN DI BENGKEL         tender ulang bila perlu
   (1.3.4)
```

Deviasi sadar dari existing (Q61): pengecekan/update **janji kirim HE** (tender ulang HE via panggilan Pega→Pega ServiceTenderUlangJanjiKirimHE ke aplikasi GCNMFW-Work-PNC) TIDAK dibawa ke ClaimQ — dihapus dari alur procurement; integrasi tersebut tidak dibangun.

#### 1.3.6 Akseptasi & Pembayaran (modul eks-E-Klaim)

Berjalan setelah rekap bengkel/procurement; murni di atas tabel flat MBU (mst_akseptasi, mst_pool_akseptasi).

```
REKAP (per bengkel / per no rekening / per ekspedisi)
   ▼
CEK REKAP (inbox cek rekap; flag autokasir; syarat: nomor
   referensi terbit, dokumen lengkap)
   ▼
AKSEPTASI
   nilai = (total jasa & sparepart + TJH)
           − (kali OR × OR) − PPh jasa + PPN
   (melebihi limit akseptasi cabang → buka proteksi 012)
   ▼
PEMBAYARAN ──► HIT API KASIR (Q39: REST insertAllPaymentKasir)
   ▼
PENERIMAAN KWITANSI & DOKUMEN BENGKEL (>7 hari di-follow-up)
   ▼
PELUNASAN BENGKEL (cek PPN bengkel; bukti potong pajak)
   ▼
Resolved-Completed
```

Deviasi sadar dari existing (Q62): pengecekan **rekap TAP vs bukan** (filter `mak_no_ref NOT LIKE '%/TAP/%'` pada inbox cek rekap existing) TIDAK dibawa ke ClaimQ — semua rekap diperlakukan sama di alur akseptasi.

Modul pendukung eks-E-Klaim lain yang berdiri di atas tabel flat yang sama (UF §6): Salvage/Lelang/TCR & Recovery, DLA/PLA/Subrogasi (reasuransi), buka proteksi (katalog PROTEKSI_ID), adjustment & penolakan klaim, master data, KPI & report.

### 1.4 Tujuan migrasi

1. Lepas total dari Pega dan dari Classic ASP E-Klaim yang tidak lagi didukung: satu platform Golang yang modular, teruji, dan mudah dipelihara, di atas Oracle existing.
2. Satu aplikasi ClaimQ untuk seluruh domain (registrasi partial/CTL, stolen, bengkel, procurement, akseptasi/pembayaran, salvage/lelang, master data, report/KPI) dengan satu pintu registrasi (B-02) dan satu domain web untuk semua asuransi (Q28).
3. Perilaku bisnis sama persis dengan existing; tampilan modern & user friendly (B-09). "Buat sama persis dengan existing" adalah jawaban final; dibuka kembali hanya bila legacy sendiri ambigu, bertentangan dengan legacy, atau angka konkret belum ada.
4. Menutup lima celah keamanan spesifik tanpa mengubah hasil fungsional (Q23-revisi), selebihnya parity.
5. Skala tepat guna untuk 100–200 user aktif harian — tanpa over-engineering, siap berkembang (B-13).

### 1.5 Non-goals (eksplisit)

Bukan re-engineering proses bisnis; bukan penggantian kontrak integrasi (dibekukan — B-10); bukan perubahan threshold/aturan bisnis; bukan migrasi struktur data bisnis (data sudah di tabel flat — yang dipindahkan hanya state/flag eks-DATAPEGA saat takeover, D-3); bukan migrasi ke PostgreSQL (Oracle dipertahankan, B-12); bukan mobile app tertanggung/surveyor (tetap sistem terpisah yang memanggil API inbound ClaimQ, Q25); bukan tabel engine flow terpisah (Q10).

## 2. Current Architecture (As-Is)

Rincian lengkap: `docs/understanding-findings.md`. Ringkasan di sini untuk kelengkapan Steering.

Stack & skala (UF §1, §2, §5):

- Pega 8.x (dua aplikasi: ICMS, GKM) — export **9.006 rule XML**: Connect-SQL/RDB-List 3.828; Activity 2.610; Section 1.475; Flow Action 353; Harness 282; Data Transform 185; When 145; Connect-REST 81; Report Definition 26; Flow 9; Validate 5; Service REST 3; lainnya 4. Pega dipakai untuk flow/case, UI (Section/Harness), activity, dan Connect-SQL/REST. Hanya 9 Rule-Obj-Flow di seluruh korpus (3 ICMS registrasi + 6 GKM stolen). Bengkel (3.418 rule) & Procurement (747) TIDAK punya Flow — orkestrasinya via flag flat-table + status.
- E-Klaim MBU — Classic ASP (VBScript), ±90 folder modul, ~119 halaman bisnis unik, APP_ID=22. Scaffolding identik per modul (koneksi Oracle, session lus_id, menu 3 level dari m_otorisasi+m_menu_aplikasi). Tidak ada layering, tidak ada test, deployment manual.
- Database Oracle. Estate terverifikasi (dump Toad 31 Agu): ICMS 623 procedure + 76 function + 62 trigger + 61 DBMS_JOB + 268 tabel; MBU 462 procedure + 316 function + 174 package + 234 trigger + 86 DBMS_JOB + 1.805 tabel + 18 sequence; POOLDATA (autochoose + DU_KLAIM_PKG). Total 296 trigger (216 aktif), 147 DBMS_JOB.

Skema Oracle yang dirujuk: icms, mbu, mbufoto, pooldata, general, datapega, bengkel, newbengkel, collection, reinsurance, hrdasm, programmer, GL. Data hidup di lebih dari satu instance (PROD_CLAIMQ untuk icms/pooldata/datapega; ASMD/SIMASNET/SYARIAH_S untuk mbu dan data asuransi lain), saling terhubung db-link.

Tabel kerja Pega (akan pensiun): datapega.pc_asm_fw_icms_work_ddfb3, datapega.pc_asm_fw_gkm_work, pr_asm_fw_gkm_data_index_spare — menyimpan pystatuswork, pyid, pxcreatedatetime, dll. Untuk klaim baru tidak dipakai lagi; flag/kolom pentingnya ditambahkan ke tabel flat existing (B-04).

Integrasi existing (UF §5, §6): AI service (deteksi panel), Google image service (upload/getURL/getAI — OCR), ASM core, AutoPro, e-part/TAP ASP, Payment WS, Kasir (GL.PKG_PELUNASAN_KASIR@SIMASNET), TEKNO_CreateSPK, lapisan KONVERSI ke ASMD, HCC/HCQ (rencana auth), WMS (unused part), SMS gateway internal, SMTP (general.lst_email_server), Crystal Reports 10 + ABCpdf5 (COM Windows, PDF), REST Pega (ServiceGenerateLoginBengkel GKM; ClaimCheck/ClaimCheckDeductible kelas GISFW). Beberapa integrasi tanpa autentikasi; konvensi tidak konsisten.

Masalah struktural terverifikasi (UF §6): SQL injection endemik (string concat, termasuk nama kolom & operator dari request); arbitrary SQL dari browser via excelwrite/excel.asp (≥10 modul); bypassLogIn (session dari query string); PDF di webroot tanpa auth; IDOR dokumen pajak lintas bengkel; ≥60 NIK hardcoded untuk otorisasi; COMMIT/ROLLBACK di dalam prosedur; kosakata status tidak konsisten (dipertahankan demi parity). Gap export: ~49 halaman act/login/config E-Klaim + schema GENERAL & GL + DDL db-link belum tersedia (Open Items OI-1..OI-3).

# BAGIAN II — ARSITEKTUR MASA DEPAN

## 3. Future Architecture (To-Be)

### 3.1 Bentuk umum

```
+---------------------------+     REST/JSON     +-------------------------------+
|  React SPA (Vite, TS)     | <---------------> |  ClaimQ API - modular monolith|
|  statis via reverse proxy |                   |  (satu binary Go, 2 instance) |
+---------------------------+                   +---------------+---------------+
   ^ internal / bengkel /                                       |
     supplier / klien                +--------------------------+------------------+
                                      v                          v                  v
   kanal pelaporan online       +-----------------+   +--------------------+  +----------------+
   (mobile/web/barcode) --> API |  Oracle x2      |   | Adapter integrasi  |  | Scheduler Go   |
   INBOUND (kontrak beku)       |  PROD_CLAIMQ +  |   | (AI, Google, ASM,  |  | (agent app,    |
                                |  ASMD/MBU,      |   | AutoPro, TAP,      |  |  antrian email/|
                                |  tabel flat +   |   | Payment/Kasir,     |  |  WA/SMS)       |
                                |  db-link warisan|   | KONVERSI/ASMD,     |  +----------------+
                                +-----------------+   | HCC/HCQ, WMS, ...) |
                                                      +--------------------+
```

Satu modular monolith Go (Q26) + React SPA (§27) di atas Oracle existing (B-12), 2 instance di belakang reverse proxy pada VM on-premise dengan Docker Compose (Q27), 3 environment DEV/UAT/PROD (Q33). Tidak ada Kubernetes dan tidak ada message broker — skala 100–200 user harian tidak membutuhkannya (B-13); yang menuntut 2 instance adalah target 24/7 + rilis rolling (Q31). Tidak ada ketergantungan runtime pada Pega untuk klaim baru sejak hari pertama.

Siklus hidup satu request (contoh approval Kabas): SPA memanggil POST /api/v1/... → middleware (trace_id, sesi, guard otorisasi §17) → use-case modul membuka transaksi (D-5) → fungsi kondisi (porting When) memvalidasi → state machine mengeksekusi transisi (status lama → status baru pada kolom tabel flat, penerima assignment berikutnya) → SQL warisan terparameterisasi menulis tabel flat → tabel log existing mencatat audit (Q13) → commit → panggilan integrasi (bila ada) dilakukan SETELAH commit dengan pencatatan log service (§12) → respons.

### 3.2 Backend: modular monolith Go (Q26)

Satu binary; modul per bounded context (§5): registrasi (partial+CTL), stolen, bengkel, procurement, akseptasi (pembayaran/rekap/kwitansi), salvage (lelang/recovery/TCR), pelaporan, masterdata, otorisasi (auth), integrasi, reporting, scheduler, platform. Batas modul ditegakkan lewat struktur paket + interface (bukan network call), sehingga pemisahan menjadi layanan terpisah di masa depan tetap terbuka tanpa membayar pajak operasional microservices hari ini. Fungsi utility kustom Pega dipadankan sekali di paket platform (terverifikasi: ASM.GetPageJSONString — 166–184× pemakaian, membangun payload JSON ke integrasi; ASM.IsDecimal — validasi angka, dipakai di Procurement; ASMGetMetaData; parse respons via pxConvertStringToPage).

### 3.3 Database: Oracle, tabel flat existing (Q9, B-04, B-12)

Klaim baru ditulis ke tabel flat existing yang sama (icms., mbu., pooldata.*). Struktur tabel existing TIDAK diubah — hanya boleh TAMBAH kolom baru (additive-only) untuk menampung flag/kolom penting eks-DATAPEGA (pystatuswork → kolom status, dsb). SQL existing direuse setelah diparameterisasi; laporan gabungan lama+baru berjalan otomatis; sistem hilir (KONVERSI/ASMD, report) tidak berubah. Tidak ada tabel engine flow terpisah (Q10). DDL hanya untuk kolom tambahan (additive) — dijalankan lewat migrasi yang direview.

### 3.4 API: REST/JSON (§11)

Tiga permukaan: (1) API internal /api/v1 (sesi cookie httpOnly); (2) API inbound publik kontrak-beku pengganti 3 Rule-Service Pega untuk kanal pelaporan online (autentikasi AccessToken + masa berlaku, direplikasi); (3) client keluar berkontrak beku, base URL/kredensial/timeout dari konfigurasi (§14). Payload error seragam (§12).

### 3.5 Frontend: React SPA (§27, Q24)

React 18 + TypeScript + Vite sebagai berkas statis di reverse proxy — tanpa server Node. Seluruhnya web (Q25), Bahasa Indonesia. **Switch Portal (Q55)**: user yang menangani lebih dari satu asuransi (dari MST_LOGIN_CABANG) dapat berpindah konteks portal (mis. ASM/ASI/SMAS) dari menu profil — meniru perilaku existing (portal aktif menentukan sourcecode, sumber data instance/db-link & base URL per-brand, logo, dan menu) dengan tampilan yang disesuaikan dan lebih user friendly; switch adalah state sesi pada satu domain web (Q28), bukan pindah URL. Perilaku & urutan field sama persis dengan existing sementara tampilan modern (B-09): Section + Harness Pega dan layout ASP menjadi sumber kebenaran field/urutan/kondisi visible-readonly/validasi, bukan styling. Logika bisnis tidak di frontend; validasi frontend hanya cermin backend.

### 3.6 Scheduler internal (Q30)

Penjadwal di dalam aplikasi Go (bukan URL-ping, bukan cron OS) dengan katalog job di konfigurasi, kunci antar-instance via DB (2 instance — hanya satu yang mengeksekusi), dan log per eksekusi. 147 DBMS_JOB Oracle (import master, OCR, alert, upload WO, booking polis, ETL KPI t_report_kpi_*, sinkronisasi) TETAP berjalan di database apa adanya. Scheduler Go menggantikan **37 Job Scheduler Pega** yang kini terinventarisasi lengkap dari folder Job_Scheduler_Pega (UF §12.1 — koreksi atas asumsi awal "agent Pega hampir tidak ada"): job procurement/TokoOnderdil (AutoChoose ASM/ASI, AutoPO, HitPO/HitWinner, Order/Confirm/Bill/DO/Resi/Ongkir TO, RetrieveBill ASM/ASI/Syariah, StatusDU, TrackingResi — kurir JNE/Sicepat/JNT Cargo), job stolen (AutoaksepStolen, EstimatorStolen, syncCasePositionStolen), job akseptasi (JobAgingAksepSebagian, JobRekapAksepSebagian), notifikasi (JobSendWAKlaimMBU — kirim WA, alert DLA/Pradana/NotulenMeeting/SurveyPGI, ABSKabasPGI), dan lainnya (ClaimQ_Print_SPK bulk, JobKonversiFotoGoogle/AVIF, JobManualMBU, ASMForceCaseClose) — semua BackgroundProcessing frekuensi "multiple times a day"; jadwal & perilaku direplikasi di scheduler Go. Batch level-aplikasi E-Klaim (WA/SMS antrian) juga masuk scheduler Go. Job penulis datapega dipensiunkan bersama Pega.

### 3.7 Flow engine: state machine di kode Go (Q10, Q14)

Setiap flow (§1.3) dinyatakan sebagai state machine terpusat di kode Go (satu berkas per flow), bukan if-else tersebar. Definisi transisi = (jenis case, status saat ini, aksi, fungsi kondisi, status berikut, aturan penerima assignment). Sumber kebenaran: FLOW_REGISTER_COMPLETE.xml + workbook case type + 9 rule Flow. Fungsi kondisi = porting rule When. Status disimpan sebagai kolom pada tabel flat; worklist/inbox dibangun dari query (meniru pola Bengkel existing yang murni flag flat-table). Kosakata status existing dipertahankan apa adanya termasuk varian ejaan (Resolved-Completed vs Resolve-Complete) demi parity tampilan/laporan.

## 4. Domain Model

Glosarium awal (diperdalam saat desain teknis). Istilah domain existing (Bahasa Indonesia/istilah legacy) dipertahankan agar tertelusur ke rule/tabel asal (D-6). Entitas inti mengikuti tabel flat existing — pemodelan ulang tidak dilakukan; tabel existing adalah modelnya (Q9).

| Term | Makna |
|---|---|
| Pelaporan | Laporan masuk sebelum menjadi klaim: online → t_pelaporan; lapor langsung → t_cetak_frm_clm. Bisa ditolak. |
| Klaim | Case utama (CLM-). Jenis: Partial, CTL, Stolen. Root: icms.t_claim / mbu.mst_klaim. |
| Polis | Data polis dari ASM (t_polis lokal + ASM_GetDataPolis). |
| Panel | Komponen kendaraan yang rusak; punya treatment (Ganti / Ganti+Cat / Ketok+Cat), status salvage, liability, panel support, mapping foto. |
| CTLO | Panel khusus klaim CTL-only. |
| TJH | Tanggung Jawab Hukum (pihak ketiga). |
| OR | Own Risk / risiko sendiri (dikalikan mengikuti jumlah kejadian; +1 bila SIM perpanjangan atau usia pengemudi <21). |
| WO | Work Order ke bengkel (Ganti vs Jasa). Root: mst_wo_est. |
| SPK | Surat Perintah Kerja (cetak via service ASM). |
| Akseptasi | Persetujuan nilai bayar klaim (mst_akseptasi / mst_pool_akseptasi). Nilai = (MWO_TTL_RG + MAK_TTL_TJH) − (MAK_KALI_OR × MAK_OR) − MAK_PPH_JASA + PPN. |
| Rekap | Rekap pembayaran per bengkel/rekening/ekspedisi; syarat: semua sparepart diterima, dokumen lengkap. |
| Kasir | Tujuan hit pembayaran (GL.PKG_PELUNASAN_KASIR@SIMASNET / API). |
| Premium Repair | Perbaikan jasa kelas premium dengan banding harga. |
| Proteksi (rangka/CTL/limit) | Mekanisme kunci yang butuh approval untuk dibuka; katalog kode PROTEKSI_ID (001 polis belum lunas, 012 limit akseptasi cabang, 021 ganti bengkel, 023 tambah kendaraan, 024 tambah WO, 068 ubah kali OR, 069 form klaim hilang, 073 fasttrack >6 panel, 076 dokumen kurang, 087 WO tidak liable, 120 tujuan bayar CTL, dll). |
| Ex-Gratia | Pembayaran di luar kewajiban polis; jenjang 100 juta (Kadiv/Direktur). |
| Komite berjenjang | Jenjang approval stolen berdasar nilai (15jt/200jt/keyless). |
| Surtol | Surat tolak (klaim ditolak). |
| QU/OU/DU | Unit procurement (Quotation / Order / Delivery). |
| Autopro | Portal supplier eksternal. |
| Salvage / Lelang / TCR | Disposal kendaraan/part sisa; lelang salvage; Total Constructive Loss. |
| Recovery Stolen | Unit stolen yang ditemukan (ditarik/dijual/klaim dibatalkan). |
| DLA / PLA | Definite / Preliminary Loss Advice (advis reasuransi). |
| jn_spv / ldi_id | Kode peran supervisor / divisi (backbone otorisasi). |
| HCC/HCQ | Aplikasi verifikasi login user internal (Q21). |
| KONVERSI / ASMD | Lapisan & sistem legacy tujuan sinkronisasi. |
| MBU | Motor Business Unit (schema mbu, aplikasi E-Klaim). |

Overloaded/collision term yang harus diselesaikan eksplisit saat desain (jangan bawa collision ke penamaan kolom): sts_pega/mapping_klaim_pega (dual-source data polis Pega vs legacy); kosakata status dengan varian ejaan.

### 4.1 Threshold & konstanta bisnis (terverifikasi — dikodifikasi sebagai konfigurasi, bukan hardcode)

Temuan penting deep-dive (UF §10): di legacy, threshold & identitas tersebar sebagai konstanta hardcoded di rule Pega dan prosedur Oracle. Di ClaimQ semuanya dipusatkan sebagai konstanta domain terdokumentasi (rujuk rule/tabel asal) atau konfigurasi. Perilaku/nilai tetap sama (parity).

| Konstanta | Nilai | Konteks | Sumber |
|---|---|---|---|
| Ex-gratia | 100.000.000 | <100jt Kadiv / ≥100jt Direktur | Partial ASM_InsertLimitClaim_Act; Stolen GetLimitKlaimKomite |
| Approval Komite (partial) | 250.000.000 | AmountSuggested > 250jt | Partial UpdateKlaimKomite_Act |
| Premium repair TSI tier | 300.000.000 & 400.000.000 | jenjang approval premium repair | Partial SaveAccPremiumRepair2_Act |
| Approval panel Kabas | 3.000.000 | nilai panel/sparepart > 3jt naik jenjang (Kabas) | Partial UpdateStatusPanel_Act |
| Jasa vs sparepart | 50% | harga jasa baru > ½ harga sparepart → approval Korwil | Partial Korwil/When/ValidasiUploadApprovalPremium |
| CTL — jumlah panel | > 20 panel | otomatis indikasi CTL | Partial ValidasiIndikasiCTL_Act; Proteksi_ICMS_GKM |
| CTL — nilai | estimasi/CTLValue > sum TSI | indikasi CTL | Partial ValidasiIndikasiCTL_Act |
| Komite stolen — MOTOR | ≥15jt Kabas→Korwil; ≥30jt Korwil→Kadiv | eskalasi organisasi | Stolen SubmitPengajuanKomite_Act |
| Komite stolen — MOBIL | ≤200jt Kabas→Korwil; >200jt Korwil→Kadiv | eskalasi organisasi | Stolen SubmitPengajuanKomite_Act |
| Komite stolen — KEYLESS | selalu eskalasi ke atas | eskalasi organisasi | Stolen SubmitPengajuanKomite_Act |
| Janji selesai bengkel | ≤ 45 hari kerja | validasi progress | Bengkel ValidasiBengkel_act |
| Own Risk (OR) | OR = ceil(OR% × TSICoverage/100); Kali OR = OR × jml kejadian | kalkulasi OR | Partial GetNilaiOR_DT |
| Autochoose supplier khusus | 1002707 (tertanggung), 1002318 (stok internal); TOD tertanggung 10 | prioritas tender | POOLDATA autochoose |
| ACCU/AKI/Battery | ≤ 2.000.000 | validasi part | POOLDATA autochoose |
| Identitas mitra (source code) | ASM 2209090011825955, ASI 2505020290303842, SMAS 2512260453085259, KB 2106300007030007 | routing per asuransi/mitra | Partial When IsASM/IsASI/... |
| ClaimFrom | 001=ASM, 002=SMAS, 003=ASI | source code rekap | Bengkel |

Catatan integrasi penting (UF §10.3): 38 dari 40 endpoint REST domain Partial di-resolve RUNTIME dari tabel konfigurasi (`ServiceFromTable`), bukan dari rule XML — daftar endpoint aktual harus di-dump dari tabel config saat migrasi (masuk Open Item §29). URL & IP yang masih hardcoded (AI PPN 192.168.108.192:8018, Payment 192.168.108.178:7001, environment app/kbinsure.claimq.id) dipindah ke konfigurasi (§14).

Catatan porting penting (UF §10, memperkuat Q11): logika bisnis nyata pada domain Pega TIDAK di rule Pega melainkan di FUNGSI/PROSEDUR Oracle yang dipanggil dari SQL (CEK_DOUBLE_CLAIM, F_CheckIsClaimHasORPerKejadianCTL, F_VALIDASI_KLAIM_PENGKINIAN, GET_HARGA_PREMIUMREPAIR, dst.) dan seluruh penulisan Pega melalui STORED PROCEDURE (pola ERRMSG/STS out). Porting ke Go (Q11) = reverse-engineer & reimplement logika fungsi/prosedur ini dengan golden test per objek (§20).

## 5. Bounded Contexts

Diturunkan dari inventaris modul (§6) & peta integrasi, dikelompokkan agar tiap konteks memiliki data inti sendiri dan kontrak eksplisit ke yang lain — ini batas modul internal modular-monolith, bukan batas microservice.

1. Registrasi & Klaim Partial/CTL — ClaimFlow + Surveyor + Estimator; review Kabas/Korwil/Tim Teknis/Compliance/Komite; ex-gratia; pindah bengkel; keputusan WO; proteksi CTL.
2. Registrasi & Klaim Stolen — 5 flow GKM; survey (TKP/by-phone); komite berjenjang; recovery; surat tolak.
3. Bengkel — progress perbaikan, penerimaan sparepart, panel jasa/ganti, premium repair & banding, rekap, kwitansi.
4. Procurement — QU/OU/DU; tender & autochoose; PO; pengiriman & SLA; return/refund; tender ulang.
5. Akseptasi & Pembayaran — cek rekap, akseptasi (per WO/sparepart/ekspedisi), pembayaran Kasir, penerimaan kwitansi & dokumen, pelunasan bengkel, PPN. (Konteks eks-E-Klaim inti.)
6. Salvage / Lelang / TCR / Recovery — salvage buyer, lelang, setoran jaminan, nego, undangan, recovery stolen, DLA/PLA/subrogasi.
7. Master Data — kendaraan, klien, supplier, bengkel, ekspedisi, panel, sparepart, harga jasa, supervisor/otorisasi, alokasi. Cross-cutting.
8. Pelaporan & Kanal Inbound — kontrak inbound pelaporan online (3 Rule-Service Pega + OCR), registrasi otomatis.
9. Identitas & Otorisasi — dua provider auth (internal HCC/HCQ; external hash lokal); parity access group + jn_spv + ldi_id + menu m_otorisasi.
10. Integrasi — adapter semua layanan eksternal (AI, Google Storage, ASM core, AutoPro, TAP/e-part, Payment/Kasir, TEKNO/SPK, KONVERSI/ASMD, HCC/HCQ, WMS, SMTP/SMS, courier).
11. Reporting & KPI — report/export Go-native (Excel & PDF), dashboard KPI (data pre-agregasi ETL).
12. Platform (infrastruktur) — config, logging, koneksi DB (2 instance), scheduler, middleware auth, utility Pega padanan.

## 6. Module Breakdown & Urutan Pengerjaan

Cutover serentak (big-bang, Q6): satu tanggal, seluruh registrasi baru + seluruh modul di ClaimQ. Urutan PENGEMBANGAN yang diusulkan mengikuti ketergantungan (bukan urutan cutover):

| Urutan | Modul | Alasan |
|---|---|---|
| 1 | Fondasi: platform (config/log/DB/scheduler/middleware), otorisasi dua provider, state machine, kerangka API, integrasi core | Semua modul lain bergantung |
| 2 | Master Data | Fondasi data untuk semua flow (kendaraan, bengkel, supplier, panel, jn_spv, dll) |
| 3 | Registrasi Partial/CTL + review berjenjang | Volume rule terbesar (2.034+), memvalidasi state machine paling dini |
| 4 | Registrasi Stolen (5 flow) + recovery | Flow paling terdokumentasi (workbook GKM) |
| 5 | Bengkel | Flag flat-table; bergantung hasil registrasi (SPK) |
| 6 | Procurement QU→OU→DU (termasuk autochoose) | Bergantung WO/SPK; integrasi terbanyak (Autopro/TAP) |
| 7 | Akseptasi & Pembayaran (Kasir) | Bergantung rekap bengkel/procurement; jalur keuangan |
| 8 | Salvage/Lelang/TCR/Recovery, DLA/PLA/Subrogasi | Bergantung CTL/stolen; modul E-Klaim mandiri |
| 9 | Pelaporan inbound + Reporting/KPI + Export Go-native | Butuh semua data hulu; report per modul |
| 10 | Kanal & integrasi tersisa, migrasi/takeover tooling | Menjelang cutover |

Status per modul dilaporkan dengan kosakata: Selesai / Selesai dengan catatan / Sebagian — tanpa klaim persentase terhadap total legacy tanpa penghitungan. Modul yang bergantung kiriman file (jalur tulis E-Klaim, schema GENERAL/GL, db-link) dibedah lebih dalam saat file diterima (OI-1..OI-3, OI-6).

# BAGIAN III — STRATEGI MIGRASI & TEKNIS

## 7. Migration Strategy

Pola: **big-bang intake + takeover klaim lama** (Q5, Q6).

Sebelum cutover:
- Bekukan kontrak integrasi (B-10); minta ekspor Rule-Service inbound (sudah ada di Website.zip), file act E-Klaim + schema GENERAL/GL + DDL db-link (OI-1..OI-3), ALL_SOURCE lengkap (OI-6).
- Hitung nilai MAX nomor case & dokumen per prefix di produksi → seed sequence (B-05, OI-5).
- Inventaris trigger tabel tulis untuk memutuskan mana yang dimatikan (single-writer) vs tetap (multi-writer, Q15).

Hari-H (satu tanggal): seluruh registrasi klaim BARU (semua asuransi, semua cabang, semua modul termasuk akseptasi/pembayaran & procurement) pindah ke ClaimQ; Pega ICMS, Pega GKM, dan E-Klaim berhenti menerima input baru saat itu juga (Q6, Q7).

Takeover klaim lama (D-3): menjelang shutdown, seluruh klaim open dibentuk statusnya di ClaimQ (kolom status/pemegang pada tabel flat) dan kolom eks-DATAPEGA di-backfill dari datapega untuk SEMUA klaim (open + resolved) agar riwayat utuh setelah datapega mati. Dua fakta membuat ini layak: kosakata status identik dipertahankan (Q10) → pemetaan status nyaris 1:1; dan data bisnis sudah di tabel flat yang sama (Q9) → tidak ada migrasi data bisnis. Assignment: pemegang case Pega dipetakan ke user login (verifikasi kecocokan — OI-7).

Verifikasi wajib (gerbang shutdown): perbandingan emas per klaim open — status, posisi, pemegang, flag di ClaimQ vs Pega pada momen cutover; selisih apa pun menghentikan shutdown.

Gerbang menuju live (Q8): setelah kode selesai — 2 minggu internal testing IT, lalu 4 minggu paralel testing + UAT bersama user terkait. Go-live hanya bila hasil lancar tanpa bug material. Paralel testing = menjalankan ClaimQ berdampingan Pega/E-Klaim pada kasus sama dan membandingkan hasil (§20).

Shutdown: Pega ICMS, Pega GKM, dan E-Klaim dimatikan bersamaan setelah gerbang kualitas & verifikasi takeover terlewati (Q7). Pega non-ICMS/GKM (GISFW/ASM core) tetap hidup sebagai integrasi eksternal (Q17). Setelah shutdown, adapter baca datapega dipensiunkan; laporan gabungan atas tabel flat tetap berjalan.

Yang sengaja TIDAK dilakukan: migrasi struktur data bisnis (sudah di tabel flat); perubahan kontrak integrasi; perubahan threshold/aturan bisnis; PostgreSQL.

## 8. Technical Strategy

Prinsip:
1. **Parity dulu, modernisasi tampilan saja** — setiap deviasi perilaku dari legacy harus punya keputusan bernomor.
2. **SQL existing adalah aset** — 3.828 Connect-SQL/RDB + SQL E-Klaim direuse sebisanya setelah diparameterisasi.
3. **Flow sebagai state machine di kode Go** — logika perpindahan status tidak ditulis sebagai if-else tersebar (§3.7).
4. **Integrasi di belakang antarmuka** — setiap layanan eksternal punya client Go tunggal dengan kontrak beku dan URL dari konfigurasi; timeout, retry-with-backoff, structured logging, circuit-breaking untuk endpoint flaky; menggantikan client HTTP hand-rolled yang tersebar. Setiap integrasi diberi kontrak sukses/gagal yang dinormalisasi.
5. **Tanpa ketergantungan runtime pada Pega ICMS/GKM** untuk klaim baru sejak hari pertama.

Cakupan porting procedure/trigger (B-06, Q11, Q15, Q16):
- Diporting ke Go: logika prosedur/orkestrasi yang dipanggil alur ClaimQ (autochoose, akseptasi, save/rekap, insert pelaporan, generate nomor, dll), trigger single-writer (seluruh penulisnya menjadi ClaimQ), dan prosedur/fungsi pembaca datapega (mati bersama Pega).
- TETAP di database: fungsi skalar read-only yang tertanam di SQL reuse (f_cek_double_klaim, f_gettanggaltanpaweekend*, get_part_ekonomis, klaimweb.get_*, dll — bagian database existing, bukan artefak baru), trigger multi-writer (mis. tabel yang masih ditulis TEKNO/Java/ASMD), dan 147 DBMS_JOB.

Stack teknis: Go (versi stabil terbaru saat implementasi), driver Oracle (mis. godror) via database/sql; SQL eksplisit lewat lapisan repository per modul (tanpa ORM berat); query builder/typed-query ringan untuk keamanan tipe. React + TypeScript + Vite (§27). Reverse proxy + Docker Compose per VM. Fungsi utility kustom Pega dipadankan sekali di paket platform.

Transaksi (D-5): batas transaksi di lapisan use-case Go (satu transaksi per aksi bisnis); COMMIT/ROLLBACK internal prosedur legacy tidak diwarisi (hilang by construction karena logika diporting ke Go). Panggilan integrasi di luar transaksi DB.

## 9. Coding Standards (baseline — diperluas menjadi style guide saat desain teknis)

Go: gofmt + golangci-lint wajib di CI; error dibungkus konteks (`fmt.Errorf("...: %w", err)`); tidak ada panic pada jalur request; transaksi eksplisit di use-case; **tidak ada SQL dirangkai string — hanya bind parameter** (menutup SQL injection, Q23); konstanta bisnis (threshold) di satu paket domain/constants dengan komentar rujukan rule/tabel asal.

Tidak ada logika bisnis di HTTP handler — handler parse/validasi input, panggil service modul, map hasil ke respons. Batas modul = batas paket Go nyata; tabel/tipe internal modul tidak di-import langsung modul lain — lewat interface tereskpor.

React/TS: strict TypeScript; komponen fungsi + hooks; state server via library query; form via library form + skema validasi diporting dari rule Validate/When; tidak ada logika bisnis di frontend.

Penamaan mengikuti istilah domain existing (pelaporan, panel, treatment, akseptasi, surtol) agar tertelusur ke rule asal (D-6).

## 10. Folder Structure (usulan — dokumen saja, belum dibuat; B-14)

```
claimq/
  backend/
    cmd/claimq/            # entrypoint tunggal (modular monolith)
    internal/
      registrasi/          # partial + ctl (flow, usecase, repo, http)
      stolen/              # 5 flow + recovery
      bengkel/             # progress, penerimaan sparepart, rekap, kwitansi
      procurement/         # QU/OU/DU, tender, autochoose
      akseptasi/           # cek rekap, akseptasi, pembayaran Kasir, pelunasan
      salvage/             # lelang, setoran jaminan, nego, DLA/PLA, subrogasi
      pelaporan/           # kanal inbound, OCR, registrasi otomatis
      masterdata/          # kendaraan, bengkel, supplier, panel, jn_spv, alokasi
      auth/                # dua provider: hccq (internal), lokal (eksternal)
      reporting/           # export Excel & PDF Go-native, KPI
      integrasi/           # 1 subpaket per layanan eksternal (kontrak beku)
      scheduler/           # agent level-app (email/WA/SMS antrian)
      platform/            # config, logging, db (2 instance), middleware, utility Pega
    migrations/            # DDL kolom tambahan additive (tabel flat existing tidak disentuh)
  frontend/
    src/{app,modules/{registrasi,stolen,bengkel,procurement,akseptasi,salvage,pelaporan,masterdata,laporan},components,api}
  docs/                    # steering, decision-log, understanding-findings, skill-usage, register integrasi
```

## 11. API Strategy

REST/JSON, versi di path (/api/v1) sejak awal. Tiga permukaan (§3.4): (1) API internal frontend↔backend, sesi cookie httpOnly (§16); (2) API inbound publik pengganti Rule-Service Pega untuk pelaporan online — kontrak sama persis (ASM_RegisPelaporan, ASM_DokumenPelaporan, GENERATE_NOPELAPORAN; autentikasi AccessToken + masa berlaku, direplikasi); (3) client keluar untuk semua integrasi — base URL/kredensial/timeout dari konfigurasi (§14), tidak pernah hardcoded.

Setiap endpoint internal wajib autentikasi + guard otorisasi (§17) — menutup temuan handler tanpa akses kontrol. Envelope respons seragam {kode, pesan, detail?, trace_id} (§12). Integrasi masuk-otomatis dari aplikasi e-Admin (dulu bypassLogIn) dipertahankan sebagai fungsi SSO lewat token service-to-service yang sah (Q23-revisi). Export Excel jadi definisi report server-side berparameter — tidak ada SQL mentah dari browser (Q23-revisi). Kamus field request/response per endpoint = artefak desain teknis, diturunkan dari Section/Harness/layout ASP & rule service.

## 12. Error Handling

Satu taksonomi (D-4): VALIDASI (input user — pesan Bahasa Indonesia mengikuti teks existing, termasuk RAISE_APPLICATION_ERROR yang diporting), BISNIS (aturan menolak — double claim, limit), INTEGRASI (layanan eksternal gagal — bedakan timeout vs menolak), SISTEM (bug/infra). Error domain bertipe (mis. ErrDoubleClaim, ErrLimitAkseptasi) dipetakan ke status HTTP konsisten di handler. Respons: {kode, pesan, detail?, trace_id}.

Kegagalan integrasi tidak menggantung case pada status ambigu: aksi yang memanggil layanan eksternal dirancang idempotent atau dicatat untuk diulang; pola log service existing (t_log_service/claimmbu_service_log) dipertahankan sebagai jejak. Integrasi yang legitim business-critical-and-blocking (mis. posting pembayaran via API Kasir — Q39 — untuk integritas keuangan) dibedakan dari yang boleh degrade dengan retry queue (mis. WA/SMS/email, tracking kurir) — ditetapkan per integrasi saat desain teknis. Perilaku saat HCC/HCQ tidak tersedia: login internal DITOLAK (Q21), tanpa mekanisme darurat; mitigasi operasional lihat §21.

## 13. Logging

Log terstruktur JSON ke stdout (dikumpulkan per VM), level INFO default; trace_id per request menembus sampai panggilan integrasi & SQL (Q34). Metrik & alert via stack ringan proporsional (mis. Prometheus/Grafana + agregator log), bukan SIEM enterprise.

Audit bisnis (Q13): setiap perpindahan status case, approval/penolakan, dan panggilan integrasi tercatat memakai **tabel log existing per modul** (mst_akseptasi_log_*, log_master_all, log_autojob_klaimmbu, t_log_service, dll); tabel log baru hanya ditambahkan pada modul yang belum punya jejak. Masking & rate-limit pencarian data nasabah (MASKING_KLAIM_MBU: log pencarian, limit harian, otorisasi buka masking) direplikasi persis (Q24-lama/parity). Tidak ada data sensitif (NIK penuh, password) dalam log aplikasi.

## 14. Configuration

Seluruh konfigurasi via environment variable / file per environment (DEV/UAT/PROD — Q33, D-1): koneksi 2 instance Oracle, base URL semua integrasi, kredensial (dari secret store/berkas ber-permission ketat, bukan repo), nama db-link per environment, toggle perilaku. Nilai produksi tidak pernah aktif secara default — guard environment allow-list. Perubahan URL integrasi = perubahan konfigurasi, bukan rilis kode. Tanpa tool secrets khusus (Vault/SOPS) pada skala ini (D-1). Secret/kredensial hardcoded existing (termasuk 6 alamat email) dipindah ke konfigurasi (Q23-revisi; alamat email direplikasi sebagai konstanta terdokumentasi, pemindahan ke tabel masuk Future Enhancement).

# BAGIAN IV — KEAMANAN & DATA

## 15. Security

Postur default = **replikasi PERILAKU existing** (parity), dengan LIMA celah yang WAJIB diamankan tanpa mengubah hasil fungsional (Q23-revisi — hasil grilling; parity yang dipegang proyek adalah perilaku bisnis, bukan mekanisme rapuh):

| # | Celah existing | Keputusan ClaimQ (hasil fungsional tetap sama) |
|---|---|---|
| 1 | SQL injection endemik (string concat, termasuk nama kolom & operator dari request) | 100% query berparameter; whitelist kolom sort; ditegakkan lewat review + lint. Hasil baris identik. |
| 2 | Arbitrary SQL dari browser (excelwrite/excel.asp, ≥10 modul) | Diganti definisi report server-side berparameter; output Excel identik. SQL mentah dari browser dihapus total. |
| 3 | bypassLogIn (e-Admin set session dari query string) | Fungsi SSO e-Admin dipertahankan lewat token service-to-service yang sah; user e-Admin tetap masuk tanpa login ulang. |
| 4 | PDF/dokumen di webroot tanpa auth | File di balik autentikasi & otorisasi. |
| 5 | IDOR dokumen pajak bengkel (lintas bengkel) | Scoping per bengkel ditegakkan (dokumen hanya untuk pemiliknya). |

Selain lima ini: postur otorisasi & perilaku lain direplikasi apa adanya (parity, §17). Least-privilege user Oracle untuk aplikasi; secret tidak pernah di repo; CSRF protection untuk sesi cookie; rate limit dasar pada endpoint inbound publik; masking & rate-limit pencarian data nasabah direplikasi (§13); dependensi dipindai berkala. TLS validation selalu aktif (menutup temuan integrasi yang menonaktifkan validasi sertifikat). Session timeout 30 menit idle (Q24-lama/parity E-Klaim).
> **AMENDEMEN Q191 (11 Sep 2026)** — batas **session timeout 30 menit idle** di atas tetap berlaku, dengan satu saklar DEV: `CLAIMQ_SESSION_IDLE_DISABLED=true` mematikannya sepenuhnya sehingga sesi hanya berakhir oleh logout. Saklarnya **eksplisit**, bukan `CLAIMQ_SESSION_IDLE_TIMEOUT=0` — nol sudah bermakna "pakai bawaan" pada `NewManager`, dan mengubah maknanya akan mematikan timeout pada environment yang lupa menyetel nilainya. Konfigurasi **MENOLAK** saklar ini di environment PROD (aplikasi tidak start), sepola guard `CLAIMQ_SESSION_COOKIE_SECURE`. Kedua penegak kedaluwarsa ditutup bersamaan (`Manager.Load` dan `Manager.Clean`), dan layar menulis "Tidak dibatasi (server pengembangan)" alih-alih "0 menit". Rincian: decision-log Q191.


## 16. Authentication (B-07, Q21)

Dua provider di belakang satu antarmuka Authenticator:

| Tipe user | Verifikasi | Penyimpanan |
|---|---|---|
| Internal (karyawan) | API HCC/HCQ (login+password dicek ke database asuransi via API) | Tidak menyimpan password internal; profil & peran dari mst_login/mst_login_cabang & sumber grant existing |
| Bengkel, supplier/mitra, klien reasuradur | Lokal | Hash modern (argon2id/bcrypt) di tabel user existing masing-masing (lst_user_bengkel/supplier/client); kolom password mentah lama tidak dipakai |

Halaman login ClaimQ dibuat BARU (Q42) — tidak mereplikasi halaman login E-Klaim/Pega; satu pintu login untuk semua jenis user dengan dua provider di belakangnya. Sesi: cookie httpOnly + server-side session store ringan (cukup untuk 2 instance via tabel sesi). Perilaku saat HCC/HCQ tak tersedia: tolak login internal (Q21), tanpa fallback. Spesifikasi kontrak API HCC/HCQ menyusul (OI-4). Kredensial user eksternal existing yang tak ter-hash di-reset terkelola saat go-live. Login bypass/backdoor existing tidak diporting (Q23-revisi #3 mengganti dengan token sah). SSO e-Admin lewat token service-to-service.

## 17. Authorization (Q22)

**Parity data**: ClaimQ MEMBACA sumber grant existing yang sama sehingga hak akses user tidak berubah saat go-live:
- Menu per-user modul eks-E-Klaim: m_otorisasi + m_menu_aplikasi (APP_ID=22).
- Peran supervisor: mst_supervisor.jn_spv (≥35 kode; katalog di modul Supervisor — mis. 003 Spv Estimator, 005 Spv OU, 010 Spv Mst Bengkel, 012 Spv Harga Jasa, 030 Komite Cabang, 032 Rekap semua bengkel).
- Divisi: lst_user_asuransi.ldi_id (0025 superadmin, 0062 bengkel, 0063 QU, 0064 OU, 0076 kabas, 0125 arsip, dll).
- Flow eks-Pega: access_group (ICMS:Kabas/Korwil/Komite/Surveyor/Estimator/Akseptor/Admin, COMPLIANCE, TEKNIS) + cakupan cabang mst_login_cabang + profil_asuransi per-asuransi.

Satu-satunya perubahan: ≥60 NIK (lus_id) hardcoded di source dipindahkan ke tabel/konfigurasi — perilaku sama, tidak lagi tertanam di kode. Predikat kondisi (rule When) diporting menjadi fungsi kondisi yang dirujuk state machine & guard endpoint. Enumerasi lengkap jn_spv/ldi_id/access_group + pull M_GRUP = artefak desain teknis (OI-11).

## 18. Database Strategy

### 18.1 Prinsip kepemilikan (Q9, B-04)

Tabel flat existing (icms., mbu., pooldata.*) ditulis oleh ClaimQ untuk klaim baru & takeover. Struktur berlaku additive-only: proyek boleh MENAMBAH kolom baru (nullable, terkoordinasi) untuk menampung flag/kolom penting eks-DATAPEGA, dan TIDAK pernah mengubah/menghapus kolom existing. Tidak ada tabel engine flow (Q10) — status/pemegang/posisi = kolom pada tabel flat. Kolom tambahan dibuat lewat migrasi additive yang direview.

### 18.2 Topologi koneksi (Q12)

Dua connection pool Go: instance PROD_CLAIMQ (modul eks-Pega: icms/pooldata/datapega) dan instance ASMD/MBU (modul eks-E-Klaim: mbu/mbufoto). SQL warisan dieksekusi di instance asalnya; db-link di dalam SQL (ASMD, SIMASNET, OPJAVA11, ASO, SYARIAH_S, PROD_CLAIMQ, PROD_HCC, dll — >13.000 referensi) tetap bekerja apa adanya, urusan sesi Oracle. Nama db-link per environment dari konfigurasi (§14). DDL db-link MBU perlu diekspor (OI-3). Akses cross-schema pada instance sama (mis. general, GL) tidak butuh db-link.

### 18.3 Penomoran (B-05, Q20)

Case (CLM/B/PC/SP): satu Oracle sequence per prefix, global lintas asuransi/cabang, format identik. ClaimQ memakai SEQUENCE EXISTING yang sudah disiapkan di database (Q44) — pola nama `*_CLMQ` di schema ICMS, contoh terverifikasi dari pemilik: `ICMS.NOCLAIM_CLMQ` (START WITH 2670, MINVALUE 1, MAXVALUE 27 digit, NOCYCLE, NOCACHE, NOORDER — NOCACHE aman untuk 2 instance dan meniadakan gap cache). Karena ICMS & GKM sama-sama memakai CLM- dengan counter terpisah, seed sequence sudah memperhitungkan nilai berjalan gabungan. Inventaris lengkap sequence per prefix (+ nomor dokumen) = artefak desain teknis; prefix yang belum punya sequence dibuat dengan pola DDL yang sama. inskey sintetis berformat lama ("ASM-FW-...-WORK CLM-nnnnn") dibangkitkan agar tabel flat & sistem hilir kompatibel. Keunikan dijamin PK; celah nomor (gap) diterima.

Nomor dokumen non-case (akseptasi, rekap/referensi, pelaporan, MMK_ID): logika generate diporting ke Go, format & urutan identik, memakai sequence Oracle atau SELECT FOR UPDATE (anti-duplikat). Pola MAX+1 tanpa lock diganti mekanisme aman dengan hasil format sama (Q20).

### 18.4 Transaksi (D-5)

Batas transaksi di lapisan use-case Go (BEGIN…COMMIT per aksi bisnis) — kebiasaan legacy COMMIT/ROLLBACK di dalam prosedur (terverifikasi: autochoose 5 COMMIT/7 ROLLBACK; DU_KLAIM_PKG) tidak diwarisi; dengan logika diporting ke Go (Q11), seluruh orkestrasi berjalan dalam satu transaksi use-case. Panggilan integrasi di luar transaksi DB.

### 18.5 Prosedur, trigger & fungsi (B-06, Q11, Q15, Q16)

- **Diporting ke Go**: prosedur orkestrasi yang dipanggil alur ClaimQ; trigger single-writer (tabel yang seluruh penulisnya menjadi ClaimQ) — logikanya pindah ke Go dan trigger dimatikan; prosedur/fungsi pembaca datapega (mati bersama Pega). Golden test per prosedur (§20).
- **Tetap di database**: fungsi skalar read-only tertanam di SQL reuse; trigger multi-writer (tabel yang masih ditulis sistem lain seperti TEKNO/Java/ASMD — mis. PINDAH_DARI_TEKNO di mst_kend_survey) tetap aktif & tidak diduplikasi; 147 DBMS_JOB. Inventaris per-objek (216 trigger aktif; procedure/function per modul) = artefak desain teknis (OI-6).

### 18.6 Backup/DR (Q32)

RPO menit / RTO < 1 jam, dibenarkan transaksi keuangan live (akseptasi, pembayaran bengkel, pelunasan Kasir, lelang). Di Oracle: redo-log shipping/Data Guard atau replikasi terkelola, bukan sekadar RMAN periodik. Runbook restore = deliverable desain teknis.

# BAGIAN V — OPERASIONAL & KUALITAS

## 19. Deployment Strategy

On-premise (Q27), Docker container via Docker Compose/systemd (tanpa Kubernetes), GitLab CI (Q33) — implikasi: migrasi source control ke Git/GitLab sebagai tugas awal. 3 environment (DEV/UAT/PROD) dengan konfigurasi terpisah; UAT punya environment sendiri (Q8/Q33). Produksi: 2 instance backend + frontend statis di belakang reverse proxy; rilis rolling per instance (instance A keluar dari upstream, update, health-check, masuk kembali, lalu B). Rollback = jalankan image sebelumnya. Migrasi DDL additive dijalankan sebelum rilis yang membutuhkannya, selalu mundur-kompatibel. Satu domain web tetap untuk semua asuransi (Q28); identitas asuransi dari login (host-agnostik). Observability: log JSON + Prometheus/Grafana proporsional (Q34), bukan SIEM. Target 24/7 (Q31) dengan jendela maintenance terkelola.

## 20. Testing Strategy (Q35)

Tiga lapis verifikasi parity:
1. **Golden test**: hasil implementasi Go dibandingkan hasil prosedur/SQL existing pada dataset UAT yang sama — autochoose (per skenario matriks keputusan), akseptasi (rumus nilai + PPN), penomoran, hitung OR/kali OR, jenjang komite (15jt/200jt/keyless/100jt), banding 50%, hari kerja (F_GETTANGGALTANPAWEEKEND*).
2. **Test flow tabelaris**: setiap baris relasi pada workbook case type & flowchart menjadi kasus uji state machine (status, kondisi, tujuan, penerima); setiap butir validasi pada Proteksi_ICMS_GKM.xlsx & rule Validate/When menjadi kasus uji.
3. **Paralel testing**: ClaimQ berjalan berdampingan Pega/E-Klaim pada kasus sama saat UAT (2 minggu internal + 4 minggu paralel/UAT — Q8), membandingkan hasil.

Unit test Go untuk fungsi domain/kondisi; integrasi test terhadap stub kontrak-beku per layanan; repository test terhadap Oracle test instance. Kriteria terima UAT = "sama persis dengan existing"; deviasi hanya yang ada di daftar pengecualian (§15), tampilan (B-09), dan deviasi bernomor Q61 (hapus cek janji kirim HE) & Q62 (hapus cek rekap TAP) — masing-masing diberi acceptance test eksplisit agar tidak dianggap bug parity. Coverage dilaporkan apa adanya per modul — tanpa klaim "semua teruji" tanpa angka.

## 21. Risk Analysis (register awal)

| # | Risiko | Dampak | Mitigasi | Status |
|---|---|---|---|---|
| 1 | SQL injection endemik + arbitrary SQL dari browser di legacy | Keamanan & parity | Parameterisasi total + report server-side (§15); golden test hasil query identik | Diputuskan (Q23-revisi) |
| 2 | Jalur tulis modul eks-E-Klaim tidak dianalisis dari source act page (Q42: export tidak diminta lagi) + schema lintas/DDL db-link belum diekspor (OI-2/OI-3) | Parity jalur tulis eks-E-Klaim | Rekonstruksi dari prosedur DB (logika tulis sesungguhnya, sudah di dump) + halaman view + golden test & UAT parity (Q35); schema lintas menyusul | Diturunkan (Q42) — terkendali |
| 3 | Port total prosedur/trigger tanpa oracle test yang lengkap | Parity Bengkel/Procurement/Akseptasi | Golden test per prosedur; ALL_SOURCE lengkap (OI-6); pengecualian multi-writer (Q15) | Terkendali desain |
| 4 | Takeover/backfill klaim open salah (status/pemegang/flag meleset) | Klaim lama macet di ClaimQ | Verifikasi emas per klaim open sebelum shutdown (§7); pemetaan status ~1:1; gladi resik di UAT | Mitigasi wajib |
| 5 | HCC/HCQ tak tersedia → login internal ditolak (by design) | Operasional 24/7 | Monitoring & alert ketersediaan HCC/HCQ; timeout ketat; pesan jelas; eskalasi ke pemilik HCC/HCQ | Diputuskan (Q21) |
| 6 | Trigger multi-writer & lintas-instance (>13.000 referensi db-link) | Efek samping ganda / integrasi putus | Inventaris per-trigger; pengecualian multi-writer (Q15); db-link dari konfigurasi | Terbuka, terkendali |
| 7 | Kontrak integrasi reverse-engineered (AI, AutoPro, TAP, Kasir, WA) | Parity integrasi | Bekukan kontrak; validasi ke tim vendor/partner sebelum implementasi modul terkait | Terbuka |
| 8 | Jalur Kasir final belum pasti (db-link vs REST) | Modul pembayaran | Ikuti pola existing (Q18); verifikasi saat OI-1/OI-2 diterima | Terbuka |
| 9 | Reporting/PDF (Crystal+ABCpdf5 COM Windows) diganti Go-native | Layout report | Reproduksi layout dari .rpt/observasi + correspondence; golden compare output | Diputuskan (Q29) |
| 10 | Tim frontend & Go — kurva belajar | Jadwal & kualitas | Stack sederhana (React/Vite), library matang, modul percontohan direview ketat | Terbuka |
| 11 | Enumerasi otorisasi (jn_spv/ldi_id/access_group/M_GRUP) + 60 NIK hardcoded | Assignment/akses salah | Pull master live; audit NIK ke tabel (OI-11) | Terbuka |
| 12 | Big-bang cutover semua modul sekaligus | Beban go-live tinggi | Gerbang kualitas 2+4 minggu; paralel testing; rollback = image sebelumnya + Pega/E-Klaim hidup sampai verifikasi lulus | Terkendali (Q6/Q8) |

## 22. Non-Functional Requirements

| NFR | Target | Dasar |
|---|---|---|
| User aktif harian | 100–200 | Brief (B-13) |
| Konkurensi puncak (perkiraan awal) | 30–60 request aktif | Turunan B-13 — divalidasi setelah UAT |
| Ketersediaan | 24/7 (Q31) | Keputusan |
| Rilis | Nyaris tanpa downtime (rolling per instance — Q27/Q31) | Keputusan |
| RPO / RTO | RPO menit / RTO < 1 jam (Q32) | Transaksi keuangan live |
| Respons API | p95 < 500 ms baca; < 2 s aksi tulis kompleks — target, divalidasi | Kewajaran skala |
| Perangkat | Web (browser evergreen), desktop-first untuk form padat (Q25) | Keputusan |
| Bahasa | Indonesia (id-ID) (D-6) | Preferensi tetap |
| Audit | Semua perpindahan status & approval terekam ke tabel log existing (§13) | Kebutuhan klaim asuransi |
| Keamanan | 5 celah wajib aman (§15), selebihnya parity | Q23-revisi |

## 23. Performance Strategy

Skala kecil = kesederhanaan: connection pool Oracle 10–20 per instance per database (mulai kecil, ukur); tanpa cache terdistribusi — cache in-memory per instance hanya untuk master nyaris statis (katalog panel, merk/model, profil_asuransi, menu/otorisasi) dengan TTL pendek; kandidat pertama caching = lookup menu/otorisasi (di legacy re-run query bertingkat tiap load). Paginasi wajib untuk worklist & laporan (menggantikan pola legacy yang memuat seluruh recordset ke memori). Query laporan berat diberi batas waktu & halaman. Dashboard produksi cukup polling interval pendek dari SPA — tanpa WebSocket pada skala ini. Tidak ada optimasi spekulatif — ukur di UAT dengan data produksi-mirip.

## 24. Scalability

Jalur tumbuh tanpa ubah arsitektur: (1) naikkan instance backend di belakang reverse proxy (stateless kecuali sesi di DB); (2) pisahkan VM frontend/backend; (3) modular monolith berbatas jelas — ekstraksi modul panas (mis. registrasi/procurement) menjadi service adalah opsi, bukan kebutuhan. Beban penentu ada di Oracle existing (sudah menanggung beban yang sama hari ini); lever pertama bila tumbuh = read-replica (Active Data Guard) sebelum ubah topologi.

## 25. Maintainability

Fix terbesar vs legacy: logika bisnis dipisah dari handler ke fungsi domain/service teruji (§9), menggantikan ASP tanpa layering & rule Pega tersebar. Batas modul nyata (§9, §10). Ketertelusuran sebagai fitur: setiap konstanta/kondisi/SQL membawa rujukan rule/tabel asal; state machine bisa dibaca analis; decision log & register integrasi hidup di docs/; ADR untuk keputusan arsitektur baru pasca-Steering. Satu repo, satu jalur build, lint & test wajib di CI (Q33). Mandatory golden + unit + integrasi test (§20) menutup nol-coverage legacy.

## 26. Future Enhancement (di luar lingkup Steering ini)

Pemindahan alamat email/konstanta hardcoded ke tabel/konfigurasi terparametrisasi; parametrisasi threshold per-asuransi bila dibutuhkan; migrasi Oracle→PostgreSQL bila kondisi (lisensi/infra/arah organisasi) membenarkan (SQL sudah ditulis rapi, tanpa artefak PL/SQL baru — mempermudah); pemensiunan lapisan KONVERSI bila ASMD pensiun; SSO/AD organisasi; secrets manager (Vault/SOPS) bila distandarkan organisasi; Kubernetes bila distandarkan organisasi; penggantian layanan ASP legacy (TAP/Kasir) bila pemiliknya memodernisasi; peningkatan otomasi AI di luar kontrak beku; mobile-friendly lanjutan untuk portal eksternal.

# BAGIAN VI — ANALISIS & REGISTER

## 27. Analisis & Rekomendasi Frontend (B-12, Q24)

Konteks penilaian: aplikasi internal berbasis web, form-heavy (ratusan field berurutan — parity urutan field wajib, B-09), tanpa kebutuhan SEO/render publik (100% di belakang login), 100–200 user, backend Go menyajikan REST/JSON, target 24/7 dengan rilis rolling berbasis berkas statis, Bahasa Indonesia, seluruhnya web (Q25).

Perbandingan kandidat:

| Kandidat | Kelebihan | Kekurangan | Performa | Maintenance | Cocok dgn Go | Skalabilitas | Ekosistem | Learning curve |
|---|---|---|---|---|---|---|---|---|
| React (SPA + Vite) | Ekosistem form/tabel/enterprise terkaya (React Hook Form, TanStack Table/Query); talenta terbanyak di Indonesia | Perlu disiplin arsitektur (tidak opinionated) | Sangat cukup untuk form app; bukan hambatan di skala ini | Baik bila pola distandarkan (§9) | Netral — konsumsi REST; hasil build statis | Baik | Terbesar | Sedang |
| Vue 3 (+ Vite) | Learning curve paling landai; dokumentasi bagus | Talenta lokal lebih sedikit dari React | Setara | Baik | Netral | Baik | Besar (kedua) | Rendah |
| Next.js | SSR/route file; kerangka lengkap | SSR/Node server tidak dibutuhkan (internal, tanpa SEO); menambah komponen runtime 24/7; kompleksitas rilis naik | Setara untuk kasus ini | Lebih banyak konsep | Menambah server Node di samping Go — mubazir | Baik | Besar | Lebih curam |
| Nuxt | Kerangka Vue lengkap | Sama dengan Next (SSR tak dibutuhkan) + talenta Vue | Setara | — | Menambah Node | Baik | Sedang | Sedang |
| Angular | Sangat opinionated, enterprise, DI bawaan | Paling berat dipelajari untuk tim tanpa pengalaman; verbose | Setara | Kuat di tim besar berdisiplin | Netral | Baik | Besar tapi menurun | Tinggi |
| Svelte/SvelteKit | Output ringan; DX menyenangkan | Ekosistem komponen enterprise & talenta lokal kecil; risiko umur panjang | Terbaik di bundle (tidak menentukan di sini) | Baik | Netral | Baik | Kecil | Rendah–sedang |
| SolidJS | Reaktivitas halus, cepat | Ekosistem paling kecil; rekrutmen sulit; risiko jangka panjang terbesar | Terbaik secara mikro (tidak menentukan) | ? | Netral | ? | Sangat kecil | Sedang |

**Rekomendasi final: React 18 + TypeScript + Vite, sebagai SPA statis** yang disajikan reverse proxy. Justifikasi: (1) kebutuhan sesungguhnya aplikasi ini adalah form engine & tabel/grid yang stabil bertahun-tahun — ekosistem React (React Hook Form, TanStack Table/Query, pustaka komponen matang) paling kuat persis di situ; (2) talenta React terbanyak → materi belajar, contoh, dan rekrutmen searah; (3) SPA statis meniadakan server Node — rilis rolling cukup mengganti berkas statis, komponen 24/7 berkurang satu; (4) Next/Nuxt ditolak karena satu-satunya nilai tambah utamanya (SSR/SEO) tidak relevan untuk aplikasi internal ber-login; (5) Angular ditolak karena biaya belajar tertinggi; (6) Svelte/Solid ditolak karena umur aplikasi asuransi menuntut ekosistem & pasokan talenta yang terbukti. Mitigasi risiko tim (§21 #10): kerangka modul percontohan dibangun & direview ketat sebelum tim menskalakan pola.

## 28. Decision Register

Ringkasan; lengkap (pertanyaan→opsi→jawaban→keputusan) di `docs/decision-log.md`.

Terkunci dari brief (B): B-01 gabung 3 aplikasi; B-02 pilih jenis klaim di awal; B-03 multi-asuransi/cabang; B-04 flat table Oracle + kolom eks-DATAPEGA additive; B-05 nomor case via sequence format identik; B-06 procedure & trigger ke kode Go; B-07 auth internal HCC/HCQ + external hash; B-08 attachment Google Storage; B-09 parity perilaku, tampilan modern; B-10 parameter REST sama, hanya URL berubah; B-11 layani data baru & lama; B-12 Go + Oracle + frontend hasil analisis; B-13 skala 100–200 DAU; B-14 tanpa kode sebelum Steering disetujui.

Discovery (Q): Q1 mulai dari nol; Q2 E-Klaim full scope + shutdown; Q3 export ASP menyusul; Q4 DOCX+MD; Q5 takeover klaim lama; Q6 big-bang cutover; Q7 shutdown Pega+E-Klaim bersamaan; Q8 gerbang 2 mgg internal + 4 mgg UAT; Q9 tulis tabel flat existing; Q10 status di kolom flat (tanpa engine); Q11 port total procedure/trigger; Q12 dua koneksi + db-link; Q13 audit ke tabel log existing; Q14 flow = state machine Go; Q15 pengecualian trigger multi-writer; Q16 fungsi skalar tetap dipakai; Q17 hanya Pega ICMS+GKM mati; Q18 Kasir ikut pola existing; Q19 notifikasi parity + backend; Q20 penomoran non-case port ke Go; Q21 login internal HCC/HCQ + eksternal hash lokal; Q22 otorisasi parity data + NIK ke tabel; Q23→Q23-revisi keamanan 5 celah wajib aman (hasil grilling); Q24 React SPA+TS+Vite; Q25 aplikasi web penuh; Q26 modular monolith; Q27 on-prem Docker Compose tanpa K8s; Q28 satu domain tetap semua asuransi; Q29 reporting Go-native; Q30 job DB tetap + scheduler Go level-app; Q31 24/7 penuh; Q32 RPO menit/RTO<1jam; Q33 DEV/UAT/PROD + Git/GitLab CI; Q34 log JSON + stack ringan; Q35 golden + paralel + UAT parity; Q36–Q38 konfirmasi turunan/format/kedalaman; Q39 jalur Kasir = API (REST insertAllPaymentKasir — menutup OI-10); Q40 verifikasi ulang folder Database; Q41 arahan format flow §1.3 per bagian; Q42–Q46 resolusi OI Ronde 12 (login baru; sequence existing *_CLMQ; msgklaim diabaikan); Q47–Q54 resolusi OI Ronde 13 (Job_Scheduler_Pega 37 job; URL_Service_ICMS 129 endpoint; POOLDATA lengkap); Q55 model multi-asuransi 3 tabel + fitur Switch Portal (tampilan modern).

Turunan (D): D-1 config env/file, tanpa Vault; D-2 attachment Google Storage + metadata tabel foto, file di balik auth; D-3 backfill semua klaim + verifikasi emas; D-4 taksonomi error + pesan Indonesia existing; D-5 transaksi per aksi di Go; D-6 Bahasa Indonesia + istilah domain existing.

## 29. Open Items Register

Status per 2 September 2026 (Ronde 15): **SEMUA Open Items (OI-1..OI-14) TERTUTUP. Tidak ada keputusan maupun kiriman yang menahan steering ini.**

| # | Item | Resolusi |
|---|---|---|
| OI-1 | Export ~49 file ASP E-Klaim | TERTUTUP (Q42): login ClaimQ dibuat baru; jalur tulis direkonstruksi dari prosedur DB + halaman view + UAT parity |
| OI-2 | Export DDL schema lintas (GENERAL, GL, BENGKEL/tap_*, MBUFOTO, COLLECTION, REINSURANCE, HRDASM, NEWBENGKEL, tabel POOLDATA) | TERTUTUP (Q56): saat implementasi ClaimQ terhubung LANGSUNG ke schema database existing (introspeksi via koneksi Q12) tanpa DDL manual; kiriman menyusul saat implementasi |
| OI-3 | DDL database link MBU & ICMS | TERTUTUP administratif (Q47): menyusul saat implementasi; nama db-link dari konfigurasi per environment |
| OI-4 | Kontrak API HCC/HCQ | TERTUTUP administratif (Q48): dokumentasi tim IT HCC/HCQ menyusul; §16 memakai antarmuka provider |
| OI-5 | Seed penomoran | TERTUTUP (Q44): pakai sequence existing pola `*_CLMQ` (ICMS.NOCLAIM_CLMQ — NOCYCLE NOCACHE NOORDER) |
| OI-6 | Export ALL_SOURCE | TERTUTUP (Q40+Q54): ICMS & MBU lengkap; POOLDATA lengkap (PKG_DU_PEGA, PKG_OU_PEGAPOOL, PKG_AKSEPT_SPAREPART) |
| OI-7 | Verifikasi pemegang case takeover | TERTUTUP (Q49): diabaikan dulu; tetap bagian gladi resik takeover di UAT (D-3) |
| OI-8 | Daftar agent Pega | TERTUTUP (Q50): folder Job_Scheduler_Pega — 37 Job Scheduler terinventarisasi (§3.6, UF §12.1) |
| OI-9 | Objek "msgklaim" | TERTUTUP (Q45): diabaikan |
| OI-10 | Jalur Kasir | TERTUTUP (Q39): API — REST insertAllPaymentKasir |
| OI-11 | Enumerasi otorisasi + NIK hardcoded | TERTUTUP (Q51): parity data existing (Q22) cukup; daftar NIK di docs/daftar-nik-hardcoded.md |
| OI-12 | URL penerus panggilan Pega→Pega (janji kirim HE) | TERTUTUP (Q52→Q61): TIDAK DIPERLUKAN — pengecekan janji kirim HE dihapus dari ClaimQ (Q61), integrasi ServiceTenderUlangJanjiKirimHE tidak dibangun |
| OI-13 | Dump tabel ServiceFromTable | TERTUTUP (Q53): URL_Service_ICMS.xls — 129 endpoint (UF §12.2) |
| OI-14 | Source package POOLDATA | TERTUTUP (Q54): PKG_DU_PEGA + PKG_OU_PEGAPOOL + PKG_AKSEPT_SPAREPART; ambang SLA terverifikasi (UF §12.3) |

Catatan jujur: OI-2/OI-3/OI-4/OI-12 ditutup atas arahan pemilik dengan kiriman MENYUSUL SAAT IMPLEMENTASI — keempatnya bersifat data/konfigurasi/dokumentasi, bukan keputusan desain; ketidakhadirannya tidak mengubah satu pun keputusan steering ini.

## 30. Catatan Penggunaan Skills

Lengkap di `docs/skill-usage-log.md`. Ringkas:

| Skill / metode | Tahap | Alasan | Hasil | Dampak |
|---|---|---|---|---|
| Pembacaan korpus multi-format (parser xlsx/docx/draw.io stdlib) | 1 | Lampiran beragam format tanpa library | Contoh steering, workbook, flowchart terbaca; korpus terverifikasi | Semua angka §2 & UF |
| Fan-out agent Explore paralel (orientasi codebase besar) | 1 | ~9.006 XML + 674 ASP + 76MB SQL tak mungkin serial | Inventaris E-Klaim A–Z, korpus Pega per folder, estate DB, deep-dive 4 domain Pega | §2, §5, §6, Open Items, Risk |
| AskUserQuestion terstruktur (interview berjejak) | 2 | Brief mewajibkan interview dengan jejak keputusan | Q1–Q38 terekam pertanyaan→opsi→jawaban | Hampir seluruh Steering |
| mattpocock-skills:grilling | 2 | Q23 (jawaban awal replikasi celah) kontradiktif & berisiko tinggi | User merevisi ke "pertahankan fungsi, implementasi aman" | §15, §16 (Q23-revisi) |

Catatan jujur: perintah `/setup-matt-pocock-skills` tidak tersedia di environment (plugin mattpocock-skills sudah terpasang); skill grilling dipanggil langsung. Skill lain (to-spec, domain-modeling, dll) yang disebut brief digantikan padanan metode terdekat dan dicatat apa adanya.

## 31. Ways of Working (aturan yang dibawa proyek ini)

1. Setiap klaim "beda dengan legacy" wajib mengutip dua sisi (kode/aturan baru + bukti legacy).
2. Jangan mewarisi klaim dari dokumen analisis tanpa cek — angka lama yang belum diverifikasi ulang diberi label.
3. Untuk perilaku kolom, tanya "siapa yang menulis ke sini", bukan "siapa yang mengisi".
4. Bawa angkanya, bukan hanya pertanyaannya (mis. rumus akseptasi, ambang komite, jumlah trigger aktif).
5. Yang tidak terbukti ditulis BELUM DIVERIFIKASI + pemilik (Open Item) — tebakan yang ditulis sebagai fakta adalah kegagalan yang tidak bisa dipulihkan.
6. "Buat sama persis dengan existing" adalah jawaban final — dibuka kembali hanya bila legacy ambigu, bertentangan dengan legacy, atau angka konkret belum ada.
7. Parity adalah tentang PERILAKU BISNIS (hasil, urutan, aturan), bukan mekanisme rapuh — mengamankan celah tanpa mengubah hasil bukan pelanggaran parity (pelajaran grilling Q23).
8. Dump repository bukan tentu = kondisi produksi; objek yang hilang dari dump (schema GENERAL/GL, db-link) diverifikasi dari database, bukan diasumsikan.

## 32. Document Control

| Item | Nilai |
|---|---|
| Versi | **v2.0 FINAL — DISETUJUI 2 September 2026 oleh Alfin (pemilik proyek)**. Riwayat: v1.9 Q61–Q62 (hapus cek HE & rekap TAP); v1.8/v1.8a Q60 + diagram; v1.7 Q59; v1.6 Q57–Q58 (review paralel + format formal); v1.5 semua OI tertutup; v1.4 Q55 Switch Portal; v1.3 Ronde 13; v1.2 Ronde 12; v1.1 Kasir=API; v1.0 draft awal 1 Sep |
| Status | **DISETUJUI — baseline v2.0 (2 Sep 2026)**. Gerbang implementasi B-14 TERBUKA. Perubahan pasca-persetujuan = AMENDEMEN bernomor (Q-nn baru) di bawah heading terkait; teks disetujui tidak dihapus; keputusan bernomor terbaru berlaku bila bertentangan |
| Metode perubahan | Keputusan baru masuk via decision-log.md (Q/D-nn) → Steering; keputusan bernomor terbaru berlaku bila bertentangan sampai rewrite disetujui |
| Dokumen pendamping | `docs/decision-log.md` · `docs/understanding-findings.md` · `docs/skill-usage-log.md` · `docs/register-integrasi.md` |
| Batasan | Bagian yang bergantung kiriman (jalur tulis E-Klaim/Kasir, schema GENERAL/GL, db-link, kontrak HCC/HCQ) ditandai Open Item (§29) dan diselesaikan saat file diterima — tidak memblokir blueprint |
