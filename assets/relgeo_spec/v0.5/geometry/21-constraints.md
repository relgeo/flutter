# 21. Constraints

Status dokumen: `Normative`

Constraint digunakan untuk memvalidasi hubungan geometri.

Constraint tidak bertindak sebagai general constraint solver.

---

## 21.1 Syntax

```rg
constraints:
  - equal:
      left: line1.length
      right: line2.length
```

---

## 21.2 Equal

Memastikan dua nilai identik.

```rg
constraints:
  - equal:
      left: line1.length
      right: line2.length
```

Atau dengan scalar literal:

```rg
constraints:
  - equal: [garisA.length, 10cm]
```

---

## 21.3 Parallel

Memastikan dua garis sejajar.

```rg
constraints:
  - parallel: [garis1, garis2]
```

Argumen adalah array dua object ID bertipe `line`.

---

## 21.4 Perpendicular

Memastikan dua garis tegak lurus.

```rg
constraints:
  - perpendicular: [garis_alas, garis_tinggi]
```

Argumen adalah array dua object ID bertipe `line`.

---

## 21.5 Tangent

Memastikan dua geometri saling tangent.

```rg
constraints:
  - tangent: [line1, circle1]
```

Argumen adalah array dua object ID. Mendukung kombinasi `line-circle`, `line-arc`, dll.

> [!NOTE]
> Constraint `tangent` bersifat **validasi** (bukan konstruksi). Untuk membangun garis singgung secara konstruktif, gunakan mode `line.tangent` di bab `10.2 Line`.

---

## 21.6 Constraint Failure

Constraint dievaluasi setelah geometri berhasil di-resolve. Resolver **tidak diperbolehkan** memodifikasi geometri untuk memenuhi constraint.

Pada kontrak aktif v0.5, constraint yang gagal **tidak** wajib menggagalkan seluruh dokumen sebagai validation error. Sebaliknya, resolver melaporkan hasilnya sebagai runtime diagnostics terstruktur pada output resolved scene, misalnya melalui koleksi `violations`.

Dengan kata lain:

1. structural/schema/reference error tetap merupakan hard error
2. constraint failure adalah hasil validasi geometri pasca-resolve
3. caller dapat memutuskan sendiri apakah `violations` harus diperlakukan sebagai warning, failed check, atau hard failure di layer yang lebih tinggi

| Diagnostic | Kondisi |
|------------|---------|
| `CONSTRAINT_VIOLATION` | Relasi geometri tidak terpenuhi |
| `OVER_CONSTRAINED` | Object memiliki constraint yang saling bertentangan |

---

[← 20. Geometry Queries](20-geometry-queries.md) &nbsp;|&nbsp; [↑ Index](README.md) &nbsp;|&nbsp; [22. Dimension Objects →](../presentation/22-dimension.md)
