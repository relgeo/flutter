# 13. Object Model

Status dokumen: `Normative`

Seluruh geometri, anotasi, dan elemen komposisi di RelGeo direpresentasikan sebagai object.

Setiap object memiliki:

- identity unik
- tipe yang eksplisit
- dependency yang dapat dianalisis
- hasil resolve yang deterministik

---

## 13.1 Object Definition

Setiap object wajib memiliki field:

```rg
objects:
  panel:
    type: rect
```

Field `type` menentukan primitive atau sistem yang digunakan.

---

## 13.2 Object Identity

Nama object menjadi identity global di dalam dokumen.

```rg
objects:
  panel:
    type: rect

  hole1:
    type: circle
```

Identity harus unik.

Duplikasi identity menghasilkan error.

---

## 13.3 Dependency Graph

Object dapat bergantung pada object lain.

Contoh:

```rg
objects:
  panel:
    type: rect

  hole:
    type: circle
    center: panel.center
```

Resolver wajib membangun dependency graph sebelum evaluasi.

---

## 13.4 Object Categories

RelGeo mengenal empat kategori object utama:

### Geometry Objects

Objek yang menghasilkan geometri.

Contoh:

```txt
point
line
rect
circle
ellipse
arc
quadratic
cubic
path
polygon
text
```

---

### Composition Objects

Objek yang menyusun, menurunkan, atau menggunakan kembali geometri.

Contoh:

```txt
group
clone
component
mirror
rotate
scale
translate
reverse
split
```

Catatan:

1. `group`, `clone`, dan `component` berfokus pada komposisi/reuse
2. geometry operation objects seperti `mirror`, `rotate`, `scale`, `translate`, `reverse`, dan `split` juga ditempatkan di kategori ini
3. berbeda dari `group`, geometry operation object tetap menghasilkan geometri baru yang nyata dan dapat dipakai ulang oleh object lain

---

### Collection Objects

Objek yang menghasilkan kumpulan geometri.

Contoh:

```txt
repeat
divide
boolean
```

---

### Annotation Objects

Objek yang tidak mengubah geometri utama.

Contoh:

```txt
dimension
annotation
```

---

## 13.5 Common Fields

Hampir semua object mendukung field-field berikut:

| Field       | Keterangan |
|-------------|------------|
| `type`      | **Wajib.** Tipe primitive atau sistem object |
| `place`     | Penempatan relasional berbasis anchor (lihat [17. Placement System](17-placement.md)) |
| `on`        | Penempatan berbasis lintasan (on.point / on.path / on.frame) |
| `transform` | Transformasi visual post-resolve pada object yang sudah ada. Berbeda dari geometry operation object seperti `mirror`/`rotate`/`scale`/`translate`/`reverse`/`split` yang menghasilkan object baru |
| `meta`      | Metadata rendering, manufaktur, atau informasi tambahan lainnya |
| `metaPreset`| Referensi ke preset reusable untuk shorthand `meta` |
| `anchors`   | Deklarasi anchor kustom yang dapat dirujuk object lain |

Catatan `v0.5`:

1. `meta` boleh mendukung `inherit` sebagai mekanisme reuse map terstruktur
2. jika `inherit` dipakai pada `meta`, merge yang dipakai tetap shallow merge dengan local override menang
3. `styles` / `style` boleh tetap diterima sebagai alias backward compatibility untuk `metaPresets` / `metaPreset`, tetapi bukan nama utama kontrak aktif

Contoh object dengan semua common fields:

```rg
objects:
  panel:
    type: rect
    size: [200mm, 100mm]
    place:
      left: base.right + 10mm
    transform:
      - rotate: 5deg
    meta:
      role: final
      stroke: "#333"
    metaPreset: thickLine
    anchors:
      mountLeft: [10%, 50%]
```

---

[← 12. Expressions](../syntax/12-expressions.md) &nbsp;|&nbsp; [↑ Index](README.md) &nbsp;|&nbsp; [14. Geometry Objects →](14-geometry-objects.md)
