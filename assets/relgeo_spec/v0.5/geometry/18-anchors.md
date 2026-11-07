# 18. Anchors

Status dokumen: `Normative`

Anchor adalah titik atau nilai referensi yang dapat diakses dari object.

---

## 18.1 Point Anchors

Anchor yang menghasilkan point.

---

### Standard 9-Point System

```txt
topLeft
topCenter
topRight

centerLeft
center
centerRight

bottomLeft
bottomCenter
bottomRight
```

---

## 18.2 Scalar Anchors

Anchor yang menghasilkan nilai tunggal.

---

### Horizontal

```txt
left
right
centerX
```

---

### Vertical

```txt
top
bottom
centerY
```

---

## 18.3 Direction Anchors

Anchor yang menghasilkan arah.

Contoh:

```txt
tangent
normal
```

---

## 18.4 Built-in Primitive Anchors

Object otomatis menyediakan anchor dasar tambahan.

Contoh:

```txt
start
end
midpoint
```

sesuai primitive masing-masing.

---

## 18.5 Custom Named Anchors

Pengguna bebas mengekspos *anchor* kustom baru dari geometri apa pun melalui blok `anchors`. Referensi kustom ini akan dievaluasi dan dapat digunakan oleh objek lain.

```rg
objects:
  badan:
    type: rect
    size: [100, 60]
    anchors:
      bahu: [20%, 0]
      pinggang: [50%, 70%]
```

## 18.6 Curve and transformed-object bounds

Untuk `path`, `quadratic`, dan `cubic`, anchor bbox (`top`, `bottom`, `left`,
`right`, `centerX`, `centerY`) mengikuti envelope kurva, bukan control polygon.
Implementasi boleh menggunakan sampling deterministik selama hasilnya stabil
dan tidak mengekspos control point sebagai bagian dari geometri resolved.

Anchor pada group, clone, dan transform operation membaca world-space result
setelah transform yang relevan. Anchor yang tidak ada harus tetap menjadi
diagnostic terstruktur pada boundary resolver; consumer tidak boleh mengubahnya
menjadi nilai `undefined` yang tampak sukses. Untuk referensi dari expression,
diagnostic tersebut mempertahankan `UNKNOWN_ANCHOR` dan path field expression
(misalnya `objects.marker.at`), sehingga lokasi referensi yang hilang tetap
dapat ditelusuri.

---

[← 17. Placement System](17-placement.md) &nbsp;|&nbsp; [↑ Index](README.md) &nbsp;|&nbsp; [19. Collections →](19-collections.md)
