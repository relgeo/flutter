# 15. Composition Objects

Status dokumen: `Normative`

Composition Objects digunakan untuk menyusun, menurunkan, mengelompokkan, dan menggunakan kembali geometri.

---

## 15.1 Group

Group mengelompokkan beberapa object menjadi satu unit logis.

---

### Syntax

```rg
objects:
  bracket:
    type: group

    children:
      - body
      - hole1
      - hole2
```

---

### Semantics

Group:

- tidak menciptakan geometri baru
- tidak mengubah child secara implisit
- dapat digunakan sebagai target transform atau placement

---

## 15.2 Clone

Clone membuat salinan object yang sudah ada.

---

### Syntax

```rg
objects:
  hole2:
    type: clone

    of: hole1
```

---

### Placement

```rg
objects:
  hole2:
    type: clone

    of: hole1

    place:
      center: panel.center
```

---

### Transform

Clone dapat diberikan transform tambahan.

```rg
objects:
  hole2:
    type: clone

    of: hole1

    transform:
      - translate: [20mm, 0]
      - rotate: 90deg
```

---

### Semantics

Clone:

- mewarisi geometri object asal
- memiliki identity sendiri
- dapat memiliki placement dan transform tambahan

---

## 15.3 Component

Component adalah definisi geometri reusable.

---

### Definition

```rg
components:
  boltHole:

    parameters:
      diameter:
        type: length
        default: 6mm

    objects:
      hole:
        type: circle
        radius: diameter / 2
```

Di dalam definisi component:

1. `parameters` mendeklarasikan kontrak input component
2. field-field di dalamnya menjelaskan input apa yang sah, tipenya apa, dan default-nya apa

Dalam kontrak aktif v0.5, definisi component juga boleh memiliki blok `derived` lokal di antara `parameters` dan `objects`.

Contoh:

```rg
components:
  bracket:
    parameters:
      width:
        type: length
      thickness:
        type: length
    derived:
      innerRadius: thickness * 1.5
      holeOffset: width / 4
    objects:
      hole:
        type: circle
        center: [holeOffset, 0mm]
        radius: innerRadius
```

---

### Instance

```rg
objects:
  h1:
    type: component

    use: boltHole

    params:
      diameter: 8mm
```

Di level instance:

1. `params` adalah nilai input aktual untuk instance tersebut
2. runtime internal component hanya membaca nilai parameter final setelah `params` dan default `parameters` di-resolve
3. `params` tidak mengubah makna `parameters`; ia hanya mengisi nilainya

`params` pada instance component mendukung `inherit` sebagai cara menyusun nilai input aktual secara lebih praktis.

Contoh:

```rg
constants:
  commonBracket:
    width: 120mm
    thickness: 6mm

  standardBoltM6:
    diameter: 6mm
    clearance: 0.5mm

objects:
  h1:
    type: component
    use: boltHole
    params:
      inherit:
        - commonBracket
        - standardBoltM6
      diameter: 8mm
```

Semantics minimum:

```txt
params = shallowMerge(source1, source2, ..., localParams)
```

Jika `inherit` berbentuk array, urutan item array adalah urutan merge normatif dari kiri ke kanan. Local override menang sebagai lapisan terakhir.

Nilai akhir ini kemudian dipakai sebagai input resolved untuk contract `parameters` milik component.

Scope minimum aktif:

```txt
inherit: single reference | ordered array of references
```

---

### Component Scope

Object internal component secara default dapat diakses melalui hierarki komponen. Namun, jika komponen mendefinisikan blok `exports`, object internal bersifat privat dan tidak dapat diakses secara global, melainkan hanya titik API spesifik yang dibuka.

`derived` lokal mengikuti scope component yang sama:

1. ia hanya hidup di dalam component
2. ia tidak dapat diakses sebagai simbol global dokumen
3. ia boleh dipakai oleh object internal dan `exports` component

---

### Identity

Object internal diakses menggunakan namespace instance.

```txt
h1.hole
```

---

### Exports

Component dapat mendefinisikan API publik.

```rg
components:
  hinge:

    objects:
      body:
        type: rect

    exports:
      center: body.center
      top: body.top
```

---

### Export Access

```rg
objects:
  p:
    type: point

    at: hinge1.center
```

---

### Rules

1. Jika blok `exports` didefinisikan, komponen memiliki kontrol akses yang ketat. Hanya export resmi yang boleh diakses dari luar component. Referensi ke objek private internal akan di-blokir dengan memicu *validation error* (`COMPONENT_EXPORT_NOT_FOUND`).
2. Jika blok `exports` TIDAK didefinisikan, sistem mengizinkan akses ke seluruh struktur objek internal komponen tersebut sebagai titik fallback.
3. Untuk scope minimum v0.5, `inherit` resmi didukung pada `params` instance component.
4. Pada scope minimum ini, `inherit` menerima satu reference atau array reference berurutan, dan selalu memakai `shallow merge`.
5. Jika `inherit` berbentuk array, urutan item array adalah urutan merge normatif.
6. `inherit` tidak boleh mengambil langsung dari geometry object kecuali sumber tersebut memang mengekspos structured value yang valid.
7. `derived` lokal component dievaluasi setelah parameter component di-resolve dan sebelum object internal component dibangun.
8. Jika ada konflik nama antara `derived` lokal dan `derived` global, evaluasi di dalam component memprioritaskan `derived` lokal.
9. Tooling boleh menampilkan object internal atau `derived` lokal sebagai data inspection, tetapi itu tidak otomatis menjadikannya API publik.
10. Dalam mode component tertutup, hanya `exports` yang menjadi surface normatif untuk referensi lintas-scope.

---

## 15.4 Geometry Operation Objects

Geometry operation objects menghasilkan geometri baru dari geometri object lain.

Dalam kontrak aktif v0.5, operation object minimum adalah:

```txt
mirror
rotate
scale
translate
reverse
split
```

Contoh:

```rg
objects:
  leftWing:
    type: polygon
    points:
      - [-20mm, -20mm]
      - [-60mm, 0mm]
      - [-20mm, 20mm]

  rightWing:
    type: mirror
    target: leftWing
    axis: y
```

### Semantics

Geometry operation objects:

- bergantung pada object target yang sudah lebih dulu terselesaikan
- menghasilkan object baru dengan identity baru
- dapat dirujuk oleh object lain seperti object geometri biasa
- berbeda dari `transform` visual, karena hasilnya adalah geometri runtime yang nyata

### Minimum Field Surface

Semua geometry operation object minimal memiliki:

| Field | Keterangan |
|-------|------------|
| `type` | Nama operation: `mirror`, `rotate`, `scale`, `translate`, `reverse`, atau `split` |
| `target` | Referensi ke object sumber yang akan diolah |

Field khusus minimum per operation:

| Operation | Field minimum tambahan |
|-----------|------------------------|
| `mirror` | `axis` |
| `rotate` | `angle` |
| `scale` | `factor` |
| `translate` | `by` |
| `reverse` | tidak ada selain `target` |
| `split` | `at`, dengan `pick` opsional |

### Split

`split` memecah satu target path-like di titik yang eksplisit.

Syntax minimum:

```rg
objects:
  splitA:
    type: split
    target: profile
    at: intersection(profile, cutLine, first)
```

Mode hasil tunggal:

```rg
objects:
  splitB:
    type: split
    target: profile
    at: intersection(profile, cutLine, first)
    pick: first
```

Semantics minimum aktif v0.5:

1. `target` hanya boleh berupa geometri `path-ref` yang didukung
2. bentuk awal yang dibakukan adalah `at: point`
3. titik `at` harus benar-benar berada pada target; engine tidak boleh diam-diam memproyeksikan atau mencari titik terdekat
4. tanpa `pick`, hasil `split` dibaca sebagai collection berisi dua bagian traversal berurutan
5. dengan `pick: first | last`, hasil `split` dibaca sebagai satu geometri path-like tunggal
6. `first` selalu berarti bagian dari `target.start` ke titik split
7. `last` selalu berarti bagian dari titik split ke `target.end`
8. target tertutup belum dibuka pada kontrak minimum ini
9. split tepat di `start` atau `end` target terbuka dianggap invalid pada kontrak minimum ini

Field minimum `split`:

| Field | Required | Keterangan |
|-------|----------|------------|
| `target` | yes | Geometri path-like yang akan dipecah |
| `at` | yes | Titik split eksplisit |
| `pick` | no | `first` atau `last`; jika tidak ditulis hasil berupa collection |

Aturan hasil minimum:

1. tanpa `pick`, `count(splitResult) = 2`
2. `first(splitResult)` adalah bagian traversal awal
3. `last(splitResult)` adalah bagian traversal akhir
4. masing-masing hasil tetap path-like dan addressable
5. engine tidak boleh memberi default `pick` secara diam-diam

Field tambahan seperti `origin` boleh dipakai pada operation yang relevan.

### Result Surface

Hasil operation object harus diperlakukan sebagai object resolved biasa.

Artinya, selama tipe hasilnya kompatibel, ia boleh:

1. dipakai sebagai input `place`, `on.path`, atau `on.frame`
2. dipakai oleh query seperti `pointAt`, `tangentAt`, `frameAt`, `length`, atau `area`
3. dipakai sebagai input operasi boolean
4. dirender sebagai object normal

### Result Type Policy

Prinsip minimum:

1. jika operasi tidak mengubah kelas geometri secara esensial, hasil sebaiknya mempertahankan tipe target
2. jika representasi spesifik tidak dapat dipertahankan dengan aman, implementasi boleh menurunkan hasil ke bentuk geometri yang lebih umum
3. walau result type internal boleh lebih umum, surface referensi yang diekspos ke user harus tetap deterministik

Contoh arah yang diharapkan:

```txt
rotate(line)       -> line-like path-ref
translate(circle)  -> circle-like ClosedShape
reverse(path)      -> path-ref
mirror(polygon)    -> ClosedShape
split(path)        -> collection<path-like> | path-ref
```

### Anchors

Hasil operation object harus tetap memiliki anchor yang stabil dan deterministik.

Aturan minimum:

1. jika tipe hasil mempertahankan surface geometri target, anchor khas tipe tersebut tetap tersedia
2. minimal, hasil harus tetap menyediakan anchor berbasis *world-space bounding box* yang konsisten

### Difference from Post-Geometry Transform

Perbedaan resmi:

1. geometry operation object menghasilkan object baru
2. `transform` pada `group`/`clone`/object biasa tidak menghasilkan identity object baru
3. operation object masuk dependency graph sebagai node object biasa
4. `transform` visual tetap bersifat post-resolve dan komposit

---

## 15.5 Post-Geometry Transform Pipeline

Transformasi geometris pada objek seperti `clone` atau `group` didefinisikan sebagai **Ordered Pipeline**. Operasi dieksekusi secara berurutan sesuai urutan penulisan, yang memberikan kontrol penuh atas urutan translasi, rotasi, skala, maupun *mirror*.

Aturan Utama:
1. **Pipeline Execution**: Dieksekusi secara sekuensial (contoh: `rotate` lalu `translate` menghasilkan posisi akhir yang berbeda dari `translate` lalu `rotate`).
2. **Default Origin: center**: Jika tidak ditentukan, seluruh transformasi non-translasi menggunakan pusat *bounding box* objek sebagai titik poros.
3. **Black Box Integrity**: Transformasi bersifat visual dan komposit (Post-Geometry). Objek internal grup menyelesaikan koordinat berdasarkan geometri pramuat (Pre-Transform), namun referensi eksternal akan menerima koordinat yang telah disesuaikan (Post-Transform).

Sintaks:
```rg
transform:
  - translate: [100, 0]
  - rotate: 45deg # Shorthand (Origin: center)
  - scale:
      factor: 1.5
      origin: [0, 0] # Origin eksplisit
```

---

[← 14. Geometry Objects](14-geometry-objects.md) &nbsp;|&nbsp; [↑ Index](README.md) &nbsp;|&nbsp; [16. Collection Objects →](16-collection-objects.md)
