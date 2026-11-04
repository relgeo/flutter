# 5. Semantic Guarantees

Status dokumen: `Normative`

Implementasi RelGeo harus mempertahankan properti-properti berikut untuk menjamin konsistensi dan kepercayaan pengguna.

---

## 5.1 Deterministic Resolution

Input yang sama **selalu** menghasilkan output yang sama, terlepas dari platform, urutan parsing, atau waktu eksekusi.

Ini berarti: tidak boleh ada randomness, tidak boleh ada global mutable state antar dokumen, dan ekspresi yang sama selalu menghasilkan nilai yang sama.

Pada boundary geometry yang aktif, replay juga mempertahankan object identity,
dependency order, selector result order, operation anchors, collection order,
kode error, dan document path. Bukti package/core lokal tidak dengan sendirinya
membuktikan replay lintas host; parity Flutter, registry, dan canonical host
tetap merupakan evidence boundary terpisah.

---

## 5.2 Stable Identity

Identity object (nama yang dideklarasikan pengguna) harus stabil sepanjang siklus hidup dokumen. Identity tidak boleh di-rename atau di-generate secara otomatis oleh resolver.

Ini menjamin bahwa referensi antar object (`hole.center`, `panel.left`) tetap valid selama nama tidak diubah pengguna.

---

## 5.3 Dependency Ordered Evaluation

Object selalu dievaluasi dalam urutan yang ditentukan oleh dependency graph - bukan urutan penulisan dalam file. Pengguna tidak perlu mendefinisikan object dalam urutan topologis; resolver melakukan topological sort secara otomatis.

---

## 5.4 Explicit Relations

Relasi antar object **tidak boleh dibuat secara implisit** oleh resolver. Setiap hubungan yang memengaruhi geometri harus dinyatakan secara eksplisit oleh pengguna dalam dokumen.

Ini menjamin bahwa dokumen RelGeo dapat dibaca dan dipahami sepenuhnya dari source-nya saja.

---

## 5.5 Numerical Semantics & Winding Independence

RelGeo memberlakukan kebijakan numerik yang ketat untuk menjamin determinisme:

1. **Toleransi float**: Kesetaraan geometris (*equality*) tidak boleh menggunakan perbandingan float mentah. Semua perbandingan geometri harus menggunakan batas toleransi (*epsilon tolerance*) yang konsisten.
2. **Winding Independence**: Arah putaran penulisan titik pada jalur tertutup (*Clockwise* atau *Counter-Clockwise*) tidak memengaruhi kalkulasi offset (`inside`/`outside`) dan pembentukan lubang (`holes`). Engine secara otomatis menormalisasi arah putaran menggunakan algoritma *signed area* dan aturan isi *even-odd* yang stabil.

Pada low-level package geometry, boundary tolerance yang dibekukan untuk
operasi yang sudah dipilih adalah:

| Nama boundary | Nilai | Pemakaian |
| --- | ---: | --- |
| `intersection` | `1e-9` | equality/deduplication titik, membership segment, angular bound, dan klasifikasi tangent |
| `pathCleanup` | `1e-7` | menghapus titik berurutan atau closing point yang nyaris sama saat normalisasi ring |
| `splitDefault` | `1e-6` | membership point-to-path ketika split tidak memberi tolerance eksplisit |
| `splitEndpoint` | `1e-9` | membedakan split valid dari endpoint degeneratif |
| `modifier` | `1e-9` | boundary numerik path modifier |

Nilai tersebut adalah policy package pada boundary ini, bukan satu epsilon
universal yang menjanjikan precision/error bound untuk semua DSL consumer atau
runtime. Invalid/degenerate input tidak boleh diselesaikan dengan coercion
diam-diam; ia harus mempertahankan error code package yang stabil lalu dipetakan
ke diagnostic/path oleh core.

Normalisasi closed shape menghasilkan outer ring canonical `ccw`, hole ring
canonical `cw`, menghapus duplicate/closing point dalam `pathCleanup`, dan
mempertahankan holes sebagai topology terpisah. Ini membekukan winding/holes
contract tanpa mempromosikan boolean `union`, `xor`, atau topology
non-rectangle yang masih ditahan.

---

## 5.6 No General Constraint Solver

RelGeo **tidak menyelesaikan** sistem constraint arbitrer (persamaan bidirectional, simultaneous equations, dll).

Constraint di RelGeo hanya berperan sebagai **validator** - memeriksa apakah relasi geometri yang sudah terbentuk memenuhi kondisi yang dinyatakan. Jika tidak, error dilempar. Resolver tidak akan mencoba mengubah geometri untuk memenuhi constraint.

---

## 5.7 Canonical Semantic Serialization

Resolved-scene JSON adalah semantic projection yang versioned dan
renderer-neutral. Contract canonical v0.5 memiliki field berikut, dalam urutan
top-level yang stabil:

1. `schema`, `schemaVersion`, dan `compatibilityLine`
2. optional scene fields (`unit`, `orientation`, `origin`, `autoSize`, `padding`)
3. `objectOrder` lalu `objects`
4. `parameterOrder` lalu `parameters`
5. `values`, `bbox`, optional `meta`, dan `violations`
6. `viewOrder` lalu `views`, serta `sheetOrder` lalu `sheets`

Aturan canonicalisasi:

- map/object keys diurutkan lexicographically secara rekursif;
- array semantic mempertahankan urutan hasil resolve, dependency, collection,
  atau violation; array tidak boleh diurutkan ulang hanya untuk membuat diff
  terlihat stabil;
- setiap number harus finite, dibulatkan ke 12 digit desimal, dan `-0`
  dinormalisasi menjadi `0`;
- field object yang bernilai `undefined` dihilangkan;
- non-finite number menggagalkan serialisasi dengan error invalid resolved
  scene;
- serializer mengeluarkan JSON semantic compact; style, whitespace, raw SVG
  bytes, dan viewBox renderer bukan bagian dari contract ini.

`objectOrder`, `parameterOrder`, `viewOrder`, dan `sheetOrder` adalah penanda
urutan semantik eksplisit; map yang menyertainya boleh canonical-sorted tanpa
menghapus urutan tersebut. Scene yang sama pada input dan compatibility line
yang sama harus menghasilkan semantic JSON yang byte-stable pada serializer
yang sama. Ini menetapkan local canonical serialization contract
(`GAP-GEO-SER-001/002`), bukan klaim bahwa consumer host atau Flutter telah
terverifikasi parity.

## 5.8 Structured Diagnostic Invariants

Diagnostic adalah semantic output yang terpisah dari exception transport.
Semua public boundary yang melaporkan kegagalan harus menyediakan envelope
logis berikut:

```json
{
  "code": "MISSING_REQUIRED_FIELD",
  "phase": "validate",
  "severity": "error",
  "message": "Human-readable detail without a code prefix",
  "path": "objects.panel.size",
  "objectId": "panel",
  "range": {
    "start": { "line": 3, "column": 4 },
    "end": { "line": 3, "column": 8 }
  },
  "dependencyChain": ["objects.panel"]
}
```

Aturan envelope:

1. `code`, `phase`, `severity`, dan `message` selalu ada; `path`, `objectId`,
   `range`, dan `dependencyChain` boleh tidak tersedia untuk error global. Pada
   serialized consumer envelope, field yang tidak tersedia direpresentasikan
   sebagai `null` agar bentuk output tetap dapat diinspeksi secara stabil.
2. `code` memakai `UPPER_SNAKE_CASE` dan berasal dari catalog error normatif.
   Code internal yang tidak terdaftar harus dinormalisasi menjadi
   `UNKNOWN_ERROR`; raw code atau raw exception tidak boleh bocor.
3. `phase` hanya memakai `parse`, `validate`, `resolve`, `runtime`, atau
   `constraint`, dengan boundary dan urutan yang ditetapkan pada
   [4.4 Diagnostic Phase Boundary](04-evaluation-order.md).
4. `severity` memakai `error`, `warning`, atau `info`. `error` memblokir
   strict parse/validate/compile boundary; constraint violation adalah temuan
   pasca-resolve dan tidak mengubah geometry.
5. `path` memakai path dokumen yang stabil, misalnya `version`,
   `objects.panel.size`, atau `constraints[0]`. Path global boleh `null`, bukan
   string exception yang berubah-ubah.
6. `range` memakai koordinat source zero-based dengan `start` inclusive dan
   `end` exclusive. Range adalah evidence lokasi, bukan pengganti `path`.
7. Message harus human-readable, deterministic untuk input yang sama, dan tidak
   mengulang code sebagai prefix. Localization boleh dilakukan adapter setelah
   code/fields disimpan.

Untuk input yang sama, daftar diagnostic harus memiliki code, phase, severity,
message, path, dan urutan yang sama. Tolerant editor recovery boleh
menghasilkan placeholder scene, tetapi tidak boleh mengubah code/phase/path
diagnostic yang akan dilihat strict boundary.

---

[← 4. Evaluation Order](04-evaluation-order.md) &nbsp;|&nbsp; [↑ Index](README.md) &nbsp;|&nbsp; [6. Error Model →](06-error-model.md)
