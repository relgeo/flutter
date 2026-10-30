# 1. Overview

Status dokumen: `Normative`

## 1.1 Purpose

RelGeo adalah bahasa konstruksi visual deklaratif untuk mendeskripsikan geometri, tata letak, dan gambar parametrik menggunakan hubungan antar elemen (*relations*) sebagai dasar utama konstruksi.

RelGeo dirancang untuk:

- konstruksi geometri parametrik
- drafting teknis ringan
- dokumentasi visual
- pola dan layout berbasis relasi
- integrasi dengan sistem dokumentasi
- generasi dan modifikasi desain oleh manusia maupun LLM

RelGeo bukan sistem CAD penuh dan bukan general-purpose programming language.

---

## 1.2 Core Principles

RelGeo dibangun berdasarkan prinsip berikut:

### Relation First

Hubungan antar objek lebih penting daripada koordinat absolut.

### Deterministic

Input yang sama harus selalu menghasilkan output yang sama.

### Human Readable

Source harus tetap dapat dibaca dan dipahami manusia.

### Typed Runtime

Semua nilai memiliki tipe yang jelas dan tervalidasi.

### Dependency Ordered

Evaluasi dilakukan berdasarkan dependency graph yang eksplisit.

### No General Constraint Solver

RelGeo tidak menyelesaikan persamaan arbitrer atau constraint network umum.

### LLM Friendly

Struktur bahasa harus mudah dihasilkan, dianalisis, dan dimodifikasi oleh model bahasa.

---

## 1.3 Evaluation Model

Dokumen RelGeo diproses melalui tahapan berikut:

```txt
Document
↓
Parser
↓
Validator
↓
Resolver
↓
Geometry Runtime
↓
Renderer
```

### Parser

Mengubah source menjadi abstract syntax tree.

Jika field `version` tidak ada, parser boleh mengisikan versi spec aktif yang diimplementasikan runtime saat itu. Dalam kontrak aktif saat ini, default tersebut dibaca sebagai `0.5`.

### Validator

Memeriksa struktur dokumen, tipe, dan aturan bahasa.

### Resolver

Menghitung dependency graph dan mengevaluasi seluruh nilai.

### Geometry Runtime

Membangun representasi geometri final.

### Renderer

Menghasilkan output visual seperti SVG atau format lain.

---

## 1.4 Coordinate Philosophy

Koordinat bukan sumber utama desain.

Koordinat dianggap sebagai hasil komputasi dari relasi yang dituliskan pengguna.

RelGeo mengutamakan konstruksi seperti:

```rg
center: panel.center
```

dibanding:

```rg
center: [120, 80]
```

meskipun keduanya tetap diperbolehkan.

---

[↑ Index](README.md) &nbsp;|&nbsp; [2. Document Structure →](02-document-structure.md)
