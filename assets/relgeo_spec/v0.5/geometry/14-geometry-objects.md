# 14. Geometry Objects

Status dokumen: `Normative`

Geometry object menghasilkan geometri yang dapat di-query, dirender, atau digunakan oleh object lain.

---

## 14.1 Point

Point merepresentasikan satu posisi dalam ruang dua dimensi.

---

### Syntax

#### Absolute Point

```rg
objects:
  p1:
    type: point
    at: [10mm, 20mm]
```

---

#### Relative Point

Selain menggunakan kordinat absolut, titik juga dapat digeser secara relatif dari titik asal menggunakan `from` dan `move`. Pergeseran mendukung sumbu Kartesian maupun Polar (sudut dan jarak):

```rg
objects:
  p_kartesian:
    type: point
    from: p1
    move:
      right: 10mm
      down: 5mm

  p_polar:
    type: point
    from: p1
    move:
      angle: 45deg
      distance: 10cm
```

---

#### Expression Point

```rg
objects:
  p2:
    type: point
    at: [panel.centerX, panel.centerY]
```

---

#### Intersection Point

```rg
objects:
  p3:
    type: point
    at: intersection(circle1, line1, first)
```

---

### Visual Customization

Titik dapat dikustomisasi secara visual menggunakan properti khusus berikut:

```rg
objects:
  p3:
    type: point
    at: [0, 0]
    pointShape: cross # Pilihan: "dot", "cross", "plus", "circle", "square", "diamond"
    color: red        # Mendukung string warna hex atau keyword
```

Jika `pointShape` tidak ditentukan, tampilan titik bergantung pada renderer. Nilai `color` bersifat opsional dan mengikuti format warna CSS.

---

### Properties

#### x

```txt
scalar-length
```

#### y

```txt
scalar-length
```

---

### Anchors

Point tidak memiliki anchor tambahan.

Object point merepresentasikan dirinya sendiri.

---

## 14.2 Line

Line merepresentasikan segmen garis lurus.

---

### From-To Mode

```rg
objects:
  line1:
    type: line

    from: A
    to: B
```

---

### Direction-Length Mode

Field `direction` menerima nilai **string enum**, bukan angle:

```rg
objects:
  line2:
    type: line

    from: A
    direction: right
    length: 100mm
```

Nilai yang didukung:

```txt
left
right
up
down
```

> [!NOTE]
> Mode ini berbeda dari Polar Movement pada `point.move.angle`. `direction` pada `line` hanya menerima arah kardinal. Untuk garis dengan sudut bebas, gunakan mode `from-to` dengan `point` yang telah dihitung menggunakan `move.angle`.

> [!NOTE]
> Pembatasan ini berlaku untuk primitive `line` sebagai object mandiri. Extension `direction` berbasis angle, `turn`, dan `forward` milik v0.5 hanya legal pada `line` yang hidup di dalam `path.segments`.

---

### Tangent Mode

```rg
objects:
  tangentLine:
    type: line

    tangent:
      from: A
      to: circle1
      pick: first
```

---

### Properties

#### start

```txt
point
```

#### end

```txt
point
```

#### center

```txt
point
```

#### length

```txt
scalar-length
```

---

### Anchors

```txt
start
end
center
```

---

## 14.3 Rect

Rect merepresentasikan persegi panjang.

---

### Syntax

#### Size Mode

```rg
objects:
  panel:
    type: rect

    size: [200mm, 100mm]
```

---

### Placement

```rg
objects:
  panel:
    type: rect

    size: [200mm, 100mm]

    place:
      center: origin
```

---

### Properties

#### width

```txt
scalar-length
```

#### height

```txt
scalar-length
```

#### area

```txt
scalar-area
```

---

### Point Anchors

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

### Scalar Anchors

```txt
left
right
top
bottom

centerX
centerY
```

---

### Holes

Rect dapat memiliki holes.

```rg
objects:
  panel:
    type: rect

    size: [200mm, 100mm]

    holes:
      - circle:
          center: panel.center
          radius: 10mm
```

---

## 14.4 Circle

Circle merepresentasikan lingkaran.

---

### Radius Mode

```rg
objects:
  hole:
    type: circle

    center: origin
    radius: 5mm
```

---

### Properties

#### center

```txt
point
```

#### radius

```txt
scalar-length
```

#### area

```txt
scalar-area
```

---

### Scalar Anchors

```txt
left
right
top
bottom

centerX
centerY
```

---

### Point Anchors

```txt
center
```

---

### Holes

Circle dapat memiliki holes.

```rg
objects:
  ring:
    type: circle

    radius: 50mm

    holes:
      - circle:
          radius: 20mm
          center: ring.center
```

---

## 14.5 Ellipse

Ellipse merepresentasikan bentuk oval tertutup.

---

### Radius Mode

```rg
objects:
  ovalHole:
    type: ellipse

    center: origin
    rx: 20mm
    ry: 10mm
    rotation: 45deg
```

---

### Size Mode

```rg
objects:
  slot:
    type: ellipse

    center: panel.center
    size: [40mm, 20mm]
```

Semantics:

```txt
rx = width / 2
ry = height / 2
```

Jika `size` dipakai bersama `rx`/`ry`, validator melempar `ELLIPSE_SIZE_CONFLICT`.

---

### Placement

Ellipse termasuk object yang dapat di-`place`.

```rg
objects:
  vent:
    type: ellipse
    rx: 30mm
    ry: 8mm
    place:
      center: panel.center
```

---

### Properties

#### center

```txt
point
```

#### rx

```txt
scalar-length
```

#### ry

```txt
scalar-length
```

#### rotation

```txt
angle
```

#### area

```txt
scalar-area
```

#### perimeter

```txt
scalar-length
```

`perimeter` adalah nilai pendekatan deterministik.

---

### Scalar Anchors

```txt
left
right
top
bottom

centerX
centerY
```

---

### Point Anchors

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

### ClosedShape Surface

Ellipse termasuk `ClosedShape`.

Karena itu ia kompatibel dengan:

1. `area`
2. boolean geometry
3. holes
4. query lintasan seperti `pointAt`, `tangentAt`, `normalAt`, dan `frameAt`

Ellipse juga sah diperlakukan sebagai `path-ref`.

Artinya object bertipe `ellipse` boleh dipakai langsung pada:

1. `on.path`
2. `on.frame`
3. `repeat.along`
4. query berbasis lintasan

Contoh:

```rg
objects:
  slotGuide:
    type: ellipse
    center: [80mm, 60mm]
    rx: 30mm
    ry: 12mm

  marker:
    type: rect
    size: [6mm, 4mm]
    on:
      path:
        path: slotGuide
        t: 0.25
```

---

### Validation

Rules minimum:

1. `rx > 0`
2. `ry > 0`
3. `rotation` default ke `0deg`
4. `size` tidak boleh dipakai bersamaan dengan `rx`/`ry`

Jika radius tidak valid, validator melempar `ELLIPSE_INVALID_RADIUS`.

Jika `size` dipakai bersama `rx`/`ry`, validator melempar `ELLIPSE_SIZE_CONFLICT`.

---

## 14.6 Arc

Arc merepresentasikan busur lingkaran.

---

### Center-Radius Mode

```rg
objects:
  arc1:
    type: arc

    center: O
    radius: 50mm

    startAngle: 0deg
    endAngle: 90deg
```

---

### Three Point Mode

```rg
objects:
  arc2:
    type: arc

    from: A
    through: B
    to: C
```

---

### Properties

#### start

```txt
point
```

#### end

```txt
point
```

#### center

```txt
point
```

jika tersedia (hanya pada mode Center-Radius).

#### length

```txt
scalar-length
```

---

### Anchors

```txt
start
end
center  (hanya pada Center-Radius Mode)
```

---

## 14.7 Quadratic

Quadratic merepresentasikan quadratic Bézier curve.

---

### Syntax

```rg
objects:
  curve:
    type: quadratic

    from: A
    cp: B
    to: C
```

---

### Properties

#### start

```txt
point
```

#### end

```txt
point
```

#### length

```txt
scalar-length
```

---

### Anchors

```txt
start
end
```

---

## 14.8 Cubic

Cubic merepresentasikan cubic Bézier curve.

---

### Syntax

```rg
objects:
  curve:
    type: cubic

    from: A
    cp1: B
    cp2: C
    to: D
```

---

### Properties

#### start

```txt
point
```

#### end

```txt
point
```

#### length

```txt
scalar-length
```

---

### Anchors

```txt
start
end
```

---

## 14.9 Path

Path merepresentasikan lintasan terbuka atau tertutup yang terdiri dari beberapa segmen.

Path aktif v0.5 memiliki tiga mode authoring resmi:

1. `points`
2. `segments`
3. `join`

---

### Point Shorthand

```rg
objects:
  guide:
    type: path

    points:
      - [0, 0]
      - [100, 0]
      - [100, 50]
```

---

### Segment Mode

`path.segments` menyusun lintasan secara berurutan. Segment pertama boleh berupa
`line`, `arc`, `quadratic`, atau `cubic`.

```rg
objects:
  outline:
    type: path

    segments:
      - line:
          from: A
          to: B

      - arc:
          through: C
          to: D
```

#### Initial Segment dan Chaining

Segment pertama wajib memiliki `from` eksplisit. Field lain yang wajib bergantung
pada jenis segment:

| Jenis segment | Field wajib pada segment pertama | Field wajib pada segment lanjutan |
|---|---|---|
| `line` | `from`, `to` | `to` |
| `arc` | `from`, `through`, `to` | `through`, `to` |
| `quadratic` | `from`, `cp`, `to` | `cp`, `to` |
| `cubic` | `from`, `cp1`, `cp2`, `to` | `cp1`, `cp2`, `to` |

Contoh initial curve:

```rg
objects:
  quadraticRoute:
    type: path
    segments:
      - quadratic:
          from: P1
          cp: C1
          to: P2

  cubicRoute:
    type: path
    segments:
      - cubic:
          from: P1
          cp1: C1
          cp2: C2
          to: P2
```

Setelah segment pertama, setiap segment memakai endpoint (`to`) segment
sebelumnya sebagai start point. `from` tidak boleh ditulis pada segment lanjutan
untuk semua jenis segment. Setiap segment memperbarui start point berikutnya ke
endpoint-nya sendiri.

```rg
objects:
  mixedRoute:
    type: path
    segments:
      - quadratic:
          from: P1
          cp: C1
          to: P2
      - cubic:
          cp1: C2
          cp2: C3
          to: P3
      - line:
          to: P4
```

Contoh tersebut membentuk lintasan `P1 → P2 → P3 → P4`. Control point hanya
membentuk curve dan tidak menjadi `currentPoint`.

Aturan ini hanya berlaku di dalam `path.segments`. Primitive standalone
`line`, `arc`, `quadratic`, dan `cubic` mempertahankan kontraknya masing-masing.
Resolver tidak melakukan snapping atau koreksi implicit jika endpoint tidak
tersambung.

Jika `from` hilang pada segment pertama, validator menghasilkan
`MISSING_REQUIRED_FIELD` pada path field `segments[0].<type>.from`. Jika `from`
muncul pada segment lanjutan, validator menghasilkan `UNKNOWN_FIELD` pada path
field `segments[i].<type>.from`.

---

### Relative Line Segment Commands

Di dalam `path.segments`, item `line` juga boleh memakai surface relatif terbatas untuk authoring jalur lurus berantai.

Contoh:

```rg
objects:
  pipeRoute:
    type: path
    segments:
      - line: { from: P1, to: P2 }
      - line: { turn: -90deg, forward: 10cm }
      - line: { turn: 45deg, forward: 5cm }
```

Boundary normatif:

1. surface ini hanya legal pada `line` yang berada di dalam `path.segments`
2. surface ini tidak mengubah kontrak primitive `line` global
3. scope awal v0.5 dibatasi hanya untuk segment `line`, bukan `arc`, `quadratic`, atau `cubic`
4. boundary ini adalah keputusan aktif v0.5 yang disengaja; authoring lintasan campuran tetap diarahkan ke `join`

#### Supported Fields

Field relatif yang legal pada line segment context:

```txt
direction
turn
forward
```

Rules:

1. `direction` boleh berupa enum arah atau angle eksplisit
2. `turn` harus bertipe angle
3. `forward` harus bertipe length dan bernilai `> 0`

#### Direction Values

Minimal direction enum bawaan:

```txt
right
left
up
down
up-right
up-left
down-right
down-left
```

Selain enum arah, `direction` juga boleh berupa angle eksplisit:

```rg
- line: { from: A, direction: 30deg, forward: 20mm }
```

#### Heading Rule

`turn` hanya valid jika heading sudah tersedia.

Heading boleh berasal dari:

```txt
line from-to
line direction + forward
previous line segment
```

Jika segment pertama tidak memiliki heading sebelumnya, ia wajib menyediakan:

1. `from` + `to`, atau
2. `from` + `direction` + `forward`

#### Validation Rules

Jika kontrak relatif ini dilanggar, validator/resolver memakai error berikut:

```txt
TURTLE_HEADING_UNAVAILABLE
INVALID_TURTLE_FORWARD
INVALID_TURTLE_TURN
```

### Join Mode

`join` menyusun path dari object geometri yang sudah ada.

```rg
objects:
  outline:
    type: path

    join:
      - topLine
      - rightArc
      - bottomLine
      - leftArc
```

Target `join` harus berupa object yang memiliki surface lintasan yang kompatibel.

Minimal target yang diizinkan:

```txt
line
arc
quadratic
cubic
path
polygon boundary
geometry operation result yang path-like
```

Catatan:

1. `join` adalah mode resmi `path`, bukan object terpisah
2. implementasi boleh me-lower `join` ke representasi segment internal, tetapi kontrak bahasa yang terlihat user tetap `path`

---

### Coexistence Rules

Field authoring berikut bersifat saling eksklusif:

```txt
points
segments
join
```

Rules:

1. tepat satu mode authoring harus dipilih
2. menggabungkan dua atau lebih mode sekaligus menghasilkan `OVER_CONSTRAINED`
3. `closeWith` hanya legal saat `path` memakai mode `join`

---

### Join Connectivity Rule

Untuk setiap pasangan item berurutan dalam `join`:

```txt
join[i].end harus sama dengan join[i+1].start
```

Perbandingan menggunakan tolerance numerik internal yang stabil.

Engine tidak boleh membalik arah object secara diam-diam.

Jika arah segment tidak sesuai, user harus eksplisit memakai object `reverse`.

Jika target tidak dapat dipakai sebagai path segment, engine melempar `INVALID_JOIN_TARGET`.

Jika dua item berurutan tidak tersambung, engine melempar `PATH_JOIN_GAP`.

Jika penyebab kegagalan adalah arah traversal yang salah pada target yang sebenarnya path-like, engine boleh memakai `PATH_JOIN_DIRECTION_MISMATCH` sebagai diagnostics yang lebih spesifik.

---

### Closed Path

```rg
objects:
  outline:
    type: path

    closed: true
```

Perilaku `closed`:

- **`closed: false`** (default): path terbuka. Properti `area` tidak tersedia, metadata `fill` diabaikan.
- **`closed: true`**: path tertutup. Mengaktifkan `area`, mengizinkan `fill`, dan mengaktifkan validasi closure sesuai mode authoring aktif.

> [!NOTE]
> Untuk mode `segments`, pengguna **tidak perlu menduplikasi titik secara manual**. Cukup pastikan koordinat titik akhir segmen terakhir sama dengan titik awal segmen pertama. Engine akan memvalidasi kondisi ini secara otomatis.

Rules per mode:

1. untuk `points`, titik terakhir dan titik pertama harus membentuk boundary tertutup yang valid menurut resolver
2. untuk `segments`, titik `to` pada segmen terakhir harus sama dengan titik `from` segmen pertama
3. untuk `join`, item terakhir harus berakhir di titik awal item pertama, kecuali `closeWith: line` dipakai

Jika closure yang diwajibkan tidak terpenuhi, engine melempar `PATH_NOT_CLOSED`.

---

### closeWith

`closeWith` adalah helper closure eksplisit untuk mode `join`.

```rg
objects:
  halfProfile:
    type: path
    join:
      - upperCurve
      - lowerCurve
    closed: true
    closeWith: line
```

Nilai yang aktif di v0.5:

```txt
none
line
```

Default:

```rg
closeWith: none
```

Semantics:

1. `closeWith: none` tidak menambahkan segmen baru
2. `closeWith: line` menambahkan segmen garis lurus dari ujung item terakhir ke titik awal item pertama
3. jika `closeWith` dipakai di luar mode `join`, validator melempar `INVALID_CLOSE_WITH`
4. jika `closed: false`, `closeWith` harus diabaikan atau ditolak; untuk kontrak v0.5 lebih aman ditolak sebagai `INVALID_CLOSE_WITH`

---

### Properties

#### start

```txt
point
```

#### end

```txt
point
```

#### length

```txt
scalar-length
```

#### area

```txt
scalar-area
```

hanya tersedia jika:

```rg
closed: true
```

---

### Holes

```rg
objects:
  plate:
    type: path

    closed: true

    holes:
      - circle:
          center: plate.center
          radius: 5mm
```

---

### Corner Processing

#### Global

```rg
corner:
  all:
    fillet: 5mm
```

---

#### Per Corner

```rg
corners:
  B:
    fillet: 5mm

  C:
    chamfer: 3mm
```

---

## 14.10 Polygon

Polygon adalah shorthand untuk closed path berbasis titik sudut.

---

### Syntax

```rg
objects:
  bracket:
    type: polygon

    points:
      - [0, 0]
      - [100, 0]
      - [100, 50]
      - [0, 50]
```

---

### Properties

Polygon mendukung:

```txt
area
left
right
top
bottom

center
centerX
centerY
```

dan seluruh 9-point anchor.

---

### Corner Processing

Polygon mendukung:

```txt
fillet
chamfer
```

melalui:

```rg
corner:
corners:
```

---

### Holes

Polygon mendukung holes secara penuh.

---

## 14.11 Text

Text merepresentasikan label atau anotasi geometri ringan.

---

### Syntax

```rg
objects:
  label:
    type: text

    content: "Rear Panel"
```

---

### Placement

```rg
objects:
  label:
    type: text

    content: "Rear Panel"

    place:
      centerX: panel.centerX
      top: panel.bottom + 5mm
```

---

### Anchors

Nilai yang didukung:

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

Default:

```txt
center
```

---

### Properties

Text mendukung seluruh anchor bounding box standar (left, right, top, bottom, center, dll).

### Styling & Metadata

Text mendukung rendering multi-line via karakter `\n` dan styling mendetail via blok `meta`:

```rg
objects:
  label:
    type: text
    content: "Baris 1\nBaris 2"
    meta:
      fontFamily: "monospace"
      fontSize: 14
      fill: "#ff0000"
```

Semantics normatif:

- Jika `meta.fontFamily` tidak ditentukan, renderer harus memakai keluarga font default yang netral, setara `sans-serif`
- Jika `meta.fontSize` tidak ditentukan, renderer harus memakai ukuran default `12` unit scene
- Jika `meta.lineHeight` tidak ditentukan, fallback measurement text harus memakai baseline `1.0`
- Object `text` tetap termasuk object yang dapat di-*place*; field `place` tetap menentukan hasil positioning/alignment seperti object lain
- Posisi `(x, y)` pada object `text` merepresentasikan origin visual untuk sudut kiri-atas baris pertama
- Renderer berbasis baseline (misalnya SVG) harus memakai semantics yang ekuivalen dengan `dominant-baseline: hanging`, atau mekanisme lain yang menghasilkan posisi visual yang sama
- Text multi-line harus mempertahankan urutan baris dari atas ke bawah

Ukuran aktual glyph tetap ditentukan oleh renderer. Implementasi boleh memakai text measurement provider atau injection mechanism internal untuk menghitung metrik glyph, selama hasil akhirnya tetap mematuhi kontrak anchor, `place`, dan origin text yang konsisten secara spasial.

Jika implementasi tidak memiliki provider measurement yang lebih akurat dan harus memakai fallback aproksimasi, baseline yang direkomendasikan adalah:

- `width ≈ longestLineLength × fontSize × 0.6`
- `height ≈ lineCount × fontSize × lineHeight`
- `ascent ≈ fontSize × 0.8`
- `descent ≈ fontSize × 0.2`

Implementasi boleh memakai aproksimasi lain, tetapi hasilnya sebaiknya tetap dekat dengan baseline ini agar drift lintas-renderer tidak membesar.

---

[← 13. Object Model](13-object-model.md) &nbsp;|&nbsp; [↑ Index](README.md) &nbsp;|&nbsp; [15. Composition Objects →](15-composition-objects.md)
