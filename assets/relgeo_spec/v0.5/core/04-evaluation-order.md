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

---

[← 3. Scene](03-scene.md) &nbsp;|&nbsp; [↑ Index](README.md) &nbsp;|&nbsp; [5. Semantic Guarantees →](05-semantic-guarantees.md)
