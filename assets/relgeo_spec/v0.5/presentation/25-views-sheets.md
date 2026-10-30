# 25. Views and Sheets

Status dokumen: `Normative`

Views dan Sheets adalah dua section top-level yang bekerja bersama untuk mengatur presentasi gambar tanpa memengaruhi model geometry.

Dalam kontrak aktif `v0.5`, section ini sah dan normatif.

Namun secara konseptual, `views` dan terutama `sheets` lebih tepat dibaca sebagai surface presentasi/domain-facing daripada sebagai kapabilitas inti bahasa RelGeo.

---

## 25.1 View

View mendefinisikan "jendela" ke satu object target beserta skala dan filter role-nya.

```rg
views:
  front:
    target: panel
    scale: "1:2"
    filter:
      roles: ["final", "centerline", "hidden"]
```

### Fields

| Field           | Wajib | Tipe               | Default | Keterangan |
|-----------------|-------|--------------------|---------|------------|
| `target`        | ✓     | string (object ID) | —       | ID object yang menjadi subjek view |
| `scale`         | ✗     | string / number    | `"1:1"` | Format `"A:B"` misal `"1:2"` (scale factor 0.5) atau `"2:1"` (scale factor 2). Nilai desimal juga diterima |
| `filter.roles`  | ✗     | array of string    | —       | Role yang diikutsertakan. Jika tidak ada, semua role diikutsertakan |
| `meta`          | ✗     | object             | —       | Metadata tambahan |

### Semantics

- View **tidak mengubah model geometry** - hanya snapshot read-only dari subset objects
- Scope view dimulai dari `target` lalu meliputi seluruh children-nya secara rekursif
- Bounding box view = bounding box objek dalam scope × `scaleFactor`
- Role `"construction"`, `"guide"`, `"centerline"`, `"hidden"` selalu diabaikan saat menghitung bounding box (terlepas dari `filter.roles`)

---

## 25.2 Sheet

Sheet mendefinisikan ukuran kertas dan menempatkan satu atau lebih view di atasnya.

```rg
sheets:
  drawing1:
    size: A4
    orientation: landscape
    views:
      - use: front
        place:
          topLeft: [20mm, 20mm]
```

### Fields

| Field         | Wajib | Tipe                     | Default      | Keterangan |
|---------------|-------|--------------------------|--------------|------------|
| `size`        | ✓     | string / `[expr, expr]`  | —            | Ukuran kertas. Wajib ada |
| `orientation` | ✗     | `"landscape"` / `"portrait"` | `landscape` | Jika `portrait`, width dan height ditukar |
| `views`       | ✗     | array of placement       | —            | Daftar view yang ditempatkan di sheet |
| `meta`        | ✗     | object                   | —            | Metadata tambahan |

### Standard Sheet Sizes

Nilai `size` yang didukung (orientasi default landscape):

| Nilai    | Ukuran (mm) |
|----------|-------------|
| `"A0"`   | 1189 × 841  |
| `"A1"`   | 841 × 594   |
| `"A2"`   | 594 × 420   |
| `"A3"`   | 420 × 297   |
| `"A4"`   | 297 × 210   |

Untuk ukuran kustom, gunakan array ekspresi panjang (dapat merujuk `parameters`):

```rg
sheets:
  customSheet:
    size: ["500mm", "400mm"]
```

---

## 25.3 View Placement

Setiap item dalam `sheets.<id>.views` menempatkan sebuah view di posisi tertentu pada sheet.

```rg
sheets:
  drawing1:
    size: A3
    views:
      - use: front
        place:
          topLeft: [20, 20]
      - use: detail
        place:
          center: [300, 150]
```

### Fields

| Field           | Keterangan |
|-----------------|------------|
| `use`           | **Wajib.** Nama view yang digunakan. Harus merujuk ke view yang terdefinisi di `views` |
| `place.topLeft` | Posisi sudut kiri-atas view di koordinat sheet. Format: `[x, y]` |
| `place.center`  | Posisi titik tengah view di koordinat sheet. Format: `[x, y]` |

Jika `place` tidak ditentukan, view ditempatkan di koordinat `[0, 0]`.

Hanya satu anchor (`topLeft` atau `center`) yang boleh digunakan per placement.

---

## 25.4 Rendering Behavior

Saat sheet di-render (misal ke SVG dengan opsi `sheetId`):

- **Background**: latar abu-abu muda sebagai representasi halaman
- **Sheet border**: garis tepi sesuai `scene.padding` sebagai batas area gambar
- **Setiap view**:
  - Dirender di posisi `place` dengan transform: `translate(x, y) scale(scaleFactor) translate(-viewBbox.x, -viewBbox.y)`
  - Batas view ditampilkan sebagai dashed rectangle
  - Label nama view + skala ditampilkan di bawah batas view
- **Title block**: di pojok kanan-bawah, berisi nama sheet, versi RelGeo, tanggal, ukuran kertas

Untuk me-render sheet tertentu, gunakan opsi `sheetId` pada renderer:

```ts
renderToSVG(scene, { sheetId: "drawing1" });
```

> [!NOTE]
> Sheet bersifat murni composition/render layer. Ia tidak mengubah model geometry, tidak menciptakan objects baru, dan tidak memengaruhi dependency graph.

---

## 25.5 Error Codes

| Error                    | Kondisi |
|--------------------------|---------|
| `MISSING_REQUIRED_FIELD` | `size` tidak ada pada sheet |
| `INVALID_VALUE`          | `size` bukan string atau `[expr, expr]`; `orientation` bukan `"portrait"`/`"landscape"`; `views` bukan array; `topLeft`/`center` bukan `[x, y]` |
| `UNKNOWN_REFERENCE`      | `target` pada view tidak ditemukan di `objects`; `use` pada placement tidak ditemukan di `views` |

---

[← 24. Drawing Roles](24-drawing-roles.md) &nbsp;|&nbsp; [↑ Index](README.md) &nbsp;|&nbsp; [26. Metadata →](26-metadata.md)
