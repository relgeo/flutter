# 26. Metadata

Status dokumen: `Normative`

Metadata menyediakan informasi tambahan yang **tidak memengaruhi geometri** dan tidak ikut dalam dependency graph resolver. Metadata digunakan oleh renderer, eksporter, atau tools eksternal.

Metadata bersifat non-authoritative terhadap bentuk geometri: jika metadata dihapus, geometri yang dihasilkan harus tetap identik.

---

## 26.1 Object Metadata

Setiap object dapat memiliki blok `meta`:

```rg
objects:
  panel:
    type: rect
    size: [200mm, 100mm]
    meta:
      role: final
      visible: true
      stroke: "#333333"
      fill: none
      strokeWidth: 1
      partNo: P-001
      description: Main Bracket
      material: aluminum
      thickness: 2mm
      process: laser-cut
```

### Rendering Metadata Fields

| Field         | Tipe    | Keterangan |
|---------------|---------|------------|
| `role`        | string  | Drawing role (lihat [24. Drawing Roles](24-drawing-roles.md)) |
| `intent`      | string  | Makna teknis/konstruktif ringan yang tidak mengubah geometri |
| `visible`     | boolean | Jika `false`, object tidak dirender |
| `stroke`      | string  | Warna garis (CSS color) |
| `fill`        | string  | Warna isi (CSS color atau `none`) |
| `strokeWidth` | number  | Tebal garis |
| `opacity`     | number  | Transparansi 0.0–1.0 |
| `label`       | string  | Label tampilan untuk debug |

### Default Stroke Visibility

Jika object terlihat dan secara konseptual memiliki stroke, tetapi author tidak memberi `strokeWidth` eksplisit, renderer tetap harus memilih perilaku default yang menjaga garis tetap terlihat pada output umum.

Semantics normatif:

1. tujuan default ini adalah menjaga object garis tetap terbaca walau scene bersatuan besar sedang di-fit, di-zoom-out, atau diproyeksikan ke viewport yang lebih kecil
2. renderer boleh memakai teknik implementation-specific untuk mencapai tujuan tersebut, misalnya hairline, minimum visible stroke, atau mekanisme lain yang ekuivalen
3. pada renderer SVG, teknik seperti non-scaling stroke adalah cara implementasi yang sah, tetapi bukan satu-satunya bentuk yang diwajibkan bahasa
4. jika `strokeWidth` eksplisit diberikan oleh author, nilai eksplisit itu menang atas kebijakan default visible stroke renderer
5. aturan ini berlaku untuk menjaga keterbacaan output presentasional, bukan untuk mengubah geometri

### Construction Intent

`meta.intent` adalah surface semantik ringan untuk menyatakan fungsi teknis object tanpa mengubah geometri maupun memaksa perilaku renderer tertentu.

Vocabulary inti aktif v0.5:

```txt
datum
centerline
baseline
clearance-hole
cut-boundary
```

Semantics normatif:

1. `intent` tidak mengubah geometri
2. `intent` tidak otomatis mengubah renderer, kecuali renderer memang memilih memanfaatkannya
3. `intent` menjawab makna teknis object, sedangkan `role` menjawab perilaku presentasi/filtering
4. satu object sebaiknya membawa satu `intent` utama, bukan daftar intent longgar
5. jika implementasi menerima nilai di luar vocabulary inti, nilai tersebut boleh diperlakukan sebagai metadata bebas, tetapi bukan bagian vocabulary normatif core

Contoh:

```rg
objects:
  datumX:
    type: line
    from: A
    to: B
    meta:
      role: centerline
      intent: datum
```

### Manufacturing Metadata Fields

| Field         | Keterangan |
|---------------|------------|
| `material`    | Bahan, misal `"aluminum"`, `"steel"` |
| `thickness`   | Ketebalan material |
| `process`     | Proses manufaktur, misal `"laser-cut"`, `"3d-print"` |
| `partNo`      | Nomor part |
| `description` | Deskripsi singkat |

---

## 26.2 Document Metadata

Metadata tingkat dokumen ditulis di root:

```rg
meta:
  title: Rear Panel
  author: Agus
  version: "1.0"
  date: "2026-06-05"
```

Catatan penting:

1. `meta.version` di sini adalah versi dokumen, revisi artefak, atau versi bisnis dokumen
2. `meta.version` **bukan** versi DSL
3. versi DSL berada di `<root>.version` dan bersifat terpisah

Contoh pembedaan:

```rg
version: "0.4"

meta:
  title: Rear Panel
  version: "1.2"
```

Pada contoh di atas:

1. `<root>.version = "0.4"` berarti dokumen itu secara eksplisit meminta kontrak lama RelGeo DSL v0.4
2. `<root>.meta.version = "1.2"` berarti revisi atau versi dokumen itu sendiri

---

## 26.3 Reusable Metadata Presets

Jika ingin menulis banyak `meta` object secara reusable, gunakan top-level `metaPresets`.

`metaPresets` adalah preset reusable untuk bundle `meta` object.

```rg
metaPresets:
  guideLine:
    stroke: "#999999"
    strokeWidth: 1
    dash: "4 2"

objects:
  centerLine:
    type: line
    from: A
    to: B
    metaPreset: guideLine
```

Semantics:

1. `metaPreset` adalah shorthand untuk merge ke `meta`
2. `metaPresets` tidak mengubah geometri
3. `meta.inherit`, jika dipakai, di-resolve setelah `metaPreset`
4. field `meta` yang ditulis langsung pada object menang di atas field dari `metaPreset` dan hasil `meta.inherit`
5. `styles` / `style` boleh tetap diterima sebagai alias backward compatibility, tetapi nama utama kontrak aktif adalah `metaPresets` / `metaPreset`

Urutan merge normatif:

```txt
metaPresets[metaPresetName] -> meta.inherit sources -> local meta fields
```

Contoh override:

```rg
constants:
  inspectionOverlay:
    dash: "4 2"
    opacity: 0.7

objects:
  centerLine:
    type: line
    from: A
    to: B
    metaPreset: guideLine
    meta:
      inherit: inspectionOverlay
      strokeWidth: 2
```

Hasil konseptual:

```rg
meta:
  stroke: "#999999"
  strokeWidth: 2
  dash: "4 2"
  opacity: 0.7
```

---

## 26.4 Metadata Inherit

`meta` boleh memakai `inherit` sebagai mekanisme reuse map metadata yang deterministik.

Contoh:

```rg
constants:
  baseCutMeta:
    stroke: "#0f172a"
    strokeWidth: 1.5

  inspectionOverlay:
    dash: "4 2"
    opacity: 0.7

objects:
  panelCut:
    type: path
    meta:
      inherit:
        - baseCutMeta
        - inspectionOverlay
      process: laser-cut
```

Aturan minimum:

1. `meta.inherit` menerima satu reference atau array reference berurutan
2. setiap source harus menghasilkan structured metadata map yang legal
3. `meta.inherit` selalu memakai `shallow merge`
4. jika berbentuk array, urutan item array adalah urutan merge normatif
5. field lokal pada `meta` selalu menang sebagai lapisan terakhir
6. `metaPreset`, `meta.inherit`, dan `meta` lokal tidak boleh memengaruhi geometri atau kontrak parameter

Catatan tooling:

1. tooling boleh menampilkan asal field metadata, misalnya dari `metaPreset`, dari `inherit`, atau dari local override
2. label seperti `inspectable` boleh hidup sebagai kontrak tooling ringan, tetapi tidak mengubah aturan referensi bahasa

---

## 26.5 Semantics

- Metadata **tidak boleh memengaruhi** geometri, dependency graph, atau hasil resolver
- Metadata dapat diwariskan dari group/clone ke children (rendering merge)
- Field yang tidak dikenali oleh renderer diabaikan tanpa error
- Resolver tidak boleh menggunakan `meta` untuk menghitung posisi, ukuran, atau relasi
- Renderer boleh menafsirkan metadata secara berbeda selama tidak mengubah kontrak geometri
- Renderer harus menjaga keterbacaan default stroke untuk object yang terlihat walau `strokeWidth` tidak ditulis, selama tidak bertentangan dengan nilai eksplisit author
- Metadata harus bersifat opsional dan dapat diabaikan tanpa membuat geometri menjadi invalid

---

[← 25. Views and Sheets](25-views-sheets.md) &nbsp;|&nbsp; [↑ Index](README.md) &nbsp;|&nbsp; [27. Summary →](../appendix/27-summary.md)
