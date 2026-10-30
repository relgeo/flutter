# 22. Dimension Objects

Status dokumen: `Normative`

Dimension digunakan untuk menampilkan ukuran pada gambar.

Dimension tidak memengaruhi geometri utama.

Dalam pembacaan konseptual RelGeo, `dimension` termasuk surface presentasi yang sangat penting untuk `technical drawing`.

Ia tetap bagian dari kontrak aktif `v0.5`, tetapi tidak perlu dibaca sebagai `core` minimum agar RelGeo tetap menjadi bahasa vektor deklaratif berbasis relasi.

---

## 22.1 Linear Dimension

Mengukur jarak antara dua titik atau anchor.

```rg
objects:
  dimWidth:
    type: dimension
    kind: linear
    from: panel.left
    to: panel.right
    offset: 10mm
```

Field:

| Field    | Keterangan |
|----------|------------|
| `kind`   | `linear` |
| `from`   | anchor atau point sumber |
| `to`     | anchor atau point tujuan |
| `offset` | jarak garis dimensi dari geometri (opsional) |
| `text`   | label kustom; gunakan `{distance}` sebagai placeholder (opsional) |

---

## 22.2 Radius Dimension

```rg
objects:
  dimRadius:
    type: dimension
    kind: radius
    target: hole1
```

---

## 22.3 Diameter Dimension

```rg
objects:
  dimHole:
    type: dimension
    kind: diameter
    target: hole1
```

Field `target`: ID object bertipe `circle` atau `arc`.

---

## 22.4 Angular Dimension

```rg
objects:
  dimAngle:
    type: dimension
    kind: angle
    between: [line1, line2]
```

Field `between`: array dua object ID bertipe `line`.

---

## 22.5 Custom Label

Semua jenis dimensi mendukung field `text` untuk label kustom:

```rg
objects:
  customDim:
    type: dimension
    kind: linear
    from: startPt
    to: endPt
    offset: 15mm
    text: "Pitch: {distance}"
```

Placeholder `{distance}` akan digantikan secara otomatis dengan nilai terukur.

Placeholder normatif inti aktif v0.5:

- `{distance}` untuk `linear`
- `{radius}` untuk `radius`
- `{diameter}` untuk `diameter`
- `{angle}` untuk `angle`

Semantics pengukuran:

- setiap object `dimension` menghasilkan measurement value internal yang deterministik dari target geometri
- custom `text` boleh memformat atau menimpa label visual, tetapi tidak mengubah measurement value internal
- placeholder yang dipakai harus sesuai dengan `kind` dimension agar menghasilkan nilai terformat yang stabil

---

## 22.6 Styling & Rendering

Dimensi tidak diproses oleh *geometry solver* melainkan diteruskan secara as-is kepada render engine (seperti SVG Renderer) di layer *annotation*. Hal ini memungkinkan tata letak dimensi yang responsif dan disesuaikan dengan estetika gambar teknik.

Renderer mendukung metadata (*styling variables*) melalui field `meta`:

```rg
objects:
  styledDim:
    type: dimension
    kind: linear
    from: A
    to: B
    offset: 20mm
    meta:
      arrowSize: 4    # Ukuran kepala panah (default ~3% dari bounding box)
      fontSize: 10    # Ukuran teks (default ~4% dari bounding box)
      fontFamily: "monospace"
      fill: "#ff0000" # Warna teks
      stroke: "blue"  # Warna panah dan garis
```

Semantics normatif:

- Jika `meta.fontFamily` tidak ditentukan, renderer harus memakai keluarga font default yang netral, setara `sans-serif`
- Jika `meta.fontSize` tidak ditentukan, renderer harus menghitung ukuran default text dimension dari diagonal bounding box scene: `max(sceneDiagonal * 0.04, 1)`
- Jika `meta.arrowSize` tidak ditentukan, renderer harus menghitung ukuran default arrowhead dari diagonal bounding box scene: `max(sceneDiagonal * 0.03, 0.5)`
- Jika `meta.fill` tidak ditentukan, warna text dimension default adalah warna netral gelap, setara `#444444`
- Jika `meta.stroke` tidak ditentukan, renderer memakai warna role/default stroke renderer untuk garis dimension dan arrowhead

Semantics text placement:

- `linear dimension` menempatkan text di sekitar titik tengah *dimension line*
- Renderer boleh merotasi text agar sejajar dengan *dimension line*
- Jika renderer memakai baseline text, ia harus menghasilkan posisi visual yang ekuivalen dengan text yang terpusat pada label dimension
- `radius`, `diameter`, dan `angle` menempatkan text dekat leader/arc dimension masing-masing, dengan anchor yang stabil dan konsisten dalam renderer tersebut

Catatan implementasi:

- Renderer boleh memakai text measurement provider atau injection mechanism internal untuk menghitung metrik label dimension
- Mekanisme tersebut tidak mengubah semantics bahasa; ia hanya membantu renderer mencapai posisi visual yang konsisten
- Jika fallback approximation dipakai untuk text metrics dimension, baseline yang direkomendasikan sama dengan object `text`: `width ≈ longestLineLength × fontSize × 0.6` dan `height ≈ lineCount × fontSize × lineHeight`

**Fitur Renderer Bawaan:**
* **Extension Lines:** Garis tambahan yang ditarik dari titik sasaran ke *dimension line*.
* **Overshoot & Gap:** Garis ekstensi memiliki sedikit celah (*gap*) ke titik sasaran geometri, dan melewati (*overshoot*) garis ukur untuk penampilan teknis profesional.
* **Arrowheads:** Kepala panah otomatis ditempatkan di kedua ujung garis ukur.
* **Auto-Rotated Text:** Orientasi teks label otomatis disejajarkan dengan garis ukur agar selalu terbaca tegak lurus terhadap arah pembacaan.

---

[← 21. Constraints](../geometry/21-constraints.md) &nbsp;|&nbsp; [↑ Index](README.md) &nbsp;|&nbsp; [23. Annotation Objects →](23-annotation.md)
