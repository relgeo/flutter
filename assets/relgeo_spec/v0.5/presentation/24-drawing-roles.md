# 24. Drawing Roles

Status dokumen: `Normative`

Role mengelompokkan object berdasarkan fungsi visual/teknis. Renderer dan tools dapat menerapkan style atau visibility yang berbeda berdasarkan role.

Dalam pembacaan konseptual RelGeo, `drawing roles` berada di lapisan presentasi.

Sebagian semantics-nya dapat berfungsi sebagai capability yang reusable, tetapi himpunan role aktif `v0.5` juga memuat muatan yang berat ke domain `technical drawing`.

---

## 24.1 Syntax

```rg
objects:
  centerAxis:
    type: line
    from: panel.top
    to: panel.bottom
    meta:
      role: centerline
```

---

## 24.2 Supported Roles

| Role           | Deskripsi |
|----------------|-----------|
| `final`        | (Default) Objek utama yang dicetak/diekspor |
| `construction` | Objek bantu geometri, tidak diekspor ke output final |
| `guide`        | Garis panduan visual |
| `dimension`    | Objek dimensi/ukuran |
| `annotation`   | Teks anotasi |
| `centerline`   | Garis sumbu (center axis) |
| `hidden`       | Garis tersembunyi (hidden line drawing) |
| `section`      | Garis potongan (section view) |
| `cut`          | Garis potong |
| `fold`         | Garis lipatan (sheet metal) |

---

## 24.3 Semantics

- Jika `meta.role` tidak ditentukan, default ke `"final"`
- Role `"construction"` dan `"guide"` **selalu diabaikan** dalam perhitungan bounding box global
- Role `"construction"` dan `"guide"` juga diabaikan dari bounding box view (lihat [25. Views and Sheets](25-views-sheets.md))
- Renderer dapat menerapkan style berbeda per role (garis putus-putus untuk `hidden`, warna khusus untuk `centerline`, dll)
- Filter role pada `views` memungkinkan view menampilkan subset role tertentu saja

---

## 24.4 Default Final Output Visibility

Spec bahasa menetapkan default visibility role untuk output final lintas-renderer.

| Role | Default di output final |
|------|--------------------------|
| `final` | tampil |
| `construction` | tersembunyi |
| `guide` | tampil |
| `dimension` | tampil |
| `annotation` | tampil |
| `centerline` | tampil |
| `hidden` | tampil |
| `section` | tampil |
| `cut` | tampil |
| `fold` | tampil |

Semantics:

- Default ini berlaku sebagai baseline untuk renderer RelGeo
- Renderer boleh menyediakan option override untuk inspection, debug, atau mode kerja lain
- Override renderer tidak mengubah makna role di level bahasa; ia hanya mengubah presentasi pada render tertentu
- Jika tidak ada override eksplisit, renderer harus mengikuti default pada tabel di atas

## 24.5 Default Final Output Palette

Spec aktif `v0.5` juga membakukan baseline palette untuk final output lintas-renderer ketika object tidak memberi `meta.stroke` eksplisit.

| Role | Default stroke/final-output color |
|------|-----------------------------------|
| `final` | `#000000` |
| `construction` | `#3B82F6` |
| `guide` | `#3B82F6` |
| `dimension` | `#000000` |
| `annotation` | `#000000` |
| `centerline` | `#FF0000` |
| `hidden` | `#555555` |
| `section` | `#000000` |
| `cut` | `#000000` |
| `fold` | `#000000` |

Semantics:

- Tabel ini berlaku untuk default final-output renderer, bukan untuk tema workbench/editor
- Renderer preview interaktif boleh memakai palette kerja yang berbeda selama jalur final-output tetap mengikuti baseline ini
- `meta.stroke` eksplisit selalu menang atas warna default role
- `dimension` dan `annotation` tetap mengikuti aturan default fill text masing-masing:
  - `dimension` text fallback: setara `#444444`
  - `annotation` text fallback: setara `#333333`
- Dash pattern atau style role lain tetap boleh berbeda per role, selama warna default final-output mengikuti tabel ini

## 24.6 Default Final Output Dash Pattern

Spec aktif `v0.5` juga membakukan baseline dash pattern untuk final output ketika object tidak memberi `meta.dash` eksplisit.

| Role | Default dash pattern final-output |
|------|-----------------------------------|
| `construction` | `2 2` |
| `guide` | `2 2` |
| `hidden` | `6 4` |
| `centerline` | `12 3 3 3` |
| `fold` | solid |
| lainnya | solid |

Semantics:

- Tabel ini berlaku untuk final-output renderer, bukan tema preview/editor
- `meta.dash` eksplisit selalu menang atas default role
- Renderer preview interaktif boleh memakai pattern berbeda untuk kebutuhan UX, selama jalur final-output tetap mengikuti baseline ini
- Jika role tidak tercantum sebagai dashed role pada tabel, renderer final-output harus jatuh ke garis solid secara default

## 24.7 Default Final Output Stroke Width

Spec aktif `v0.5` membakukan baseline stroke width final-output berikut:

- Jika object memiliki stroke terlihat tetapi tidak memberi `meta.strokeWidth` eksplisit, fallback width final-output adalah `0.5`
- Jika `meta.strokeWidth` eksplisit diberikan, nilai itu menang
- Aturan ini berlaku juga untuk object presentasional seperti `dimension` dan `annotation` pada jalur final-output
- Renderer preview/editor boleh memakai strategi lain untuk keterbacaan workspace, selama final-output tetap mengikuti baseline ini

---

[← 23. Annotation Objects](23-annotation.md) &nbsp;|&nbsp; [↑ Index](README.md) &nbsp;|&nbsp; [25. Views and Sheets →](25-views-sheets.md)
