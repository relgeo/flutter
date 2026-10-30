# 16. Collection Objects

Status dokumen: `Normative`

Collection Object menghasilkan sekumpulan object runtime.

Catatan:

1. beberapa geometry operation object juga dapat menghasilkan collection pada mode tertentu
2. `split` adalah contohnya: tanpa `pick`, ia menghasilkan dua bagian path-like berurutan

---

## 16.1 Repeat

Repeat menghasilkan banyak object berdasarkan pola tertentu.

Dalam kontrak aktif v0.5, `repeat` memiliki mode resmi berikut:

1. linear
2. each
3. grid
4. polar
5. along

---

### Linear Repeat

Linear Repeat menghasilkan N instance item. Pengguna mengatur posisi setiap item menggunakan konteks `index` dalam ekspresi:

```rg
objects:
  rivetHoles:
    type: repeat
    count: 5
    item:
      type: circle
      radius: 3mm
      center:
        from: panel.leftCenter
        move:
          right: index * 20mm
```

`index` dimulai dari `0`. `count` adalah total jumlah item.

> [!NOTE]
> Linear Repeat tidak memiliki field `spacing` atau `direction` yang eksplisit. Distribusi diatur sepenuhnya melalui ekspresi di dalam `item` yang menggunakan context variable `index`.

---

### Along Repeat

`repeat.along` mendistribusikan item di sepanjang geometri berbasis lintasan.

```rg
objects:
  blocks:
    type: repeat
    along:
      target: curve
      count: 12
      spacing: uniform-length

    item:
      type: rect
      size: [6mm, 3mm]
      on:
        frame: item.frame
```

Contoh dengan `ellipse` sebagai target:

```rg
objects:
  ventGuide:
    type: ellipse
    center: [80mm, 50mm]
    rx: 40mm
    ry: 16mm

  vents:
    type: repeat
    along:
      target: ventGuide
      spacing: fixed-distance
      distance: 14mm

    item:
      type: rect
      size: [6mm, 2mm]
      on:
        frame: item.frame
```

Catatan:

1. `repeat.along` adalah mode resmi `repeat`, bukan object baru
2. ia dibangun di atas surface lintasan yang sama dengan `on.path`, `on.frame`, `pointAt`, `frameAt`, dan `tAtLength`
3. `target` boleh berupa `ellipse` selama ia kompatibel dengan `path-ref`

#### Fields

| Field | Required | Keterangan |
|-------|----------|------------|
| `target` | yes | Target path-like geometry |
| `spacing` | yes | Mode distribusi |
| `count` | conditional | Jumlah item; wajib pada `uniform-length` dan `uniform-t`, dan tidak legal pada `fixed-distance` dalam kontrak minimum v0.5 |
| `distance` | conditional | Wajib saat `spacing: fixed-distance` |
| `startOffset` | no | Offset awal pada lintasan |
| `endOffset` | no | Offset akhir pada lintasan |

#### Spacing Modes

Nilai aktif:

```txt
uniform-length
uniform-t
fixed-distance
```

`uniform-length`

```txt
distance = index / (count - 1) * usableLength
t = tAtLength(target, startOffset + distance)
```

`uniform-t`

```txt
t = index / (count - 1)
```

`fixed-distance`

```txt
distance = startOffset + index * distanceStep
t = tAtLength(target, distance)
```

Dalam kontrak minimum v0.5, mode ini sengaja berbasis `distance` saja. Resolver menurunkan jumlah item dari panjang lintasan yang tersedia:

```txt
count = floor(usableLength / distance) + 1
```

`count` tidak boleh ditulis bersama `spacing: fixed-distance` pada v0.5 karena itu akan membuka keputusan tambahan yang belum dibakukan, seperti alignment terhadap awal, akhir, atau pusat distribusi.

#### Offsets

Semantics:

```txt
usableLength = length(target) - startOffset - endOffset
```

Default:

```txt
startOffset = 0
endOffset = 0
```

#### Closed Path Note

Untuk closed path dengan `uniform-length`, kontrak default v0.5 adalah:

```txt
exclude endpoint duplication
```

Artinya item terakhir tidak boleh menduplikasi item pertama pada titik yang sama.

#### Over-constraint Rule

Jika mode `along` aktif, `item` tidak boleh sekaligus menentukan positioning lintasan yang bertentangan secara manual.

Untuk kontrak minimum v0.5:

1. `item` boleh memakai `on.frame: item.frame` atau `on.path` berbasis context `item`
2. `item` tidak boleh menentukan placement manual yang mengabaikan context lintasan aktif
3. pelanggaran rule ini menghasilkan `OVER_CONSTRAINED_REPEAT_LAYOUT`

---

### Each Repeat

```rg
objects:
  holes:
    type: repeat

    each:
      - [20mm, 20mm]
      - [80mm, 20mm]

    item:
      type: circle
```

---

### Grid Repeat

Sistem `repeat.grid` mendukung tiga mode tata letak (layout):

#### 1. Manual Layout

Jika `pitch` maupun `gap` tidak didefinisikan, seluruh *item* akan di-resolve di koordinat `[0, 0]`. Pengguna dapat memposisikan komponen secara manual menggunakan konteks `row` dan `col` di dalam blok `item.place`.

#### 2. Auto-Layout: Pitch

Menggunakan `pitch` (jarak statis antar titik asal/pusat) untuk mendistribusikan item secara seragam, tanpa memedulikan dimensi geometri dari item.

```rg
objects:
  vents:
    type: repeat
    grid:
      rows: 3
      cols: 5
      pitch: [10mm, 10mm]
    item:
      type: circle
```

#### 3. Auto-Layout: Gap

Menggunakan `gap` (jarak dinamis tepi-ke-tepi yang mempertimbangkan *Bounding Box* tiap item). *Engine* menggunakan *Two-Pass Layout System* untuk mengukur dimensi terlebar/tertinggi tiap kolom/baris terlebih dahulu, kemudian menata posisi (translate) item agar selaras dan berjarak seragam sesuai `gap` yang diberikan.

> **Auto-Layout Validation Rules:**
> - Properti `pitch` dan `gap` bersifat **mutually exclusive** (`INVALID_GRID_SPACING`).
> - Jika *Auto-Layout* (`pitch` atau `gap`) aktif, Anda **dilarang** menggunakan properti penempatan manual (`place`, `on`, `at`, `center`) di dalam definisi `item`. Jika dilanggar, *validator* akan melempar error `OVER_CONSTRAINED_REPEAT_LAYOUT`.
> - Untuk menempatkan/memindahkan keseluruhan kisi (*Collection-Level Placement*), gunakan properti `place` secara langsung pada struktur induk `repeat` (sejajar dengan deklarasi `grid`).

---

### Polar Repeat

```rg
objects:
  bolts:
    type: repeat

    polar:
      count: 6
      center: flange.center
      radius: 40mm

    item:
      type: circle
```

---

### Repeat Context

Field berikut tersedia di dalam ekspresi `item` selama evaluasi repeat:

| Field | Tersedia pada |
|-------|---------------|
| `index` | Linear, Each, Grid, Polar |
| `count` | Linear, Each, Grid, Polar |
| `row`, `col` | Grid, Each, Polar (walaupun untuk Each/Polar row=0) |
| `rows`, `cols` | Grid |
| `item` | Each, Polar |
| `item.position` | Each, Polar (koordinat awal) |
| `item.angle` | Each, Polar (sudut iterasi) |

Field tambahan untuk `along`:

| Field | Tersedia pada |
|-------|---------------|
| `index` | Along |
| `count` | Along |
| `item.t` | Along |
| `item.point` | Along |
| `item.angle` | Along |
| `item.tangent` | Along |
| `item.normal` | Along |
| `item.frame` | Along |
| `item.distance` | Along |

Contoh:

```rg
item:
  type: circle
  radius: 2mm + (index / count) * 5mm  # radius bertambah per item
```

Pada mode `along`:

1. `item.point` setara dengan `pointAt(target, item.t)`
2. `item.tangent` setara dengan `tangentAt(target, item.t)`
3. `item.normal` setara dengan `normalAt(target, item.t)`
4. `item.frame` setara dengan `frameAt(target, item.t)`
5. `item.angle` setara dengan `item.frame.angle`
6. `item.distance` adalah jarak traversal dari awal lintasan setelah memperhitungkan `startOffset`

---

### Identity

Linear repeat:

```txt
holes[0]
holes[1]
holes[2]
```

Grid repeat:

```txt
vents[0,0]
vents[0,1]
vents[1,0]
```

Identity harus stabil untuk input yang sama.

---

## 16.2 Divide

Divide membagi geometri menjadi titik parametrik.

---

### Syntax

```rg
objects:
  marks:
    type: divide

    target: outline
    count: 10
```

---

### Result Shape

Divide menghasilkan:

```txt
collection<point>
```

---

### Identity

```txt
marks[0]
marks[1]
marks[2]
```

---

### Semantics

Urutan collection mengikuti arah geometri target.

Titik-titik hasil `divide` dapat diakses dan digunakan sebagai referensi:

```rg
derived:
  firstMark: marks[0]
  secondMark: marks[1]

objects:
  # Menempatkan lingkaran di setiap titik hasil divide
  rivets:
    type: repeat
    each: marks
    item:
      type: circle
      center: item
      radius: 2mm
```

---

## 16.3 Split Result as Collection

Walau `split` diklasifikasikan sebagai geometry operation object, mode default-nya menghasilkan collection.

Contoh:

```rg
objects:
  cutProfile:
    type: split
    target: profile
    at: intersection(profile, cutter, first)
```

Semantics collection minimum:

1. `count(cutProfile) = 2`
2. `first(cutProfile)` adalah bagian traversal awal
3. `last(cutProfile)` adalah bagian traversal akhir
4. identitas hasil harus stabil untuk input yang sama

Contoh penggunaan:

```rg
objects:
  cutProfile:
    type: split
    target: profile
    at: intersection(profile, cutter, first)

  firstHalfMarker:
    type: point
    at: pointAt(first(cutProfile), 0.5)
```

---

## 16.4 Boolean

Boolean menghasilkan geometri baru dari operasi antar ClosedShape.

---

### Supported Operations

```txt
union
subtract
intersect
xor
```

---

### Syntax

```rg
objects:
  plate:
    type: boolean

    operation: subtract

    base: panel

    tools:
      - hole1
      - hole2
```

---

### Result Modes

#### Single

```rg
result:
  mode: single
```

Menghasilkan satu ClosedShape.

---

#### Multi

```rg
result:
  mode: multi
```

Menghasilkan:

```txt
collection<ClosedShape>
```

---

### Constraints

Boolean hanya berlaku untuk:

```txt
ClosedShape 2D
```

---

[← 15. Composition Objects](15-composition-objects.md) &nbsp;|&nbsp; [↑ Index](README.md) &nbsp;|&nbsp; [17. Placement System →](17-placement.md)
