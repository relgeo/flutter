# RelGeo Language Spec Editorial Guide

Status dokumen: `Informative`

Tanggal: `2026-07-22`

Dokumen ini menjelaskan aturan editorial untuk menulis dan merawat dokumen di `id/`.

Tujuannya adalah menjaga konsistensi struktur, penomoran, istilah, navigasi, dan kualitas dua-permukaan tanpa mengubah kontrak DSL secara tidak sengaja.

Konteks versioning:

1. `id/` adalah spec lengkap yang aktif untuk implementasi saat ini
2. pohon ini saat ini merepresentasikan `RelGeo DSL v0.5`
3. delta versi hidup di luar pohon spec aktif dan tidak menggantikan status normatif `id/`
4. default field `version` pada dokumen sebaiknya dibahas sebagai “versi spec aktif saat runtime”, bukan sebagai angka yang dianggap abadi
5. folder `en/` disiapkan untuk surface publik bahasa Inggris, tetapi belum menggantikan status normatif `id/`

---

## 1. Peran Dokumen

Gunakan panduan ini untuk:

1. menambah bab baru
2. memecah bab yang sudah ada
3. merapikan bahasa dan heading
4. meninjau apakah perubahan bersifat editorial atau semantik

Panduan ini bukan dokumen normatif DSL.

---

## 2. Aturan Penomoran

1. nama file chapter harus memakai format `NN-slug.md`
2. `NN` mengikuti urutan baca utama spec
3. heading utama file harus cocok dengan nomor file
4. subheading bernomor harus mengikuti nomor chapter yang sama

Contoh:

```md
# 12. Expressions
## 12.1 Arithmetic Operators
## 12.2 Built-in Functions
```

Jika sebuah bab dipecah:

1. tentukan dulu urutan baca barunya
2. renumber file yang terdampak secara berurutan
3. perbarui heading internal
4. perbarui tautan silang dan navigasi `prev/next`

---

## 3. Aturan Struktur

Setiap chapter normatif sebaiknya memakai pola berikut bila relevan:

1. ringkasan singkat tujuan bab
2. syntax
3. fields atau properties
4. semantics atau rules
5. contoh
6. navigasi `prev/next`

Tidak semua bab harus memakai semua section di atas, tetapi label helper yang dipakai harus konsisten.

Label helper yang disarankan:

1. `Syntax`
2. `Fields`
3. `Properties`
4. `Placement`
5. `Semantics`
6. `Rules`
7. `Anchors`
8. `Result Shape`

Hindari membuat variasi baru bila label yang ada sudah cukup.

---

## 4. Aturan Bahasa

1. narasi utama boleh berbahasa Indonesia
2. istilah teknis DSL boleh tetap memakai English bila lebih presisi
3. label struktural sebaiknya konsisten dalam English
4. hindari campuran istilah untuk fungsi yang sama dalam bab yang berdekatan

Contoh yang diutamakan:

1. `Syntax`, bukan campuran `Syntax` dan `Sintaks`
2. `Rules`, bukan campuran `Rules` dan `Aturan` pada level heading
3. `Semantics`, bukan variasi acak seperti `Perilaku` kecuali memang bab itu membutuhkan istilah domain khusus

---

## 5. Aturan Link dan Navigasi

1. gunakan relative links di dalam dokumen
2. jangan gunakan local absolute path
3. setiap chapter normatif sebaiknya punya navigasi bawah:

```md
[← Bab Sebelumnya](...) | [↑ Index](README.md) | [Bab Berikutnya →](...)
```

4. navigasi harus mengikuti urutan baca global, bukan hanya urutan folder
5. jika nama file berubah, perbarui seluruh referensi yang menunjuk ke file itu
6. link dan navigasi harus tetap masuk akal baik saat dibuka sebagai file Markdown mentah maupun saat tampil di website

Aturan boundary tambahan:

1. hindari link ke dokumen di luar pohon spec
2. source spec aktif harus tetap portable jika nanti dipindah ke repo sendiri
3. jika butuh konteks sejarah, audit, atau strategi, jelaskan secara naratif tanpa membuat ketergantungan link keluar-repo

---

## 5A. Aturan Bilingual

Pohon spec sekarang bersifat bilingual secara struktur.

Aturan praktisnya:

1. `id/` adalah source normatif aktif
2. `en/` adalah surface publik bahasa Inggris yang harus dijaga konsisten arahnya
3. jangan memindahkan kontrak normatif aktif ke `en/` sebelum ada keputusan editorial yang eksplisit
4. docs-site boleh memakai route publik yang stabil walau source internal aktif tetap berada di `id/`

Saat menambah atau mengubah dokumen:

1. perubahan semantik harus masuk ke `id/` terlebih dahulu
2. `en/` boleh tertinggal sementara, tetapi statusnya harus jelas
3. bila halaman `en/` belum punya isi penuh, gunakan placeholder yang jujur daripada terjemahan parsial yang menyesatkan
4. hindari menyebut `en/` sebagai source of truth selama kontrak aktif masih dipelihara di `id/`

Tujuan aturan ini:

1. menjaga agar implementasi, audit, dan sejarah versi tetap merujuk ke satu rumah normatif aktif
2. tetap membuka jalan bagi website dan dokumentasi publik bilingual
3. mencegah drift diam-diam antara bahasa Indonesia dan Inggris
4. menjaga agar submodule spec tidak bergantung pada konteks root workspace

---

## 5B. Aturan Dua-Permukaan

Pohon spec harus lulus sebagai source publik dua-permukaan:

1. permukaan mentah, yaitu tetap enak dibaca langsung di IDE atau editor teks
2. permukaan ter-render, yaitu tetap rapi saat ditampilkan di website resmi

Implikasinya:

1. jangan menulis dokumen yang hanya bagus di website
2. jangan menulis dokumen yang hanya enak dibaca sebagai Markdown mentah tetapi rusak saat dirender
3. presenter atau docs-site harus mengikuti dokumen yang baik, bukan menyelamatkan dokumen yang buruk
4. kualitas source lebih penting daripada trik presentasi sementara

Hal-hal yang harus dijaga sekaligus:

1. heading jelas saat dibaca mentah
2. penomoran file dan heading tetap konsisten
3. link relatif tidak rusak
4. `prev/next` tidak tumpang tindih
5. index section tetap jelas
6. tidak ada asumsi path lokal atau struktur mesin tertentu
7. tidak ada ketergantungan link keluar-repo dari source spec aktif

---

## 6. Aturan Perubahan

Pisahkan dua jenis perubahan ini:

1. perubahan editorial
2. perubahan semantik

Perubahan editorial mencakup:

1. rename file
2. renumber heading
3. perapian istilah heading
4. perbaikan tautan
5. perbaikan tata bahasa tanpa mengubah makna kontrak

Perubahan semantik mencakup:

1. menambah field baru
2. mengubah aturan validasi
3. mengubah evaluation order
4. mengubah behavior resolver, runtime, atau renderer
5. mengubah batasan normatif

Jangan campur perubahan editorial besar dengan perubahan semantik besar dalam satu langkah bila bisa dihindari.

Untuk perubahan lintas versi:

1. siapkan delta atau proposal versi di luar pohon spec aktif
2. evaluasi apakah delta itu sudah benar-benar diadopsi implementasi atau dinaikkan menjadi kontrak aktif
3. serap kontrak normatifnya ke `id/`
4. setelah diserap, source of truth tetap berada di pohon spec aktif ini

---

## 7. Checklist Review

Sebelum menyelesaikan perubahan pada language spec, cek:

1. apakah nomor file dan heading utama sudah cocok
2. apakah subheading bernomor masih benar
3. apakah `prev/next` sudah linear
4. apakah semua link internal masih valid
5. apakah label helper konsisten
6. apakah perubahan ini editorial atau semantik sudah jelas
7. apakah dokumen ini masih layak dibaca dari atas ke bawah oleh pembaca baru
8. apakah dokumen ini tetap nyaman dibaca sebagai file mentah di IDE
9. apakah dokumen ini tetap rapi dan layak saat dirender di website

---

## 8. Boundary Repo

Pohon spec harus diperlakukan sebagai repo mandiri.

Aturannya:

1. root workspace boleh merujuk ke submodule spec
2. source spec aktif tidak boleh bergantung pada link ke root workspace
3. link lintas repo non-root sebaiknya dihindari sampai struktur multi-repo final benar-benar diterapkan
4. jika suatu konteks belum bisa dirujuk secara stabil dari repo spec mandiri, konteks itu tidak perlu ditautkan dari dalam source spec
