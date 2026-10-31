# Kebijakan Rilis Desktop RelGeo

**Status:** kebijakan distribusi awal; workflow draft GitHub Release tersedia, smoke test rilis lintas OS masih perlu bukti pada target masing-masing
**Pemilik aplikasi dan release:** `relgeo/flutter`  
**Platform:** macOS, Ubuntu/Linux x64, Windows x64

Dokumen ini menetapkan bagaimana build desktop RelGeo dikemas, diberi versi,
diverifikasi, dan diterbitkan. Workflow draft release mengikuti aturan ini;
target smoke lintas OS tetap harus ditinjau sebelum maintainer menerbitkan release.

Icon aplikasi menggunakan mark global RelGeo dari
[`relgeo.github.io/public/brand/relgeo-mark.png`](https://github.com/relgeo/relgeo.github.io/blob/main/public/brand/relgeo-mark.png).
File platform di repository Flutter adalah hasil turunan untuk format icon OS;
gunakan ulang master tersebut dan pertahankan warna, transparansi, serta
proporsinya ketika aset perlu dibuat ulang.

## 1. Lokasi rilis dan kepemilikan

Rilis aplikasi desktop diterbitkan di halaman
[`relgeo/flutter` Releases](https://github.com/relgeo/flutter/releases). Tag,
catatan rilis, dan binary harus berada pada repository yang memiliki source
aplikasi dan workflow build-nya.

`relgeo/workspace` tetap menjadi pemilik orkestrasi lintas-repository, fixture
conformance, compatibility line DSL, dan catatan evidence lintas-repo. Workspace
boleh menautkan ke release Flutter, tetapi tidak menduplikasi aset desktop atau
menerbitkan release kedua untuk binary yang sama.

Rilis desktop adalah versi aplikasi Flutter. Versi tersebut terpisah dari
versi kontrak RelGeo DSL (`0.5`) dan versi Flutter SDK yang dipakai untuk
membangun aplikasi. Aplikasi ini tetap bukan package `pub.dev`.

## 2. Versi dan tag

1. Setiap rilis stabil memakai tag `desktop-vX.Y.Z`, misalnya
   `desktop-v1.0.0`.
2. `X.Y.Z` harus sama dengan `build-name` aplikasi pada `version` di
   `pubspec.yaml` pada commit yang ditag. Suffix build setelah tanda `+`
   merupakan build number aplikasi dan bukan bagian dari nama tag.
3. Tag rilis dibuat pada commit yang sudah berada di `main` setelah perubahan
   diterima melalui review. Push biasa ke `main` tidak menerbitkan release.
4. Kandidat pra-rilis memakai suffix eksplisit, misalnya
   `desktop-v1.1.0-rc.1`, dan ditandai sebagai GitHub Pre-release.
5. Tag yang sudah dipakai release tidak dipindahkan atau dipakai ulang. Koreksi
   aset atau source diterbitkan sebagai versi patch baru.

## 3. Format aset awal

Semua aset harus berisi runtime files yang diperlukan, bukan executable tunggal.
Nama aset menyebut aplikasi, platform, arsitektur, dan versi:

| Target | Aset awal | Isi dan batas distribusi |
| --- | --- | --- |
| macOS | `RelGeo-macos-<arch>-vX.Y.Z.zip` | `RelGeo.app` lengkap. Nilai `<arch>` menyatakan arsitektur yang benar-benar dibangun dan diuji (`arm64`, `x64`, atau `universal`). Jangan menyebut `universal` kecuali executable dan framework sudah diverifikasi memuat `arm64` serta `x86_64`. |
| Ubuntu/Linux | `RelGeo-linux-x64-vX.Y.Z.tar.gz` | Folder `RelGeo/` lengkap, termasuk executable `relgeo_flutter`, `lib/`, dan `data/`. Target awal adalah Linux x64 pada Ubuntu; distro dan library system yang diperlukan harus disebutkan di release notes. |
| Windows | `RelGeo-windows-x64-vX.Y.Z.zip` | Folder release lengkap, termasuk `relgeo_flutter.exe`, `flutter_windows.dll`, dan `data/`. Berkas `.exe` saja bukan aset rilis yang valid. |

Aset awal adalah arsip untuk ekstrak dan jalankan. Windows belum menyediakan
installer `.msi`, `.exe` setup, atau MSIX. macOS belum menyediakan installer
`.dmg`/`.pkg`. macOS code signing dan notarization, Windows code signing, serta
installer produksi berada di luar tahap distribusi awal dan memerlukan
keputusan serta verifikasi tersendiri. Release notes tidak boleh menyebut
arsip unsigned sebagai installer resmi atau menyiratkan bahwa OS tidak akan
menampilkan peringatan keamanan.

## 4. Gerbang build dan publikasi

Workflow [`desktop-release.yml`](../../.github/workflows/desktop-release.yml)
memenuhi urutan berikut dan hanya membuat GitHub Release sebagai draft:

1. Dipicu oleh tag `desktop-v*`; release stabil tidak terbit otomatis dari
   setiap push `main`.
2. Memeriksa format tag dan memastikan versi `X.Y.Z` cocok dengan
   `pubspec.yaml` pada commit tersebut.
3. Menjalankan quality gate yang disetujui untuk source commit yang sama,
   termasuk analyzer/test serta build native pada runner macOS, Ubuntu, dan
   Windows. Tiap OS harus dibangun pada runner OS-nya sendiri.
4. Memeriksa isi arsip, executable, runtime files, platform, dan arsitektur
   sebelum aset dinyatakan siap dipasang ke release. Kegagalan satu target
   membuat release tidak siap dipublikasikan sebagai release lengkap.
5. Membuat GitHub Release sebagai **draft**, mengunggah seluruh aset yang lulus,
   lalu menunggu maintainer meninjau catatan dan aset sebelum menekan Publish.
   Pra-rilis tetap berstatus Pre-release saat diterbitkan.
6. Menghasilkan checksum SHA-256 untuk setiap arsip dan mengunggah manifest
   checksum bersama aset platform.

Job build hanya memerlukan `contents: read`. Hak `contents: write` diberikan
hanya ke job publikasi release. Pull request dan build pada branch biasa tidak
boleh memperoleh job/token publikasi. Workflow harus menggunakan token GitHub
Actions berlingkup repository tersebut; secret PAT berjangka panjang tidak
diperlukan untuk membuat release di repository yang sama.

## 5. Provenance dan release notes

Setiap GitHub Release harus mencatat:

- versi aplikasi dan tag;
- compatibility line DSL yang didukung;
- commit `relgeo/flutter` yang dibangun;
- revision repository/path dependency MCP yang digunakan;
- versi Flutter dan Dart;
- OS runner, arsitektur aset, dan URL run workflow;
- perubahan pengguna, catatan instalasi/ekstraksi, serta batasan signing;
- checksum SHA-256 aset.

Workflow harus membuat provenance dari metadata build, bukan menyalin nilai
manual yang dapat berbeda dari source yang benar-benar dibangun. Release asset
tidak boleh menyertakan credential, file lokal operator, atau konfigurasi
runtime yang bersifat rahasia.

## 6. Instruksi pengguna dan batas klaim

Release notes harus memberi langkah yang cocok dengan format aset:

- **Windows:** unduh ZIP, ekstrak seluruh isinya, lalu jalankan
  `relgeo_flutter.exe` dari folder hasil ekstrak.
- **Ubuntu/Linux:** unduh dan ekstrak arsip, pastikan library desktop yang
  disebutkan tersedia, lalu jalankan `relgeo_flutter` dari folder `RelGeo/`.
- **macOS:** unduh ZIP, ekstrak `RelGeo.app`, lalu pindahkan ke `Applications`
  bila diinginkan. Sebutkan status signing/notarization yang sebenarnya.

Build sukses dan pemeriksaan isi arsip membuktikan bahwa artifact berhasil
dibuat; itu sendiri belum membuktikan pengalaman instalasi dan runtime pada
komputer pengguna. Klaim dukungan rilis siap pakai harus didukung smoke test
target OS yang tercatat. Untuk Linux dan Windows, verifikasi minimum mencakup
mengekstrak dan meluncurkan artifact pada target yang didukung. Untuk macOS,
verifikasi mencakup arsitektur bundle dan launch; pemeriksaan signing,
notarization, dan aksesibilitas tetap dicatat terpisah.

## 7. Tahap lanjutan

Setelah arsip awal lulus smoke test pengguna pada Windows 11, Ubuntu, dan macOS,
maintainer dapat memutuskan apakah perlu menambahkan MSIX/installer Windows,
DMG/PKG macOS, signing/notarization, serta mekanisme update. Keputusan itu
memiliki gerbang verifikasi tersendiri dan tidak menjadi prasyarat untuk
mengunggah arsip awal ke GitHub Release.

Rencana lintas-repository dan status evidence platform tetap dicatat pada
workspace, termasuk [rencana desktop platform delivery](https://github.com/relgeo/workspace/blob/main/docs/plans/08-desktop-platform-delivery.md).
