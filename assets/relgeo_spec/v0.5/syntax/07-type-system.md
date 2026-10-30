# 7. Type System

Status dokumen: `Normative`

RelGeo menggunakan sistem tipe eksplisit.

Seluruh parameter, constant, derived value, query result, dan property turunan memiliki tipe yang terdefinisi.

---

## 7.1 Scalar Types

### length

Nilai panjang.

Contoh:

```rg
10mm
25cm
4in
```

Semua nilai `length` dievaluasi relatif terhadap `scene.unit` dan disimpan dalam bentuk yang sudah ternormalisasi oleh resolver.

---

### number

Nilai numerik tanpa satuan.

Contoh:

```rg
5
12.5
```

---

### angle

Nilai sudut.

Contoh:

```rg
45deg
90deg
```

---

### percent

Nilai persentase.

Contoh:

```rg
50%
```

Nilai `percent` mempertahankan makna proporsional. Implementasi boleh menormalkannya ke representasi numerik internal selama kontrak semantiknya tetap sama.

---

### boolean

Nilai logika.

Contoh:

```rg
true
false
```

---

### string

Nilai teks.

Contoh:

```rg
"Rear Panel"
```

---

## 7.2 Structured Types

### point

Koordinat dua dimensi.

```rg
[10mm, 20mm]
```

---

### vector

Representasi arah atau perpindahan dalam 2D.

Contoh:

```rg
[1, 0]   # vektor ke kanan
[0, -1]  # vektor ke atas (y-down)
```

---

### array

Kumpulan nilai berurutan.

```rg
- 10
- 20
- 30
```

---

### object

Kumpulan field bernama.

```rg
diameter: 6mm
count: 4
```

---

### frame2d

Representasi posisi dan orientasi pada suatu titik di lintasan.

Field yang dikandung:

```txt
point    (wajib) — koordinat 2D posisi
angle    (wajib) — sudut orientasi dalam radian
tangent  (turunan) — vektor tangent di posisi tersebut
normal   (turunan) — vektor normal di posisi tersebut
```

`tangent` dan `normal` dapat diturunkan dari `angle`. Keduanya bersifat read-only.

Contoh akses field `frame2d`:

```rg
derived:
  posisi: frameAt(outline, 0.25).point
  sudut:  frameAt(outline, 0.25).angle
  normal: frameAt(outline, 0.25).normal
```

---

### bbox2d

Representasi world-space bounding box yang dihasilkan oleh query `bbox(...)`.

Field yang dikandung:

```txt
minX    (wajib) — batas kiri bbox
maxX    (wajib) — batas kanan bbox
minY    (wajib) — batas atas bbox
maxY    (wajib) — batas bawah bbox
width   (wajib) — lebar bbox
height  (wajib) — tinggi bbox
```

Contoh akses field `bbox2d`:

```rg
derived:
  panelBox: bbox(panel)
  panelLeft: bbox(panel).minX
  panelWidth: bbox(panel).width
```

Catatan:

1. `bbox2d` adalah hasil query, bukan object geometri biasa
2. `bbox2d` tidak otomatis menjadi `PlaceableObject`
3. `bbox2d` tidak otomatis memiliki seluruh anchors object biasa

---

### collection

Kumpulan objek runtime yang dihasilkan oleh sistem.

Contoh sumber collection:

```txt
repeat
divide
split (tanpa `pick`)
multi-result intersection
multi-result boolean
```

---

### path-ref

Referensi ke geometri berbasis lintasan. Digunakan sebagai parameter untuk `on.path`, `on.frame`, query seperti `pointAt`, `tangentAt`, `frameAt`, dll.

Surface ini juga menjadi dasar konseptual untuk item pada `path.join`.

Tipe ini tidak diinstansiasi secara eksplisit - melainkan diperoleh dengan merujuk nama object bertipe `line`, `arc`, `ellipse`, `path`, `polygon`, bentuk tertutup apapun, atau geometry operation result yang tetap/path-like:

```rg
objects:
  outline:
    type: path
    ...

  marker:
    type: rect
    on:
      path:
        ref: outline   # outline adalah path-ref
        t: 0.5
```

Jika sebuah geometry operation object menghasilkan surface lintasan yang kompatibel, result tersebut juga sah diperlakukan sebagai `path-ref`.

Khusus untuk `split`:

1. jika `pick: first | last` dipakai, hasil tunggalnya sah diperlakukan sebagai `path-ref`
2. jika `pick` tidak dipakai, hasilnya adalah `collection` yang item-itemnya masing-masing tetap path-like

Catatan:

1. `ellipse` berada pada level yang sama dengan primitive lintasan lain dalam surface ini
2. `ellipse` tidak hanya closed shape untuk `area`, tetapi juga lintasan deterministik untuk `pointAt`, `tangentAt`, `normalAt`, `frameAt`, dan `tAtLength`

Contoh:

```rg
objects:
  leftArc:
    type: arc
    ...

  rightArc:
    type: reverse
    target: leftArc

  marker:
    type: rect
    on:
      path:
        ref: rightArc
        t: 0.5
```

---

### ClosedShape

Surface semantik untuk object tertutup 2D yang sah dipakai pada query seperti `area(...)` dan `perimeter(...)`.

Target minimum yang termasuk `ClosedShape`:

```txt
rect
circle
ellipse
polygon
boolean result
path tertutup
geometry operation result yang tetap tertutup
```

Catatan:

1. `ClosedShape` adalah surface eligibility, bukan syntax type yang ditulis author secara eksplisit
2. target yang termasuk `ClosedShape` boleh tetap path-like pada saat yang sama
3. target `ClosedShape` yang path-like tetap sah dipakai pada `length(...)`

---

## 7.3 Type Safety

Resolver wajib:

- mempertahankan tipe hasil evaluasi
- memvalidasi operasi antar tipe
- menghasilkan error jika tipe tidak kompatibel

Tidak diperbolehkan melakukan konversi implisit yang dapat mengubah makna geometris.

---

## 7.4 Contextual Numeric Semantics

RelGeo membedakan angka murni sebagai `number` dari angka yang dipakai sebagai panjang kontekstual.

Aturan umum:

1. pada konteks yang mengharapkan `length`, angka tanpa unit diperlakukan sebagai panjang dalam `scene.unit`
2. pada konteks aritmetika skalar, angka tanpa unit tetap bertipe `number`
3. satuan eksplisit selalu lebih kuat daripada default context

Contoh:

```txt
width: 72        → 72 dalam scene.unit
10 * 20cm        → 200cm
100cm / 2        → 50cm
```

---

## 7.5 Unit and Coercion Contract

Untuk spec aktif v0.5, coercion yang dianggap sah harus tetap sempit dan deterministik.

Aturan minimum:

1. `length + length` dan `length - length` sah
2. `number * length` dan `length / number` sah
3. `number + number`, `number - number`, `number * number`, `number / number` sah
4. `length * length` tidak sah
5. operasi campuran yang mengaburkan makna geometri harus ditolak

Contoh:

```txt
10cm + 5mm     -> sah
2 * 10cm       -> sah
10cm / 2       -> sah
10cm * 5cm     -> invalid
10cm + true    -> invalid
```

Aturan unitless number:

1. angka tanpa unit hanya boleh diperlakukan sebagai `length` bila konteksnya memang mengharapkan panjang
2. di luar konteks panjang, angka tanpa unit tetap `number`
3. implementasi tidak boleh mengonversi `number` ke `length` hanya karena "terasa masuk akal" tanpa konteks yang eksplisit

Aturan string coercion minimum:

1. coercion implisit ke `string` hanya sah pada family fungsi string aktif seperti `concat(...)` dan `format(...)`
2. di luar surface itu, implementasi tidak boleh diam-diam mengubah nilai typed menjadi `string`

Catatan:

1. kontrak ini sengaja sempit agar bahasa tetap relation-first dan dapat diprediksi
2. perluasan coercion di luar daftar ini sebaiknya diperlakukan sebagai proposal versi berikutnya, bukan asumsi aktif v0.5

---

[← 6. Error Model](../core/06-error-model.md) &nbsp;|&nbsp; [↑ Index](README.md) &nbsp;|&nbsp; [8. Parameters →](08-parameters.md)
