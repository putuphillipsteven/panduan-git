# TEKNO (e-BENGKEL)

The operational system for PT. Asuransi Sinar Mas's network of vehicle body-repair workshops. This
context covers the whole life of one repair job, from the vehicle arriving to the vehicle leaving,
together with the procurement, billing and period-close attached to it.

**How to use this document.** It is a glossary, not a specification — no implementation detail, no
column names used as definitions, no technical decisions. A term only enters here after it has been
**confirmed by the work owner** and recorded in `docs/decision-log.md` with its `Qnn`. The original
Indonesian terms (SPK, OR, TCR, Bengkel, and so on) are **not translated**.

Terms that still carry an open question are **marked explicitly** under §Terms not yet locked.
Writing an unconfirmed definition into the main section would turn a guess into official
vocabulary — which is exactly what this document exists to prevent.

## Language

### Work and place

**SPK** (Surat Perintah Kerja):
The work document for one repair job on one vehicle. The root entity of the whole production flow;
every downstream module refers to it.
_Avoid_: Work Order, WO, Job Order — "WO" means something different in the insurance system and must
not be used interchangeably with SPK.
Source: Q366.

**Bengkel**:
One workshop unit operating under a single identity. There are 15 active bengkel across three name
groups, spread over five cities, and **all three groups are real workshops** — not accounting
entities sharing a location. One bengkel is **one cutover unit**.
_Avoid_: Cabang, Branch — misleading, because a single city contains more than one bengkel.
Source: Q370.

**Lokasi Pengerjaan**:
The work stream a given SPK is handled on — Reguler, Fast Track, Premier Line, TCR, Fast Moving,
TPR, TransJ, Salon, Tata Puminar, Divisi Karoseri, Regular Caroline, General Repair, Mobility
Service, EV Line. It determines the pos sequence, the QC rules, and some of the pricing rules.
_Avoid_: VIP, Status VIP, Hangar — in the data it rides in a column named like a VIP flag, and that
confusion has already caused Fast Track SPK to be displayed as VIP. Two different concepts; do not
give them one name.
Source: Q376 (the authoritative list comes from the Lokasi Pengerjaan master).

### Workflow

**Registrasi Kendaraan Masuk**:
The screen where an SPK is created — recording the vehicle, the owner, the damage, the services and
the spare parts, then issuing the SPK number. This is the term operators use on the floor.
_Avoid_: Registrasi SPK, Input SPK, Registrasi Pelanggan — and **do not** use this name for Keluar
Masuk Kendaraan, which is a different process.
Source: Q376.

**Keluar Masuk Kendaraan**:
The record of a vehicle passing the bengkel gate — in and out — along with the driver and the
destination. A **separate** process from Registrasi Kendaraan Masuk: the two are only linked when
the SPK is printed, by matching the number plate. A vehicle can have a gate record and never have an
SPK, and the reverse.
_Avoid_: Gate Pass, Pos Jaga, Registrasi Kendaraan Masuk — there is no specific term on the floor, so
the application's own name is used.
Source: Q378.

**Pos** (Proses Kerja):
A production stage an SPK passes through — Registrasi, Bongkar, Las Ketok, Dempul & Surfacer,
Sanding/Masking, Cat, Poles, Pemasangan, Finishing, QC Final, and so on. The sequence and the
percentage weights **differ between bengkel**.
Movement between pos is **one-way**: an SPK cannot be returned to an earlier pos.
_Avoid_: Progress, Status SPK, Tahapan — "Progress" is used for something else (progress reporting to
the customer and to the insurer).
Source: Q387.

**Cetak SPK**:
The action that turns an SPK from a registration into production work. Before it is printed, an SPK
is not yet a job — and the majority of SPK ever created never reach this stage. Cetak SPK is also
the moment the promised date to the customer first comes into existence.
_Avoid_: Approve SPK, Aktivasi SPK.
Source: Q385, Q387.

**Selesai** (of an SPK):
The state where the work is complete and the vehicle **has left the bengkel**. Marked by the exit
date, **not** by the final pos — most vehicles leave while their pos still reads QC Final. A report
that measures "finished" from the pos will report less than a third of reality.
_Avoid_: using the pos "SELESAI" as the definition of finished.
Source: Q387.

**SPK Terlambat**:
An SPK that has passed **one calendar day** beyond the estimated completion **per pos**. Grouped as
H+1, H+2, H+3, and beyond H+3. Measured against the pos estimate, **not** against the promised date
to the customer, and counted only for ASM customers. It triggers no automatic action — the follow-up
is manual.
_Avoid_: treating it as the same thing as "late against the promise to the customer"; the two are
measured differently.
Source: Q386.

### Time

**Hari Kerja**:
Monday to Friday in full, **Saturday a half day (08:30–12:00)**, Sunday closed. Applies uniformly to
every bengkel. There is no second shift and overtime is not accounted for.
Source: Q365.

**Hari Libur**:
Dates excluded from the working-day calculation. In the new system the holiday list has **one single
source**, maintained by TEKNO itself.
_Avoid_: assuming national holidays are counted automatically — in the legacy the list stopped being
updated in 2018, so since then only Sundays have actually been excluded.
Source: Q364.

**Tanggal Janji Selesai**:
The estimated date the vehicle will be finished, as communicated to the customer. Comes into
existence at Cetak SPK. **Not a frozen commitment**: it is recalculated every time the vehicle moves
pos, and takes the furthest value across all open SPK for that vehicle at that bengkel. A customer
can find the date has changed without anyone having changed it.
_Avoid_: Deadline, Due Date, Janji Pengiriman — and do not call it a "commitment".
Source: Q385, Q386.

### Price and approval

**Pricelist**:
The official service price list per combination of damage category, vehicle type, panel type and
insurer. The pricelist price **always wins** over a price typed by an operator: where a pricelist
value exists, the manual entry is discarded without notice.
_Avoid_: Harga Standar, Master Harga, Tarif.
Source: Q396.

**Pengajuan Perubahan Harga**:
A formal request to use a price different from the pricelist on a service or spare-part line. Raised
by an operator, then approved or rejected. **The approval is performed by IT** — not because of an
authorisation rule, but because IT is simply who does it. Whatever business decision sits behind it
happens outside the system.
_Avoid_: Approval Harga, Request Harga, Override Harga.
Source: Q393, Q396.

### People and access

**Grup**:
A bundle of rights attached to a user. In practice **two different things live in one place**: some
express a job title (SA, Foreman, Kasir, Kepala Bengkel, Direktur Bengkel), while others merely mark
a single capability and grant no screen access at all (for example Pindah Bengkel, Cetak Surat
Keluar, Cek Titipan).
_Avoid_: Role, Peran — misleading, because half of them are not roles but capability flags.
Source: Q392.

**Hak Akses**:
A user's authority over a screen. Granted through a group **or** directly to the person, and **both
routes can only add** — there is no mechanism that revokes. In practice direct grants to individuals
are used far more than groups, so the effective model is a **per-person permission list**, not
role-based access.
_Avoid_: RBAC, Role-Based Access Control — naming it that in a document makes the reader assume a
role model that does not actually apply.
Source: Q391.

---

## Terms not yet locked

Recorded so they are not used as though settled. Each needs work-owner confirmation before being
promoted to the main section.

| Term | What is known | What is not |
|---|---|---|
| **OR** / **Nilai OR** | Appears in registration, in billing, and in the conditions for releasing a vehicle; the value can be overwritten from the insurance claim system | Its business definition, and **who owns the number authoritatively** — registration/estimate or e-Klaim |
| **PPB** | The purchase-request document that precedes a PO | Its definition and business boundary |
| **PO** | An order to a supplier | Same |
| **TCR** | The total-loss flow: estimate → approval → auction/salvage | What the acronym officially stands for, and its boundary against Bursa Mobil |
| **Lelang** | Disposal of a total-loss/salvage vehicle | Its relationship to TCR and Bursa Mobil |
| **TKU** | One of the three bengkel groups; also used for a used-spare-part marketplace | **Two different meanings share one name** — they need separating |
| **Bursa Mobil** | The used-car exchange | Who owns the process, and how it relates to TCR |
| **Bartender** | A role whose activity is recorded and approved separately | What the job actually is |
| **Foreman** | Used for two different things: a job title, and the person recorded as QC on a panel | Which one is meant in a reporting context |
| **Rawat Jalan (RJ)** | A repair flow where the vehicle does not stay overnight | The criteria for entering it |
| **Redo** | Rework after a failed QC | Who bears the cost |
| **Status Penyediaan Sparepart** | Determines how a spare part is sourced (new, economy, insurer supply, bengkel supply, transfer to procurement, mobility service) | Its canonical name, and why the name in the data is misleading |
| **Cabang TAP** | The destination code for spare-part procurement, **different** from a warehouse; has been misread as a warehouse | Its business definition and who owns it |
| **Gudang** | The storage destination for spare parts sent to the procurement system | Its ownership and scope |
| **Klaim** vs **Polis** vs **Case** | Three different identifiers attached to one SPK | The boundary and owner of each |

Note: `docs/STEERING.md` §4 contains an early glossary that has **not** been confirmed by the work
owner and was therefore not carried over here. Several of its entries were already shown to be wrong
during Phase 1–2 (among them the list of Lokasi Pengerjaan values and the meaning of pos `000`), so
copying it across as-is would have moved those errors into the document that is supposed to be the
reference.
