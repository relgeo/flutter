# 20. Geometry Queries

Status dokumen: `Normative`

Geometry Query menghasilkan informasi geometri tanpa menciptakan object baru.

---

## 20.1 distance

Menghasilkan jarak antara dua point.

```rg
distance(A, B)
```

Hasil:

```txt
length
```

---

## 20.2 length

Menghasilkan panjang geometri.

```rg
length(line1)
length(path1)
```

Hasil:

```txt
length
```

`length(...)` adalah query panjang lintasan umum.

Ia tetap sah dipakai untuk geometri terbuka maupun tertutup yang memiliki surface lintasan.

---

## 20.3 perimeter

Menghasilkan keliling ClosedShape.

```rg
perimeter(panel)
perimeter(slot)
```

Hasil:

```txt
length
```

Boundary v0.5:

1. `perimeter(...)` sah untuk target `ClosedShape`
2. nilainya boleh bersifat pendekatan deterministik bila shape memang tidak memiliki bentuk keliling eksak sederhana
3. untuk `ellipse`, hasil query ini sepadan dengan kontrak `ellipse.perimeter`

---

## 20.4 bbox

Menghasilkan world-space bounding box target sebagai record khusus.

```rg
bbox(panel)
bbox(slot)
```

Hasil:

```txt
bbox2d
```

Field minimum:

```txt
minX
maxX
minY
maxY
width
height
```

Boundary v0.5:

1. `bbox(...)` menghasilkan record bbox minimum, bukan object geometri biasa
2. hasilnya tidak otomatis menjadi `PlaceableObject`
3. hasilnya tidak otomatis memiliki anchors kaya seperti object biasa

---

## 20.5 width / height

Menghasilkan ukuran world-space bounding box dari target.

```rg
width(panel)
height(slot)
```

Hasil:

```txt
length
```

Boundary v0.5:

1. `width(...)` dan `height(...)` dibaca terhadap world-space bounding box target
2. query umum ini melengkapi property object yang sudah ada, bukan menggantikannya

---

## 20.6 minX / maxX / minY / maxY

Menghasilkan batas world-space bounding box dari target.

```rg
minX(panel)
maxX(panel)
minY(slot)
maxY(slot)
```

Hasil:

```txt
length
```

Makna:

1. `minX(...)` adalah batas kiri bbox
2. `maxX(...)` adalah batas kanan bbox
3. `minY(...)` adalah batas atas bbox
4. `maxY(...)` adalah batas bawah bbox

---

## 20.7 midpoint

Menghasilkan titik tengah antara dua point.

```rg
midpoint(A, B)
```

Hasil:

```txt
point
```

---

## 20.8 area

Menghasilkan luas ClosedShape.

```rg
area(panel)
area(slot)
```

Hasil:

```txt
area
```

`area(...)` sah dipakai untuk object tertutup seperti `rect`, `circle`, `ellipse`, `polygon`, `boolean`, dan `path` tertutup.

---

## 20.9 polar

Menghasilkan point dari pusat, radius, dan sudut.

```rg
polar(centerPoint, 25mm, 45deg)
```

Hasil:

```txt
point
```

Semantik:

1. argumen pertama harus `point`
2. argumen kedua harus `length`
3. argumen ketiga harus `angle`
4. hasil dibaca sebagai titik pada jarak radius dari pusat ke arah sudut yang diberikan

---

### 20.9.1 Collection and query failure boundary

Index array maupun collection yang berada di luar domain harus gagal dengan
`INVALID_COLLECTION_ACCESS` pada phase `runtime`, mempertahankan object/path
context bila tersedia. Query path dengan parameter di luar `[0, 1]`, target
degenerate, atau selector yang tidak sah harus mengembalikan diagnostic
terstruktur; resolver tidak boleh menebak titik terdekat atau mengembalikan
`undefined` sebagai hasil yang valid.

---

## 20.10 angleBetween

Menghasilkan arah dari point pertama ke point kedua.

```rg
angleBetween(A, B)
```

Hasil:

```txt
angle
```

Boundary v0.5:

1. `angleBetween(...)` hanya sah untuk dua point
2. fungsi ini tidak membuka overload vector-to-vector pada nama yang sama

---

## 20.11 pointAt

Menghasilkan point pada lintasan.

```rg
pointAt(path1, 0.5)
pointAt(ellipse1, 0.25)
```

Hasil:

```txt
point
```

`pointAt(...)` sah dipakai untuk object yang kompatibel dengan `path-ref`, termasuk `line`, `arc`, `circle`, `ellipse`, `rect`, `path`, `polygon`, dan result geometry operation yang tetap path-like.

---

## 20.12 tangentAt

Menghasilkan vektor tangent.

```rg
tangentAt(path1, 0.5)
tangentAt(ellipse1, 0.25)
```

Hasil:

```txt
vector
```

---

## 20.13 normalAt

Menghasilkan vektor normal.

```rg
normalAt(path1, 0.5)
normalAt(ellipse1, 0.25)
```

Hasil:

```txt
vector
```

---

## 20.14 closestPoint

Menghasilkan point terdekat pada geometri.

```rg
closestPoint(path1, P)
```

Hasil:

```txt
point
```

---

## 20.15 project

Menghasilkan proyeksi ortogonal sebuah point ke line acuan.

```rg
project(P, guideLine)
```

Hasil:

```txt
point
```

Boundary v0.5:

1. argumen pertama harus `point`
2. argumen kedua harus object bertipe `line`
3. fungsi ini tidak berlaku untuk `path-ref` umum
4. untuk target lintasan umum, gunakan `closestPoint(...)`

---

## 20.16 reflect

Menghasilkan refleksi sebuah point terhadap point atau line acuan.

```rg
reflect(P, centerPoint)
reflect(P, mirrorLine)
```

Hasil:

```txt
point
```

Boundary v0.5:

1. argumen pertama harus `point`
2. argumen kedua hanya sah untuk target `point` atau `line`
3. target `segment`, `path-ref`, dan `frame2d` tidak didukung pada tahap ini

---

## 20.17 toWorld / toLocal

Mengonversi titik abstrak antar-ruang koordinat.
- `toWorld(point, object)`: Mengonversi koordinat lokal objek ke koordinat dunia.
- `toLocal(point, object)`: Mengonversi koordinat dunia ke koordinat lokal objek.

Hasil:

```txt
point
```

---

## 20.18 intersection

Menghasilkan titik perpotongan.

```rg
intersection(circle1, line1, first)
```

Pilihan selector:

```txt
first
last
nearest(...)
farthest(...)
index
```

Contoh:

```rg
intersection(circle1, line1, farthest(anchorA))
```

Hasil:

```txt
point
```

atau:

```txt
collection<point>
```

bergantung pada konteks.

### 20.18.1 Bounded pair contract v0.5

Kontrak aktif memakai pasangan kanonik yang simetris: urutan dua argumen tidak
mengubah pasangan atau hasil. Pada package geometry, hasil mentah selalu
berupa array titik yang sudah diurutkan `x` naik lalu `y` naik dan dideduplikasi
dengan tolerance intersection. Pada konteks DSL yang mengharapkan satu `point`,
aturan mode di bawah berlaku.

| Pair kanonik | Mode yang didukung | Cardinality / ordering | Error boundary |
| --- | --- | --- | --- |
| `line-line` | raw, implicit single, `first`, `last`, `index`, `nearest`, `farthest` | 0 atau 1 titik; parallel/coincident menghasilkan empty | `NO_INTERSECTION`, selector errors, invalid input |
| `circle-line`, `arc-line` | raw, semua selector | 0, 1 (tangent), atau 2 titik; urutan canonical | `NO_INTERSECTION`, selector errors, invalid input |
| `circle-circle`, `arc-circle`, `arc-arc` | raw, semua selector | 0, 1 (tangent), atau 2 titik; arc difilter sesuai angular bounds | `NO_INTERSECTION`, selector errors, invalid input |
| `line-path`, `line-polygon`, `line-rect` | raw, semua selector | 0..N titik dari segment target; endpoint duplicate dideduplikasi | `NO_INTERSECTION`, selector errors, invalid input |
| `circle-path`, `circle-polygon`, `circle-rect` | raw, semua selector | 0..N titik dari segment target; canonical order | `NO_INTERSECTION`, selector errors, invalid input |
| `arc-path`, `arc-polygon`, `arc-rect` | raw, semua selector | 0..N titik yang lolos angular bounds; canonical order | `NO_INTERSECTION`, selector errors, invalid input |
| `path-path`, `path-polygon`, `path-rect`, `polygon-polygon`, `polygon-rect`, `rect-rect` | raw, semua selector | 0..N titik dari pasangan segment; canonical order/deduplication | `NO_INTERSECTION`, selector errors, invalid input |

`path`, `polygon`, dan `rect` pada tabel terakhir adalah path-like boundary;
`quadratic`, `cubic`, dan sebagian pasangan campuran diproses melalui sampling
deterministik. Sampling adalah perilaku package saat ini, bukan janji error
bound universal untuk DSL atau parity lintas host.

### 20.18.2 Selector and result modes

Intersection comparison and point deduplication use the deterministic
`GEOMETRY_TOLERANCES.intersection` value of `1e-9` in scene units. This is the
numeric boundary for coincidence and canonical ordering; it is not a general
expression-evaluation epsilon. Curve approximation assertions may use a wider
fixture tolerance when the result is produced by deterministic sampling.

| Mode | Perilaku |
| --- | --- |
| raw collection | Mempertahankan seluruh titik dalam urutan canonical; mode ini adalah konteks hasil collection, bukan pilihan diam-diam untuk `point`. |
| implicit single | Tanpa selector, satu titik dikembalikan jika cardinality tepat satu. Cardinality 0 atau >1 adalah error. |
| `first` / `last` | Memilih titik pertama/terakhir dari urutan canonical. |
| `index(n)` atau `{index: n}` | Memilih index zero-based; index di luar range adalah error. DSL v0.5 menerima bentuk selector index yang dipetakan core dari expression query. |
| `nearest(point)` / `farthest(point)` | Memilih berdasarkan jarak kuadrat ke reference point; tie mempertahankan urutan canonical. |

Error stabil untuk query intersection:

| Kode | Kondisi |
| --- | --- |
| `NO_INTERSECTION` | Hasil kosong dipakai pada konteks `point` atau selector apa pun. |
| `MULTIPLE_INTERSECTIONS` | Hasil lebih dari satu dipakai tanpa selector pada konteks `point`. |
| `INTERSECTION_INDEX_OUT_OF_RANGE` | `index` negatif atau tidak kurang dari jumlah hasil. |
| `INVALID_INTERSECTION_SELECTOR` | Bentuk selector tidak dikenali. |
| `UNSUPPORTED_FEATURE` | Pair/type tidak ada di tabel supported pair, misalnya `text-circle`; tidak boleh diproyeksikan diam-diam. |
| `INVALID_INTERSECTION_INPUT` | Koordinat/radius non-finite atau geometri degenerate, misalnya line zero-length atau circle non-positive radius. |

Fixture deterministik `geometry/src/__tests__/geometry-contract.fixture.ts`
dan test `geometry/src/__tests__/intersection.test.ts` wajib mencakup
success-single, multiple, empty, unsupported, invalid, tangent boundary,
implicit single, seluruh selector, dan selector/error boundary. Fixture
workspace 15 tetap menjadi evidence consumer untuk semantics
intersection/subtract yang sudah disetujui; fixture ini tidak mempromosikan
`union`, `xor`, atau operand boolean/non-rectangle yang masih ditahan.

---

## 20.19 frameAt

Menghasilkan frame lokal pada lintasan.

Query ini menjadi fondasi orientasi untuk `on.frame` dan `repeat.along`.

```rg
frameAt(path1, 0.25)
frameAt(ellipse1, 0.25)
```

Hasil:

```txt
frame2d
```

Field minimum hasil `frame2d`:

```txt
point
angle
tangent
normal
```

Catatan:

1. `frame2d` adalah hasil query orientasi, bukan object geometri biasa
2. field di atas bersifat read-only
3. query ini adalah surface normatif untuk orientasi pada `on.frame` dan `repeat.along`

---

## 20.20 tAtLength

Mengubah panjang lintasan menjadi parameter t.

Query ini menjadi fondasi distribusi berbasis panjang pada `repeat.along`, terutama untuk mode `uniform-length` dan `fixed-distance`.

```rg
tAtLength(path1, 50mm)
tAtLength(ellipse1, 25mm)
```

Hasil:

```txt
number
```

---

[← 19. Collections](19-collections.md) &nbsp;|&nbsp; [↑ Index](README.md) &nbsp;|&nbsp; [21. Constraints →](21-constraints.md)
