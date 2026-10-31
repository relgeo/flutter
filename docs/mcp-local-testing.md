# Menguji MCP RelGeo secara lokal

RelGeo Desktop dapat menjalankan MCP server sementara di komputer yang sama.
Server mati secara default, hanya bind ke `127.0.0.1`, dan memakai bearer
token sementara. Menonaktifkan server atau menutup workbench mencabut token.

## Menjalankan aplikasi desktop

Dari folder `flutter/`, jalankan target desktop yang sesuai:

```sh
flutter run -d macos
```

Untuk target lain, gunakan `flutter run -d windows` atau `flutter run -d linux`.

Di aplikasi, pilih **Workbench → MCP Server…**. Secara default MCP memakai mode
read-only. Jika agent perlu mengubah gambar, centang **Allow MCP to edit the
active document**, lalu tekan **Enable MCP**. Mode ini memberi izin hanya untuk
patch bounded pada dokumen aktif; satu pemanggilan menjadi satu transaksi yang
bisa di-Undo, dan tidak pernah menyimpan file secara otomatis.
Dialog menampilkan endpoint dan token. Tombol **Copy connection details** akan
menyalin URL beserta header otorisasi dalam bentuk JSON umum. Format konfigurasi
MCP berbeda antar-klien, jadi salin URL dan token itu ke pengaturan klien Anda.

## Mencoba dengan MCP Inspector

MCP Inspector adalah alat pengembang terpisah. Perintah ini memerlukan Node.js
22.19 atau lebih baru dan `npx`; RelGeo Desktop sendiri tidak memerlukan
Node.js. Opsi `--protocol-era legacy` memilih profil handshake yang saat ini
didukung adapter RelGeo.

```sh
npx @modelcontextprotocol/inspector --cli \
  --server-url http://127.0.0.1:PORT/mcp \
  --transport http \
  --protocol-era legacy \
  --header "Authorization: Bearer TOKEN" \
  --method tools/list
```

Ganti `PORT` dan `TOKEN` dengan nilai dari dialog aplikasi. Untuk membaca
dokumen aktif melalui tool:

```sh
npx @modelcontextprotocol/inspector --cli \
  --server-url http://127.0.0.1:PORT/mcp \
  --transport http \
  --protocol-era legacy \
  --header "Authorization: Bearer TOKEN" \
  --method tools/call \
  --tool-name relgeo_get_active_document \
  --format json
```

Inspector juga dapat dibuka dalam mode web dengan menjalankan
`npx @modelcontextprotocol/inspector`, lalu menambahkan endpoint HTTP dan
header `Authorization: Bearer TOKEN` pada koneksi server.

## Menghubungkan dari ChatGPT Desktop

Di ChatGPT Desktop, buka **Settings → Plugins → Add → MCP servers → Streamable
HTTP**. Isi URL dengan endpoint `http://127.0.0.1:<port>/mcp` dari dialog
RelGeo. Pada bagian **Headers**, tambahkan key `Authorization` dan value
`Bearer <token>` dari dialog. Biarkan **Bearer token env var** dan **Headers
from environment variables** kosong jika memasukkan token langsung di header;
kolom env var meminta nama variabel lingkungan yang memang harus sudah tersedia
di lingkungan ChatGPT Desktop, bukan nilai token itu sendiri. Jangan membagikan
token ini karena siapa pun yang memilikinya dapat memakai izin sesi MCP yang
sedang berjalan.

Simpan konfigurasi, lalu refresh/reconnect server. Server harus tetap aktif di
RelGeo Desktop selama dipakai. Setelah mengubah daftar tool atau mengganti mode
server, refresh koneksi agar metadata tool diperbarui. Token diterbitkan ulang
saat server diaktifkan, jadi perbarui header `Authorization` pada klien.
Mulai percakapan baru atau sebut server secara eksplisit, misalnya: “Gunakan
MCP `relgeo`, cari aturan persegi pada spec, lalu jelaskan syntax-nya.” Untuk
mengubah gambar: “Gunakan MCP `relgeo` untuk membuat persegi 40 × 40 mm di
dokumen aktif.”

Panduan ini untuk ChatGPT Desktop pada komputer yang sama dengan RelGeo. Jika
memakai layanan hosted dari komputer lain, alamat loopback tidak menunjuk ke
komputer RelGeo; jalur itu memerlukan endpoint yang dapat dijangkau klien.

## Kemampuan saat ini

- `relgeo_get_capabilities` melaporkan tool, resource, dan batas kemampuan
  server saat ini.
- `relgeo_search_spec` mencari seluruh snapshot Markdown `spec/id/` yang
  terbundel secara offline, dengan section ID, snippet, status normatif, dan
  provenance revision/digest.
- `relgeo_get_spec_section` mengambil section lengkap setelah agent memilih
  hasil pencarian. `relgeo_find_syntax` tetap tersedia sebagai alias
  kompatibilitas dan memakai corpus yang sama.
- Setelah aturan spec ditemukan, `relgeo_get_examples` dapat memberi contoh
  YAML persegi atau persegi panjang sebagai ilustrasi sekunder.
- `relgeo_get_active_document` membaca source, identitas, revisi, dan status
  perubahan dokumen aktif.
- `relgeo_apply_document_edit` tersedia hanya jika izin edit dipilih sebelum
  server dijalankan. Tool ini memerlukan document ID dan revision terbaru,
  menerima patch bounded, menolak patch stale, dan membuat satu transaksi
  undoable.
- Resource `relgeo://document/active` menyediakan snapshot yang sama.
- Resource `relgeo://document/active/diagnostics` menyediakan error YAML atau
  compiler yang sedang ditampilkan workbench.
- Corpus spec dimuat dari Flutter asset bundle saat server dimulai; runtime
  tidak membaca path `spec/` dari repository dan tidak membutuhkan
  Node.js/npm atau koneksi remote. Validasi dan render source sebagai tool MCP
  belum tersedia.
- Protocol adapter desktop menegosiasikan versi MCP `2025-11-25` dan
  `2025-06-18` agar kompatibel dengan MCP client yang versinya berbeda.

Token berlaku hingga delapan jam selama server berjalan dan hanya ditampilkan
di dialog aplikasi. Tekan **Disable** untuk mencabutnya segera. Mengaktifkan
kembali server membuat endpoint dan token baru.

## Verifikasi otomatis

Flutter test `test/mcp_server_io_test.dart` menjalankan server Streamable HTTP
loopback yang nyata, mengambil daftar tool, memastikan izin read-only menolak
patch, lalu menerapkan patch pada sesi read-write dan memeriksa Undo serta
dirty state.
