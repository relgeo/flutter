# 8. Parameters

Status dokumen: `Normative`

Section `parameters` mendefinisikan kontrak input dokumen yang dapat diubah pengguna.

Catatan penting:

1. `parameters` adalah deklarasi input
2. ia menjelaskan nama, tipe, default, dan batasan input
3. ia berbeda dari `params` pada instance `component`
4. `params` adalah nilai input aktual yang dikirim ke satu instance component tertentu

## 8.1 Basic Syntax

```rg
parameters:
  width:
    type: length
    default: 100mm
```

---

## 8.2 Fields

### type

Tipe parameter.

Wajib ditentukan.

### default

Nilai bawaan parameter.

Opsional tetapi direkomendasikan.

---

### 8.2.1 Shorthand Syntax

Untuk kemudahan penulisan, RelGeo mendukung sintaks *shorthand* di mana nilai parameter atau konstanta dapat ditulis langsung tanpa pembungkus objek.

**Format Standar:**
```rg
parameters:
  lebar:
    type: length
    default: 100mm
```

**Format Shorthand:**
```rg
parameters:
  lebar: 100mm
```

> [!NOTE]
> Format *shorthand* secara otomatis memperlakukan nilai sebagai tipe data yang sesuai dengan nilainya (angka, string, boolean, atau panjang dengan unit). Fitur tambahan seperti `min`, `max`, atau `description` tetap membutuhkan format standar.

---

## 8.2.2 Parameters vs Params

Pemisahan istilah yang dipakai RelGeo:

1. `parameters`
   Kontrak input yang dideklarasikan pada root document atau definisi component.
2. `params`
   Nilai input aktual untuk satu instance component.

Contoh:

```rg
components:
  boltHole:
    parameters:
      diameter:
        type: length
        default: 6mm

objects:
  h1:
    type: component
    use: boltHole
    params:
      diameter: 8mm
```

Maknanya:

1. `parameters` pada `boltHole` mendefinisikan input yang sah
2. `params` pada `h1` memberi nilai aktual untuk instance itu
3. jika satu field tidak diisi di `params`, default dari `parameters` tetap berlaku

---

## 8.3 Scalar Parameters

```rg
parameters:
  width:
    type: length
    default: 100mm

  count:
    type: number
    default: 4

  angle:
    type: angle
    default: 45deg
```

---

## 8.4 Point Parameters

```rg
parameters:
  startPoint:
    type: point
    default: [10mm, 20mm]
```

---

## 8.5 Array Parameters

```rg
parameters:
  mountingPoints:
    type: array
    items: point
```

---

## 8.6 Object Parameters

```rg
parameters:
  bolt:
    type: object

    properties:
      diameter: length
      spacing: length
      count: number

    default:
      diameter: 6mm
      spacing: 20mm
      count: 4
```

---

[← 7. Type System](07-type-system.md) &nbsp;|&nbsp; [↑ Index](README.md) &nbsp;|&nbsp; [9. Constants →](09-constants.md)
