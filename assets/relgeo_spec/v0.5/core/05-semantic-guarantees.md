# 5. Semantic Guarantees

Status dokumen: `Normative`

Implementasi RelGeo harus mempertahankan properti-properti berikut untuk menjamin konsistensi dan kepercayaan pengguna.

---

## 5.1 Deterministic Resolution

Input yang sama **selalu** menghasilkan output yang sama, terlepas dari platform, urutan parsing, atau waktu eksekusi.

Ini berarti: tidak boleh ada randomness, tidak boleh ada global mutable state antar dokumen, dan ekspresi yang sama selalu menghasilkan nilai yang sama.

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

---

## 5.6 No General Constraint Solver

RelGeo **tidak menyelesaikan** sistem constraint arbitrer (persamaan bidirectional, simultaneous equations, dll).

Constraint di RelGeo hanya berperan sebagai **validator** - memeriksa apakah relasi geometri yang sudah terbentuk memenuhi kondisi yang dinyatakan. Jika tidak, error dilempar. Resolver tidak akan mencoba mengubah geometri untuk memenuhi constraint.

---

[← 4. Evaluation Order](04-evaluation-order.md) &nbsp;|&nbsp; [↑ Index](README.md) &nbsp;|&nbsp; [6. Error Model →](06-error-model.md)
