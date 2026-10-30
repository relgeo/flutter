# 9. Constants

Status dokumen: `Normative`

Constants adalah nilai tetap yang ditetapkan pada saat authoring dan **tidak dapat diubah** oleh pengguna saat runtime. Berbeda dengan `parameters`, constants tidak memiliki `min`, `max`, atau `step`.

---

## 9.1 Basic Syntax

```rg
constants:
  margin: 10mm
  pi: 3.14159
```

---

## 9.2 Structured Constants

Constants dapat berupa object dengan beberapa field:

```rg
constants:
  pageMargin:
    top: 10mm
    right: 15mm
    bottom: 10mm
    left: 15mm
```

Diakses sebagai: `pageMargin.top`, `pageMargin.left`, dll.

---

## 9.3 Array Constants

Constants dapat berupa array nilai atau titik:

```rg
constants:
  holePattern:
    - [20mm, 20mm]
    - [80mm, 20mm]
    - [80mm, 80mm]
    - [20mm, 80mm]
```

Diakses sebagai: `holePattern[0]`, `holePattern[1]`, dll.

---

## 9.4 Rules

- Constants **tidak dapat diubah** oleh `profiles` (profiles hanya boleh override `parameters`)
- Constants dievaluasi sebelum `derived` dan `objects`
- Constants boleh merujuk ke constant lain, selama tidak membentuk dependency melingkar
- Structured constants boleh dipakai sebagai sumber `inherit` pada surface map yang mendukung `inherit`

---

[← 8. Parameters](08-parameters.md) &nbsp;|&nbsp; [↑ Index](README.md) &nbsp;|&nbsp; [10. Derived Values →](10-derived.md)
