# 23. Annotation Objects

Status dokumen: `Normative`

Annotation adalah object yang memberikan informasi teks tambahan pada gambar. Annotation **tidak memengaruhi geometri utama** dan termasuk dalam annotation layer.

---

## 23.1 Basic Annotation

```rg
objects:
  note1:
    type: annotation
    target: hole1
    text: "M6 clearance"
```

| Field    | Wajib | Keterangan |
|----------|-------|------------|
| `type`   | ✓     | Selalu `annotation` |
| `text`   | ✓     | Teks yang ditampilkan |
| `target` | ✗     | ID object yang menjadi referensi |
| `leader` | ✗     | Garis penunjuk (leader line) |
| `place`  | ✗     | Posisi teks annotation |

---

## 23.2 Leader Annotation

Leader adalah garis penunjuk dari teks ke suatu titik atau objek.

```rg
objects:
  note2:
    type: annotation
    text: "Vent Area"
    leader:
      from: vent.center
      to: [120mm, 40mm]
```

```rg
objects:
  note3:
    type: annotation
    target: hole2
    text: "Tapped M3x0.5"
    place:
      right: hole2.right + 5mm
```

---

## 23.3 Semantics

- Annotation tidak mengubah geometri utama
- `meta.role` default: `annotation`
- Annotation dapat disembunyikan oleh renderer berdasarkan filter role
- Annotation mengikuti target jika target bergerak (dependency)

---

## 23.4 Styling & Text Metrics

Renderer mendukung styling annotation melalui `meta`.

```rg
objects:
  note4:
    type: annotation
    text: "CHECK EDGE"
    leader:
      from: panel.topRight
      to: [120mm, 30mm]
    meta:
      fontFamily: "sans-serif"
      fontSize: 8
      fill: "#333333"
      stroke: "#555555"
      arrowSize: 4
```

Semantics normatif:

- Jika `meta.fontFamily` tidak ditentukan, renderer harus memakai keluarga font default yang netral, setara `sans-serif`
- Jika `meta.fontSize` tidak ditentukan, renderer harus menghitung ukuran default annotation dari diagonal bounding box scene: `max(sceneDiagonal * 0.04, 1)`
- Jika `meta.arrowSize` tidak ditentukan, renderer harus menghitung ukuran default arrowhead dari diagonal bounding box scene: `max(sceneDiagonal * 0.03, 0.5)`
- Jika `meta.fill` tidak ditentukan, warna text annotation default adalah warna netral gelap, setara `#333333`
- Jika annotation memiliki beberapa baris text, renderer harus mempertahankan urutan baris dari atas ke bawah; jarak antarbaris boleh diaproksimasi sekitar `1.2em`
- Jika annotation memakai `place`, field tersebut tetap menjadi mekanisme utama untuk menentukan positioning/alignment text block
- Jika annotation hanya memiliki `target` tanpa `place` dan tanpa `leader`, renderer harus tetap menampilkan text dengan fallback placement yang stabil di dekat target
- Posisi text annotation harus memakai semantics origin visual kiri-atas baris pertama
- Renderer berbasis baseline harus memakai semantics yang ekuivalen dengan `dominant-baseline: hanging`, atau mekanisme lain yang menghasilkan posisi visual yang sama

Untuk `leader` annotation:

- `leader.from` dan `leader.to` mendefinisikan garis penunjuk
- Jika tidak ada `place` eksplisit, renderer boleh menempatkan text block dengan offset kecil dari `leader.to`
- Detail offset horizontal/vertikal dapat berbeda antar renderer, tetapi harus stabil dan konsisten dalam renderer tersebut
- Untuk annotation berbasis `target` tanpa `leader`, renderer boleh memakai fallback placement di sisi kanan target atau posisi stabil lain yang sebanding
- Arrowhead, titik asal, dan garis accent horizontal termasuk perilaku renderer yang direkomendasikan untuk output drafting, tetapi bukan syarat geometri utama

Catatan implementasi:

- Renderer boleh memakai text measurement provider atau injection mechanism internal untuk menghitung metrik text annotation
- Mekanisme tersebut tidak mengubah semantics bahasa; ia hanya membantu renderer mencapai posisi visual yang konsisten
- Jika fallback approximation dipakai untuk text metrics annotation, baseline yang direkomendasikan sama dengan object `text`: `width ≈ longestLineLength × fontSize × 0.6` dan `height ≈ lineCount × fontSize × lineHeight`

---

[← 22. Dimension Objects](22-dimension.md) &nbsp;|&nbsp; [↑ Index](README.md) &nbsp;|&nbsp; [24. Drawing Roles →](24-drawing-roles.md)
