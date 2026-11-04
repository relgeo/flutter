# 4. Evaluation Order

Status dokumen: `Normative`

Resolver mengevaluasi dokumen RelGeo dalam urutan berikut yang deterministik. Setiap tahap hanya boleh bergantung pada hasil tahap sebelumnya.

---

## 4.1 Evaluation Order

```txt
1. parameters   → nilai default
2. profiles     → preset aktif mengoverride `parameters`
3. constants    → nilai tetap, boleh merujuk parameter
4. derived      → hasil ekspresi, boleh merujuk parameter/constants/derived lain
5. metaPresets  → preset metadata reusable yang tidak mengubah geometri
6. components   → definisi komponen (dideklarasikan, belum diinstansiasi)
7. objects      → geometri utama, termasuk geometry operation objects, dievaluasi berdasarkan dependency graph
8. collections  → repeat/divide/boolean, tergantung pada objects
9. constraints  → validasi relasi antar object (bukan mengubah geometri)
10. annotations  → dimension dan annotation objects
11. views       → snapshot read-only dari subset objects
12. sheets      → komposisi views ke lembar gambar
```

---

## 4.2 Dependency Graph as Source of Truth

Urutan di atas adalah urutan *kategori*. Di dalam kategori `objects`, urutan evaluasi individual ditentukan oleh **dependency graph**:

- Object yang tidak bergantung pada objek lain dievaluasi lebih dulu
- Object yang bergantung pada hasil object lain dievaluasi setelahnya
- Geometry operation object mengikuti rule yang sama: ia baru boleh dievaluasi setelah `target`-nya selesai
- Dependency melingkar dalam satu kategori menghasilkan error `CIRCULAR_DEPENDENCY`

---

## 4.3 Rules

- Tahap yang lebih awal **tidak boleh bergantung** pada hasil tahap yang lebih akhir
- `objects` boleh bergantung pada `derived`, `constants`, dan `parameters`
- geometry operation object menghasilkan object resolved biasa dan karena itu hasilnya boleh dipakai lagi oleh object atau collection berikutnya selama dependency graph valid
- jika suatu surface map mendukung `inherit`, merge harus diselesaikan setelah sumber referensinya resolved dan sebelum map tersebut dipakai oleh object/component target
- untuk component, `derived` lokal dievaluasi setelah parameter instance final tersedia dan sebelum object internal component di-resolve
- `metaPresets` tidak mengoverride parameter dan tidak memengaruhi geometri
- `styles` / `style`, bila masih diterima demi kompatibilitas mundur, harus diperlakukan ekuivalen dengan `metaPresets` / `metaPreset`
- `derived` boleh bergantung pada anchor object (evaluasi lazy setelah objects)
- `constraints` dievaluasi **setelah** semua geometri selesai - hanya memvalidasi, tidak mengubah

## 4.4 Diagnostic Phase Boundary

Parsing adalah precondition sebelum langkah evaluasi `parameters` sampai
`sheets`. Setiap kegagalan yang melewati public boundary harus dipetakan ke
diagnostic terstruktur seperti yang didefinisikan di [6. Error Model](06-error-model.md).
Raw `Error`, stack trace, atau string exception tidak boleh menjadi contract
consumer.

| Phase | Boundary yang menghasilkan diagnostic | Aturan urutan dan hasil |
| --- | --- | --- |
| `parse` | YAML decoding, root document shape, version gate, dan syntax/document envelope | Terjadi sebelum evaluation order; tidak ada resolved scene yang boleh diklaim valid |
| `validate` | Schema, field/type/value, reference, dependency, dan pre-resolution constraint validation | Terjadi sebelum geometry resolution; strict boundary gagal dengan code/path stabil |
| `resolve` | Expression evaluation, dependency execution, object/component resolution, dan derived values | Berjalan sesuai dependency graph; kegagalan menghentikan hasil resolve strict |
| `runtime` | Kegagalan operasional saat membentuk hasil resolved, misalnya empty/unsupported result atau non-finite output | Tidak boleh diturunkan menjadi `UNKNOWN_ERROR` bila code runtime yang stabil tersedia |
| `constraint` | Pemeriksaan constraint setelah seluruh geometry selesai | Tidak mengubah geometry; default v0.5 mempertahankan resolved scene dan melaporkan violation |

Adapter boleh menggabungkan tahap `parse` dan `validate` dalam satu operasi
parse/validate, tetapi field `phase` pada diagnostic tetap wajib mengikuti
boundary yang menghasilkan kegagalan. Pengurutan multi-diagnostic mengikuti
urutan phase di atas, lalu source range/path/code/message secara deterministic.

Mode `editor` boleh menjalankan recovery lokal agar dokumen parsial tetap dapat
ditampilkan. Recovery tidak mengubah arti mode `validate` atau `compile`, tidak
boleh menghapus diagnostic, dan tidak boleh dipakai sebagai bukti bahwa dokumen
compile-valid. Mode `validate` dan `compile` wajib strict untuk parse,
validation, resolution, dan runtime failures. `compile` menghasilkan output
hanya jika boundary strict tersebut tidak gagal; post-resolve constraint
violation tetap mengikuti aturan `constraint` di atas dan dapat dipromosikan
menjadi hard failure oleh consumer build/CI policy.

---

[← 3. Scene](03-scene.md) &nbsp;|&nbsp; [↑ Index](README.md) &nbsp;|&nbsp; [5. Semantic Guarantees →](05-semantic-guarantees.md)
