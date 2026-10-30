# RelGeo Language Spec

Status dokumen: `Informative Index`

Version target: `0.5`

Spec aktif untuk implementasi saat ini: `RelGeo DSL v0.5`

## 1. Tujuan

Folder ini adalah rumah utama untuk dokumentasi language spec RelGeo.

Tujuannya:

1. mengumpulkan seluruh kontrak DSL dalam satu area yang jelas
2. memisahkan spec normatif dari catatan implementasi dan dokumen pendukung
3. memberi jalur baca yang lebih stabil untuk author, implementor, reviewer, dan LLM
4. menjaga agar pohon ini tetap layak dibaca langsung di IDE dan tetap layak dirender di website resmi

Pohon ini adalah lokasi utama dan target final untuk dokumentasi language spec RelGeo.

Status versioning:

1. `id/` adalah spec lengkap yang aktif untuk implementasi saat ini
2. versi aktif yang direpresentasikan pohon ini adalah `RelGeo DSL v0.5`
3. delta yang belum diserap ke pohon ini belum menjadi bagian dari source of truth implementasi
4. field dokumen `version`, jika dihilangkan, boleh diasumsikan sebagai versi spec aktif yang diimplementasikan runtime saat itu

---

## 2. Cara Membaca

Gunakan urutan berikut:

1. `core/`
2. `syntax/`
3. `geometry/`
4. `presentation/`
5. `appendix/`

Urutan ini mengikuti cara memahami DSL:

1. fondasi bahasa
2. nilai, tipe, dan ekspresi
3. model object dan geometri
4. lapisan presentasi
5. material pendukung

Catatan:

1. nomor file sekarang mengikuti urutan baca utama spec
2. beberapa topik tetap digabung dalam satu file bila kontraknya lebih mudah dibaca bersama

---

## 3. Struktur Folder

### `core/`

Untuk fondasi normatif DSL:

1. overview
2. document structure
3. scene dan coordinate model
4. evaluation order
5. semantic guarantees
6. error model

### `syntax/`

Untuk kontrak nilai dan ekspresi:

1. type system
2. parameters
3. constants
4. derived values
5. profiles
6. expressions

### `geometry/`

Untuk object model dan perilaku geometri:

1. object model
2. geometry objects
3. composition objects
4. collection objects
5. placement
6. anchors
7. collections
8. geometry queries
9. constraints

### `presentation/`

Untuk lapisan presentasi gambar:

1. dimension objects
2. annotation objects
3. drawing roles
4. views dan sheets
5. presentation-related metadata

Catatan konseptual:

1. seluruh pohon ini tetap bagian dari kontrak aktif `RelGeo DSL v0.5`
2. tetapi tidak semua bab di spec aktif otomatis mewakili kapabilitas inti bahasa RelGeo
3. khusus area `presentation/`, beberapa kontrak lebih tepat dibaca sebagai `capability layer` atau `domain layer`, terutama untuk surface yang berat ke technical drawing

### `appendix/`

Untuk material pendukung:

1. summary
2. glossary
3. examples
4. migration notes
5. cross-reference index

---

## 4. Status Dokumen

Setiap dokumen di pohon ini sebaiknya memakai salah satu label berikut:

### `Normative`

Dokumen yang mendefinisikan kontrak DSL dan wajib diikuti implementasi.

### `Informative`

Dokumen penjelas yang membantu memahami spec tanpa menambah kontrak baru.

### `Implementation Note`

Dokumen yang menjelaskan strategi runtime, renderer, atau detail implementasi tertentu.

---

## 5. Provenance

Bab-bab di pohon ini lahir dari proses restrukturisasi dokumentasi dan penyerapan kontrak aktif ke satu rumah normatif yang konsisten.

Untuk tujuan pemeliharaan source aktif:

1. pohon ini diperlakukan sebagai artefak mandiri
2. konteks sejarah, audit, dan restrukturisasi boleh ada di luar pohon ini, tetapi tidak menjadi ketergantungan link dari source spec aktif
3. source of truth aktif tetap berada di pohon ini

---

## 6. Daftar Bab

### `core`

1. `01-overview.md`
2. `02-document-structure.md`
3. `03-scene.md`
4. `04-evaluation-order.md`
5. `05-semantic-guarantees.md`
6. `06-error-model.md`

### `syntax`

1. `07-type-system.md`
2. `08-parameters.md`
3. `09-constants.md`
4. `10-derived.md`
5. `11-profiles.md`
6. `12-expressions.md`

### `geometry`

1. `13-object-model.md`
2. `14-geometry-objects.md`
3. `15-composition-objects.md`
4. `16-collection-objects.md`
5. `17-placement.md`
6. `18-anchors.md`
7. `19-collections.md`
8. `20-geometry-queries.md`
9. `21-constraints.md`

### `presentation`

1. `22-dimension.md`
2. `23-annotation.md`
3. `24-drawing-roles.md`
4. `25-views-sheets.md`
5. `26-metadata.md`

### `appendix`

Status saat ini:

1. `27-summary.md`

Bab appendix lain seperti glossary, examples, migration notes, dan cross-reference index adalah target struktur, tetapi belum dipisah menjadi file tersendiri.

---

## 7. Aturan Pemeliharaan

1. gunakan folder ini sebagai tujuan penataan language spec
2. jangan campur restrukturisasi dengan revisi semantik besar dalam langkah yang sama
3. jika ada konflik isi antar dokumen lama, catat dan audit terhadap pohon ini
4. dokumen di luar pohon ini tidak boleh dianggap source of truth untuk kontrak DSL
5. perlakukan delta versi sebagai material di luar pohon ini, bukan sebagai pengganti spec lengkap
6. jika delta sudah diadopsi implementasi, serap isinya ke `id/`
7. rawat seluruh pohon ini sebagai dokumen dua-permukaan:
   - tetap nyaman dibaca langsung di IDE
   - tetap rapi dan layak saat dirender di website
8. jangan mengandalkan kurasi ad-hoc di website untuk “membersihkan” dokumen yang buruk
9. jika satu file terasa buruk di website, benahi dokumen sumbernya, bukan hanya presenter-nya
10. jangan membuat link keluar dari pohon spec kecuali nanti sudah ada target repo final yang stabil dan memang sengaja dipakai

Panduan editorial:

1. [editorial-guide.md](./editorial-guide.md)

---

## 8. Langkah Lanjut

Langkah kerja yang disarankan:

1. rapikan cross-link internal di dalam pohon ini
2. jaga agar index, section, dan chapter tetap linear
3. pindahkan atau serap materi yang memang perlu menjadi kontrak aktif
4. hindari ketergantungan link keluar-repo dari source spec aktif
5. saat menyiapkan versi berikutnya, serap hanya kontrak yang benar-benar sudah matang ke pohon ini
