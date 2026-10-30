# 11. Profiles

Status dokumen: `Normative`

`profiles` di RelGeo dipakai untuk preset parameter.

Tujuannya adalah memberi cara praktis untuk mengubah banyak nilai parameter sekaligus tanpa mengubah struktur object.

Contoh:

```rg
parameters:
  width:
    type: length
    default: 100mm

profiles:
  large:
    width: 200mm
  compact:
    width: 60mm
```

Profile ini diaktifkan saat dokumen di-resolve dengan opsi `profile: large`.

---

## 11.1 Parameter Profile

```rg
profiles:
  large:
    width: 200mm
    height: 150mm
```

Aturan:
- Profile **boleh** mengoverride nilai `parameters`.
- Profile **tidak boleh** mengoverride `constants`.
- Runtime internal tetap hanya peduli pada nilai parameter final setelah preset dipilih.

---

## 11.2 Semantics

`profiles`:

1. bekerja pada lapisan input / preset
2. tidak menjadi field common object
3. tidak dipakai untuk reusable object styling
4. tidak mengubah dependency graph selain lewat nilai parameter akhir

Jika dibutuhkan shorthand reusable untuk `meta`, gunakan mekanisme `metaPresets` / `metaPreset`, bukan `profiles`.

Jika dibutuhkan reuse map terstruktur untuk `params` atau `meta`, gunakan `inherit` pada surface yang memang mendukungnya, bukan `profiles`.

---

[← 10. Derived Values](10-derived.md) &nbsp;|&nbsp; [↑ Index](README.md) &nbsp;|&nbsp; [12. Expressions →](12-expressions.md)
