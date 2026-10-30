# 12. Expressions

Status dokumen: `Normative`

RelGeo mendukung ekspresi deklaratif untuk menghitung nilai numerik, geometri, dan hasil query.

Bab ini merangkum semua operator dan fungsi yang tersedia.

---

## 12.1 Arithmetic Operators

Operator berikut didukung:

```txt
+
-
*
/
%
^
```

Contoh:

```rg
derived:
  radius:
    value: diameter / 2
```

### Precedence

Urutan prioritas operator:

```txt
1. ()
2. unary !
3. ^
4. * / %
5. + -
6. comparison operators
7. &&
8. ||
9. ternary ? :
```

---

## 12.2 Built-in Functions

RelGeo menyediakan berbagai fungsi matematika dan geometri bawaan:

### Matematika

```txt
min(a, b)           → nilai minimum
max(a, b)           → nilai maksimum
abs(x)              → nilai absolut
clamp(x, min, max)  → membatasi x dalam rentang [min, max]
round(x)            → pembulatan
floor(x)            → pembulatan ke bawah
ceil(x)             → pembulatan ke atas
sqrt(x)             → akar kuadrat
sin(angle)          → sinus (input: angle type)
cos(angle)          → kosinus
tan(angle)          → tangen
```

### Geometri

```txt
distance(A, B)      → panjang antara dua titik
length(path)        → panjang total geometri
perimeter(shape)    → keliling closed-shape
bbox(target)        → world-space bounding box minimum
midpoint(A, B)      → titik tengah antara dua titik
polar(C, r, angle)  → titik dari pusat, radius, dan sudut
angleBetween(A, B)  → arah dari titik A ke titik B
width(target)       → lebar bounding box target
height(target)      → tinggi bounding box target
minX(target)        → batas kiri bounding box target
maxX(target)        → batas kanan bounding box target
minY(target)        → batas atas bounding box target
maxY(target)        → batas bawah bounding box target
project(P, line)    → proyeksi ortogonal titik ke line
reflect(P, target)  → refleksi titik terhadap point atau line
pointAt(path, t)    → titik pada parameter t ∈ [0, 1]
```

Catatan:

1. `angleBetween(A, B)` pada v0.5 dibatasi untuk dua point, bukan overload vector-to-vector
2. `bbox(target)` pada v0.5 menghasilkan record `bbox2d` minimum dengan field `minX`, `maxX`, `minY`, `maxY`, `width`, dan `height`
3. family `width/height/minX/maxX/minY/maxY` pada v0.5 dibaca terhadap world-space bounding box target
4. `project(P, line)` pada v0.5 hanya sah untuk target `line`
5. `reflect(P, target)` pada v0.5 hanya sah untuk target `point` atau `line`

### String

```rg
derived:
  label: concat("Part-", partNo)
  initial: charAt("Agus", 0)    # → "A"
  info: format("{} × {}", width, height)
```

Kontrak minimum v0.5:

```txt
concat(...values)        -> string
format(template, ...values) -> string
charAt(text, index)      -> string
```

Catatan:

1. `concat(...)` dan `format(...)` boleh menerima nilai non-string dan mengonversinya ke representasi string secara deterministik
2. `format(...)` adalah surface formatting minimum, bukan bahasa formatting yang lebih luas
3. `charAt(...)` mengambil satu karakter pada indeks yang diberikan
4. `toString(...)` bukan bagian surface aktif v0.5

Contoh tambahan:

```rg
derived:
  note: format("R={} mm", radius)
  tag: concat("Hole-", index)
```

Jika fungsi tidak dikenal atau argumennya tidak valid terhadap kontrak tipenya, resolver harus menghasilkan `INVALID_EXPRESSION`.

---

## 12.3 Comparison Operators

Operator berikut menghasilkan nilai boolean:

```txt
==
!=
<
>
<=
>=
```

---

## 12.4 Logical Operators

Operator berikut didukung:

```txt
&&
||
!
```

---

## 12.5 Ternary Expression

Format:

```txt
condition ? valueA : valueB
```

Contoh:

```rg
derived:
  width:
    value: compact ? 80mm : 120mm
```

---

## 12.6 References

Ekspresi dapat mereferensikan:

```txt
parameters
constants
derived values
object properties
anchors
queries
```

Contoh:

```rg
panel.width
panel.centerX
hole.radius
```

---

## 12.7 Type Rules

Operasi berikut valid secara umum:

```txt
length + length
length - length
number * length
length / number
number + number
```

Operasi yang mengubah makna geometris secara ambigu harus ditolak.

Contoh:

```txt
length * length   → invalid
10cm + true       → invalid
```

Jika salah satu operand pada penjumlahan atau pengurangan bertipe `length` dan operand lainnya adalah angka tanpa unit yang berada di konteks panjang, angka tersebut diperlakukan sebagai `scene.unit`.

---

## 12.8 Evaluation Constraints

Ekspresi RelGeo harus:

```txt
deterministic
side-effect free
context dependent hanya melalui reference eksplisit
```

Kondisi berikut wajib menghasilkan error:

1. pembagian dengan nol
2. fungsi yang tidak dikenal
3. identifier yang tidak dikenal
4. operator yang tidak didukung

---

[← 11. Profiles](11-profiles.md) &nbsp;|&nbsp; [↑ Index](README.md) &nbsp;|&nbsp; [13. Object Model →](../geometry/13-object-model.md)
