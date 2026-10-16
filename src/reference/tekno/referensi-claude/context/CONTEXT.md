# ClaimQ — Glosarium Domain (CONTEXT.md)

Satu konteks bahasa untuk seluruh aplikasi ClaimQ (migrasi Pega ICMS + Pega GKM + E-Klaim MBU → Go/Oracle/React). Basis: Steering v2.0 §4 (Domain Model), dipertajam dari UF §10–§13 dan keputusan Q64–Q68. Istilah legacy Bahasa Indonesia/istilah asal DIPERTAHANKAN agar tertelusur ke rule/tabel asal (D-6). Dokumen ini glosarium murni — tanpa detail implementasi.

Format per istilah: definisi · _Hindari_ (sinonim yang tidak boleh dipakai) · _Relasi_ · _Aktor_ · _Sumber_ (tabel/rule/keputusan asal).

---

## Pelaporan & Registrasi

**Pelaporan**:
Laporan kerugian yang masuk SEBELUM menjadi klaim; bisa ditolak. Dua jalur: online (kanal eksternal via API inbound) dan lapor langsung (cetak formulir klaim).
_Hindari_: "laporan klaim" (belum tentu jadi klaim), "registrasi" (itu tahap berikutnya).
_Relasi_: menjadi [Klaim] setelah registrasi. _Aktor_: Tertanggung, kanal online, CS. _Sumber_: icms.t_pelaporan (online), icms.t_cetak_frm_clm (langsung); Rule-Service ASM_RegisPelaporan (Website/).

**Registrasi**:
Tindakan mengubah pelaporan menjadi case klaim bernomor CLM-; di ClaimQ diawali pemilihan jenis klaim (partial vs kehilangan/stolen) di satu pintu (B-02).
_Hindari_: "pendaftaran", "input klaim".
_Relasi_: menghasilkan [Klaim], [Nomor Case]. _Aktor_: CS/cabang, Surveyor. _Sumber_: B-02; flow ClaimFlow (Klaim Partial/), Regis_klaim (Klaim Stolen/).

**Klaim**:
Case utama berprefix CLM-. Jenis: **Partial** (kerusakan sebagian), **CTL** (kerusakan parah), **Stolen** (kehilangan kendaraan).
_Hindari_: "kasus", "tiket" (tiket = unit kerja proyek, bukan domain).
_Relasi_: berakar pada [Polis]; memuat [Panel]; berujung [Akseptasi]. _Aktor_: semua. _Sumber_: icms.t_claim, mbu.mst_klaim.

**Polis**:
Data pertanggungan dari sistem ASM (salinan lokal + layanan GetDataPolis); sumber TSI, coverage, dan OR%.
_Hindari_: "kontrak".
_Relasi_: menentukan [TSI], [OR], coverage CTL-only. _Aktor_: Surveyor, Kabas, sistem. _Sumber_: icms.t_polis; ASM_GetDataPolis.

**Nomor Case**:
Nomor identitas case per prefix (CLM- klaim, B- bengkel, PC- quotation procurement, SP- supplier), format identik existing, global lintas asuransi/cabang, dari sequence Oracle pola `*_CLMQ`. Catatan sejarah: ICMS & GKM sama-sama memakai CLM- dengan counter dulunya terpisah — seed sequence gabungan sudah memperhitungkannya.
_Hindari_: "nomor tiket", "ID Pega".
_Relasi_: dibungkus [inskey] untuk kompatibilitas hilir. _Aktor_: sistem. _Sumber_: B-05, Q20, Q44; ICMS.NOCLAIM_CLMQ; UF §8.

**inskey**:
String identitas case berformat lama Pega ("ASM-FW-ICMS-WORK CLM-nnnnn") yang tersimpan di tabel flat dan dibaca sistem hilir; ClaimQ MEMBANGKITKAN nilai sintetis berformat sama untuk case baru.
_Hindari_: "pzInsKey" untuk nilai buatan ClaimQ (pzInsKey = kolom asal Pega; nilai ClaimQ disebut inskey sintetis).
_Relasi_: turunan [Nomor Case]. _Aktor_: sistem, hilir (KONVERSI/report). _Sumber_: icms.t_claim.claim_inskey; UF §8, §10.3.

## Panel & Kerusakan

**Panel**:
Komponen kendaraan yang rusak pada satu klaim; punya treatment, status salvage, liability, mapping foto, dan penanda (support, fast moving, velg).
_Hindari_: "part"/"sparepart" (itu barang yang dibeli, bukan komponen yang rusak), "item kerusakan".
_Relasi_: menentukan [WO], [Bengkel]; >20 panel → indikasi [CTL]. _Aktor_: Surveyor, AI, Checker, Estimator. _Sumber_: icms.t_panel, t_treatment.

**Treatment**:
Perlakuan atas satu panel: **Ganti** (1), **Ganti+Cat** (2/mix), **Ketok+Cat** (3). Ganti/Ganti+Cat mutually exclusive dengan Ketok+Cat.
_Hindari_: "aksi panel", "repair type".
_Relasi_: Ganti memicu [Procurement]; Jasa (Ketok+Cat) bisa memicu [Premium Repair]. _Aktor_: Surveyor, Estimator, Bengkel. _Sumber_: icms.t_treatment; UF §10.2.

**Sparepart**:
Barang yang diadakan lewat procurement untuk panel ber-treatment Ganti; diterima bengkel dengan status penerimaan (SUDAH TERIMA) dan kondisi (Sesuai/Rusak/Part Salah/Belum Dicocokkan).
_Hindari_: "panel" (lihat Panel), "onderdil" dalam dokumen (kecuali nama produk TokoOnderdil).
_Relasi_: hasil [Tender]; syarat [Rekap]. _Aktor_: Procurement, Supplier, Bengkel. _Sumber_: pr_asm_fw_gkm_data_index_spare; pooldata.tender_supplier.kondisi_barang; UF §10.4.

**CTLO**:
Panel khusus yang dipasang otomatis pada klaim ber-coverage hanya-CTL (bengkel = NONE); dihapus saat konversi CTL→Partial.
_Hindari_: menyebutnya "panel biasa".
_Relasi_: penanda jalur [CTL]. _Aktor_: sistem, Korwil. _Sumber_: §1.3.2 Steering.

**TJH**:
Tanggung Jawab Hukum — kerugian pihak ketiga yang ikut diklaim; punya blok dokumen sendiri dan komponen nilai sendiri di akseptasi.
_Hindari_: menerjemahkan ke "third party liability" di UI/dokumen.
_Relasi_: komponen rumus [Akseptasi] (MAK_TTL_TJH). _Aktor_: Surveyor, Akseptor. _Sumber_: icms.t_tjh.

**TSI**:
Total Sum Insured — nilai pertanggungan polis; pembanding indikasi CTL (estimasi > TSI) dan jenjang premium repair (300jt/400jt).
_Hindari_: "nilai kendaraan".
_Relasi_: dasar [OR], [CTL], [Premium Repair]. _Aktor_: sistem, Komite. _Sumber_: mst_coverage; §4.1 Steering.

**OR / Kali OR**:
Own Risk (risiko sendiri): OR = ceil(OR% × TSICoverage/100); **Kali OR** = OR × jumlah kejadian, bertambah +1 bila SIM perpanjangan atau usia pengemudi <21.
_Hindari_: "deductible" di UI (istilah existing = OR).
_Relasi_: pengurang rumus [Akseptasi]; proteksi 068 (ubah kali OR). _Aktor_: Surveyor, Akseptor. _Sumber_: GetNilaiOR_DT (Klaim Partial/); BR-12.

**CTL**:
Jalur klaim kerusakan parah (Constructive Total Loss): dipicu >20 panel / panel di master rusak parah / estimasi > TSI; keputusan proteksi CTL oleh Korwil; dapat dikonversi CTL↔Partial tanpa registrasi ulang; ujungnya SPGR CTL + salvage/lelang.
_Hindari_: "total loss" tanpa kualifikasi (bedakan dari stolen).
_Relasi_: varian [Klaim]; memicu [Salvage]. _Aktor_: Korwil, Komite, GA. _Sumber_: ValidasiIndikasiCTL_Act; §1.3.2.

## Review, Komite & Approval

**Review Klaim**:
Tahap pemeriksaan berjenjang sebelum keputusan. Partial/CTL: AI (otomatis) → Kabas ∥ Compliance (paralel) → Korwil → Tim Teknis (Q57). Stolen: paralel per divisi Compliance ∥ Kabas ∥ Korwil, masing-masing dengan decision "Apakah Review Klaim Sesuai?" (Q59/Q60).
_Hindari_: "verifikasi" (dipakai untuk Checker), "approval" (itu keputusan, bukan review).
_Relasi_: mendahului [Komite Berjenjang] / [Keputusan WO]. _Aktor_: Kabas, Korwil, Compliance, Tim Teknis. _Sumber_: FLOW_REGISTER_COMPLETE.xml; t_review_clm; GetDataReviewCompliance.

**Komite Berjenjang**:
Jenjang approval stolen berdasar nilai × jenis kendaraan: motor ≥15jt Kabas→Korwil, ≥30jt →Kadiv; mobil ≤200jt Kabas→Korwil, >200jt →Kadiv BAS; keyless selalu eskalasi ke atas.
_Hindari_: menyamakan dengan "Approval Komite partial" (ambang 250jt — konsep berbeda).
_Relasi_: setelah [Review Klaim] stolen; hasil setuju → [SPGR]. _Aktor_: Kabas, Korwil, Kadiv BAS. _Sumber_: SubmitPengajuanKomite_Act; INSERT_COMITTE_DATA; BR-08..BR-10.

**Ex-Gratia**:
Pembayaran di luar kewajiban polis; jenjang tunggal **250 juta** di ClaimQ (amendemen Q84-P2, deviasi sadar dari legacy 100jt): <250jt Kadiv Teknis, ≥250jt Direktur Teknis (partial & stolen).
_Hindari_: "goodwill payment"; memakai angka legacy 100jt untuk ClaimQ.
_Relasi_: cabang khusus [Review Klaim]. _Aktor_: Kadiv Teknis, Direktur Teknis. _Sumber_: Q84-P2 (nilai); mekanisme parity: ASM_InsertLimitClaim_Act; GetLimitKlaimKomite.

**Keputusan WO**:
Keputusan akhir klaim partial: setujui **Ganti** / jadikan **Jasa** / **tolak**; setuju → cetak SPK; tolak → Resolved-Rejected.
_Hindari_: "final approval".
_Relasi_: menghasilkan [WO], [SPK] atau [Surtol]. _Aktor_: Komite/Akseptor sesuai jenjang. _Sumber_: §1.3.1 Steering.

**Proteksi / Buka Proteksi**:
Mekanisme kunci sistem yang menahan suatu aksi sampai di-approve ("dibuka"); berkatalog kode PROTEKSI_ID (001 polis belum lunas, 012 limit akseptasi cabang, 021 ganti bengkel, 068 ubah kali OR, 073 fasttrack >6 panel, 120 tujuan bayar CTL, dst.).
_Hindari_: "lock"/"exception" generik.
_Relasi_: dipicu banyak modul (rangka beda, limit, dsb); butuh approval [Kabas]/[Korwil]. _Aktor_: pemicu = Bengkel/Akseptor/sistem; pembuka = jenjang approval. _Sumber_: t_request_proteksi; katalog PROTEKSI_ID; Proteksi ICMS_GKM.xlsx.

**Surtol**:
Surat tolak — dokumen resmi penolakan klaim, terbit lewat flow Reject Stolen (review komite → checker surtol → approval) atau penolakan partial.
_Hindari_: "rejection letter" di UI.
_Relasi_: ujung negatif [Klaim]; status Resolved-Rejected. _Aktor_: Checker surtol, Komite. _Sumber_: flow Reject_Stolen; SuratTolak_CORR.

## Bengkel & Perbaikan

**WO**:
Work Order — perintah kerja perbaikan ke bengkel per klaim, berjenis **Ganti** atau **Jasa** (perbaikan).
_Hindari_: "SPK" (SPK = dokumen cetak perintahnya, WO = objek kerjanya).
_Relasi_: lahir dari [Keputusan WO]; jenis Ganti memicu [Procurement]; root nilai [Rekap]. _Aktor_: Bengkel, Procurement, Akseptor. _Sumber_: mbu.mst_wo_est.

**SPK**:
Surat Perintah Kerja — dokumen cetak yang memerintahkan bengkel bekerja; dicetak via layanan ASM (TEKNO_CreateSPK). Momen "setelah cetak SPK" adalah batas historis masuknya modul eks-E-Klaim.
_Hindari_: memakai "SPK" untuk klaim stolen/CTL (di sana dokumennya [SPGR]).
_Relasi_: mengaktifkan [Bengkel] & [Procurement]. _Aktor_: Komite, Bengkel. _Sumber_: TEKNO_CreateSPK; CHECK_KONDISI_CETAKSPK.

**SPGR**:
**Surat Persetujuan Ganti Rugi** (kepanjangan dari work owner, Q69) — dokumen persetujuan pembayaran ganti rugi untuk jalur CTL (SPGR CTL) dan stolen (SPGR Stolen); nomor via SET_SPKNO_STOLEN.
_Hindari_: "SPK stolen".
_Relasi_: padanan [SPK] untuk CTL/stolen; mendahului [Akseptasi]. _Aktor_: Komite, Akseptor. _Sumber_: SET_SPKNO_STOLEN; DokPengajuanSPGRLog (UF §10.1).

**Progress Bengkel**:
Tahapan perbaikan berurutan wajib: BONGKAR→KETOK→DEMPUL→CAT→PASANG→FINISHING→QC FINAL→SELESAI (+LAIN-LAIN, RAWAT JALAN, TUNGGU SPAREPART); janji selesai maksimal 45 hari kerja.
_Hindari_: "status bengkel" (status = kolom flag; progress = tahapan fisik).
_Relasi_: syarat [Rekap]; hari kerja dihitung fungsi F_GETTANGGALTANPAWEEKEND*. _Aktor_: Bengkel, Kabas. _Sumber_: SaveInputBengkel_Act; ValidasiBengkel_act; BR-11, BR-19.

**Rawat Jalan**:
Kondisi kendaraan keluar bengkel sementara lalu masuk kembali; tanggal keluar & masuk kembali wajib berurutan.
_Hindari_: makna medis.
_Relasi_: bagian [Progress Bengkel]. _Aktor_: Bengkel. _Sumber_: ValidasiBengkel_act (UF §10.2).

**Premium Repair**:
Perbaikan jasa kelas premium yang butuh approval Korwil dengan jenjang TSI 300jt/400jt; termasuk **banding harga**: harga jasa baru >50% harga sparepart → approval Korwil.
_Hindari_: mengaitkan approval banding ke "direksi" (koreksi terverifikasi UF §10.3 — approvernya Korwil).
_Relasi_: varian [Treatment] jasa. _Aktor_: Bengkel, Korwil. _Sumber_: SaveAccPremiumRepair2_Act; ValidasiUploadApprovalPremium; BR-03, BR-05.

**Panel Tambahan**:
Panel yang terdeteksi (AI) setelah WO berjalan; butuh approval per jenis treatment: JASA (Ganti+Cat / Ketok+Cat) → Kabas; GANTI → Korwil (keputusan work owner, Q72).
_Relasi_: menambah [WO]; proteksi 024 (tambah WO). _Aktor_: Bengkel, AI, Kabas, Korwil. _Sumber_: §1.3.4; UF §10.2; Q72.

**Rekap**:
Rekap pembayaran bengkel per bengkel / per no rekening / per ekspedisi; syarat: SEMUA sparepart diterima & sesuai, foto EPOXY (WO jasa) / foto SALVAGE+PEMASANGAN (WO ganti), dokumen lengkap. (Deviasi sadar Q62: pembedaan rekap TAP dihapus di ClaimQ.)
_Hindari_: memakai "rekap" tanpa kualifikasi untuk rekap lain (mis. rekap ongkir) — sebut lengkap.
_Relasi_: masukan [Akseptasi]; nomor via P_SET_NO_REKAP. _Aktor_: Bengkel, Akseptor. _Sumber_: SET_REKAP_BENGKEL_KLAIMMBU; BR-20.

**Kwitansi**:
Bukti tagihan bengkel yang dicetak + diupload setelah rekap; penerimaannya (>7 hari di-follow-up) menjadi syarat pelunasan.
_Relasi_: antara [Rekap] dan [Pelunasan]. _Aktor_: Bengkel, Akseptor. _Sumber_: KWITANSI_BENGKEL_KLAIMMBU; BR-22.

## Procurement

**QU / OU / DU**:
Tiga unit procurement berurutan: **Quotation Unit** (buat quotation PC- + tender), **Order Unit** (pemenang + PO), **Delivery Unit** (monitoring kirim + penerimaan). Stage tersimpan sebagai ProcurementGroup, bukan status case.
_Hindari_: menyebut DU "ASMD" (lihat ASMD di bawah).
_Relasi_: dipicu [WO] Ganti; berujung [Sparepart] diterima bengkel. _Aktor_: Procurement, Supplier. _Sumber_: kelas ASM-FW-GKM-Work-Procurement; UF §10.4.

**Tender / Autochoose**:
Proses pemilihan supplier sparepart. **Autochoose** = pemilihan otomatis berprioritas: (1) ganti tunai tertanggung (supplier 1002707, TOD 10); (2) stok internal (1002318); (3) tender reguler CHEAPEST (multi-penawaran lokal-semua = FASTEST).
_Hindari_: "lelang" (lelang = disposal salvage, konsep lain).
_Relasi_: menghasilkan pemenang [OU]; golden test wajib (Q35). _Aktor_: sistem (job), Procurement. _Sumber_: POOLDATA PROSES_AUTOCHOOSE_PEGA; AutoChoose_Procurement.md; BR-15.

**Alasan Pemenang**:
Pernyataan tertulis petugas Order Unit tentang dasar memilih satu penawaran sebagai pemenang; wajib diisi saat pemenang ditetapkan, dan melekat pada PENAWARAN yang menang — bukan pada tendernya.
_Hindari_: menyamakan dengan "Alasan Tender Ulang" (itu sebab MEMBATALKAN pemenang) atau dengan "Alasan Stock"/"Alasan Transfer".
_Relasi_: hasil [Tender / Autochoose] yang dipilih manual; tampil sebagai kolom pada grid pembanding penawaran [OU]. _Aktor_: Order Unit. _Sumber_: ICMS.T_TENDER.ALASAN_MENANG; BENGKEL.TAP_T_TENDER_SUPPLIER.ALASAN_MENANG; Q364, Q395.

**TOD**:
Lama hari janji pengiriman supplier; **janji kirim** = tanggal PO + TOD.
_Hindari_: mengartikan "term of delivery" formal tanpa verifikasi — pakai fungsinya.
_Relasi_: dasar [SLA DU]. _Aktor_: Procurement, Supplier. _Sumber_: MBU.PKG_OU_PEGA.GET_JANJI_KIRIM; POOLDATA.F_GET_JANJI_KIRIM.

**SLA DU**:
Ambang keterlambatan penanganan di DU per kondisi barang: Part Rusak >2 hari, Part Salah >2 hari, Belum Dicocokkan >5 hari (dari tanggal aktual terima).
_Relasi_: dashboard [DU]. _Aktor_: Procurement. _Sumber_: POOLDATA.PKG_DU_PEGA.F_SLA_DU (UF §12.3).

**Stok Internal**:
Sumber sparepart dari gudang milik sendiri, bukan dari supplier luar; ikut tender sebagai penawaran atas nama "Stock ASM" dan menang lewat jalur tersendiri yang mengalokasikan nomor stok serta menambah booking saldo.
_Hindari_: "stok" tanpa kualifikasi (bisa berarti persediaan bengkel); "supplier stok" seolah pihak ketiga.
_Relasi_: prioritas ke-2 [Tender / Autochoose], mendahului tender reguler; subjek [Ongkir Stock]. _Aktor_: Order Unit, Quotation Unit. _Sumber_: BENGKEL.TAP_M_SUPPLIER 99999 "STOCK ASM" (= 1002318 "Stock ASM" legacy); TAP_T_ORDER_ALOKASI_STOCK; Q310, Q338, Q346.

**Ongkir Stock**:
Pengubahan ongkos kirim pada penawaran sparepart bersumber [Stok Internal], dilakukan SEBELUM pemenang tender ditentukan; setiap perubahan wajib beralasan dan meninggalkan jejak audit berisi nilai lama dan nilai baru.
_Hindari_: "adjustment ongkir" (modul lain — penyesuaian tagihan ongkir ekspedisi setelah pengiriman), "rekap ongkir", "pembayaran ongkir TO".
_Relasi_: satu-satunya pintu mengubah ongkir penawaran stok — Input Penawaran sengaja tidak menyentuhnya (Q329). _Aktor_: Order Unit, Quotation Unit, Kabas, Tekno. _Sumber_: korpus Procurement/Ongkir Stock; TAP_T_ORDER_LOG jenis log ongkir; Q346, ADR-0030.

**Verify Stock**:
Pernyataan bahwa barang stok yang ditawarkan benar sesuai kebutuhan panel pada satu SPK; tidak tersedia bagi stok yang catatannya menyebut RUSAK atau HILANG.
_Hindari_: menyamakan dengan [Akseptasi Sparepart] (itu penerimaan barang di bengkel) atau dengan kondisi barang saat DITERIMA (Q185/Q277).
_Relasi_: bagian layar [Ongkir Stock]; hasilnya tersimpan per (nomor stok, SPK, kendaraan survey). _Aktor_: Order Unit, Quotation Unit. _Sumber_: When IsVerifcationStock; BENGKEL.TAP_M_STOCK_VERIFY; Q346.

**Autopro**:
Portal/marketplace supplier eksternal untuk tender, PO, dan dokumen DO/resi/indent. Backend URL-nya kini keluarga tokoonderdil.id (UF §12.2).
_Hindari_: menyamakan dengan [TAP].
_Relasi_: kanal [Tender]/[OU]/[DU]. _Aktor_: Supplier, Procurement. _Sumber_: po.autopro.co.id API; register-integrasi.

**TAP / e-part**:
Layanan ASP legacy internal untuk book TO, PO manual, dan tender ulang supplier non-Autopro; kontrak beku.
_Relasi_: kanal alternatif [OU]. _Aktor_: Procurement. _Sumber_: app.sinarmas.co.id/tap_to/*.asp; UF §10.4.

**Cash Advance**:
Sub-lingkup procurement GKM untuk uang muka (work class tersendiri), termasuk return cash advance.
_Aktor_: Procurement. _Sumber_: ASM-FW-GKM-Work-CashAdvance.

**Akseptasi Minus**:
Akseptasi pembayaran yang **nilainya negatif** dan sudah punya nomor request advance; dipantau pada daftar tersendiri beserta status closing-nya. Negatif di sini sifat nilainya, bukan jenis transaksi tersendiri — [Akseptasi Pembayaran] yang sama, hanya bertanda minus.
_Hindari_: menyamakan dengan "Inbox Adjustment Minus" (layar lain); menyebutnya "retur" atau "penarikan dana" tanpa verifikasi — sebabnya belum terverifikasi (lihat Pertanyaan terbuka #5).
_Relasi_: himpunan bagian [Akseptasi Pembayaran]; bertetangga jalur [Cash Advance] (daftarnya memuat No Advance). _Aktor_: Procurement. _Sumber_: korpus Procurement/Akseptasi Minus; MBU.MST_AKSEPTASI (MWO_TTL_RG < 0, NO_REQUEST not null); Q388.

## Akseptasi & Pembayaran

**Akseptasi**:
Persetujuan nilai bayar klaim: nilai = (total jasa & sparepart + TJH) − (Kali OR × OR) − PPh jasa + PPN; melebihi limit akseptasi cabang → buka proteksi 012. Kata "akseptasi" JUGA dipakai legacy untuk (a) akseptasi sparepart/ekspedisi dan (b) tahap akseptor pada master data (maker-checker-akseptor) — selalu beri kualifikasi: **Akseptasi Pembayaran**, **Akseptasi Sparepart**, **Akseptasi Master**.
_Hindari_: "approval pembayaran" (istilah existing = akseptasi).
_Relasi_: setelah [Rekap]; sebelum hit [Kasir]. _Aktor_: Akseptor. _Sumber_: mst_akseptasi, mst_pool_akseptasi; BR-13, BR-14.

**Kasir**:
Sistem tujuan posting pembayaran; jalur ClaimQ = API REST insertAllPaymentKasir (Q39) — bukan db-link GL.
_Hindari_: menyebut jalur db-link GL.PKG_PELUNASAN_KASIR sebagai jalur ClaimQ.
_Relasi_: dipanggil setelah [Akseptasi Pembayaran]; business-critical-blocking. _Aktor_: Akseptor, sistem. _Sumber_: Q39; register-integrasi.

**Pelunasan**:
Tahap akhir pembayaran bengkel setelah kwitansi & dokumen diterima: cek PPN bengkel + bukti potong pajak → Resolved-Completed.
_Relasi_: setelah [Kwitansi]; dokumen pajak ber-scoping per bengkel (celah IDOR ditutup). _Aktor_: Akseptor, Bengkel. _Sumber_: §1.3.6; GL.upload_bukti_potong.

**Tgl Upload Bukti Bayar**:
Tanggal diunggahnya bukti transfer atas satu nomor akseptasi, dirangkai `no_aksep` → `GL.T_ALL_PAYMENT.NO_REF_BANK` → `GL.MST_REF_BANK.NO_PRE` → `MIN(TRUNC(GL.BUKTI_TRANSFER_KASIR.TGL_INPUT))`. Kosong berarti pembayarannya belum terjadi, dan itu memang menyaring baris keluar dari layar [Keterlambatan Dokumen].
_Hindari_: membacanya sebagai tanggal unggah Delivery Order — alias SQL legacy `TGL_UPLOAD_DO` SALAH NAMA; judul layar "Tgl Upload Bukti Bayar" yang benar. Jangan pula disamakan dengan `MBUFOTO.TRANSFER.TGL_INP`, yang dipakai layar [Kontrol Dokumen] lewat rantai `GL.MST_ADVANCE` yang BERBEDA.
_Relasi_: dasar hitung [Tgl Deadline Dokumen]. _Aktor_: Kasir (penulis), Procurement (pembaca). _Sumber_: BENGKEL.PKG_AKSEP_SEBAGIAN.GET_TGLUPLOADTRANS (Database/BENGKEL/PKG_AKSEP_SEBAGIAN.pkb baris 3044–3089); Q392.

**Tgl Deadline Dokumen**:
Batas waktu dokumen penutup akseptasi sebagian harus sudah masuk: [Tgl Upload Bukti Bayar] + **3 hari KERJA**, melompati Sabtu/Minggu dan libur `GENERAL.HRD_LBR`.
_Hindari_: menghitungnya dari Tgl Request atau Tgl Aksep, dan menghitungnya sebagai hari kalender.
_Relasi_: pembanding penanda telat layar [Keterlambatan Dokumen]. _Aktor_: Procurement. _Sumber_: BENGKEL.GETJANJIKIRIM2(…, 3); Q392.

**Aging (Akseptasi Sebagian)**:
Umur sejak **pengajuan** (`TRUNC(SYSDATE) − TRUNC(TGL_REQUEST)`) — BUKAN ukuran keterlambatan.
_Hindari_: membacanya sebagai "sudah telat sekian hari". Tenggatnya dihitung dari [Tgl Deadline Dokumen], sehingga baris ber-Aging 40 bisa belum lewat tenggat dan sebaliknya; yang menyatakan keterlambatan adalah penanda `telat` terpisah. Kata "Aging" di layar [DU] berarti lain lagi — di sana ia diwarnai menurut [SLA DU].
_Relasi_: kolom layar [Keterlambatan Dokumen] mode Aging. _Aktor_: Procurement. _Sumber_: RDB-List/AgingAksepSebagian_SQL; Q392.

**Keterlambatan Dokumen** (layar, menu `MKD`):
Pemantauan pengajuan [Akseptasi Sebagian] yang bukti bayarnya SUDAH diunggah tetapi dokumen penutupnya belum menyusul. Dua mode: **Aging** (kwitansi penutup belum diunggah) dan **Rekap** (dokumen fisik belum diterima DAN sudah lewat ambang hari).
_Hindari_: menyamakannya dengan [Kontrol Dokumen] (`KDAS`) yang memantau KELENGKAPAN keempat dokumen, atau dengan layar approval `ASB`.
_Relasi_: membaca kumpulan baris yang sama dengan `KDAS`; murni baca. _Aktor_: Procurement. _Sumber_: korpus Procurement/Monitoring Keterlambatan Dokumen; Q392.

## Salvage, Lelang & Reasuransi

**Salvage**:
Sisa kendaraan/part yang menjadi hak asuransi setelah penggantian; dikelola untuk disposal (jual/lelang). Di bengkel, "foto salvage" = bukti part lama WO ganti.
_Hindari_: mencampur makna "foto salvage bengkel" dengan "modul Salvage" — beri konteks.
_Relasi_: dari [CTL]/[WO Ganti]; menuju [Lelang]/[TCR]. _Aktor_: Divisi GA, Bengkel. _Sumber_: modul E-Klaim Salvage*; UF §6.

**Lelang**:
Proses penjualan salvage ke salvage buyer: undangan (SMS+email+PDF), setoran jaminan, nego.
_Hindari_: memakai "tender" untuk lelang.
_Aktor_: Divisi GA, salvage buyer. _Sumber_: modul E-Klaim Lelang Salvage/Setoran Jaminan/Input Hasil Nego.

**TCR**:
**Tekno Car Recondition** (kepanjangan dari work owner, Q69) — jalur rekondisi kendaraan pada penanganan kerugian konstruktif total; punya estimasi tersendiri.
_Aktor_: Divisi GA, Estimator. _Sumber_: newbengkel.t_estimasi_tcr; Q69.

**Recovery Stolen**:
Penanganan unit stolen yang ditemukan kembali: ditarik / dijual / klaim dibatalkan.
_Relasi_: pasca-[SPGR Stolen]. _Aktor_: Kabas, GA. _Sumber_: modul E-Klaim Recovery Stolen; §1.3.3.

**DLA / PLA**:
Definite / Preliminary Loss Advice — advis kerugian ke reasuradur; berikut subrogasi, dikelola di modul reasuransi + portal klien reasuradur.
_Aktor_: klien reasuradur (mis. Transjakarta), internal reasuransi. _Sumber_: reinsurance.mst_dla/mst_pla; modul E-Klaim DLA/PLA.

## Identitas, Otorisasi & Multi-Asuransi

**sourcecode**:
Kode identitas asuransi/kantor: setiap kantor PUSAT punya sourcecode sendiri; CABANG memakai sourcecode pusatnya. Nilai per mitra terverifikasi (ASM/ASI/SMAS/KB — BR-17).
_Hindari_: "kode perusahaan" generik; jangan hardcode di kode baru (dibaca dari PROFIL_ASURANSI).
_Relasi_: kunci [Switch Portal], routing integrasi per-brand. _Aktor_: sistem. _Sumber_: PROFIL_ASURANSI.SOURCECODE (UF §13.1); When IsASM/IsASI.

**Switch Portal**:
Perpindahan konteks asuransi aktif (ASM/ASI/SMAS) oleh user multi-asuransi dari menu profil; state sesi pada satu domain — menentukan sourcecode, sumber data instance/db-link, base URL per-brand, logo, dan menu.
_Hindari_: "ganti login", "pindah URL".
_Relasi_: hak dari [MST_LOGIN_CABANG]. _Aktor_: user internal multi-asuransi. _Sumber_: Q55, Q28; Switch_Portal.png (UF §13.2).

**access_group**:
Peran flow eks-Pega per user (ICMS:Kabas/Korwil/Komite/Surveyor/Estimator/Akseptor/Admin, COMPLIANCE, TEKNIS); satu user bisa punya hingga 4 (ACCESS_GROUP..ACCESS_GROUP4).
_Hindari_: "role" generik tanpa menyebut sumbernya.
_Relasi_: salah satu dari 4 mekanisme otorisasi paralel (bersama [jn_spv], [ldi_id], menu m_otorisasi). _Aktor_: semua user internal. _Sumber_: MST_LOGIN (UF §13.1); Q22.

**MST_MENUNAV / MST_MEMBERSHIP**:
Model akses menu per login (Q86): MST_MENUNAV = master daftar menu aplikasi (SECTION, NAMA, POSISIMENU, STSAKTIF, flag ISBENGKEL/ISSUPPLIER/ISASURANSIA/ISIT); MST_MEMBERSHIP = menu yang boleh diakses per login (MENUID × OPERATORID × SOURCECODE). Sumber gerbang modul master (Q85) dan menu Switch Portal.
_Hindari_: menyamakan dengan m_otorisasi/m_menu_aplikasi (itu model menu eks-E-Klaim APP_ID=22).
_Relasi_: dasar [Switch Portal]; gerbang modul master data. _Aktor_: semua user. _Sumber_: Profil_Asuransi_Login/MST_MENUNAV.xls & MST_MEMBERSHIP.xls; Q85, Q86.

**jn_spv**:
Kode peran supervisor (≥35 kode: 003 Spv Estimator, 005 Spv OU, 012 Spv Harga Jasa, 030 Komite Cabang, 032 Rekap semua bengkel, dst.) — backbone otorisasi modul eks-E-Klaim. Amendemen Q85: TIDAK dipakai sebagai gerbang aksi MODUL MASTER DATA (diganti akses menu per login); modul lain tetap parity Q22.
_Hindari_: menerjemahkan kodenya; memakainya sebagai gerbang modul master.
_Relasi_: dibaca guard otorisasi parity (Q22, kecuali modul master — Q85). _Aktor_: user internal. _Sumber_: general.mst_supervisor; katalog modul Supervisor; Q85.

**ldi_id**:
Kode divisi user (0025 superadmin, 0062 bengkel, 0063 QU, 0064 OU, 0076 kabas, 0125 arsip, dst.).
_Relasi_: mekanisme otorisasi paralel ketiga. _Aktor_: user internal & eksternal. _Sumber_: general.lst_user_asuransi.

**HCC/HCQ**:
Aplikasi internal verifikasi login karyawan; ClaimQ memverifikasi user internal ke sana via API dan MENOLAK login internal bila HCC/HCQ tidak tersedia (tanpa fallback).
_Hindari_: "LDAP/AD".
_Relasi_: provider [Autentikasi] internal. _Aktor_: user internal. _Sumber_: B-07, Q21; kontrak menyusul (Q48).

**e-Admin SSO**:
Jalur masuk-otomatis dari aplikasi e-Admin; di ClaimQ diselenggarakan lewat token service-to-service yang sah (pengganti bypassLogIn legacy).
_Hindari_: "bypassLogIn" untuk mekanisme baru (itu nama celah lama).
_Sumber_: Q23-revisi #3.

## Status & State

**Status Case (kosakata eks-Pega)**:
Nilai pyStatusWork per flow (mis. Pending-InputIncident, Pending-InboxKomite, Resolved-Completed, Resolved-Rejected). Di ClaimQ disimpan sebagai kolom pada tabel flat; kosakata existing dipertahankan verbatim (Q10) dengan SATU amendemen: ClaimQ menulis literal kanonik tunggal **`Resolved-Completed`** untuk semua flow — varian legacy `Resolve-Complete` tidak lagi ditulis untuk data baru (amendemen Q69). Data historis tidak dinormalisasi; pembacaan data lama wajib mengenali kedua literal.
_Hindari_: "state" untuk nilai bisnis ini (state = istilah teknik state machine); menulis `Resolve-Complete` pada data baru.
_Relasi_: digerakkan state machine (Q14); dasar worklist/inbox. _Sumber_: Q10, Q69; UF §10.1, §10.3.

**Status/Posisi Klaim (kosakata legacy DB)**:
Kosakata Indonesia pada kolom status_claim/posisi_claim (Pengecekan, Menunggu Akseptasi, Pengajuan, Register Klaim, Close/Batal, Reject, TANYA MARKETING/KABAS, …; posisi REGISTER→ESTIMATOR→SURVEYOR→ANALISATOR→BENGKEL→KOMITE/AKSEPTOR). Ini KOSAKATA BERBEDA dari Status Case eks-Pega, hidup di kolom berbeda, dan keduanya dipertahankan berdampingan — jangan digabung atau saling diterjemahkan.
_Sumber_: UF §10.3; Q10.

**sts_pega**:
Flag sumber data polis per klaim (legacy: 1 = data polis via layanan GISFW + salinan di [mapping_klaim_pega]; 0 = jalur tabel legacy). Klaim BARU ClaimQ: SELALU ditulis `1` (Q74-P1) — konsekuensinya setiap klaim baru WAJIB berbaris di `mapping_klaim_pega`.
_Hindari_: memakai sts_pega sebagai "status klaim" (ia flag sumber, bukan status proses); nilai selain 0/1.
_Relasi_: menentukan cabang baca data polis di DLA/SPGR/komite/report. _Sumber_: cek_klaim_pega.asp; dla.asp; UF §6; Q74.

## Sistem & Integrasi

**KONVERSI**:
Kelas Integration Pega (ASM-FW-GKM-Int-KONVERSI/2/3 dan service KonversiASM_*) — MAPPER data DB↔work object / sinkronisasi ke sistem inti, BUKAN sistem eksternal berdiri sendiri. Di ClaimQ menjadi mapper/fungsi internal + client sinkronisasi.
_Hindari_: "sistem KONVERSI" seolah aplikasi terpisah.
_Sumber_: UF §10.4 (koreksi istilah); register-integrasi.

**ASMD**:
DUA makna legacy yang WAJIB dibedakan: (1) **instance Oracle** tujuan db-link @ASMD (3.116 referensi) — makna kanonik di ClaimQ; (2) ASMDeliveryUnitPortal = portal DU internal Pega — di ClaimQ SEBUT "Portal DU", jangan "ASMD".
_Sumber_: UF §10.4 (koreksi istilah); UF §5.

**MBU**:
Motor Business Unit — schema Oracle `mbu` dan sebutan aplikasi E-Klaim MBU. Konteks menentukan makna; dalam dokumen teknis sebut eksplisit "schema mbu" atau "E-Klaim MBU".
_Sumber_: UF §1.

**Takeover**:
Pengambilalihan klaim lama ke ClaimQ menjelang shutdown: pembentukan status klaim open + backfill kolom eks-DATAPEGA untuk SEMUA klaim (open+resolved).
_Hindari_: "migrasi data" (data bisnis tidak pindah — sudah di tabel flat).
_Relasi_: digerbangi [Verifikasi Emas]. _Sumber_: B-11, D-3, Q5.

**Verifikasi Emas**:
Perbandingan per klaim open (status, posisi, pemegang, flag) ClaimQ vs Pega pada momen cutover; selisih apa pun MENGHENTIKAN shutdown.
_Hindari_: "golden test" (itu istilah verifikasi parity logika per prosedur — konsep berbeda).
_Sumber_: §7 Steering; D-3.

**Golden Test**:
Uji parity logika: hasil implementasi Go dibandingkan hasil prosedur/SQL existing pada dataset sama (autochoose, rumus akseptasi, OR, jenjang komite, hari kerja, double claim, penomoran).
_Hindari_: mencampur dengan [Verifikasi Emas].
_Sumber_: Q35; §20 Steering.

---

## Pertanyaan terbuka (istilah/aturan yang TIDAK boleh diberi definisi karangan)

| # | Hal | Status | Pemilik |
|---|---|---|---|
| 1 | ~~Nilai `sts_pega` klaim baru~~ — TERJAWAB (Q74-P1): selalu `1` + wajib isi baris `mapping_klaim_pega` | Tertutup 3 Sep 2026 | — |
| 2 | ~~Split approval panel tambahan~~ — TERJAWAB (Q72): jasa → Kabas, ganti → Korwil | Tertutup 3 Sep 2026 | — |
| 3 | ~~Daftar IDBengkel foto ekstra~~ — TERJAWAB (Q73): 6 ID = daftar PENGECUALIAN yang dibebaskan dari kewajiban upload pemasangan part/gandeng/epoxy; dipindah ke konfigurasi | Tertutup 3 Sep 2026 | — |
| 4 | ~~Normalisasi literal `Resolve-Complete` historis~~ — TERJAWAB (Q76-P2): TIDAK dinormalisasi; pembaca wajib mengenali kedua literal | Tertutup 3 Sep 2026 | — |
| 5 | **Sebab sebuah [Akseptasi Minus] bernilai negatif** — koreksi kelebihan bayar, pembatalan sebagian, atau hal lain. Layar legacy hanya menyaring `MWO_TTL_RG < 0`; tidak ada rule yang menyatakan sebabnya. | Terbuka 11 Okt 2026 (Q388) | work owner |

*Perubahan glosarium mengikuti mekanisme steering: keputusan baru = entri Q-nn di decision-log, lalu CONTEXT.md diperbarui merujuknya.*
