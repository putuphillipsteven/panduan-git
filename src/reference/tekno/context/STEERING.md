# TEKNO (e-BENGKEL) → Golang/PostgreSQL Migration — STEERING DOCUMENT

**Status:** Draft v1.1 for review — Phase 1 (Understanding) + Phase 2 (Deep Discovery) complete for the priority module; remaining modules understood at inventory level only (see §6, §21). **Revision note (v1.1):** database strategy revised — Oracle retained as the production database, with a PostgreSQL-portable SQL standard adopted so a future migration is low-effort (see §3.3, §18, and `docs/decision-log.md`).
**Amended:** v1.2, 28 August 2026 — amendments only; **no approved v1.1 content removed**. See §0 for the Amendment Register. Where this document and an ADR disagree, **the ADR applies**.
**Owner:** PT. Asuransi Sinar Mas — TEKNO migration project
**Prepared:** 2026-07-31
**Traceability:** every decision below is sourced from `docs/decision-log.md` (question asked → options → answer → decision). Every architectural/technical claim about the existing system is sourced from `docs/understanding-findings.md`, which is itself grounded in direct source-code reading and grep evidence gathered in this session — **not** from the pre-existing `analisis/` folder, which was found to rest on a missing reference document (`ANALISIS_PROJECT_TEKNO.md`) and is treated throughout as an unverified prior hypothesis set, not fact.

This document is the blueprint for the migration. It intentionally does not contain source code, API schemas, or database migration scripts — those come after this Steering is reviewed and approved, per the process this task was scoped to.


---

## 0. Revision v1.2 — Amendment Register *(28 August 2026)*

**Nothing approved in v1.1 has been deleted.** Every section below is intact. Where a decision taken
since has superseded a statement, an **⟢ AMENDMENT** block sits directly under that section heading,
stating what still stands, what changed, and the evidence. This register is the index to them.

**Why the amendments are inline rather than applied as edits.** Until the work owner approves a
rewrite, STEERING and the ADRs are allowed to disagree — and when they do, **the ADRs are what
applies**. Silently editing the approved text would erase the fact that a decision changed, and that
fact is often the most useful thing in the record.

| # | Section | What changed | Source |
|---|---|---|---|
| **A-01** | §1.1 | "5 branches" → **15 active bengkel**; the cutover unit is one bengkel | [ADR-0008](adr/0008-cutover-per-bengkel-lima-belas-unit.md) |
| **A-02** | §1.4 | The cited "§6.1" **does not exist**; the decision is **no pre-existence gate**, not a tightening — a gate would reject 16.58% of historical SPK | [ADR-0016](adr/0016-kendaraan-tidak-wajib-terdaftar.md) |
| **A-03** | §3.3 | No-stored-procedure rule is now **absolute**; both exceptions withdrawn. Verified inventory: 37 call sites / 34 objects | [ADR-0003](adr/0003-tanpa-pemanggilan-stored-procedure.md) |
| **A-04** | §4 | Glossary moved to **`CONTEXT.md`**; four entries here are wrong, and 15 terms are recorded as **not yet locked** | `CONTEXT.md`, [ADR-0018](adr/0018-penanda-selesai-adalah-tanggal-keluar.md) |
| **A-05** | §5 | Module boundaries follow the **legacy menu groups**, not these bounded contexts | [ADR-0022](adr/0022-batas-modul-mengikuti-menu-sistem-lama.md) |
| **A-06** | §6 | Modules 5–11 are **built**, not inventory-level; status vocabulary defined (`Selesai` / `Selesai*` / `Sebagian`) | Q397 |
| **A-07** | §7 | Cutover order **reversed** — largest bengkel first; a third precondition added per bengkel | [ADR-0008](adr/0008-cutover-per-bengkel-lima-belas-unit.md), [ADR-0004](adr/0004-logika-trigger-dipindah-ke-aplikasi.md) |
| **A-08** | §13 | The auditability requirement is **not met in four places, knowingly** | [ADR-0023](adr/0023-audit-trail-data-master-ditangguhkan.md), [ADR-0013](adr/0013-postur-otorisasi-legacy-direplikasi.md) |
| **A-09** | §15 | **The "must-fix, do not replicate" posture was not adopted.** Default is replicate; exactly **two** exceptions | [ADR-0013](adr/0013-postur-otorisasi-legacy-direplikasi.md), [ADR-0011](adr/0011-pengecualian-layar-administrasi-hak-akses.md), [ADR-0021](adr/0021-backdoor-login-tidak-diport-didokumentasikan-tersamar.md) |
| **A-10** | §18 | Two premises false (**504 PK / 37 triggers exist**; source **is** available); warehouse-map risk **withdrawn**; numbering has **two** sources | [ADR-0020](adr/0020-gudang-dan-cabang-pengadaan-dua-konsep.md), [ADR-0005](adr/0005-penomoran-spk-dua-sumber-gap-diterima.md) |
| **A-11** | §20 | The "one intentional change" is **not a change**; real coverage measured and materially thinner than "all tests pass" suggests | Q382, TKT-PRD-012 |
| **A-12** | §21 | Risk register: **3 closed, 1 downgraded, 1 confirmed, 8 added** | various |
| **A-13** | §22 | Scale figures corrected and **measured**, not estimated | counted 28 Aug 2026 |
| **A-22** | §20 | A replicated defect that writes a MONEY column is escalated, not quietly reproduced | Q436, Q437, TKT-PRD-043 |
| **A-23** | §11 | Fidelity covers HOW a request is sent; and "the legacy never writes X" can mean it INHERITS X from its platform | Q439, Q441, TKT-PRD-044/046 |
| **A-28** | §16 | A nil slice is `null` on the wire, not `[]` — and a throw during render blanks the WHOLE page, not one panel | Q451, TKT-PRD-050 |
| **A-27** | §14 | One legacy screen often reads SEVERAL tables in order, and the ORDER is the precedence — porting the first table alone silently empties the form | Q447, TKT-PRD-048 |
| **A-26** | §14 | `SUM()` with GROUP BY returns NO rows where a bare `SUM()` returns one NULL — legacy flow control often hangs on that | Q444, TKT-PGL-001 |
| **A-25** | §11 | The legacy leans on its platform's LENIENCY — wire shape, transport and decoder all differ in Go | Q434, Q441, Q443 |
| **A-24** | §16 | An error whose cause is dropped costs a second round of diagnosis; log the chain where it happens | Q442, TKT-PLT-001 |
| **A-20** | §11 | An integration contract is READ from the legacy's calling code and pinned by an httptest server; a stub cannot catch a wrong contract | Q434, [ADR-0041](adr/0041-kontrak-integrasi-dibaca-dari-sumber-bukan-ditebak.md) |
| **A-18** | §14 | A silent no-op is the worst refusal: an action that neither acts nor speaks reads as a broken screen | Q432, TKT-PNR-006 |
| **A-19** | §18 | A compiled report (`.rpt`) is unreadable — fix what is MEASURABLE and say what is not | Q430, TKT-PMB-003 |
| **A-17** | §11 | The envelope is not optional, it fails SILENTLY when bypassed, and only a handler-level test catches it | Q428, TKT-PRD-039 |
| **A-16** | §15 | A facsimile signature is printed on TWO documents, and only below the stamp-duty threshold; the only control over it is the menu grant, and that is now stated | Q426, Q427, [ADR-0040](adr/0040-tanda-tangan-tercetak-adalah-aset-yang-dipasang-per-dokumen.md) |
| **A-15** | §18 | A cursor column's NAME is not evidence of its SOURCE — export the procedure before mapping it | Q423, TKT-AR-005 |
| **A-14** | §6, §22 | **The percentage against the legacy system's total menu has never been counted and must not be estimated.** Only "complete out of what was scoped" can be stood behind today | `docs/ticketing/README.md` §6.2 |

### One conflict this document cannot resolve by itself

**The owning company is stated differently in two approved documents.** This STEERING (§Owner, §1.1)
and `CONTEXT.md` say **PT. Asuransi Sinar Mas**; the approved BRD v1.0 cover and §2 say **PT. Jakarta
Teknologi Utama Motor**. Both are plausible — an insurer and a workshop operator in the same group,
and the legacy source tree contains a `JTU_SRV_TERIMA_PART` integration folder consistent with the
second. **Not resolved here.** It affects document headers, report footers, and any tax identity, so
it needs a one-line answer from the work owner rather than a guess.
**BELUM DIPUTUSKAN — open question.** Owner: work owner.

---

## 1. Business Understanding

### 1.1 What TEKNO is

> ### ⟢ AMENDMENT A-01 — branch count *(v1.2, 28 Aug 2026)*
> **The approved text below stands as the July 2026 baseline and is not deleted.** It is superseded
> on one point of fact: **there are 15 active bengkel, not 5.** Master data shows fifteen active
> workshops across three name groups spread over five cities, and **all three groups are real
> workshops** — not accounting entities sharing a physical location. The five city names below remain
> correct as *cities*; they were mistaken for *branches*.
> **The cutover unit is one bengkel, so the plan is 15 events, not 5.**
> Source: `docs/decision-log.md` Q370 · [ADR-0008](adr/0008-cutover-per-bengkel-lima-belas-unit.md).
> The same correction applies to every other "5 branches" statement in this document (§3.3, §7.1,
> §7.2, §22 Scale) — see the Amendment Register, §0.

TEKNO (e-BENGKEL) is the operational system for PT. Asuransi Sinar Mas's network of vehicle body-repair workshops ("bengkel"), serving insurance-claim-driven repairs across (at least) 5 branch cities (Jakarta, Medan, Pekanbaru, Palembang, Surabaya — per prior BRD, not independently re-verified this session but consistent with the `M_PROF_BENGKEL`/`BENGKEL_ID` multi-branch pattern confirmed in code). It manages the complete lifecycle of a vehicle repair job from intake through delivery, plus several adjacent business lines.

### 1.2 Core business flow (verified from source)

```
KENDARAAN MASUK ──▶ REGISTRASI & SPK (Work Order) ──▶ PRODUKSI (multi-stage + QC)
                                                              │
                     ┌────────────────────────────────────────┤
                     ▼                                        ▼
              AUTO/MANUAL PO (Bahan/Sparepart)   HIT PROGRESS: ClaimQ / PEGA / (narrow) WA
                     │                                        │
              PENERIMAAN PART ◀── PO ke SUPPLIER               │
                     │                                        │
              PENGAMBILAN BAHAN (per SPK)                      │
                     └──────────────────┬─────────────────────┘
                                        ▼
                              TAGIHAN/OR (Finance)
                                        │
                                        ▼
                    PELUNASAN (termasuk Virtual Account)
                                        │
                                        ▼
                                 SETOR BANK
                                        │
                                        ▼
                          DELIVERY (Serah Kendaraan) ──▶ FOLLOW-UP CS
```

Parallel flow: **TCR/Total Loss** — estimasi kerusakan total → approval → lelang/salvage → journal posting. Also present: an internal used-parts marketplace (TKU), a used-car exchange (Bursa Mobil), and a General-Affairs internal-asset repair workflow, all sharing the same platform/database but functionally distinct from the core vehicle-repair business.

### 1.3 Business objectives for this migration (confirmed this session, §see decision log Q8-Q11, grilling)

1. Move all operational capability off unsupported ASP.NET Web Forms (.NET 2.0, VB.NET, no vendor support, no tests, no CI/CD) onto a modern, testable, maintainable Golang platform — retaining the existing Oracle database for now, but writing all SQL and data-access code to a PostgreSQL-portable standard so a future Oracle→PostgreSQL migration requires minimal change (§18).
2. Preserve business continuity — the legacy system remains the sole production system, unchanged, until the new system is fully built and validated (§7 Migration Strategy).
3. Close known technical-debt and security gaps rather than replicate them (§15).
4. Modernize the UI to a React SPA with a professional, modern look (§1.4, §3.5).
5. Right-size the architecture to the actual scale — 200-300 daily active users, on-premise deployment — avoiding both under-engineering (no tests, no structure — today's problem) and over-engineering (no microservices/Kubernetes/Vault at this scale — an equally real risk this Steering explicitly guards against per user decisions in §7 and §14).

### 1.4 Explicit non-goals

> ### ⟢ AMENDMENT A-02 — the "§6.1" that does not exist, and the decision it referred to *(v1.2)*
> **The approved text below stands.** Two corrections to it:
> 1. **There is no §6.1 in this document.** Three places (§1.4 below, §20, §21 risk #11) cite a
>    decision to "§6.1"; §6 is only the module table. Cite the ADR instead.
> 2. **The decision itself is the opposite of a tightening.** No Polisi and core vehicle data are
>    **mandatory to enter**, but there is **no gate requiring the plate to pre-exist** in the vehicle
>    master. The legacy gate is dead code. A hard gate would reject **41,353 of 249,448 SPK — 16.58%,
>    about one in six** of all historical work orders.
>    Source: Q381, Grill #2 · [ADR-0016](adr/0016-kendaraan-tidak-wajib-terdaftar.md).
>
> **Consequence for §1.4's count of exceptions:** the exceptions to "preserve as verified" are **not**
> the two named below. As of v1.2 there are exactly **two**, and they are different ones:
> [ADR-0011](adr/0011-pengecualian-layar-administrasi-hak-akses.md) (three access-rights admin
> screens) and [ADR-0021](adr/0021-backdoor-login-tidak-diport-didokumentasikan-tersamar.md) (the
> login bypass is not ported). **The blanket security must-fix framing in §15 is itself amended** —
> see A-08.

- This is a **reimplementation**, not a business-process **reengineering** — existing business rules are preserved unless a decision in this document explicitly says otherwise (two explicit exceptions exist so far: the "No Polisi wajib diisi" tightening in §6.1, and the security fixes in §15 — everything else is preserve-as-verified).
- The Classic ASP subsystem (`login.asp`, `menu*.asp`) is explicitly OUT of scope — confirmed orphaned, to be decommissioned, not ported (decision log Q15).
- Database topology re-architecture (per-branch split, multi-tenancy) is explicitly OUT of scope — one shared database is retained (decision log Q11). The database engine itself also remains Oracle, not migrated to PostgreSQL as part of this project (revised strategy — see §18).

---

## 2. Current Architecture (As-Is)

*(Full detail: `docs/understanding-findings.md`. Summary here for Steering completeness.)*

- **Stack:** ASP.NET Web Forms (VB.NET, .NET 2.0, Web Site model — no `.sln`/`.vbproj`, direct IIS deployment, no build system) + an orphaned Classic ASP predecessor still in the source tree. Oracle 10.2 database (schema `NEWBENGKEL` on instance `asmd`), plus direct connections to two *other* Oracle instances for other-insurer categories (`simasnet`, `syariah_s`). Mercurial VCS pointed at an internal server.
- **Scale:** ~766 `.aspx` pages + code-behind, a second parallel sub-application (`Teknobodyrepair/`, own config/bin, JSON API surface for external/customer-facing features), 23 `.ashx` JSON API handlers, 305 Crystal Reports, a single 9,723-line shared "God class" (`App_Code/General.vb`) that most pages inherit from or call into for cross-cutting logic (validation snippets, ~20 external-integration client code, formatting helpers).
- **No architectural layering**: no ORM, no service layer, no repository pattern — raw SQL and stored-procedure calls built ad hoc per page (`OracleCommand`, mostly direct string concatenation for regular SQL, more consistent bind-parameter use only in the newest code, e.g. the OCR/Google-Storage features).
- **No automated tests, no CI/CD** — deployment is manual (mechanism not confirmed from source; flagged as an open item if needed for cutover planning, not for the new system's own design).
- **Data access reality**: ~736 distinct stored-procedure/package-procedure names are called from the app, but only ~5.5% of them have any DDL/source present in this repository — most business logic (production state-machine transitions, complaints, payroll, and calls into two entirely separate Oracle schemas `BENGKEL`/`MBU`) lives **only** in the live Oracle database. **A fresh, complete live-database export is a hard prerequisite for detailed technical design of any module**, not just SPK/QC.
- **No schema constraints**: neither SQL dump in this repo has a single `PRIMARY KEY`, `FOREIGN KEY`, `CHECK` constraint, or trigger. All integrity is enforced in application/procedure code. Confirmed schema drift exists between checked-in DDL and the live DB (e.g. `M_USER.HASH_PASSWORD`, the entire RBAC table set have zero DDL in this repo).
- **Dual authentication**: ASP.NET (`Default.aspx`, DB-backed via `M_USER`, SHA-256 hashed) is live; Classic ASP (`login.asp`, hardcoded plaintext per-role credentials) is a confirmed orphaned island (decision log Q15) — zero inbound references from the live app.
- **Integration surface**: ClaimQ, ~15 ad hoc PEGA/HCC endpoints, a WhatsApp-Web-automation-style gateway (narrower live usage than previously assumed — CS-agent replies only), Journal Service (REST/JSON despite the "-WS" name, zero auth), Virtual Account (outbound creation + inbound webhook, zero auth on the webhook), plus several integrations not previously documented: SiCepat/PCP courier APIs, SimasPoin loyalty (sends KTP/PII, no auth), a BalaiLelang auction integration that runs inside an open DB transaction, and the app's own document-storage + LLM-OCR backend. **No integration anywhere implements retry logic; all are synchronous/blocking; auth conventions are inconsistent (5+ different hardcoded credential pairs, several endpoints with zero auth at all).**

---

## 3. Future Architecture (To-Be)

### 3.1 High-level shape

```
┌─────────────────────────┐        REST/JSON        ┌──────────────────────────────┐
│   React SPA (Vite, TS)  │◀────────────────────────▶│  Golang API — modular monolith│
│   Ant Design/shadcn UI  │                          │  (single deployable binary)   │
└─────────────────────────┘                          └───────────────┬───────────────┘
                                                                      │
                                    ┌─────────────────────────────────┼───────────────────────┐
                                    ▼                                 ▼                        ▼
                          ┌──────────────────┐            ┌──────────────────┐    ┌───────────────────────┐
                          │   Oracle (kept)   │            │ External adapters │    │ Internal scheduler    │
                          │ single shared DB, │            │ (ClaimQ, PEGA/HCC,│    │ (replaces "URL-ping"  │
                          │ BENGKEL_ID filter,│            │ WA, GL, VA, ...)  │    │ JOB_* pattern)        │
                          │ Postgres-portable │            │                   │    │                       │
                          │ SQL style         │            │                   │    │                       │
                          └──────────────────┘            └──────────────────┘    └───────────────────────┘
```

### 3.2 Backend: modular monolith (decision log Q9)

One Go binary/deployable, internally partitioned by domain module (see §6 for the module list). No service mesh, no distributed tracing/service-discovery infrastructure — unjustified at 200-300 DAU. Internal module boundaries are enforced by Go package structure and internal interfaces (see §12 Folder Structure), not by network calls — this keeps the modular-monolith honest (modules can be split into real services later if genuinely needed, without having paid microservices operational tax today).

### 3.3 Database: Oracle retained, written to a PostgreSQL-portable standard (decision log Q11 topology + revision)

> ### ⟢ AMENDMENT A-03 — the no-stored-procedure rule is now absolute *(v1.2)*
> **The approved text below stands and is strengthened.** Where it says "no direct application-level
> reliance", the rule is now **no calls at all, with no exceptions**. The two exceptions this document
> and its ADR predecessors granted (the estimate formula and the payroll package) are **withdrawn**;
> both are rewritten in Go.
> Source: Q375 (W-44) · [ADR-0003](adr/0003-tanpa-pemanggilan-stored-procedure.md).
>
> **The scale of the task is far smaller than §21 risk #1 assumed** — see A-11. Verified inventory:
> **37 call sites across 34 procedures/functions/packages**, and **every object in scope is present in
> `ALL_SOURCE`** on the live database. The "only ~5.5% have source" figure counted what was checked
> into the repository, not what is readable from the database.
>
> **Database links remain permitted** (§18.1) and are unaffected: permitting a link says nothing about
> procedures. Two later decisions apply the link rule concretely —
> [ADR-0034](adr/0034-sumbis-memilih-link-dari-instance-tekno.md) (an insurer-group selector chooses a
> link suffix, never a second connection).

The database technology target for this migration has been revised: **the new Golang system keeps the existing Oracle database** (single shared instance serving all 5 branches, `bengkel_id` retained as a plain discriminator/filter column — not a routing key, not a basis for schema-per-tenant, directly continuing the pattern already proven in the legacy system). PostgreSQL is **not** adopted as part of this migration.

However, every SQL statement and data-access pattern written for this project must follow a **PostgreSQL-friendly, portable style**, so that a future Oracle→PostgreSQL migration requires minimal change:

- **No direct application-level reliance on Oracle stored procedures or packages.** Business logic that would traditionally live in a `PROCEDURE`/`PACKAGE` (as ~540+ of them do in the legacy system) must instead be written or declared in the Golang application layer (service/repository code) — the database is used for storage and querying, not for hosting business logic that has no direct PostgreSQL equivalent.
- **Avoid Oracle-specific SQL dialect features when a portable, ANSI-SQL alternative exists** — e.g. `COALESCE` instead of `NVL`, `CASE WHEN` instead of `DECODE`, ANSI `JOIN` syntax instead of the `(+)` outer-join operator, `OFFSET`/`FETCH FIRST n ROWS ONLY` instead of `ROWNUM`-based pagination, standard recursive `WITH` CTEs instead of `CONNECT BY` where feasible.
- **Oracle DATABASE LINKs are PERMITTED** where the legacy system already depends on one to reach another instance (see §18.1 for the rule and its rationale). This is the one deliberate exception to "prefer the portable construct": some business data simply does not live in this database, and the legacy reaches it by link.
- All guidance in §8 (Technical Strategy), §18 (Database Strategy), and §20 (Testing Strategy) reflects this Oracle-now/PostgreSQL-portable-later approach — see those sections for the concrete implications (driver choice, migration tooling, type/DDL guidance, testing target).

### 3.4 API: REST/JSON

REST chosen over gRPC — the only consumer is the React SPA (no inter-service calls exist in a modular monolith, so gRPC's main benefit — efficient service-to-service contracts — doesn't apply here). See §11.

### 3.5 Frontend: React SPA (decision log Q7)

React 18+, Vite, TypeScript, a mature admin-UI component library (Ant Design or shadcn/ui+Tailwind — final pick deferred to technical design/prototyping), talking to the Go API over REST. No SSR framework (Next.js/Nuxt rejected — TEKNO is 100% behind authentication with no public/SEO-sensitive pages, so SSR would add real operational complexity — hydration, server runtime, edge/node deployment model — for no benefit). Full comparative analysis is in this session's working notes; headline reasoning: React's ecosystem (Ant Design/MUI/shadcn, TanStack Table/Query, React Hook Form) has the deepest set of production-grade building blocks for exactly this kind of CRUD/grid/report-heavy application, and the largest hiring pool in Indonesia — weighed by the user as more important than Vue's gentler learning curve, given the explicit requirement for a modern, professional result.

### 3.6 Deployment topology: on-premise, Docker Compose/systemd, no Kubernetes (decision log Q12-Q14)

On-premise Sinar Mas data center (consistent with existing internal-IP-based integrations — no VPN/private-link redesign needed). No pre-existing container-orchestration standard, so Steering recommends Docker containers managed via Docker Compose/systemd on a small VM set — proportional to scale, avoids the operational tax of a Kubernetes cluster (control plane, ingress, cert management, etc.) that 200-300 DAU does not justify. This can evolve to Kubernetes later if Sinar Mas standardizes on it more broadly — the Go binary/Docker image itself does not need to change for that migration path.

### 3.7 Scheduling: real internal scheduler replaces "URL-ping" pattern

The legacy `JOB_AUTOPO`/`JOB_SEND_WA`/`JOB_GET_REPLY_WA`/`JOB_KIRIM_EMAIL` pattern (a page that runs a batch action in `Page_Load` when hit by an unknown external trigger, confirmed via source to have zero internal Global.asax scheduling) is replaced by a proper in-process Go scheduler (e.g. a cron-like library or a lightweight internal job runner) with explicit, versioned schedules — no dependency on an external, undocumented Windows Task Scheduler trigger. The corresponding legacy queue tables (`INBOX_AUTOPO`, `t_tekno_send_wa`, `T_TEKNO_SEND_EMAIL`) map directly onto equivalent job-queue tables in the retained Oracle database, defined and queried using the same PostgreSQL-portable SQL style described in §3.3/§18 so they carry over cleanly whenever the database itself eventually migrates.

---

## 4. Domain Model (initial glossary — to be deepened via `/domain-modeling` during technical design)

> ### ⟢ AMENDMENT A-04 — the glossary moved to `CONTEXT.md`, and four entries below are wrong *(v1.2)*
> **The table below stands as the July 2026 draft.** The **authoritative glossary is now
> [`CONTEXT.md`](../CONTEXT.md)** at the repository root: 17 terms locked with work-owner confirmation
> and a `Qnn` source each, plus **15 terms explicitly recorded as not yet locked** rather than being
> given a plausible definition. Where the two disagree, `CONTEXT.md` applies.
>
> Four corrections to the entries below, each with evidence:
>
> | Entry | Says below | Verified |
> |---|---|---|
> | `PROSES_ID` `000` | "not yet printed" | **`REGISTRASI`.** It means an SPK that was **never printed** — 206,784 of 206,790 rows have no print date and **none** has a departure date. Codes `002`–`006` are all confirmed (Q376, Q387) |
> | `PROSES_ID` `010` | "SELESAI/closed" | It exists, but it is **not a reliable completion marker**: of vehicles that actually left, 21,687 were still at `009` and only 8,188 at `010` — **`010` captures about 27%**. The reliable marker is the departure date ([ADR-0018](adr/0018-penanda-selesai-adalah-tanggal-keluar.md)) |
> | `STS_VIP` "values `6`,`7`,`9`,`G`,`M`" | five values | **14 values** in the authoritative location master. `M` = **Mobility Service** (not TransJakarta); code `8` = Tata Puminar was in no document at all |
> | Term set | 17 terms | `CONTEXT.md` also records **OR, PPB, PO, TCR, Lelang, TKU, Bursa Mobil, Bartender, Foreman, RJ, Redo, Cabang TAP, Gudang, sparepart-sourcing status, and Klaim/Polis/Case as NOT YET LOCKED** — the definitions below for several of them are drafts, not confirmed business definitions |
>
> The `STS_VIP` collision the text below flags is **confirmed and quantified**: 10,185 rows carry a
> location code that is displayed as a VIP flag. It is not yet decided whether the new system splits
> the display (TKT-PRD-020, awaiting the work owner).

| Term (Indonesian, as used in the live system — preserved, not translated) | Meaning |
|---|---|
| **SPK** (Surat Perintah Kerja) | Work Order — the central transaction record for one vehicle repair job. Root DB entity `T_SPK`. |
| **Bengkel** | Workshop/branch. `BENGKEL_ID` — a filter/discriminator column throughout, not a routing key. |
| **Proses** / `PROSES_ID` | Production stage. Verified live codes: `000`=not yet printed, `001`=BONGKAR, `007`=PEMASANGAN, `008`=FINISHING, `009`=QC FINAL, `010`=SELESAI/closed, `021`=BUBUT (treated as equivalent to "dempul"/filler for insurer-status mapping purposes). Codes `002`-`006` exist in the live system but their full names could only be confirmed from the live Oracle `M_PROSES_KERJA` table, not from the stale seed data checked into this repo. |
| **OR** (Official Receipt) | The customer/insurer invoice = total jasa (services) + total sparepart, minus "Nilai OR" (deductible) per specific business rules found in `General.vb`. |
| **PPB** | Permintaan Pembelian Bahan/Sparepart — the internal purchase-request document that precedes a PO. |
| **PO** | Purchase Order to a supplier. |
| **TCR** | Total Constructive Loss — the total-loss claim workflow (estimate → approval → auction/salvage). |
| **Lelang** | Auction — disposal of a total-loss/salvage vehicle. |
| **HASIL_QC** | QC outcome flag: `1`=pass, `0`=fail, null=pending. |
| **Bartender** | A specialized personnel role (paint-mixing-adjacent) whose activity/time log is tracked separately from per-panel mechanic assignment (`T_AKT_BARTENDER`, approved by an "Atasan"/superior). |
| **Foreman** | In the dashboard/reporting sense, whoever is recorded as `MEKANIK_QC` on a panel/jasa assignment — distinct from the actual working mechanic (`MEKANIK_AWAL`). |
| **TKU** | An internal used-sparepart e-commerce/marketplace sub-domain, sharing the platform but functionally distinct. |
| **Bursa Mobil** | Used-car exchange, tied to TCR/salvage disposal. |
| **STS_EKONOMIS** | Sparepart sourcing-classification code (not "economical vs non-economical" as the name suggests) — governs whether/how a sparepart line is auto-ordered. |
| **No Polisi** | Vehicle plate number — the primary natural key used across SPK/vehicle/customer lookups. |

**Overloaded/collision terms flagged for the domain model to resolve explicitly** (do not carry the collision into Postgres column naming): `STS_VIP` on `T_SPK` is simultaneously used as a genuine VIP boolean (on `M_CLIENT`) and as a "Lokasi Pengerjaan" location-selector code (values `6`,`7`,`9`,`G`,`M`) on `T_SPK` — these must become two distinct, named Postgres columns.

---

## 5. Bounded Contexts

> ### ⟢ AMENDMENT A-05 — module boundaries follow the legacy menu, not these bounded contexts *(v1.2)*
> **The nine contexts below stand as the domain analysis.** They are **no longer the module boundary**.
> The boundary that was built and shipped follows the **legacy system's own menu groups**, because
> that is the boundary users, access rights, and every analysis document already speak in.
> Source: [ADR-0022](adr/0022-batas-modul-mengikuti-menu-sistem-lama.md).
>
> The as-built module set is 14 business groups plus one infrastructure package:
> `production` · `masterdata` · `penerimaan` · `pembelian` · `pengeluaran` · `distribusi` · `ar` ·
> `ap` · `kasbank` · `laporan` · `utility` · `emonitoring` · `dashboard` · `spk` *(empty — see A-13)*
> · `platform` *(infrastructure)*.
> Current status per module: [`docs/ticketing/README.md`](ticketing/README.md) §2.
>
> Reporting (context 7) is **in active scope and built**, as the revision note below already records.

Derived from the verified module inventory (§6) and integration map, grouped so that each context owns its core data and exposes explicit contracts to the others — this is the modular-monolith's internal module boundary, not a microservice boundary:

1. **SPK & Production/QC** (priority context — deeply verified this session) — work-order lifecycle, multi-stage production tracking, mechanic/Bartender assignment, ClaimQ/PEGA/QC integration hooks.
2. **Procurement (Sparepart/Bahan/PO)** — auto/manual PO, goods receipt, stock, the (currently three, mutually-inconsistent — see §21 open items) branch↔warehouse mapping.
3. **Finance** — OR/billing, settlement (incl. Virtual Account), bank deposit/reconciliation, journal posting to the external GL service. *(Not yet deep-verified from source — inventory level only, §21.)*
4. **TCR / Salvage / Lelang (Total Loss)** — estimation, approval, auction, disposal, journal posting. *(Inventory level only.)*
5. **Customer Service** — complaint intake/tracking (per production stage), follow-up, online tracking (customer-facing, currently unauthenticated — see §15). *(Inventory level only.)*
6. **Master Data** — vehicles, clients, suppliers, insurers, materials, services, panels, users/RBAC. Cross-cutting; every other context depends on it.
7. **Reporting** — the Crystal Reports replacement (§10, §21). **Now in active scope** (revision, Session 20 — decision log Q137): the new system generates its own report/export files, reproducing the legacy layouts rather than deferring them. The column set and order of each report come from the checked-in dataset definition the legacy `.rpt` binds to (`App_Code/*.xsd`) — the one machine-readable record of a report's structure that survives without the Crystal designer, exactly the reconstruction route §21 risk #6 anticipated. Reports are produced per-module by the module that owns the data, using one shared writer in `internal/platform/report`.
8. **Auxiliary marketplaces** — TKU (used-parts e-commerce), Bursa Mobil (used-car exchange), General-Affairs asset repair — smaller, more self-contained contexts; lower priority.
9. **Integrations** — a dedicated context/package for all external adapters (ClaimQ, PEGA/HCC, WhatsApp, Journal Service, VA, SMTP, courier APIs, SimasPoin, document/OCR backend) — centralizing what is currently ~9 duplicated hand-rolled HTTP client implementations scattered through `General.vb` into one consistent, testable client layer per integration.

---

## 6. Module Breakdown & migration order

> ### ⟢ AMENDMENT A-06 — modules 5–11 are no longer "inventory level"; they are built *(v1.2)*
> **The table below stands as the July 2026 assessment and is now out of date in the project's
> favour.** The deferral it describes did not persist: modules 5–11 were built in subsequent sprints.
>
> **As-built status, and the vocabulary it uses** (work-owner definition, Q397 — use these words
> exactly, they are not interchangeable):
>
> | Status | Meaning | Modules |
> |---|---|---|
> | **Selesai** | Implemented **and** through UAT | `production/spkreg` — **the only one** |
> | **Selesai\*** | Read path verified; **write path never executed in any environment** | penerimaan, ar, ap, pengeluaran, pembelian, kasbank, distribusi, laporan, utility, emonitoring, dashboard |
> | **Sebagian** | Some screens only; code exists, UAT incomplete | `production` (other than spkreg), `masterdata` |
>
> **The asterisk is discipline, not neglect.** The write path has not been executed because the work
> owner's own safety rule forbids write/delete operations during construction. But the consequence is
> real: **code that has never been run is not proven code**, however well it reads. The single gate
> that opens all eleven is **TKT-LTS-014** (permission to test writes on DEV).
>
> **Two numbers must always be presented together** when this status reaches management: "complete out
> of what was scoped" and "complete out of the legacy system's total menu" are very different figures,
> and presenting only the second misleads. The second **has never been counted in a way that can be
> evidenced and must not be estimated** — see A-14.

| # | Module (maps to §5 bounded context) | Verification depth this session | Migration order |
|---|---|---|---|
| 1 | SPK (Work Order) | **Deep** — real file identified (`T_SPK_maintenance.aspx.vb`), fields/validations/save-order/numbering/state model fully mapped | **First** (decision log Q10) |
| 2 | Production/QC | **Deep** — real file identified (`T_Input_QC_MB.aspx.vb`), stage codes, sequencing enforcement, PASS/FAIL, integration hooks fully mapped | **First**, alongside SPK |
| 3 | Mechanic/Bartender assignment | Deep (sub-dive) — `INPUT_PANEL_LARIAN.aspx.vb`, `input_aktivitas_bartender.aspx.vb`, `Approval_Atasan_Bartender.aspx.vb` | With SPK/QC |
| 4 | Auto/Manual PO | Deep (sub-dive) — 3 coexisting subsystems identified (legacy PPB-based, buffer/threshold-based, dead SPK-sparepart-auto-order) | With SPK/QC (Auto-PO feeds directly off production/procurement) |
| 5 | Procurement/Sparepart/Bahan (broader) | Inventory-level | Second wave |
| 6 | Finance/OR/Settlement | Inventory-level | Second wave |
| 7 | TCR/Salvage/Lelang | Inventory-level | Third wave |
| 8 | Customer Service | Inventory-level | Third wave |
| 9 | Master Data | Inventory-level (cross-cutting — needed early in practice even though not "first" as a user-facing module) | Alongside first wave, as a shared foundation |
| 10 | Reporting | Inventory-level; Crystal Reports replacement strategy defined in principle (§10) | Ongoing, per-module as each module's reports are needed |
| 11 | TKU / Bursa Mobil / GA-asset-repair | Inventory-level | Last wave (lowest business criticality of the identified modules) |

Per decision log: modules 5-11 require their own deep-dive (same rigor as modules 1-4) **before their detailed technical design begins** — this Steering explicitly does not claim they're understood to implementation-ready depth yet, and this is an accepted, deliberate trade-off (decision log, understanding-phase checkpoint), not an oversight.

---

## 7. Migration Strategy

> ### ⟢ AMENDMENT A-07 — cutover order reversed, and one precondition added *(v1.2)*
> **The strategy below stands. Two changes of fact:**
>
> 1. **The unit is one bengkel, and there are 15 of them** (A-01), so the rollout is 15 events.
> 2. **The order is reversed: the FIRST bengkel is the LARGEST, in Jakarta** — not the smallest as
>    §7.2 and §19 propose. The contradiction was surfaced when the decision was taken and the work
>    owner confirmed it. The reason: that bengkel is the **only one with a complete production-stage
>    master**, which makes it the most ready in data terms.
>    Consequence to plan for: the highest volume and widest case variety land in the **first** wave,
>    so the rollback plan and stabilisation period must be sized for that load, not the average.
>    Source: Q370 · [ADR-0008](adr/0008-cutover-per-bengkel-lima-belas-unit.md).
>
> **A third precondition now applies per bengkel**, and it is not optional:
>
> | # | Precondition | Ticket |
> |---|---|---|
> | 1 | That bengkel's production-stage master is populated — **13 of 15 are still empty** | TKT-LTS-012 |
> | 2 | That bengkel has a warehouse mapping; unmapped is **rejected**, never defaulted | TKT-PRD-004 |
> | 3 | **The legacy must not be running on that bengkel at the same time** | TKT-LTS-008 |
>
> Precondition 3 is a direct consequence of moving the triggers into the application
> ([ADR-0004](adr/0004-logika-trigger-dipindah-ke-aplikasi.md)): while a trigger is still enabled in
> the database and the same logic already runs in Go, **every write is subject to that logic twice**.
> Because cutover is per bengkel, a period in which both systems are alive **will happen** — what must
> not happen is both touching the same bengkel.
>
> §7.4 (version control) is **now confirmed, no longer awaiting confirmation** — see A-12.

1. **Build phase**: every Golang module is built and validated against the legacy system's actual behavior (characterization-tested, §16) while the legacy ASP.NET + orphaned Classic ASP system remains the sole, unmodified production system for all 5 branches. No dual-system data synchronization is designed for this phase, because nothing is live yet.
2. **Cutover phase**: once all modules are built and validated, cutover is rolled out **branch-by-branch**, not as one simultaneous 5-branch event — starting with the smallest/lowest-risk branch, monitored for an agreed stabilization period, before proceeding to the remaining branches (refined via `/grilling`, decision log Grill #1 — supersedes a plain "single simultaneous cutover" framing while preserving the "everything built first" principle).
3. Because a branch is always wholly on one system or the other at any point in time, there is no need for real-time data synchronization between old and new systems for the same business entity — this is the key structural benefit of choosing branch-by-branch (not module-by-module) as the cutover unit.
4. Version control: this project's CI/CD target (GitLab CI, decision log Q14) implies migrating source control from the current Mercurial repository to Git/GitLab as an explicit, early technical-strategy task — **flagged for explicit confirmation**, since it was a derived implication rather than a directly-asked decision.
5. Priority module (SPK+Production/QC, §6) is the first to go through full technical design, build, and characterization testing — chosen deliberately as the most business-critical and most externally-integrated module, accepting the trade-off that this is also the highest-complexity starting point (a conscious choice, confirmed twice this session, not a naive default).

---

## 8. Technical Strategy

- **Language/runtime:** Go (version per team standard at implementation time — recommend latest stable Go 1.2x).
- **Database driver/ORM:** database remains Oracle (§3.3), accessed via a Go Oracle driver (e.g. `godror`/ODPI-C or `go-ora`) through the standard `database/sql` interface — but all queries are written in the PostgreSQL-portable style defined in §3.3 (no procedure/package calls, no Oracle-only SQL dialect features where a portable alternative exists), using a lightweight query builder or `sqlc`-style typed-query generation over a heavyweight ORM. This preserves SQL transparency (important given how much undocumented business logic lives in query predicates today) while gaining compile-time safety Go didn't have in the VB.NET raw-SQL-string world, and keeps a future swap to a Postgres driver a driver-layer change only, not a query-rewrite exercise.
- **Migrations:** a real migration tool that supports both Oracle and PostgreSQL dialects (e.g. `atlas`, or hand-written versioned SQL run through `golang-migrate` with an Oracle driver) — replacing the legacy's "manual DBA script run directly against production" process (a real fact confirmed via the prior interview record, not re-verified this session, but consistent with the total absence of schema-versioning artifacts anywhere in this repo). Migration DDL itself should stick to portable, ANSI-standard constructs wherever Oracle offers one, reserving Oracle-only syntax for cases with no practical portable equivalent.
- **Transactions:** every multi-statement business operation (e.g. SPK save, QC save) must be wrapped in a single DB transaction with proper rollback — directly closing a confirmed, real gap in the legacy system (SPK save today runs as a chain of independently auto-committing statements across two separate connection objects, per `docs/understanding-findings.md` §5).
- **Integrations layer:** one consistent HTTP client abstraction (timeout, retry-with-backoff, structured logging of request/response, circuit breaking for known-flaky endpoints) shared by every external adapter — replacing the ~9 duplicated, inconsistent hand-rolled HTTP helpers found in `General.vb`. Every integration gets an explicit success/failure contract normalized to one convention (the legacy system has at least two **inverted** conventions across ClaimQ vs. PEGA — this must not be replicated as ambiguous "1 means success, except when it doesn't").

---

## 9. Coding Standards (baseline — to be expanded into a full style guide during technical design)

- Standard Go conventions (`gofmt`/`golangci-lint` enforced in CI), table-driven tests, explicit error wrapping (`fmt.Errorf("...: %w", err)`) rather than the legacy pattern of swallowing/`Response.Write`-ing errors from deep inside shared utility code.
- No business logic embedded in HTTP handlers — handlers parse/validate input, call a domain-module service function, map the result to a response. This is the direct structural fix for the legacy's core problem (business logic scattered across 775 code-behind files and one 9,723-line shared class with `Inherits System.Web.UI.Page`, making it untestable outside a live web request).
- Domain-module boundaries are real Go package boundaries — a module's internal tables/types are not imported directly by another module; cross-module calls go through an explicit exported interface (this is what makes the "modular" half of "modular monolith" real rather than nominal).
- **SQL writing standard (revised): every SQL statement in the codebase must be written in a PostgreSQL-portable style, even though the database is Oracle today** (§3.3/§18) — no calls to Oracle stored procedures/packages as part of application design; no Oracle-only dialect features (`NVL`, `DECODE`, `(+)` outer joins, `ROWNUM` pagination, `CONNECT BY`, etc.) where a portable ANSI-SQL equivalent exists; business logic normally placed in a PL/SQL procedure/package is instead written directly in Go service/repository code. This is enforced the same way other coding standards are — code review + (where practical) lint/static-analysis checks for the disallowed patterns.

---

## 10. Folder Structure (proposed, Go backend)

```
/cmd
  /api            — main entrypoint(s)
/internal
  /spk            — SPK bounded context (domain, service, repository, handlers)
  /production     — Production/QC bounded context
  /procurement    — Sparepart/Bahan/PO
  /finance        — OR/Settlement/VA
  /tcr            — Total Loss/Salvage/Lelang
  /customerservice
  /masterdata     — Vehicles, Clients, Suppliers, Insurers, Materials, Services, Users/RBAC
  /reporting      — PDF generation replacing Crystal Reports
  /integrations   — ClaimQ, PEGA/HCC, WhatsApp, JournalService, VA, SMTP, courier, SimasPoin, OCR — one subpackage each, one shared HTTP client core
  /scheduler      — replaces the JOB_* URL-ping pattern
  /platform       — cross-cutting: config, logging, db connection pool, auth middleware
/migrations       — versioned SQL migrations (golang-migrate/atlas/goose)
/web              — React SPA (Vite, TypeScript) — separate deployable, own folder structure per standard React/Vite conventions (feature-folders mirroring the backend's bounded contexts where practical)
```

---

## 11. API Strategy

- REST/JSON, versioned via URL path (`/api/v1/...`) from day one — the legacy system has no API versioning concept at all, a gap not worth repeating.
- Every endpoint requires authentication (JWT or session-token, to be finalized in technical design) — directly closing the confirmed finding that 20 of 23 legacy `.ashx` handlers (87%) have zero access control today.
- Consistent envelope for success/error responses (explicit status/error-code fields) — replacing the legacy's ad hoc mix of raw exceptions, silent failures, and inconsistent JSON shapes per handler.
- Customer-facing endpoints (Online Tracking — currently unauthenticated in the legacy system) get real, if lightweight, authentication (e.g. signed token tied to No Polisi/No HP lookup) — this is a deliberate security improvement over the legacy behavior, consistent with §15.

> ### ⟢ AMENDMENT A-17 — the envelope is not optional, and bypassing it fails silently *(v1.2)*
> **Added, nothing withdrawn.** The bullet above ("consistent envelope") states the intent. What it
> does not state is the FAILURE MODE, which cost a whole screen: one module wrote its payload through
> a local helper instead of `httpserver.WriteJSON`, so its responses arrived without the `data` key.
>
> **Nothing errors when that happens.** The status is 200, the body is valid JSON, the server logs
> are clean. The browser client returns `body.data`, which is `undefined`, and the failure only
> appears one line later as a TypeError in the caller — which, not being an `ApiError`, lands in
> whatever catch-all message that screen happens to have. SPK OCR reported it as *"periksa koneksi ke
> server"* and as a button that could never enable; the SQL, the repository and the service were
> correct the entire time (Q428).
>
> **Three rules follow.**
>
> 1. **Every handler answers through `httpserver.WriteJSON` / `httpserver.WriteError`.** A
>    module-local JSON writer is a defect, not a style choice.
> 2. **A service test cannot catch this** — the service was right. Any module whose wire shape matters
>    gets a handler-level test with `httptest` asserting the payload is reachable at `data.…`, as
>    `internal/production/spkocr/handler_test.go` now does.
> 3. **Grep is the cheap audit**: a `func writeJSON` or a bare `json.NewEncoder(w)` inside
>    `internal/**/handler*.go` is the shape to look for. That audit was run when this was found and
>    returned three modules: `spkocr` (fixed, Q428), `spkreg` (SAFE — its local `writeJSON` delegates
>    to `httpserver.WriteJSON`, and its comment records that this same bug was caught there once
>    before, blanking every dropdown on the registration page), and **`production/mixing`, which has
>    the defect and is NOT yet fixed** — out of the scope that found it, tracked as TKT-PRD-040.

---

## 12. Error Handling

- Structured, typed errors at the domain layer (e.g. `ErrVehicleNotRegistered`, `ErrSequenceViolation`) mapped to consistent HTTP status codes at the handler layer — replacing the legacy's mix of try/catch-and-alert, silent empty catches, and `Throw ex` (which discards stack traces).
- External-integration failures must **not** silently block core business flow by default — e.g. a failed WhatsApp notification must not prevent a QC save from completing (directly fixing the legacy pattern where a ClaimQ failure rolls back the entire QC-save transaction, per §2/`understanding-findings.md` §6). The design should distinguish integrations that are legitimately business-critical-and-blocking (e.g. GL journal posting for financial integrity) from those that should degrade gracefully with a retry queue (e.g. WhatsApp, courier tracking-number generation) — this distinction must be made explicitly per integration during technical design, not defaulted uniformly either way.

---

## 13. Logging

> ### ⟢ AMENDMENT A-08 — the auditability requirement is NOT met, knowingly *(v1.2)*
> **The requirement below stands as the target.** It is **not met today**, and that is a recorded
> decision rather than an oversight. Stating the target without stating the gap would misrepresent the
> system to anyone relying on this document.
>
> | Where auditability is absent | Status |
> |---|---|
> | Master-data changes | **Deferred** by decision — [ADR-0023](adr/0023-audit-trail-data-master-ditangguhkan.md) |
> | Branch switching by an administrator | **Not added** by decision — Q372 |
> | Credential lifecycle (IT changes passwords directly in the database) | **No trace by design** — [ADR-0012](adr/0012-siklus-hidup-kredensial-dikelola-it.md) |
> | Save failures on the registration screen | **Nothing is recorded anywhere** — TKT-PRD-022, awaiting decision |
>
> **One exception is enforced:** changes to access rights themselves are recorded — who changed what,
> when ([ADR-0011](adr/0011-pengecualian-layar-administrasi-hak-akses.md), TKT-LTS-011).
>
> There is also a **coverage hole inherited from the legacy** that this section should name: activity
> logging lives inside the gated master page, so the **252 pages that do not use it are not logged at
> all**. A screen with zero log rows may be unused — or may simply be one of those 252. Never conclude
> "unused" from an empty log without checking which (TKT-LTS-017).

- Structured logging (e.g. `slog` or `zerolog`) with request-correlation IDs, replacing the legacy's inconsistent `Response.Write`-based error display and the single `insertlogactivity` activity-log table (page name, IP, browser/OS — worth preserving as a feature, just implemented properly).
- No pre-existing enterprise logging/observability standard to conform to (decision log Q13) — recommend a proportional self-hosted stack (structured JSON logs shipped to a lightweight aggregator, e.g. Loki, plus Prometheus/Grafana for metrics) sized for 200-300 DAU, not an enterprise-scale SIEM.
- Auditability requirement (per business objectives, §1.3): every critical action (approval, production-status change, financial transaction) must be logged with enough detail to reconstruct "who did what when" — a real improvement over the legacy system, which only logs login/page-hit activity today, not business-state changes.

---

## 14. Configuration

- Environment variables / an encrypted config file mounted at deploy time (decision log Q17) — no new secrets-management tool (Vault/SOPS) introduced at this scale. This replaces `TeknoLib.dll`'s closed, reflection-based connection-string-decrypt mechanism with something the whole team can read and reason about directly.
- Per-environment config (dev/test/prod) via distinct config files/env-var sets — replacing the legacy's "comment out one URL literal, uncomment another" pattern for switching ClaimQ/PEGA/WhatsApp endpoints between environments, which is a real, current source-control footgun (a wrong commit can silently point production at a test endpoint).

---

## 15. Security

> ### ⟢ AMENDMENT A-09 — the "must-fix, do not replicate" posture was NOT adopted *(v1.2)*
> **This is the largest divergence between this document and what was decided and built. The table
> below is not deleted — it remains the security assessment, and every finding in it is real.** What
> changed is the *disposition*: the project's default became **replicate the legacy authorization
> posture as it is**, including the places where authorization is in fact absent.
> Source: Q372, Q386, Q394 · [ADR-0013](adr/0013-postur-otorisasi-legacy-direplikasi.md),
> [ADR-0014](adr/0014-replikasi-perilaku-termasuk-kontrol-yang-diam.md).
>
> **Exactly two exceptions were granted, and no others:**
>
> | Exception | What it covers | ADR |
> |---|---|---|
> | 1 | The **three access-rights administration screens** must sit behind a session and a rights check, and record who changed what — the one place the legacy posture is deliberately not copied | [ADR-0011](adr/0011-pengecualian-layar-administrasi-hak-akses.md) |
> | 2 | The **login bypass is not ported**, and its value is never written into any committed document | [ADR-0021](adr/0021-backdoor-login-tidak-diport-didokumentasikan-tersamar.md) |
>
> **What this means line by line, so the table below is not read as a commitment that was made:**
>
> | Row below | Actual disposition |
> |---|---|
> | Login bypass | **Not ported** ✓ — exception 2. It remains live in the legacy throughout the build; risk owner is the work owner (Q380) |
> | Unauthenticated API handlers | **Legacy posture replicated** by default. Any tightening is a per-case decision, not a blanket rule (TKT-LTS-017) |
> | Plaintext password column | **Already closed** — the column no longer exists; this row is void ([ADR-0012](adr/0012-siklus-hidup-kredensial-dikelola-it.md)) |
> | Unauthenticated inbound webhook | Not yet decided; no exception granted |
> | Hardcoded credentials in source | **Adopted** — configuration only, never committed ([ADR-0026](adr/0026-konfigurasi-lewat-environment-tanpa-perkakas-rahasia.md)) |
> | SQL string concatenation | **Adopted** — parameterised throughout |
> | Session timeout 120 minutes | **Kept**, deliberately ([ADR-0025](adr/0025-session-timeout-120-menit-dipertahankan.md)) |
>
> **Two authorization facts this section should state plainly**, because they are the shape of the
> replicated posture rather than defects to be fixed silently:
> - The effective model is a **per-person allow-list, not role-based access**. Grants come from a group
>   **or** directly from the person, both unions **add only** — nothing revokes
>   ([ADR-0009](adr/0009-model-hak-akses-daftar-izin-per-orang.md)). Calling it "RBAC" in a document
>   leads a reader to expect a role model that does not apply.
> - Some rules are enforced **only by a disabled button**. The screen that changes the customer
>   promise date has **no menu row, no gate, and no rights check**: anyone who knows its address can
>   change it. The audit row is still written in that person's name — **the trace exists, the
>   prevention does not** (Q386).
>
> **A third security decision, added since:** where a legacy PL/SQL procedure refuses with its own
> `RAISE_APPLICATION_ERROR`, **that message text is shown to the user** as a validation refusal; every
> other failure keeps a generic message and is logged server-side with its full chain
> ([ADR-0029](adr/0029-pesan-raise-application-error-diteruskan-ke-pengguna.md)).

**Must-fix findings from the legacy system (do not replicate):**

| Legacy issue | Severity | New-system requirement |
|---|---|---|
| Live unauthenticated login bypass (`Default.aspx?l=BB&p=3902141`) | **CRITICAL** | Not ported. Documented here per decision log Q4 (user chose to document only, not escalate separately outside this migration). |
| 20/23 `.ashx` API handlers have zero access control | **CRITICAL** | Every API endpoint requires authentication (§11). |
| Plaintext password column (`M_USER.PASSWORD`) actively kept in sync with the hashed column, used for password-change verification via SQL-injectable string concatenation | **HIGH** | New system stores only a modern password hash (bcrypt/argon2); no plaintext copy anywhere; all queries parameterized. |
| Inbound VA-payment webhook (`srv_status_lunas_va.ashx`) has zero authentication, protected only by data-matching | **HIGH** | Inbound webhooks require signature/token verification. |
| 5+ distinct hardcoded Basic-Auth credential pairs and API keys committed to source across `General.vb` and various handlers | **HIGH** | All secrets move to configuration (§14), never committed to source. |
| Journal Service (GL) integration has zero authentication on any call | **HIGH** | Add authentication consistent with the rest of the integration layer (§8). |
| SQL built via raw string concatenation in numerous legacy pages (SQL-injection-shaped) | **HIGH** | 100% parameterized queries in the new system, enforced via code review/lint rule. |
| Static, hardcoded `machineKey`; `viewStateEncryptionMode="Never"`; `enableEventValidation="false"` | MEDIUM | Not applicable in the new architecture (ViewState is a Web-Forms-specific concept) — but the underlying principle ("never trust client-supplied state without server-side verification") applies to every API endpoint. |
| One integration (`BursaMobil`/PEGA) unconditionally disables TLS certificate validation | HIGH | Certificate validation always on; no per-integration opt-out. |
| Classic ASP hardcoded, case-sensitive, shared-per-role plaintext credentials | CRITICAL (but out of migration scope — being decommissioned, decision log Q15) | N/A — not migrated. |

> ### ⟢ AMENDMENT A-16 — a facsimile signature now prints on two documents *(v1.2)*
> **Added, nothing withdrawn.** §15 catalogues what the legacy got wrong; this records something the
> new system now DOES, so that it is a decision on the record rather than a detail inside a renderer.
>
> The KWITANSI printed by A/R → PEMBUATAN TAGIHAN ASURANSI LAIN (00000215) and A/R → CETAK ULANG
> TAGIHAN (00000493) — one document, two grants — carries a **scanned signature of a named
> individual**, embedded in the binary ([ADR-0040](adr/0040-tanda-tangan-tercetak-adalah-aset-yang-dipasang-per-dokumen.md)).
> It is the only signed document in the application.
>
> **The consequence, stated plainly: anyone who can reach those two menus can produce a PDF that
> looks signed.** There is no second factor, no per-document approval, and no audit of who printed
> what. That is also true of the legacy — the same picture sits inside `Tagihan_ASR_ASOKA.rpt` and
> any user with the menu could print it — so this is replication, not a new exposure. It is written
> down because "the legacy did it too" is a reason to keep a behaviour, not a reason to leave it
> undocumented.
>
> **Not every bill from those menus is signed** *(rev. 2, Q427)*. Above **Rp 5.000.000** the bill
> attracts **bea meterai**: a stamp is affixed and the signatory signs **by hand across it**, so the
> printed facsimile is withheld and the space left blank. This narrows the exposure — the largest
> bills, the ones worth forging, are the ones the system will not sign — but it does not remove it:
> everything at or below the threshold still prints signed on demand. An unsigned bill does not
> carry the picture inside it either, so the signature cannot be lifted out of one.
>
> **The control is the menu grant on 00000215 / 00000493, and nothing else.** If that is judged
> insufficient, the fix is narrowing those grants (§17), not weakening the document. Two things
> deliberately NOT done, so that the boundary stays visible: the signature is **not** configurable
> (a settings key would let a deployment sign a document nobody approved), and there is **no shared
> signature package** (it would make "which documents are signed" a consequence of imports rather
> than a decision). Any further document that should carry one needs its own `Qnn`.

**Session timeout:** kept at 120 minutes (decision log Q20) — a deliberate, informed trade-off favoring shop-floor usability (long idle gaps between physical production activity) over shortening session life; mitigated by fixing the actual critical gaps above rather than by reducing session duration.

---

## 16. Authentication

- Single, unified authentication scheme for the new system — no dual-system pattern (the legacy's ASP.NET-vs-Classic-ASP split is retired entirely along with Classic ASP itself, decision log Q15).
- Credential check against a `users` table (on the retained Oracle database, §3.3, defined using PostgreSQL-portable SQL) with a modern password hash (bcrypt/argon2) — replacing SHA-256(upper(password)) (itself already a real improvement over the plaintext path the prior BRD assumed was live, per `understanding-findings.md` §8, but bcrypt/argon2 is the correct modern standard, not SHA-256).
- Session/token mechanism to be finalized in technical design (JWT vs. server-side session store) — either way, session timeout **stays at 120 minutes** per §15/decision log Q20.
- The live login-bypass backdoor (§15) is explicitly not ported.

---

## 17. Authorization

- Preserve the proven RBAC shape: many-to-many user↔group membership, group↔menu grants **unioned** with per-user menu overrides (verified directly from `MasterPage.master`'s `LoadMenu` SQL — a real, working pattern, not a design flaw, despite the underlying tables having zero DDL anywhere in this repo, per `understanding-findings.md` §4/§8).
- A live database pull of `M_GRUP` (group ID → description) is a hard prerequisite for building a complete permission enumeration — dozens of group IDs are referenced by number across the legacy codebase with no central description table available in this repo.
- One legacy per-user boolean-flag permission gate was found sitting directly on `M_USER` (`M_MASTER`, `T_SPK` columns), outside the group/menu RBAC system entirely — needs a full audit before the new RBAC model is finalized (an open item, not yet resolved this session).
- Branch-switching (IT Admin viewing/acting across branches) is preserved as a feature, backed by an explicit role check rather than a hardcoded `grup_id IN ('01','18')` string comparison scattered through the UI layer.

---

## 18. Database Strategy

> ### ⟢ AMENDMENT A-10 — two premises here are false, and one risk is withdrawn *(v1.2)*
> **The strategy below stands.** Three factual corrections, each verified against the live database:
>
> 1. **"The legacy schema has zero PRIMARY KEY / FOREIGN KEY / CHECK constraints and no triggers" is
>    false.** The *checked-in SQL dumps* have none; the **live schema has 504 primary keys, 40 foreign
>    keys, 47 unique constraints and 37 triggers.** The guidance to add constraints is still sound, but
>    the premise that there are none to start from is not. It also means the dumps in this repository
>    cannot be used to reason about integrity at all.
> 2. **"Only ~5.5% of the stored procedures have source available" is superseded.** Every object in
>    scope **is present in `ALL_SOURCE`** and can be exported read-only. The fresh-export prerequisite
>    below is still correct and still required — but as ordinary preparation, not as a
>    project-threatening unknown. See A-03 for the verified inventory.
> 3. **The "three mutually inconsistent bengkel→warehouse maps" risk is WITHDRAWN.** They are **three
>    different concepts** that happen to share a shape: two produce warehouse pointers for two
>    different flows, the third produces a **procurement-branch** pointer that fills an entirely
>    different column. Nothing needs reconciling; what is needed is that they are never confused.
>    A bengkel with no mapping is **rejected with a validation error, never defaulted** — a default
>    silently ships goods to the wrong warehouse and nobody finds out until the goods are missing.
>    Source: Q371, Q389, W-13 · [ADR-0020](adr/0020-gudang-dan-cabang-pengadaan-dua-konsep.md).
>
> **Document numbering — the paragraph at the end of this section is incomplete.** There are **two**
> numbering sources, not one: a counter table for non-claim work orders, and a **database sequence
> allocated by the claims platform** for insurer claims. About **60% of the numbers at the largest
> bengkel do not come from the counter at all.** Row locking on the counter therefore closes **one of
> two** sources. **Gaps in the number series are explicitly accepted**; the guarantee against duplicates
> is the **primary key**, not the lock. Two hard ceilings are documented and unguarded — see
> [ADR-0005](adr/0005-penomoran-spk-dua-sumber-gap-diterima.md) and TKT-PRD-011.
>
> ### ⟢ AMENDMENT A-15 — a cursor column's NAME is not evidence of its SOURCE *(v1.2)*
> **Added, nothing withdrawn.** §18 already requires that stored-procedure bodies be reimplemented in
> the application rather than called (A-03, ADR-0003). What it does not say, and what cost a
> customer-facing defect, is **how to read the body you are replacing**.
>
> A legacy page reads a cursor column by name — `dsKend("ALAMAT_RUMAH")` — and the obvious mapping is
> the table column of that name. In `PC_M_KEND_SELECT.SP_M_KEND_SELECT_BY_NOPOL` that name belongs to
> a **CASE expression** implementing a three-step fallback (home address → office address → a sentence
> saying there is none). Mapping it to `M_CLIENT.ALAMAT_RUMAH` printed a blank line on **22.268 of
> 78.352** receipts at one bengkel. The same procedure returns `TIPE` from `M_DET_MERK`, not the
> tariff class the name might suggest, and applies `MASKING_ETEKNO` to three phone columns.
>
> **The rule: before mapping any column a legacy page takes from a cursor, export the procedure from
> `ALL_SOURCE` and read the SELECT list.** Aliases, `CASE`s, function calls and joins that silently
> filter are all invisible from the call site. Exports live in `docs/legacy-plsql/`.
>
> This is cheap — every object in scope is exportable (A-10, correction 2) — and the failure it
> prevents is the expensive kind: **wrong data on a document handed to a customer, rendered by code
> that passes all its tests**, because "renders without error" is not the same claim as "prints the
> right value". Source: Q423 · TKT-AR-005 · `docs/legacy-plsql/PC_M_KEND_SELECT.sql`.

> **Triggers.** Since the live schema does have triggers (correction 1), and some of them **refuse
> inserts** with business messages — one carrying a bengkel identity written inside its own sub-query,
> so the rule applies differently per bengkel with that fact visible nowhere else — **all trigger logic
> moves into the application** ([ADR-0004](adr/0004-logika-trigger-dipindah-ke-aplikasi.md)), and each
> refusal must surface as a message a user can understand, not a raw database error.

**Revised strategy: the database engine stays Oracle for this migration; PostgreSQL is a future, not a current, target.** Every guideline below is written to make that eventual future migration as cheap as possible, per explicit user instruction — this supersedes the original "Target: PostgreSQL" framing that appeared everywhere in the earlier draft of this Steering document (§1.3, §1.4, §3.1, §3.3, §3.7, §8, §9, §16, §20, §21, §23, §24 have all been updated accordingly; §26 now tracks the eventual PostgreSQL move as a future enhancement).

- **Target now:** Oracle, single shared instance for all 5 branches (§3.3), same topology already proven by the legacy system (`bengkel_id` as a filter column). **Target later (out of this project's active scope, tracked in §26):** PostgreSQL, once the codebase and schema built under this project's PostgreSQL-portable standard make that migration low-risk.
- **No application-level reliance on Oracle stored procedures/packages.** New code must not call `PROCEDURE`/`PACKAGE` objects as part of its design — this is the single most important rule in this revised strategy, since PL/SQL procedures/packages have no direct PostgreSQL equivalent and calling them from the app is exactly the pattern that made the legacy system hard to port in the first place. Where legacy business logic currently lives only in a stored procedure/package, it must be **understood and re-implemented directly in the Golang application layer** (service/repository code), not merely called through a wrapper.
- **Hard prerequisite, still called out prominently (revised rationale)**: a fresh, complete export of the live Oracle database — schema (`NEWBENGKEL`, `BENGKEL`, `MBU`, and any other schema the app touches) plus full stored-procedure/package source (`DBMS_METADATA.GET_DDL` or equivalent) — remains required before detailed design of any module beyond the two already deep-verified this session. The reason has shifted, not gone away: this export is no longer needed to plan a schema port, but to correctly **read and re-implement** the business logic those procedures/packages currently encode, in Go, instead of calling them. The three SQL dumps in this repo are demonstrably incomplete and, in places, stale (schema drift confirmed on `M_USER` and the entire RBAC table set), so they cannot substitute for this fresh export.
- **SQL writing standard** (see also §8, §9): avoid Oracle-specific SQL dialect features whenever a portable, ANSI-SQL-compatible alternative exists — e.g. `COALESCE` instead of `NVL`, `CASE WHEN` instead of `DECODE`, ANSI `JOIN` syntax instead of the `(+)` outer-join operator, `OFFSET`/`FETCH FIRST n ROWS ONLY` instead of `ROWNUM`-based pagination. Where an Oracle-only construct is genuinely unavoidable (e.g. certain sequence/identity mechanics), isolate it behind a single repository-layer function so the eventual PostgreSQL swap touches one place, not every call site.
- **Type/DDL guidance for any new or changed tables under this project** (still informed by the direct DDL analysis performed this session): prefer `VARCHAR2`/`NUMBER(p,s)` definitions that map cleanly to PostgreSQL `varchar`/`numeric` later (don't introduce new fixed-width `CHAR(n)` columns for what are semantically variable-length or numeric-ID fields, continuing a pattern already recognized as a legacy wart); be deliberate about `DATE` vs. a real timestamp type per column (Oracle `DATE` conflates date+time, which has caused ambiguity in the legacy schema); avoid introducing new `REF CURSOR`-returning procedures (per the no-procedures rule above — logic moves to the app layer instead); avoid new Oracle-only object types, nested tables, or `CONNECT BY`-hierarchical designs where a portable recursive-CTE-style approach can express the same query in both Oracle and PostgreSQL syntax.
- **Constraints added, not just ported**: since the legacy schema has zero `PRIMARY KEY`/`FOREIGN KEY`/`CHECK` constraints anywhere, the schema built for this project should add real constraints reflecting the business rules currently enforced only in procedure/application code (e.g. status-flag domains, the sequential-progression rules in Production/QC) — standard SQL constraints are fully portable between Oracle and PostgreSQL, so this strengthening is pure upside for the eventual migration, not a trade-off. Call this out per-table during technical design as each module's schema is finalized.
- **Known reconciliation work before schema-freeze for procurement-adjacent tables**: three mutually-inconsistent hardcoded Bengkel→Warehouse maps exist in the legacy `General.vb` (§21 open items) — must be resolved with the business before a single authoritative mapping is encoded in the (still-Oracle) schema.
### §18.1 Database links — PERMITTED, configured, and isolated *(revision, Session 20)*

**Revision note.** An earlier draft of this project treated Oracle DATABASE LINKs as ruled out, by
extension of the "prefer portable constructs" rule above. That extension was wrong in practice and is
withdrawn: **database links are permitted**, matching what the legacy system actually does. The
decision is the user's, recorded in `docs/decision-log.md` Q136.

Why the earlier position could not hold: some data the business needs is not in this database at all.
EMONITORING's PROGRES PER POS screen is the concrete case — `GET_SPART_TERIMA` and
`GET_JANJI_TERIMA` branch on the work order's insurer, and for `TIPE_ASR_ID = '00011'` (SIMAS
INSURTECH, **38% of all in-scope work orders**, 49% at the busiest branch) the spare-part figures live
on the SIMASNET instance and are reached with `@SIMASNET.SINARMAS.CO.ID`. There is no portable
alternative that returns the same numbers; the choice was between a link and a screen that is wrong
for its largest insurer.

**The rules that go with the permission:**

1. **A link is used only where the legacy already uses one to reach another instance.** Cross-SCHEMA
   access on the same instance (`MBU`, `BENGKEL`) needs no link and must not use one — both schemas
   are directly readable, verified live (1,037 and 498 tables visible).
2. **The link name is CONFIGURATION, never a literal in source.** It is supplied per environment via
   environment variable (§14), because the name differs between environments and a hardcoded name is
   the same footgun as the legacy's commented-out URL literals.
3. **Unconfigured means unavailable, not wrong.** When the variable is empty the affected query is not
   silently re-pointed at a local table that happens to share the name — the feature reports that the
   figure is unavailable. Reading the local `MBU` copy for an insurer whose data lives elsewhere would
   produce a plausible number that is simply false, which is worse than a blank.
4. **Isolated behind one repository-layer function**, per the §319 rule for Oracle-only constructs, so
   an eventual PostgreSQL migration has one place to look rather than every call site.
5. **The no-stored-procedure rule is UNCHANGED.** Permitting links says nothing about procedures and
   packages: §317 still stands, and the logic inside `GET_SPART_TERIMA`/`GET_JANJI_TERIMA` is
   re-implemented in the application layer rather than called.

- **Backup/DR**: strict RPO (minutes)/RTO (<1 hour) per decision log Q19 — on Oracle this means continuous redo-log shipping/Data Guard (or equivalent managed replication), not just periodic RMAN dumps, justified by TEKNO handling live financial transactions (OR, settlement, VA). A fast-restore runbook is a deliverable of technical design, not this Steering. (This is the direct Oracle-side equivalent of the "WAL archiving/streaming replication" guidance a PostgreSQL target would have called for — same RPO/RTO requirement, Oracle-appropriate mechanism.)
- **Document numbering** (`NO_SPK`, `NO_PO`, `NO_PPB`, etc.): the legacy `M_COUNTER`-based numbering has a real, currently-live race condition (non-locking read-then-write). The new implementation must close this using an Oracle-appropriate mechanism — e.g. `SELECT ... FOR UPDATE` row locking, encapsulated in a single repository-layer function — rather than a Postgres-only sequence construct, so the fix is correct today and trivially portable later. This is a correctness fix, not new scope.

---

## 19. Deployment Strategy

- On-premise (§3.6), Docker containers via Docker Compose/systemd (no Kubernetes at this scale), GitLab CI pipelines (decision log Q14) — implying a Mercurial→Git source-control migration as an explicit early task (§7.4).
- Branch-by-branch cutover rollout (§7.2), starting with the smallest/lowest-risk branch.
- No pre-existing observability standard (decision log Q13) — recommend a proportional stack (structured logs + Prometheus/Grafana or equivalent) rather than an enterprise SIEM.

---

## 20. Testing Strategy

> ### ⟢ AMENDMENT A-11 — what testing actually exists, and what "the one intentional change" now is *(v1.2)*
> **The strategy below stands as the standard.** Two corrections and one measured gap:
>
> 1. **The "one confirmed intentional behaviour change" named below is not a change at all.** Mandatory
>    vehicle input without a pre-existence gate **is** the legacy behaviour — the gate is dead code
>    (A-02). It needs regression cover so it is never "tightened" by mistake, but it is not a
>    divergence. The two real divergences are the ones in A-09.
> 2. **Characterization testing was not the method used.** The method that was used, and that worked,
>    is *read both sides and cite both*: every claim that the new system differs from the legacy must
>    quote **the legacy source and the new source**. Three "behaviour change" reports collapsed when
>    that rule was applied — all three came from reading the new code **and believing its comment**
>    about the legacy instead of checking (Q382).
> 3. **Measured coverage, as at 28 August 2026:** 524 Go files, **81 test files**. But on the one
>    module that is through UAT, the tests cover a **narrow path only** — 22 functions over registration
>    validation, lookup and type mapping — with **no coverage on 11 of its 12 write endpoints**, none
>    on the 20-step save validation ladder, none on atomicity, and none on counter locking.
>    "`go test ./...` passes" is therefore **true but materially misleading**, and is corrected in
>    TKT-PRD-012. This matters beyond one module: it is the **reference standard** the other 14 inherit.
>
> **Write-path verification has a decided method and an undecided history.** Three methods were put to
> the work owner (rollback-a-real-transaction; write-then-clean-up; rely on UAT). UAT passed, which is
> the third — whether the first was ever run separately **cannot be established from the sources** and
> is marked `UNVERIFIED` (TKT-PRD-028). It matters because ~43 columns on the insert path may never
> have been executed by Oracle outside whatever UAT happened to touch; **five column-name guesses were
> already found wrong, and execution — not code reading — is what found them.**

- **Characterization tests are mandatory before porting any module's business logic**, given the legacy system has zero automated test coverage today — this is the only way to verify behavioral parity for a reimplementation project, especially given how much business logic was found to be non-obvious from a first read (dead-vs-live code paths, three inconsistent hardcoded maps, inverted integration-success conventions, etc., per `understanding-findings.md`).
- Standard Go unit tests for all new domain/service logic (target meaningful coverage on business-rule-bearing code, not a blanket percentage mandate).
- Integration tests against a real (test) Oracle instance for repository-layer code (the database engine remains Oracle per the revised §18 strategy) — given how much of the legacy's "business logic" turned out to live in SQL predicates and stored procedures, the new system's query logic needs equivalent scrutiny, not just unit-tested Go functions in isolation. Because all queries are written in the PostgreSQL-portable style (§3.3/§18/§9), these same integration tests are expected to need only minimal adjustment if/when they are later re-pointed at a PostgreSQL test instance.
- The one confirmed, deliberate **intentional behavior change** (§6.1/§21 — mandatory vehicle-data input without a hard "must pre-exist in master" gate) needs its own explicit acceptance-test coverage, called out separately from "preserve existing behavior" tests, so it's never silently reverted during later refactoring.

---

## 21. Risk Analysis

> ### ⟢ AMENDMENT A-12 — risk register updated: three closed, one downgraded, five added *(v1.2)*
> **The table below is not deleted.** Its current disposition:
>
> | # | Was | Now |
> |---|---|---|
> | 1 | CRITICAL — only 5.5% of procedures have source | **Downgraded.** All in-scope objects readable from `ALL_SOURCE`; inventory is 37 call sites / 34 objects (A-03, A-10) |
> | 5 | MEDIUM-HIGH — three conflicting warehouse maps | **WITHDRAWN** — three different concepts (A-10) |
> | 10 | Big-bang cutover | **Still addressed**, but the unit is bengkel and there are 15 (A-01, A-07) |
> | 11 | Re-enforcing "No Polisi wajib terdaftar" | **Void** — no such tightening was adopted (A-02) |
> | 12 | Mercurial→Git migration unstated | **CONFIRMED and decided** — Git/GitLab from the start, **no history carried**; the legacy repository stays on Mercurial as a read-only archive ([ADR-0019](adr/0019-repo-baru-git-tanpa-riwayat-mercurial.md)) |
>
> **Risks added since, each with a ticket:**
>
> | # | Risk | Severity | Where |
> |---|---|---|---|
> | 13 | **Eleven modules are `Selesai*`** — their write path has never been executed anywhere. One permission unblocks all of them | **HIGH** | TKT-LTS-014 |
> | 14 | **13 of 15 bengkel have no production-stage master**, so they cannot cut over and have no promise date | **HIGH** | TKT-LTS-012 |
> | 15 | **A tax multiplier that returns 0 on error** makes every price-plus-tax **0** rather than failing — a wrong number that looks plausible | **HIGH** | TKT-PRD-024 |
> | 16 | **Group identities written inside page code** switch behaviour with no table showing it; 15 groups have active members and zero menu grants and cannot be found by reading the grant tables | **HIGH** | TKT-LTS-010 |
> | 17 | **Six live redirects still point at the first-generation registration screen** whose menu is hidden. If those flows are in use they are in scope and are in no ticket | **HIGH** | TKT-PRD-026 |
> | 18 | **A grant table with ~1,385 rows is referenced by no code at all** — copying it migrates dead data, deleting it is unsafe until proven unread | MEDIUM | [ADR-0009](adr/0009-model-hak-akses-daftar-izin-per-orang.md) |
> | 19 | **Reports that measure "finished" by production stage** understate reality by roughly two-thirds | MEDIUM-HIGH | TKT-LTS-015 |
> | 20 | **A screen deferred from migration still blocks saves** — its validation is active while its editing screen is only a notice | MEDIUM-HIGH | TKT-PRD-013 |

| # | Risk | Severity | Mitigation |
|---|---|---|---|
| 1 | Only ~5.5% of stored procedures the app calls have any source in this repo; several entire packages (production state machine, complaints, payroll) and two whole schemas (`BENGKEL`, `MBU`) are completely absent | **CRITICAL** | Fresh live-DB export is a hard prerequisite (§18) — must happen before detailed design of any module beyond SPK/QC. |
| 2 | Zero automated test coverage in the legacy system — no oracle to verify behavioral equivalence | **HIGH** | Mandatory characterization testing per module before porting (§20). |
| 3 | ClaimQ/PEGA/WhatsApp integration contracts are reverse-engineered from code, not officially documented | **HIGH** | Validate against vendor/partner teams before implementing the SPK+QC module specifically (this module depends on them most heavily). |
| 4 | `JTU_SRV_TERIMA_PART` has two diverging copies (one drops supplier name, the other drops price list) — which is actually live is undeterminable from source alone | MEDIUM-HIGH | Confirm via IIS/access-log inspection before migrating this endpoint. |
| 5 | Three mutually-inconsistent hardcoded Bengkel→Warehouse maps in `General.vb`, using different numbering spaces | MEDIUM-HIGH | Reconcile with business/ops before the (Oracle, PostgreSQL-portable-style) procurement schema is finalized. |
| 6 | No guaranteed access to original Crystal Reports `.rpt` designer files for 293 live reports | MEDIUM | Reconstruct from the in-repo `.xsd`/`.xss` schemas (1:1 name-matched to reports, already confirmed present) plus observed output samples; build a Go-native PDF-generation replacement (§10 `/reporting`) — confirmed feasible, not a blocker. |
| 7 | Security debt (§15) risks being silently replicated if not explicitly designed against | HIGH | Security section (§15-17) written as explicit must-fix requirements, not left implicit. |
| 8 | Live login-bypass backdoor remains active in the legacy system throughout the (potentially long) build phase | CRITICAL, accepted | User decision (Q4): document only, no separate ops escalation requested — recorded here as a knowingly-accepted risk, not an oversight. |
| 9 | Modules 5-11 (§6) are only understood at inventory level — real complexity (dead code, hidden state machines, inconsistent hardcoded rules) is very likely present there too, based on the pattern found in SPK/QC/Auto-PO | MEDIUM-HIGH | Each module gets the same deep-dive rigor applied to SPK/QC before its own technical design begins (explicit, accepted deferral, decision log understanding-phase checkpoint). |
| 10 | Big-bang, all-branches-simultaneous cutover risk | Addressed | Refined via `/grilling` to branch-by-branch rollout (§7.2) — no longer a live risk as originally framed. |
| 11 | Re-enforcing "No Polisi wajib terdaftar" could block legitimate SPK creation for vehicles with incomplete historical master data | Addressed | Refined via `/grilling` to mandatory-input-without-pre-existence-check (§6.1) — avoids the go-live blocking risk while still closing the real data-quality gap. |
| 12 | Mercurial→Git source-control migration is an unstated but necessary implication of the GitLab-CI decision | MEDIUM | Called out explicitly (§7.4) for confirmation, not left implicit. |

---

## 22. Non-Functional Requirements

> ### ⟢ AMENDMENT A-13 — scale figures corrected, and one row is not met *(v1.2)*
> **The table below stands.** Corrections:
>
> | Row | Says | Verified 28 Aug 2026 |
> |---|---|---|
> | Scale | "5 branches" | **15 active bengkel** (A-01). The 200–300 daily-user figure is unchanged and still the sizing basis |
> | Auditability | required for every critical action | **Not met for four of them, knowingly** — see A-08 |
> | Availability | legacy stays available | Unchanged, and now has a per-bengkel precondition: the legacy must **not** run on a bengkel that has cut over (A-07) |
>
> **Measured system scale, replacing the estimates used in the BRD and §2** *(counted 28 Aug 2026)*:
>
> | Item | Figure |
> |---|---|
> | `.aspx` pages | **775** (`.aspx.vb` code-behind: 711) |
> | `.ashx` JSON handlers | **23** |
> | Classic ASP files | **257** — confirmed an orphaned island, no ASP.NET file references any of them |
> | Crystal Reports `.rpt` | **303** |
> | Shared "God class" `App_Code/General.vb` | **9,723 lines** |
> | PL/SQL source exported into the repository | **185 objects** |
> | New backend | **524 Go files, 81 test files**, 14 business modules + 1 platform package |
> | New frontend | **120 React pages** |

| Category | Requirement |
|---|---|
| Scale | 200-300 daily active users, on-premise, 5 branches — sized explicitly to avoid both under- and over-engineering (§1.3). |
| Availability | Legacy system remains fully available, unmodified, throughout the build phase (§7.1) — a hard constraint, not a target. |
| Data durability (RPO/RTO) | RPO in minutes, RTO <1 hour (decision log Q19) — justified by live financial transactions. |
| Session | 120-minute timeout retained (decision log Q20), an explicit usability-over-marginal-security trade-off. |
| Localization | Bahasa Indonesia (id-ID) throughout, consistent with the legacy system. |
| Auditability | Every critical action (approval, production-status change, financial transaction) logged with enough detail to reconstruct who-did-what-when — an explicit improvement over the legacy's login/page-hit-only activity log. |
| Security | See §15-17 — must-fix list, not a replicate-as-is list. |

---

## 23. Performance Strategy

- At 200-300 DAU on a single on-premise Oracle instance (database engine per the revised §18 strategy), a conventional connection-pooled Go backend (via the standard `database/sql` pool settings over an Oracle driver such as `godror`) requires no exotic caching layer by default — recommend starting without a dedicated cache (e.g. Redis) and adding one only where a specific, measured hot path justifies it (e.g. the menu/RBAC lookup that currently re-runs a 4-level nested SQL query on every page load in the legacy system — a good first caching candidate, in-memory or Redis, decided during technical design once real query latency is measured).
- The lobby/production dashboard screens (near-real-time production-status displays) do not need WebSockets/server-push at this scale — short-interval polling from the React SPA is sufficient and far simpler operationally; revisit only if measured latency/DB load becomes a real problem.

## 24. Scalability

- Modular monolith (§3.2) keeps the option open to extract a genuinely hot module (most likely SPK/Production given its integration load) into a separate service later, without having paid microservices operational tax upfront — this is the concrete scalability argument for choosing modular monolith over either a tangled single-package monolith or premature microservices.
- Single shared Oracle database (§3.3, §18) scales adequately for 200-300 DAU; if branch count or transaction volume grows materially in the future, read-only replicas (e.g. Oracle Active Data Guard) are the first lever to reach for before considering any schema-topology change.

## 25. Maintainability

- The single biggest maintainability fix versus the legacy system is structural: business logic separated from HTTP handlers into testable domain/service functions (§9), replacing a 9,723-line shared class with `Inherits System.Web.UI.Page` baked into "business logic," and 775 code-behind files each doing their own ad hoc data access.
- Real module boundaries (§9, §10) directly address the legacy's complete absence of layering.
- Mandatory characterization + unit + integration tests (§20) directly address the legacy's zero test coverage — the single most-cited technical-debt complaint driving this whole migration (§1.3).

## 26. Future Enhancement (out of this Steering's current scope, noted for later consideration)

- **Eventual migration from Oracle to PostgreSQL**, once conditions (licensing cost, infra strategy, or organizational direction) justify it — enabled by this project's requirement (§3.3, §18) to avoid Oracle stored-procedure/package reliance and write every SQL statement in a PostgreSQL-portable style from day one, specifically so this future migration is low-effort rather than a second full rewrite.
- Extracting SPK/Production into a separate service if/when genuinely justified by measured load (§24).
- Introducing a secrets-management tool (Vault/SOPS) if Sinar Mas standardizes on one organization-wide (currently explicitly deferred, decision log Q17).
- Adopting Kubernetes if Sinar Mas standardizes on it organization-wide (currently explicitly deferred, decision log Q12).
- Revisiting session timeout policy if a future security review calls for it (currently explicitly kept at 120 minutes by user decision, §15/§22).
- Official API contract validation/renegotiation with ClaimQ/PEGA/WhatsApp partner teams, potentially opening the door to a more modern, officially-supported integration surface than today's reverse-engineered one.

---

## Appendix — Traceability index

- Full source-grounded findings: `docs/understanding-findings.md`
- Every question/option/answer/decision, in order: `docs/decision-log.md`
- Matt Pocock skill usage and rationale: `docs/skill-usage-log.md`
- Agent-skill tooling configuration (issue tracker, triage labels, domain docs): `docs/agents/*.md`
- Pre-existing, **unverified** prior-session artifacts (treated as hypotheses only, not relied upon for any claim in this document): `analisis/*.md`

---

# PART II — ADDED IN v1.2

*Sections 27–32 are new. They record what a steering document of this project's maturity should now
carry and previously could not: a decision register, the as-built breakdown, the cutover runbook, the
open-items register, and the working rules the project earned the hard way.*

---

## 27. Decision Register (ADR index)

Every architectural decision is a numbered record in [`docs/adr/`](adr/), each citing the
`docs/decision-log.md` `Qnn` that produced it. **37 records, numbered 0001–0037 (0028 unused).**
Where an ADR and this STEERING disagree, **the ADR applies** until the work owner approves the
rewrite — see §0.

### Architecture and data

| ADR | Decision |
|---|---|
| [0001](adr/0001-oracle-dipertahankan-sql-portabel-postgresql.md) | Oracle retained; SQL written PostgreSQL-portable |
| [0002](adr/0002-modular-monolith-go-dan-react-spa.md) | Modular monolith in Go + React SPA |
| [0003](adr/0003-tanpa-pemanggilan-stored-procedure.md) | **No stored-procedure calls at all**, no exceptions |
| [0004](adr/0004-logika-trigger-dipindah-ke-aplikasi.md) | All trigger logic moves into the application |
| [0005](adr/0005-penomoran-spk-dua-sumber-gap-diterima.md) | Two numbering sources; **gaps accepted**; the PK is the guarantee |
| [0020](adr/0020-gudang-dan-cabang-pengadaan-dua-konsep.md) | Warehouse and procurement branch are **two concepts** |
| [0024](adr/0024-guard-lingkungan-database-harus-allow-list.md) | Environment guard must be an **allow-list** |
| [0026](adr/0026-konfigurasi-lewat-environment-tanpa-perkakas-rahasia.md) | Configuration via environment; production values never active by default |
| [0033](adr/0033-konstanta-integrasi-per-lingkungan-dari-konfigurasi.md) | Environment-dependent integration constants come from configuration |
| [0034](adr/0034-sumbis-memilih-link-dari-instance-tekno.md) | An insurer-group selector chooses a **database link**, never a second connection |
| [0037](adr/0037-foto-dokumen-dua-sumber-blob-dan-google-storage.md) | Document photos served from wherever the legacy put them; re-signing is best-effort |

### Business rules

| ADR | Decision |
|---|---|
| [0006](adr/0006-kalender-kerja-satu-sumber-hari-libur.md) | One holiday source; Saturday is a half day, all bengkel |
| [0007](adr/0007-tanggal-janji-bukan-komitmen-beku.md) | **The promise date is not frozen** — it moves on every stage change |
| [0015](adr/0015-ppn-empat-sumber-tarif.md) | Tax has **four rate sources**; do not collapse them to one number |
| [0016](adr/0016-kendaraan-tidak-wajib-terdaftar.md) | A vehicle need not be pre-registered |
| [0017](adr/0017-registrasi-dan-ocr-tetap-dua-layar.md) | Registration and OCR stay **two separate screens** |
| [0018](adr/0018-penanda-selesai-adalah-tanggal-keluar.md) | "Finished" is the departure date, **not** the production stage |
| [0031](adr/0031-cetak-spk-selalu-tiga-dokumen.md) | Print SPK always yields three documents; reprint yields two |
| [0035](adr/0035-aturan-validasi-legacy-mengikuti-cabangnya.md) | A legacy rule keeps **its branch**; alert text verbatim |

### Security and access rights

| ADR | Decision |
|---|---|
| [0009](adr/0009-model-hak-akses-daftar-izin-per-orang.md) | Effective model is a **per-person allow-list**, not roles |
| [0010](adr/0010-grup-dibawa-apa-adanya-peran-dan-flag.md) | Groups carried as-is — they are part role, part feature flag |
| [0011](adr/0011-pengecualian-layar-administrasi-hak-akses.md) | **Exception:** three access-rights screens are properly gated |
| [0012](adr/0012-siklus-hidup-kredensial-dikelola-it.md) | Credential lifecycle stays with IT |
| [0013](adr/0013-postur-otorisasi-legacy-direplikasi.md) | **The legacy authorization posture is replicated** |
| [0021](adr/0021-backdoor-login-tidak-diport-didokumentasikan-tersamar.md) | **Exception:** the login bypass is not ported |
| [0025](adr/0025-session-timeout-120-menit-dipertahankan.md) | 120-minute session timeout retained |
| [0029](adr/0029-pesan-raise-application-error-diteruskan-ke-pengguna.md) | A procedure's own refusal text is shown to the user |

### Process, scope and presentation

| ADR | Decision |
|---|---|
| [0008](adr/0008-cutover-per-bengkel-lima-belas-unit.md) | Cutover per bengkel, 15 units, **largest first** |
| [0014](adr/0014-replikasi-perilaku-termasuk-kontrol-yang-diam.md) | Replicate behaviour **including controls that silently do nothing** |
| [0019](adr/0019-repo-baru-git-tanpa-riwayat-mercurial.md) | New repository on Git/GitLab, **no history carried** |
| [0022](adr/0022-batas-modul-mengikuti-menu-sistem-lama.md) | Module boundaries follow the legacy menu |
| [0023](adr/0023-audit-trail-data-master-ditangguhkan.md) | Master-data audit trail deferred |
| [0027](adr/0027-tiket-sebagai-markdown-di-docs-ticketing.md) | Tickets are markdown in `docs/ticketing/` |
| [0030](adr/0030-view-dokumen-adalah-popup-pratinjau-dengan-download.md) | "View" reproduces the legacy popup chain, step for step |
| [0032](adr/0032-halaman-cetak-meniru-pdf-legacy-dan-auto-print.md) | A report the legacy served as a PDF is served as a PDF |
| [0036](adr/0036-layar-komposit-legacy-dipertahankan-dan-email-permintaan-non-blocking.md) | A composed legacy screen is ported **as composed**; notification email is best-effort |

---

## 28. As-Built Work Breakdown

The authoritative, always-current version is [`docs/ticketing/README.md`](ticketing/README.md).
**74 tickets** across 14 module directories plus `lintas` (cross-cutting), one file per ticket at
`docs/ticketing/<module>/TKT-<CODE>-NNN-slug.md`
([ADR-0027](adr/0027-tiket-sebagai-markdown-di-docs-ticketing.md)).

**One as-built specification exists**, for the only module through UAT:
[`docs/specs/proses-produksi-registrasi-kendaraan-masuk.md`](specs/proses-produksi-registrasi-kendaraan-masuk.md).
It documents behaviour that was decided and shipped — not a plan — and validating it against the
ticket board produced 19 further tickets and demoted two. Any module that reaches UAT should get the
same treatment.

**Traceability chain, end to end:**
`BRD → docs/decision-log.md Qnn → ADR → spec → ticket → code`.
Every ticket carries a `Sumber:` line pointing back up that chain; every ADR cites its `Qnn`. The
chain is checkable — a `Qnn` cited by an ADR that does not exist in the decision log is a broken
link, and that has happened once and was caught.

---

## 29. Cutover Runbook — preconditions and sequence

Expands §7 and §19 with what the amendments established.

**The unit is one bengkel. There are 15. The first is the largest, in Jakarta** (A-01, A-07).

### Per-bengkel gate — all three, no exceptions

1. **Production-stage master populated** for that bengkel. Currently **only 2 of 15** have rows.
   This is business data; it must be decided by the people who own the process, not filled in by the
   project (TKT-LTS-012).
2. **Warehouse mapping exists.** A bengkel without one is **rejected with a message naming what is
   missing** — never defaulted (TKT-PRD-004,
   [ADR-0020](adr/0020-gudang-dan-cabang-pengadaan-dua-konsep.md)).
3. **The legacy is not serving that bengkel.** Because trigger logic now lives in the application, a
   bengkel served by both systems has that logic applied **twice** to every write (TKT-LTS-008,
   [ADR-0004](adr/0004-logika-trigger-dipindah-ke-aplikasi.md)).

### Sequencing consequence

A period where both systems are alive **will occur** — that is inherent to a 15-step rollout. What
must never occur is both systems touching **the same bengkel**. Rollback for wave 1 must be sized for
the largest bengkel's volume and case variety, not for the average.

### Not a precondition, and worth stating so it is not treated as one

The ~206,000 work orders sitting at stage `000` are **not bad data needing a clean-up before
cutover**. They are registrations that never became production jobs — 99.997% were never printed and
**none** ever left the workshop (Q387).

---

## 30. Open Items Register

Items awaiting a decision that this project must not take on the work owner's behalf. The live
register is [`docs/ticketing/README.md`](ticketing/README.md) §6; this is the steering-level summary.

| # | Open item | Blocks | Ticket |
|---|---|---|---|
| 1 | **Permission to execute writes on DEV** | **11 modules** stuck at `Selesai*` | TKT-LTS-014 |
| 2 | Behaviour when a cross-instance write fails halfway | Rewrite of the cross-instance flow | TKT-LTS-006 |
| 3 | Production-stage master content for 13 bengkel | Cutover of those 13 | TKT-LTS-012 |
| 4 | **13 registration-module business decisions** — replicate or fix (4 at P0) | Registration follow-up work | `ticketing/README.md` §4 |
| 5 | Approval of this STEERING rewrite | STEERING and ADRs stay out of sync until then | §0 |
| 6 | **15 domain terms not yet locked** | Precise wording in specs and tickets | `CONTEXT.md` |
| 7 | `backend/internal/spk/` is an **empty directory** with no status | Unknown scope | `ticketing/README.md` §6.1 |
| 8 | Legacy total-menu count — needed, or not? | Any percentage-complete reporting | A-14 |
| 9 | **Owning company name** — two approved documents disagree | Headers, report footers, tax identity | §0 |
| 10 | Escalation threshold for a late SPK (who, after how long) | Late-SPK follow-up design | Q385(c) |

**Two divergences from [ADR-0014](adr/0014-replikasi-perilaku-termasuk-kontrol-yang-diam.md) exist in
shipped code and have never been ratified**: transaction handling on the save path (TKT-PRD-010) and
replacing raw error text with business messages (TKT-PRD-022). Both are probably right. Until they
are ratified, the ADR and the code disagree — which is exactly the situation this register exists to
keep visible.

---

## 31. Ways of Working — rules this project earned

These are not style preferences. Each is here because its absence produced a wrong claim that reached
a document.

1. **Any claim that the new system differs from the legacy must cite BOTH sides.** Three "behaviour
   change" reports collapsed under this rule. All three came from reading the new code **and
   believing its comment** about the legacy. A comment in new code is a claim to verify, not evidence.
2. **Never inherit a claim from an analysis document without checking it.** "Three conflicting
   warehouse maps" was wrong, and it propagated into further documents before anyone read the source.
3. **For a column's behaviour, ask "who writes here?", not "who fills this in?"** The promise date was
   reported as write-once from one screen; it has **four** writers, and the one that matters
   overwrites with no guard.
4. **The activity log is a better liveness oracle than grep — but it only covers gated pages.** 252
   pages are never logged at all, so zero rows there proves nothing.
5. **What lives in the database is the truth, not what is checked into the repository.** Several
   objects exist only in `ALL_SOURCE`, including one that every estimate date passes through.
6. **Bring the number, not just the question.** The fastest and best decisions came when the question
   arrived with a measurement — 16.58% of work orders would have been rejected by a gate that was
   proposed; only 27% of finished jobs are visible at stage `010`.
7. **DEV is not a faithful clone of production** — the work-order table has **zero rows for 2023**.
   Figures from DEV prove *structure* and *magnitude*, never production volume. Say so every time.
8. **When a fact cannot be proved, write `BELUM DIPUTUSKAN — pertanyaan terbuka` and name the owner.**
   Filling a gap with a plausible guess is the one failure this project treats as unrecoverable,
   because a guess written as fact in an ADR is indistinguishable from a decision.
9. **"Buat sama persis dengan existing" is a final answer**, not an opening position. It is re-opened
   only when the legacy itself is ambiguous, when the answer conflicts with the legacy, or when a
   concrete number is missing. Three UAT rounds were spent learning this on one screen
   ([ADR-0030](adr/0030-view-dokumen-adalah-popup-pratinjau-dengan-download.md)).

---

## 32. Document Control

| Item | Value |
|---|---|
| Version | **v1.2** — amendments only; no approved v1.1 content removed |
| Amended | 28 August 2026 |
| Amendment method | Inline **⟢ AMENDMENT** blocks under each affected heading, indexed by §0 |
| Authority when in conflict | **The ADR applies**, until the work owner approves a consolidating rewrite |
| Change control | New decisions enter via `decision-log.md` (`Qnn`) → ADR → here. STEERING is **never** the first place a decision is recorded |
| Companion documents | [`../CONTEXT.md`](../CONTEXT.md) (glossary) · [`adr/README.md`](adr/README.md) (decisions) · [`ticketing/README.md`](ticketing/README.md) (work) · [`specs/`](specs/) (as-built) · `decision-log.md` (raw record) |

> ### ⟢ AMENDMENT A-18 — a silent no-op is the worst answer a screen can give *(v1.2)*
> **Added.** Three separate defects in this sprint were the same shape: a control that, in some
> state, did nothing AND said nothing.
>
> - PENERIMAAN → Terima Bahan: the "Tambah" button began `if (!picked || !pickedQty) return`. On a
>   fully received line the quantity was `null`, so pressing Tambah added no line, raised no message
>   and did not even close its dialog. Reported as "Finalize hanya menyimpan 1 bahan" — the operator
>   believed they had staged three materials (Q432).
> - PEMBELIAN → Inbox Manual PO Bahan: `onKodeBlur` swallowed a failed lookup with an empty `catch`,
>   so a mistyped code left the previous selection silently in place (Q429).
> - The same page's "Tambah" then refused with "Pilih bahan dari hasil pencarian terlebih dahulu",
>   which described neither the cause nor the fix.
>
> **The rule.** Every control has exactly three permitted outcomes: it acts, it refuses **out loud**,
> or it is **not offered**. "Offered, pressed, nothing happened" is a defect regardless of whether
> the server would have refused anyway — the operator cannot see the server.
>
> Two consequences that are part of the rule:
>
> 1. **`0` and `null` are not the same as "invalid".** A falsy guard (`if (!qty) return`) turns a
>    legitimately empty box into silence. Validate the value, then say what is wrong with it.
> 2. **Legacy said so first.** These screens raised `MsgBox11.alert` — a browser alert. Where the
>    legacy popped up, the port pops up; a page-level `<Alert>` at the top of a long scrolled page is
>    not the same control. Banners stay for PAGE state (a load failure); popups carry the outcome of
>    an action the operator just took.
>
> The testable half belongs in a pure module (`terimaBahanRules.ts`, `pelunasanPuRules.ts`), because
> a rule with a test cannot quietly become a no-op again.
>
> **⟢ A third shape, 1 September 2026 — the control that is never OFFERED.** The
> OCR draft was read-only, and the one button that would have opened it for
> editing was behind an optional prop (`onUseDraft`) that nothing ever passed —
> so it never rendered. Not a silent action: no action at all, and no way out
> (Q440). Grep for optional props that gate a control, and check something
> actually supplies them.

---

> ### ⟢ AMENDMENT A-19 — a compiled report is evidence you do not have *(v1.2)*
> **Added.** `Reports/*.rpt` are OLE compound documents whose `CrystalReportDesignerStream` is
> compressed. Three have now been opened and none yielded a layout: `InvoicePU.rpt` and
> `Tagihan_ASR_ASOKA.rpt` (TKT-AR-007) and `PO.rpt` (TKT-PMB-003). The only thing that has ever
> unblocked one is **a PDF printed by the production system**, which the work owner supplied for the
> KWITANSI and which made that layout exact.
>
> **What to do instead of guessing.**
>
> 1. **Reconstruct the DATA CONTRACT, which IS readable** — the cursor the code binds plus every
>    `SetParameterValue`. For `PO.rpt` that is `PC_CETAK_PO.LISTPO_M` plus `bklid`,
>    `NamaMenyetujui` (`T_EMAIL_ERR` `IDERR='PO_BAHAN_TTD'`), `IsAutoPO` and `CetakKe`. A parameter
>    the legacy feeds but the port's renderer does not use is a KNOWN GAP to record, not a detail to
>    invent — the report changes on it, and how is unknowable from here.
> 2. **Fix what is measurable.** "Tampilan terpotong" is not taste, it is arithmetic: the PO table
>    was laid out 200 mm wide inside a 180 mm printable area, putting the Total column's right edge
>    at 215 mm on a 210 mm sheet. Assert the drawn geometry — parse the `re` operators out of the
>    content stream and measure the furthest right edge — rather than trusting the constants that
>    were wrong in the first place.
> 3. **Say which half is which.** "It now fits the page and no column is clipped" is provable.
>    "It matches the legacy exactly" is not, until a sample arrives. Never write the second when only
>    the first is true.
>
> **⟢ Addendum, 1 September 2026 — the sample arrived, and it settled the argument.** The work owner
> supplied a printed PO. The "measurable" half had been right; **the rest was guessed and most of it
> was wrong** — the title, the column count, the number format, the totals labels, the footer, and
> the fact that the date beside the city is the PRINT date rather than TGL_PO (Q438). Two things that
> looked like formatting turned out to be DATA: a supplier whose `KOTA` and `TELEPON` columns
> literally contain "-". Rule 3 is not a formality; it is the difference between a claim that held and
> a set of assumptions that did not.

---

> ### ⟢ AMENDMENT A-20 — a guessed integration contract is not a contract *(v1.2)*
> **Added.** `internal/production/spkocr/pipeline.go` carried this comment:
>
> > The shapes mirror the legacy's `HitService_UploadFoto_GStorage` and
> > `HitService_OCR`: a multipart upload that returns an image id…
>
> Every clause was false. It had been inferred from the function NAMES. The real
> routines take JSON with the token in the body as `Kodestring`, send base64
> **after a third service nobody knew about** (`convert-avif`), never return an
> image id — the caller mints its own — and the application, not the engine,
> writes every OCR row. The feature could not work in any configuration, and it
> shipped with passing tests (Q434).
>
> **Why the tests passed.** They stubbed the pipeline and asserted the service
> called it. The service did call it, correctly, with a contract that did not
> exist. **A stub asserts what the caller INTENDS; only a real server on the
> other end shows what it SENDS.**
>
> **Three rules.**
>
> 1. **Read the caller, not the name.** URL, headers, body, field spellings
>    (capitals included) and response handling are all in the legacy routine, and
>    all of them are the contract.
> 2. **Pin it with `httptest`.** Every outbound integration gets a test that
>    stands up the endpoint and reads the request bytes —
>    `upload_contract_test.go` is the pattern.
> 3. **Write down what has NOT been read.** "The OCR engine populates T_OCR_SPK"
>    was an optimistic comment that hid 3,230 lines of `PKG_OCR` this port does
>    not implement (TKT-PRD-043). An untraced leg is a ticket, not a comment.
>
> **Standing consequence:** every integration written from inference rather than
> from source is suspect until a contract test exists — ClaimQ, the SMTP relay,
> the Sumbis links, Google Storage. None has one yet.
>
> **And two things verification against DEV caught that no amount of reading
> would have:** `STANDARD_HASH` returns a RAW that PL/SQL converts to hex
> implicitly and Go does not (`RAWTOHEX` is mandatory), and the same document
> type is normalised TWO different ways — stripped for the storage file name,
> collapsed to single spaces for the `TYPEIMAGE` column. Read the source, then
> check it against the data.

---

> ### ⟢ AMENDMENT A-21 — E2E runs against stubs, never against a configured production endpoint *(v1.2)*
> **Added.** `backend/.env` currently points `OCR_UPLOAD_URL` / `OCR_EXTRACT_URL`
> at `app2.teknobodyrepair.id`, which is production. A browser test that reached
> them would create real documents and real OCR rows.
>
> The Playwright suite (`web/e2e/`) therefore boots the Vite dev server and
> NOTHING else — no Go backend, no Oracle. `e2e/fixtures.ts` answers `/api/**`
> from fixtures and **aborts every other request, recording it**, and each test
> asserts that record is empty. The browser is launched with
> `--no-proxy-server` as a second barrier.
>
> **A local trap worth knowing.** This machine exports
> `HTTP_PROXY=http://192.168.150.6:8080` — the same proxy the legacy's
> `HitAPI_Post` hardcodes. Playwright's "is the dev server up?" probe travels
> through it, gets a 403, reads that as "already running", never starts Vite, and
> every test then dies on `ERR_CONNECTION_REFUSED` against a server that was
> never launched. `playwright.config.ts` sets `NO_PROXY` for exactly this
> reason; the symptom looks nothing like the cause.

---

> ### ⟢ AMENDMENT A-22 — replicate defects, but ESCALATE the ones that write money *(v1.2)*
> **Added; ADR-0014 stands.** Porting the OCR write-back turned up four legacy
> defects (Q436). Three are reproduced without comment beyond a code note: RT/RW
> always takes a dead branch because `P_LENGTH` is never assigned; an OCR row is
> attached to the LAST image of its type; a panel-name rule matches its own
> output and doubles the name.
>
> **The fourth writes a money column, and that is a different kind of defect.**
> `REGEXP_REPLACE(V,'[,.][0-9]+$','')` treats the final thousands group as a
> decimal, so `'1.500.000'` is stored as **1500**. It has already fired: 8 rows
> of `T_OCR_SPK` on DEV carry `NILAI_OR = 300` beside 160 carrying 300000.
>
> **The rule.** Replication remains the default and was followed — the code
> behaves exactly as the legacy does. But when a replicated defect corrupts an
> amount, a quantity or a date that a person will act on, **reproducing it
> silently is not a neutral act**. It is written up with the evidence, the
> options are put to the work owner, and the decision is recorded (Q437). The
> three options are always the same shape: keep it, fix the port only (and
> accept a divergence), or fix both (and change the legacy).
>
> **How to tell which kind you have:** ask what the wrong value causes. A
> mis-split RT/RW is a cosmetic field on a form somebody re-types. A value
> divided by a thousand is an amount somebody invoices.
>
> **And verify the defect before reporting it.** All four above were confirmed by
> running the legacy's own expression on DEV — `SELECT` on `DUAL`, plus a count
> of how many production rows already show the symptom. "I read the code and it
> looks wrong" is not enough to put in front of the work owner.

---

> ### ⟢ AMENDMENT A-23 — an integration's TRANSPORT is part of its contract *(v1.2)*
> **Added; extends A-20.** A-20 says the request SHAPE is read from the legacy's
> calling code. That is necessary and it is not sufficient. With the shape
> finally right and all three endpoints configured, the OCR upload still failed —
> because Go's `http.DefaultTransport` uses `http.ProxyFromEnvironment` and the
> machine exports `HTTP_PROXY`. The legacy sets no proxy on any of the three
> calls. The request never left for the host; it left for a proxy that cannot
> reach an internal `10.x` address (Q439).
>
> **The rule.** When porting an outbound call, read the transport settings too,
> and set them explicitly rather than inheriting a runtime default:
>
> - **proxy** — .NET's `HttpWebRequest` and Go's default client disagree by
>   default; say which one you mean;
> - **timeout** — .NET's default is 100s, Go's `http.Client` zero value is *no
>   timeout at all*;
> - **redirects, TLS versions, connection reuse** — same class of difference.
>
> These are invisible in both codebases: nothing in the legacy source says "no
> proxy", it simply never sets one. That is exactly why it has to be looked for.
>
> **And diagnose at the layer, not by guessing.** The proof here was two lines: a
> plain TCP dial to the host (succeeded) and `http.ProxyFromEnvironment` on the
> same URL (returned the corporate proxy). Reachable host, unreachable
> transport.
>
> **⟢ REVISED, 1 September 2026 — and this is the half the first version missed.**
> The fix above was "use no proxy", and it was wrong: the converter is internal
> and must go direct, while storage and OCR are external and DO need the proxy —
> one upload touches both, and disabling proxying made those two time out for 22
> seconds before answering 503 (Q441).
>
> **"The legacy never writes X" does not mean "the legacy does not do X."** It may
> INHERIT X from its platform. `HttpWebRequest.Proxy` defaults to
> `WebRequest.DefaultWebProxy` — the system proxy, whose bypass list already
> covers local addresses. The legacy never says "no proxy" because it never has
> to. The Go equivalent is not `Proxy = nil`; it is a proxy WITH a bypass list
> (`httpproxy.Config`).
>
> So the rule has a second half: when the legacy sets nothing, **go and find out
> what its runtime supplies by default** — do not read silence as absence. And
> assert the routing decision PER HOST, because a single yes/no answer cannot
> serve an integration that spans both sides of a firewall.

---

> ### ⟢ AMENDMENT A-24 — an error that arrives without its cause costs a second round *(v1.2)*
> **Added.** `httpserver.WriteError` keeps the operator's message and DROPS the
> wrapped cause; there is no logger in it at all. Every module wraps failures
> with `apperr.Wrap(kind, message, err)`, and that `err` is read by nobody. What
> reaches the log is `status=503` and nothing else.
>
> ADR-0029 promises that failures are "logged server-side with its full chain".
> The generic message is there; the chain is not.
>
> **What it cost, concretely.** A failed OCR upload reported 503 after 22
> seconds. The real error was a `*url.Error` naming the address it could not
> reach — the one fact that separates a proxy misconfiguration from a dead
> service. It was inside `err`, wrapped, and thrown away, so the diagnosis had to
> be rebuilt by hand and the fix took two rounds (Q441, Q442).
>
> **The rule.** Where a service makes a call that can fail for reasons outside
> the message it shows the operator — anything outbound, anything with a host —
> log the cause AT THE POINT OF FAILURE, with the stage and the subject. A
> `*url.Error` carries its own URL, so "log the error" is usually enough.
>
> **Not fixed globally, deliberately.** `WriteError` is called by every handler;
> changing it means deciding logger plumbing, redaction (raw errors can carry
> customer data or SQL fragments) and level-per-Kind. Raised as TKT-PLT-001 with
> options rather than changed unilaterally inside an unrelated ticket.

---

> ### ⟢ AMENDMENT A-25 — the same mistake three times: inherited leniency *(v1.2)*
> **Added; consolidates A-20 and A-23.** The OCR integration failed three times,
> in three different layers, for one reason each time: **the legacy relies on
> something its platform does for free, and Go does not do it.**
>
> | Layer | What .NET/VB gave the legacy | What Go does |
> |---|---|---|
> | Request shape (Q434) | — (this one was simply guessed, not inherited) | — |
> | Transport (Q441) | `HttpWebRequest.Proxy` defaults to the SYSTEM proxy, bypass list included | `DefaultTransport` reads `HTTP_PROXY` with no bypass of its own |
> | Decoder (Q443) | Newtonsoft coerces a JSON number into a `String` member | `encoding/json` refuses outright |
>
> **The rule.** When a port of a working legacy feature fails on ordinary input,
> ask what the OLD RUNTIME was doing that the new one is not. The legacy source
> will not mention it — that is the whole point; it inherited the behaviour and
> never had to write it down.
>
> **Checklist for any ported integration**, in the order these actually bit:
>
> 1. **Shape** — read the calling code, pin it with an httptest server (A-20).
> 2. **Transport** — proxy, bypass, timeout, redirects, TLS (A-23).
> 3. **Decoder** — type coercion (number↔string), casing, unknown fields,
>    trailing commas. Newtonsoft is lenient in ways `encoding/json` is not, and
>    every legacy `Structure` here is all-`String`.
>
> **And narrow by elimination, with evidence.** A 500 on a write path looks like
> SQL. Before rewriting any statement, the schema was checked against DEV:
> column names, NOT NULL coverage and column lengths were all clean — and that
> is what pointed at the decoder instead. Ruling something out is a result.

---

> ### ⟢ AMENDMENT A-26 — "no rows" and "one NULL row" are different answers *(v1.2)*
> **Added.** A query the legacy used as a CEILING was ported as
> `SELECT SUM(...)`, dropping its `GROUP BY`. The two are not equivalent:
>
> | | no matching rows |
> |---|---|
> | `SELECT SUM(x) FROM t WHERE …` | ONE row, value NULL |
> | `SELECT SUM(x) FROM t WHERE … GROUP BY k` | ZERO rows |
>
> The legacy joined that CTE with `CROSS JOIN` — an inner join — and put its
> entire limit check inside `If reader.Read()`. Zero rows therefore meant **no
> ceiling at all**. The port's version returned NULL, which became 0, which
> became a ceiling of zero, and every take was refused on **135,336 of 249,375
> work orders** — more than half (Q444).
>
> **The rule.** When porting a query whose RESULT COUNT drives control flow —
> `If reader.Read()`, `EXISTS`, an inner join, `Exit Sub` when empty — preserve
> the distinction between "no answer" and "the answer is zero", and carry it
> into the Go signature: `(value, found, error)`, not a bare value.
>
> **How to spot it.** Look for `GROUP BY` on an aggregate with no grouping
> purpose, `CROSS JOIN`/`JOIN` where a `LEFT JOIN` would have been the safe
> choice, and any `If reader.Read()` wrapping a whole block. Each is the legacy
> saying "absent means skip".
>
> **And quantify the blast radius before calling it a bug.** One count against
> DEV turned "a query looks wrong" into "this refuses every take on 54% of work
> orders", which is what makes the fix urgent and the ticket credible.

---

> ### ⟢ AMENDMENT A-27 — the reading ORDER is the precedence *(v1.2)*
> **Added.** A screen's load routine was ported by transcribing the query it
> opens with. It opens with FOUR:
>
> ```
> T_OCR_SPK  ->  T_OCR_KTP  ->  T_OCR_STNK  ->  T_OCR_RANGKA
> ```
>
> and every later block assigns only where the control is STILL EMPTY. The
> precedence is nowhere written down — it emerges from the reading order plus a
> row of `If String.IsNullOrEmpty(...)` guards. Porting the first table alone
> left the form blank for every vehicle whose claim sheet was thin, which on DEV
> is an ordinary case, not an edge one (Q447).
>
> **The rule.** Before declaring a load routine ported, count the queries it
> runs. If there is more than one, the order is part of the contract:
>
> 1. transcribe EVERY read, not the first;
> 2. put the merge in a PURE function, apart from the SQL — precedence is the
>    part that fails silently, and a fake-free test can pin it;
> 3. list the assignments that carry NO guard. Those overwrite deliberately, and
>    a "tidy" COALESCE would lose them;
> 4. check whether a threshold or a WHERE differs between the reads. Two queries
>    that look alike are not one query: here the vehicle class matched at > 95
>    on one document and > 90 on another, and sharing them would have changed
>    which vehicles auto-fill.
>
> **How it announces itself.** The complaint is never "you missed a table"; it
> is "this field is empty", four times, from four different screens' worth of
> symptoms. When several reports share the shape *a field that should be filled
> is not*, count the queries before fixing them one at a time.

---

> ### ⟢ AMENDMENT A-28 — a nil slice is not an empty list *(v1.2)*
> **Added.** Two separate bug reports — both "the page shows white space" —
> were one nil slice. `crossChecks` returns nil when it has nothing to say, Go
> marshals that as `null`, and the screen read `.length` on it (Q451).
>
> Two facts that make this worse than it sounds:
>
> 1. **Go's zero value for a slice is `null`, not `[]`.** Every "no rows"
>    answer therefore CHANGES THE TYPE of the field, and only for the empty
>    case — the case least likely to be in a fixture.
> 2. **In React, a throw during render unmounts the whole tree.** The symptom
>    is not a broken panel with a message; it is a BLANK PAGE with nothing in
>    it, which is the least informative failure there is and looks to the user
>    like the feature was never built.
>
> **The rule.** A JSON field the client treats as a list is always a list.
> Coerce it where the response is BUILT (`emptyIfNil`), and guard it again where
> it is READ — the cost of being wrong is the entire screen; the cost of the
> guard is two lines.
>
> **And test it with what the server actually sends.** Fourteen browser tests
> passed over this bug because every fixture had been written by hand, and every
> hand-written fixture said `warnings: []`. A fixture you wrote only tests the
> shape you already imagined. Dump one real payload, use it verbatim, and attach
> `page.on("pageerror")` so a throw during render FAILS the test instead of
> passing quietly.
>
> **The trigger is often a previous fix.** This defect was old; what changed was
> that A-27's four-document merge made "nothing to warn about" the ordinary case
> instead of a rare one. After widening what a screen can fill in, re-check the
> paths that fire when there is nothing left to say.

---

**Known limitation of this document.** It now describes a system that is largely built, using a
structure written before it was built. The amendment blocks keep it honest but do not make it short.
A consolidating rewrite — folding the amendments into the body and retiring §0 — is the right next
step **once the work owner approves it**, and only then.
