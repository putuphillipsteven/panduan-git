---
name: pega-xml-analyzer
description: Gunakan saat menganalisis file XML rule Pega (Activity, HTML Section, Data Page, Flow, RDB-List, Connect-REST, Data Transform, When) di repo ClaimQ untuk migrasi ke backend Go dan frontend React/TypeScript, termasuk mencari dependency antar rule.
---

# Analisis Rule Pega ClaimQ

## Lokasi file XML
XML disimpan per modul, lalu per jenis rule. Contoh:
- Bengkel/<JenisRule>/
- Klaim Partial/Korwil/Section/, Klaim Partial/Korwil/Activity/
- Klaim Partial/Kabas/Section/
Jika rule yang direferensikan tidak ditemukan, cari di seluruh repo
berdasarkan nama rule sebelum menandainya "RULE HILANG".

## Konteks yang wajib dibaca dulu
- docs/STEERING_CLAIMQ.md
- docs/decision-log.md dan docs/adr/ (keputusan arsitektur yang sudah diambil)

## Langkah kerja
1. Identifikasi jenis rule dari pxObjClass.
2. Analisis sesuai panduan jenis rule di bawah.
3. Telusuri rule lain yang dipanggil (Call, Branch, Data Page, include Section).
4. Tulis hasil ke docs/pega-analysis/<Modul>/<NamaRule>.md.

## Activity
- Setiap step: method, parameter, step page, kondisi when, jump
- Property yang dibaca/ditulis, tabel database yang disentuh
- Usulan function/endpoint Go

## HTML Section
- Field, control, visibility/disable condition, action
- JavaScript/Chart.js custom diekstrak terpisah
- Usulan komponen React/TypeScript

## Data Page / RDB-List
- Parameter, query SQL, tabel sumber
- Usulan endpoint GET di Go

## Flow
- Urutan shape, routing assignment, kondisi percabangan (diagram mermaid)

## Format Output
Ringkasan, Input/Output, Logika bisnis, Dependency, Usulan implementasi, PERTANYAAN

## Aturan
- Jangan menebak logika yang tidak tertulis di XML. Tandai sebagai PERTANYAAN.
- Jangan mengubah file XML.