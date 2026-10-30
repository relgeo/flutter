# 3. Scene

Status dokumen: `Normative`

Section `scene` mendefinisikan perilaku global dokumen.

`scene` bukan kantong metadata umum. Informasi tambahan yang tidak memengaruhi geometri atau viewport harus ditulis di `<root>.meta`, bukan di `scene.meta`.

## 3.1 Syntax

```rg
scene:
  unit: mm
  orientation: y-down
  autoSize: true
  padding: 20
```

---

## 3.2 Fields

Field yang valid di dalam `scene` terbatas pada:

```txt
unit
origin
orientation
autoSize
padding
```

> [!WARNING]
> `scene.meta` bukan bagian dari kontrak bahasa aktif.

### unit

Menentukan satuan panjang default dokumen.

Nilai yang didukung:

```txt
mm
cm
m
in
px
```

Jika tidak ditentukan:

```txt
px
```

digunakan sebagai default.

Semua nilai panjang pada dokumen dinormalisasi terhadap `scene.unit` selama proses resolve. Satuan eksplisit tetap diperbolehkan dan harus dikonversi ke unit scene sebelum dipakai oleh runtime geometri.

> [!NOTE]
> Angka tanpa unit di konteks yang mengharapkan panjang dibaca menggunakan `scene.unit`, kecuali aturan field tertentu menyatakan lain.

---

### origin

Lokasi titik (0,0) pada viewport. Bersifat visual (*viewport shift*).

Nilai:

```txt
top-left
```

Default:

```txt
top-left
```

> [!IMPORTANT]
> `origin` mengatur posisi titik (0,0) di layar, tetapi **tidak** mengubah sistem koordinat internal. Gunakan `orientation: y-up` jika ingin membalik sumbu Y (Cartesian).

---

### orientation

Menentukan arah sumbu Y global.

Nilai:

```txt
y-down
y-up
```

Default:

```txt
y-down
```

---

### autoSize

Menentukan apakah ukuran *viewport* gambar (`viewBox`) dihitung otomatis dari batas geometri. RelGeo menghitung *Recursive Bounding Box* dari semua elemen terlihat setelah transformasi untuk menjamin seluruh objek termuat (zoom-to-fit). Jika `padding` didefinisikan, ia akan ditambahkan di sekeliling area tersebut.

Tipe:

```txt
boolean
```

Default:

```txt
true
```

---

### padding

Margin tambahan di sekitar batas geometri.

Contoh:

```rg
padding: 20
```

menggunakan satuan `scene.unit`.

```rg
padding: 10mm
```

menggunakan satuan eksplisit.

Jika tidak ditentukan, sistem menerapkan padding visual sebesar:

```txt
20px
```

yang dikonversi ke satuan scene.

---

## 3.3 Coordinate Space

RelGeo menggunakan satu ruang koordinat dunia (*world space*).

Transformasi objek, clone, dan placement menghasilkan koordinat dunia final yang dapat diakses melalui anchor dan query.

> [!NOTE]
> **Post-Transform Access**: Secara otomatis, mengakses *anchor* dari objek yang berada di dalam `group` atau `clone` akan mengembalikan koordinat dunia hasil transformasi (*Post-Transform*). Sebaliknya, komponen internal di dalam *group* yang sama akan tetap berkomunikasi secara geometris menggunakan keadaan asli objek (*Pre-Transform*) untuk menjamin modularitas.

---

## 3.4 Unit Normalization

Resolver wajib menerapkan normalisasi satuan secara deterministik:

1. nilai panjang eksplisit seperti `10mm` atau `2m` dikonversi ke `scene.unit`
2. angka tanpa unit yang berada di konteks panjang diperlakukan sebagai panjang dalam `scene.unit`
3. nilai numerik murni tetap bertipe `number` jika konteksnya memang mengharapkan skalar

Contoh:

```txt
scene.unit = cm

1m   → 100cm
10cm → 10cm
5mm  → 0.5cm
```

---

## 3.5 Unit and Coercion Baseline

`scene.unit` adalah baseline untuk seluruh panjang default dokumen.

Implikasinya:

1. angka tanpa unit yang masuk ke field atau ekspresi bertipe `length` dibaca dalam `scene.unit`
2. angka tanpa unit yang tidak berada di konteks panjang tetap `number`
3. satuan eksplisit seperti `mm`, `cm`, `m`, `in`, dan `px` harus selalu menang atas baseline `scene.unit`

Contoh:

```txt
scene.unit = mm

width: 25      -> 25mm
radius: 2cm    -> 20mm
count: 25      -> number, bukan 25mm
```

Catatan:

1. kontrak coercion lengkap tetap dijelaskan di [../syntax/07-type-system.md](../syntax/07-type-system.md)
2. bab `scene` ini hanya menetapkan baseline globalnya

---

[← 2. Document Structure](02-document-structure.md) &nbsp;|&nbsp; [↑ Index](README.md) &nbsp;|&nbsp; [4. Evaluation Order →](04-evaluation-order.md)
