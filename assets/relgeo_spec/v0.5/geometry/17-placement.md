# 17. Placement System

Status dokumen: `Normative`

Placement menentukan hubungan spasial antar object.

Placement tidak mengubah geometri dasar object.

Placement hanya menentukan posisi akhir object.

---

## 17.1 Place

Place adalah sistem penempatan berbasis anchor.

Field yang diizinkan di dalam `place`:

```txt
left, right, top, bottom
centerX, centerY
center
topLeft, topRight, bottomLeft, bottomRight
topCenter, bottomCenter, centerLeft, centerRight
inside, margin
```

> [!WARNING]
> Penggunaan field di luar daftar di atas akan ditolak oleh validator.

---

### Scalar Placement

```rg
place:
  left: panel.left
  top: panel.top
```

---

### Scalar Placement with Offset

Ekspresi offset dapat ditambahkan langsung:

```rg
place:
  left: tanah.left + 2m
  top: panel.bottom + 5mm
```

---

### Point Placement

```rg
place:
  center: panel.center
```

---

### Point Anchor Placement

```rg
place:
  topLeft: A
```

Dengan `A` adalah referensi ke object bertipe `point`.

---

### Multi Anchor Placement

```rg
place:
  centerX: panel.centerX
  top: panel.bottom + 5mm
```

---

### Inside Placement

```rg
place:
  inside: panel
  margin: 10mm
```

> [!NOTE]
> `place.inside` bersifat eksklusif **Placement-only**. Properti ini hanya mengubah letak (translasi/koordinat) *bounding box* dari objek, dan **TIDAK** mengubah dimensi (`width`/`height`) dari objek anak secara otomatis. Kontainer yang didukung terbatas pada objek bertipe `rect`.

#### Kapan menggunakan `inside` vs `center`?

| | `place: { center: X }` | `place: { inside: X, margin: Y }` |
|---|---|---|
| **Posisi** | Tepat di titik tengah X | Di dalam area X, dengan jarak seragam dari tepi |
| **Kontrol** | Presisi ke satu titik | Margin otomatis di semua sisi |
| **Kegunaan** | Menghimpitkan pusat dua objek | Menempatkan objek "di dalam" kontainer dengan padding |
| **Kontainer** | Semua object | Hanya `rect` |

---

### Rules

Placement dievaluasi setelah geometri object selesai dihitung.

---

## 17.2 on.point

Menempatkan object pada titik tertentu.

---

### Syntax

```rg
objects:
  marker:
    type: rect

    on:
      point:
        at: hole.center
```

---

### Fields

#### at

Ekspresi yang menghasilkan point.

Wajib.

---

#### anchor

Anchor object yang ditempelkan.

Opsional.

Default:

```txt
center
```

---

## 17.3 on.path

Menempatkan object pada posisi parametrik suatu lintasan.

Orientasi object tidak berubah.

---

### Syntax

```rg
objects:
  marker:
    type: rect

    on:
      path:
        path: outline
        t: 0.5
```

Contoh dengan `ellipse`:

```rg
objects:
  slotGuide:
    type: ellipse
    center: [60mm, 40mm]
    size: [50mm, 18mm]

  marker:
    type: rect
    size: [5mm, 3mm]
    on:
      path:
        path: slotGuide
        t: 0.25
```

---

### Fields

#### path

Target path-like geometry.

Termasuk `line`, `arc`, `circle`, `ellipse`, `rect`, `path`, `polygon`, dan result geometry operation yang tetap kompatibel dengan `path-ref`.

#### t

Parameter:

```txt
0.0 ≤ t ≤ 1.0
```

#### anchor

Anchor object.

Default:

```txt
center
```

---

## 17.4 on.frame

Menempatkan object pada lintasan sekaligus mewarisi orientasi. Berbeda dari `on.path`, object akan dirotasi mengikuti arah kurva di titik `t`.

---

### Syntax

```rg
objects:
  notch:
    type: rect

    on:
      frame:
        path: outline
        t: 0.25
        anchor: topCenter
```

Contoh dengan `ellipse`:

```rg
objects:
  guide:
    type: ellipse
    center: [90mm, 55mm]
    rx: 35mm
    ry: 14mm
    rotation: 20deg

  lug:
    type: rect
    size: [8mm, 4mm]
    on:
      frame:
        path: guide
        t: 0.125
        anchor: center
```

---

### on.path vs on.frame

| | `on.path` | `on.frame` |
|---|---|---|
| Posisi | Di titik `t` pada kurva | Di titik `t` pada kurva |
| Orientasi | **Tetap** (tidak berubah) | **Mengikuti** arah kurva di titik `t` |
| Kegunaan | Label, marker statis | Notch, kontur mengikuti bentuk |

---

### Semantics

Resolver akan:

1. menghitung posisi pada lintasan
2. menghitung orientasi lokal (tangent angle) di titik `t`
3. menerapkan rotasi object sesuai orientasi tersebut

Surface ini juga menjadi dasar positioning untuk `repeat.along` saat item memakai context seperti `item.frame`.

Karena `ellipse` kompatibel dengan `path-ref`, semantics yang sama berlaku saat target lintasan adalah `ellipse`.

---

### Fields

Field yang didukung sama dengan `on.path`:

| Field | Keterangan |
|-------|------------|
| `path` | Target path-like geometry |
| `t` | Parameter `0.0 ≤ t ≤ 1.0` |
| `anchor` | Anchor object (default: `center`) |

---

[← 16. Collection Objects](16-collection-objects.md) &nbsp;|&nbsp; [↑ Index](README.md) &nbsp;|&nbsp; [18. Anchors →](18-anchors.md)
