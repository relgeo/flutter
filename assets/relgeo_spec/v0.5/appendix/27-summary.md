# 27. Summary

Status dokumen: `Informative`

RelGeo adalah bahasa konstruksi visual deklaratif berbasis YAML yang dirancang untuk mendeskripsikan geometri, tata letak, dan gambar parametrik melalui relasi antar elemen.

---

## Prinsip Inti

| Prinsip | Makna |
|---------|-------|
| **Relation-First** | Konstruksi berbasis hubungan antar elemen, bukan koordinat absolut |
| **Deterministic** | Input yang sama selalu menghasilkan output yang sama |
| **Typed Runtime** | Semua nilai memiliki tipe eksplisit yang tervalidasi |
| **Dependency Ordered** | Evaluasi mengikuti dependency graph yang eksplisit |
| **No Constraint Solver** | Relasi selalu directional dan deterministic - bukan persamaan arbitrer |
| **Human Readable** | Source tetap dapat dibaca dan dipahami manusia |
| **LLM Friendly** | Struktur mudah dihasilkan, dianalisis, dan dimodifikasi oleh model bahasa |

---

## Apa yang Didukung

- Geometri 2D parametrik (point, line, rect, circle, ellipse, arc, bezier, path, polygon, text)
- Komposisi (group, clone, component dengan exports)
- Repeat system (linear, each, grid, polar)
- Boolean geometry (union, subtract, intersect, xor)
- Placement system (place, on.point, on.path, on.frame)
- Constraint validation (parallel, perpendicular, tangent, equal)
- Dimension & annotation layer
- Drawing roles & filter
- Views & sheets composition
- Typed parameters dengan profile override

---

## Apa yang Tidak Didukung

- General-purpose constraint solver (persamaan bidirectional)
- 3D geometry
- Animation atau timeline
- Scripting atau control flow (if/loop sebagai bahasa)

---

## Filosofi

RelGeo mendeskripsikan **intent** konstruksi visual, bukan hasil akhirnya. Koordinat, geometri final, dan output rendering adalah hasil evaluasi dari relasi yang ditulis pengguna - bukan yang diketik secara manual.

---

[← 26. Metadata](../presentation/26-metadata.md) &nbsp;|&nbsp; [↑ Index](README.md)
