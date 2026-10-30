# 6. Error Model

Status dokumen: `Normative`

Resolver dan validator menghasilkan error yang deterministik. Setiap error memiliki kode unik dan path ke lokasi masalah dalam dokumen.

---

## 6.1 Resolution Errors

Error yang terjadi selama evaluasi dependency graph dan ekspresi.

| Kode | Kondisi |
|------|---------|
| `UNKNOWN_REFERENCE` | Merujuk ke ID object, parameter, atau constant yang tidak terdefinisi |
| `CIRCULAR_DEPENDENCY` | Dua atau lebih nilai saling bergantung satu sama lain secara melingkar |
| `INVALID_EXPRESSION` | Ekspresi tidak dapat dievaluasi (tipe tidak cocok, fungsi tidak dikenal, dll) |
| `DIVISION_BY_ZERO` | Ekspresi melakukan pembagian dengan nilai nol |
| `INVALID_UNIT_VALUE` | Nilai unit tidak dapat diparse atau tidak valid |

`CIRCULAR_DEPENDENCY` juga dipakai untuk kasus `derived` lokal di dalam component jika ia membentuk siklus dengan parameter, derived lokal lain, atau ekspresi internal component.

---

## 6.2 Geometry Errors

Error yang terjadi saat membangun geometri dari relasi yang diberikan.

| Kode | Kondisi |
|------|---------|
| `NO_INTERSECTION` | Dua object diminta berpotongan, namun tidak ada perpotongan |
| `MULTIPLE_INTERSECTIONS` | Perpotongan menghasilkan lebih dari satu titik tanpa instruksi `pick` |
| `PATH_NOT_CLOSED` | Path dengan `closed: true` memiliki titik akhir yang tidak sama dengan titik awal |
| `PATH_JOIN_GAP` | Dua item berurutan pada `path.join` tidak saling tersambung |
| `PATH_JOIN_DIRECTION_MISMATCH` | Target `path.join` path-like tetapi arah traversalnya tidak cocok dengan item sebelumnya |
| `ELLIPSE_INVALID_RADIUS` | `ellipse.rx` atau `ellipse.ry` bernilai nol, negatif, atau tidak valid |
| `INVALID_OFFSET` | Gagal menghitung offset (self-intersection ekstrem) |
| `TANGENT_NOT_FOUND` | Tidak ada solusi garis singgung yang valid |
| `DEGENERATE_ARC` | Busur tidak valid (3 titik segaris pada mode 3-point) |
| `SELF_INTERSECTING_PATH` | Path memotong dirinya sendiri (kritikal untuk offset) |
| `INVALID_CORNER_OPERATION` | Radius fillet/chamfer melebihi panjang segmen yang tersedia |
| `INVALID_JOIN_TARGET` | Item pada `path.join` bukan target lintasan yang valid |
| `INVALID_CLOSE_WITH` | `closeWith` dipakai pada mode/context path yang tidak valid |
| `TURTLE_HEADING_UNAVAILABLE` | Segment `line` relatif memakai `turn` atau `forward` tanpa heading awal yang valid |
| `INVALID_TURTLE_FORWARD` | Nilai `forward` pada relative line segment tidak valid |
| `INVALID_TURTLE_TURN` | Nilai `turn` pada relative line segment tidak valid |

---

## 6.3 Geometry Operation Errors

| Kode | Kondisi |
|------|---------|
| `INVALID_GEOMETRY_OPERATION` | Tipe operation object tidak dikenali atau tidak didukung |
| `INVALID_OPERATION_TARGET` | `target` tidak kompatibel dengan operation yang diminta |
| `INVALID_SCALE_FACTOR` | `scale.factor` bernilai nol, negatif, atau bentuknya tidak valid |
| `INVALID_MIRROR_AXIS` | `mirror.axis` tidak valid untuk kontrak bahasa yang aktif |
| `INVALID_REVERSE_TARGET` | `reverse` dipakai pada target yang tidak memiliki arah traversal yang valid |
| `INVALID_SPLIT_TARGET` | `split.target` bukan geometri path-like yang didukung |
| `SPLIT_POINT_OFF_TARGET` | Titik `split.at` tidak berada pada target dalam tolerance runtime |
| `DEGENERATE_SPLIT` | Split terjadi tepat di ujung target terbuka atau menghasilkan bagian nol-panjang yang tidak sah |
| `SPLIT_RESOLUTION_FAILED` | Titik split sah secara kontrak, tetapi engine gagal membangun hasil split deterministik |

---

## 6.4 Component Errors

| Kode | Kondisi |
|------|---------|
| `COMPONENT_NOT_FOUND` | Nama component tidak terdefinisi di section `components` |
| `COMPONENT_EXPORT_NOT_FOUND` | Mengakses export yang tidak terdefinisi di `exports` component |

---

## 6.5 Validation Errors

Error yang terjadi sebelum resolver berjalan, saat validator memeriksa struktur dokumen.

| Kode | Kondisi |
|------|---------|
| `INVALID_TYPE` | Tipe field tidak sesuai yang diharapkan |
| `MISSING_REQUIRED_FIELD` | Field wajib tidak ada |
| `INVALID_VALUE` | Nilai field tidak valid (di luar enum, format salah, dll) |
| `UNKNOWN_FIELD` | Field tidak dikenal untuk struktur yang sedang divalidasi |
| `OVER_CONSTRAINED` | Object memiliki terlalu banyak constraint yang saling bertentangan |
| `UNDER_CONSTRAINED` | Object tidak memiliki cukup constraint untuk diselesaikan |
| `ELLIPSE_SIZE_CONFLICT` | `ellipse` memakai `size` bersamaan dengan `rx`/`ry` sehingga constraint menjadi ganda |
| `INHERIT_TARGET_NOT_FOUND` | Referensi `inherit` tidak ditemukan |
| `INVALID_INHERIT_TARGET` | Target `inherit` ada tetapi bukan structured value yang legal |
| `CIRCULAR_INHERIT` | Rantai `inherit` membentuk siklus |
| `INHERIT_TYPE_CONFLICT` | Hasil merge `inherit` menghasilkan konflik tipe yang tidak legal |

---

## 6.6 Post-resolution Constraint Diagnostics

Constraint diperiksa setelah resolver menghasilkan geometri.

Pada kontrak aktif v0.5:

1. constraint failure tidak wajib dilempar sebagai validation error
2. resolver boleh mengembalikan hasil resolved scene beserta diagnostics constraint
3. diagnostics ini bersifat deterministik dan tidak boleh mengubah geometri untuk "memaksa" constraint terpenuhi

| Kode | Kondisi |
|------|---------|
| `CONSTRAINT_VIOLATION` | Relasi geometri tidak terpenuhi setelah seluruh object selesai di-resolve |

Jika suatu aplikasi membutuhkan mode strict, aplikasi tersebut boleh memperlakukan diagnostics ini sebagai hard failure di layer compile, CI, atau publishing. Namun perilaku dasar runtime v0.5 tetap berupa laporan diagnostics pasca-resolve.

---

## 6.7 Validation Phases

Validator dan resolver dapat memeriksa dokumen dalam beberapa fase konseptual berikut:

1. structural validation
2. schema validation
3. reference validation
4. expression validation
5. dependency validation
6. geometry validation

Fase-fase ini tidak harus diekspos sebagai API terpisah, tetapi hasil akhirnya harus tetap deterministik dan konsisten terhadap kode error yang didefinisikan spec.

---

## 6.8 Collection & Repeat Errors

| Kode | Kondisi |
|------|---------|
| `INVALID_GRID_SPACING` | `pitch` dan `gap` keduanya ditentukan (mutually exclusive) |
| `OVER_CONSTRAINED_REPEAT_LAYOUT` | Auto-layout aktif, namun item juga memiliki placement manual |
| `INVALID_REPEAT_ALONG_TARGET` | `repeat.along.target` bukan geometri lintasan yang valid |
| `INVALID_REPEAT_ALONG_SPACING` | Nilai `repeat.along.spacing` tidak dikenal atau tidak cocok dengan field yang diberikan |
| `INVALID_FIXED_DISTANCE` | Mode `fixed-distance` dipakai tanpa `distance` yang valid |
| `REPEAT_ALONG_LENGTH_FAILED` | Resolver gagal menghitung distribusi berbasis panjang pada target lintasan |

---

## 6.9 Hole Errors

| Kode | Kondisi |
|------|---------|
| `INVALID_HOLE_SHAPE` | Object di dalam `holes` bukan ClosedShape |
| `HOLE_OUTSIDE_BOUNDARY` | Lubang berada di luar atau melewati batas bentuk penampung |
| `HOLE_OVERLAP` | Dua lubang saling tumpang tindih |

---

[← 5. Semantic Guarantees](05-semantic-guarantees.md) &nbsp;|&nbsp; [↑ Index](README.md) &nbsp;|&nbsp; [7. Type System →](../syntax/07-type-system.md)
