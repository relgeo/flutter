# 2. Document Structure

Status dokumen: `Normative`

## 2.1 Root Structure

Dokumen RelGeo menggunakan struktur tingkat atas berikut:

```rg
version: 0.5

scene:

parameters:

constants:

derived:

profiles:

metaPresets:

components:

objects:

constraints:

views:

sheets:

meta:
```

Seluruh section bersifat opsional kecuali ditentukan lain oleh preset parameter tertentu.

> [!NOTE]
> Jika `version` tidak ditulis, parser boleh mengasumsikan versi spec aktif yang diimplementasikan runtime saat itu. Pada kontrak aktif saat dokumen ini ditulis, default tersebut adalah `0.5`.

---

## 2.2 Minimal Document

Contoh dokumen RelGeo paling sederhana:

```rg
objects:
  p1:
    type: point
    at: [0, 0]
```

---

## 2.3 Section Overview

| Section        | Wajib | Keterangan | Detail |
|----------------|-------|------------|--------|
| `version`      | ✗     | Versi spesifikasi RelGeo yang digunakan. Jika tidak ditulis, runtime boleh memakai versi spec aktifnya sebagai default | — |
| `scene`        | ✗     | Konfigurasi unit, orientasi, origin, padding | [→ 3. Scene](03-scene.md) |
| `parameters`   | ✗     | Input yang dapat diubah pengguna, dengan default dan constraints | [→ 8. Parameters](../syntax/08-parameters.md) |
| `constants`    | ✗     | Nilai tetap yang tidak dapat diubah saat runtime | [→ 9. Constants](../syntax/09-constants.md) |
| `derived`      | ✗     | Nilai hasil ekspresi, tergantung pada parameters/constants/anchors | [→ 10. Derived Values](../syntax/10-derived.md) |
| `profiles`     | ✗     | Preset override untuk `parameters` | [→ 11. Profiles](../syntax/11-profiles.md) |
| `metaPresets`  | ✗     | Preset reusable untuk bundle `meta` object | [→ 26. Metadata](../presentation/26-metadata.md) |
| `components`   | ✗     | Definisi template komponen yang dapat diinstansiasi | [→ 15. Composition Objects](../geometry/15-composition-objects.md) |
| `objects`      | ✗*    | Objek geometri utama | [→ 14. Geometry Objects](../geometry/14-geometry-objects.md) |
| `constraints`  | ✗     | Validasi hubungan geometri | [→ 21. Constraints](../geometry/21-constraints.md) |
| `views`        | ✗     | Snapshot tampilan subset geometri dengan skala | [→ 25. Views and Sheets](../presentation/25-views-sheets.md) |
| `sheets`       | ✗     | Komposisi lembar gambar dari views | [→ 25. Views and Sheets](../presentation/25-views-sheets.md) |
| `meta`         | ✗     | Metadata tingkat dokumen | [→ 26. Metadata](../presentation/26-metadata.md) |

> [!NOTE]
> `objects` secara teknis opsional - dokumen tanpa objects valid secara sintaks, namun tidak menghasilkan geometri apapun.

> [!NOTE]
> `meta` pada root berbeda dari `scene`. `scene` hanya untuk konfigurasi perilaku global, sedangkan metadata dokumen berada di `<root>.meta`. `scene.meta` bukan bagian dari spec aktif.

---

[← 1. Overview](01-overview.md) &nbsp;|&nbsp; [↑ Index](README.md) &nbsp;|&nbsp; [3. Scene →](03-scene.md)
