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
