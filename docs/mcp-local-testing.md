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

Di aplikasi, pilih **Workbench → MCP Server…**, lalu tekan **Enable MCP**.
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

## Menghubungkan dari Codex Desktop

Di Codex Desktop, tambahkan server melalui Settings → Plugins → Add → MCP
servers → Streamable HTTP. Gunakan endpoint loopback dan bearer token dari
dialog RelGeo. Codex Desktop berjalan pada host lokal yang sama sehingga dapat
mengakses `127.0.0.1` secara langsung. Hosted ChatGPT plugins memerlukan HTTPS
endpoint atau Secure MCP Tunnel; jalur itu berbeda dari Codex Desktop lokal.

Setelah mengubah daftar tool, refresh koneksi/plugin agar metadata tool yang
baru ditemukan. Mulai percakapan baru atau sebut plugin secara eksplisit,
misalnya: “Gunakan MCP `relgeo`, panggil `relgeo_get_capabilities`, lalu
jelaskan kemampuan dan batasannya.”

## Kemampuan saat ini

- `relgeo_get_capabilities` melaporkan tool, resource, dan batas kemampuan
  server saat ini.
- `relgeo_find_syntax` mencari aturan normatif yang saat ini tersedia untuk
  primitive `rect` dari pertanyaan authoring.
- `relgeo_get_syntax_rule` mengembalikan aturan `14.3 Rect` dari spec v0.5,
  termasuk ukuran dan placement. Untuk pertanyaan “persegi”, MCP menjelaskan
  bahwa memakai lebar dan tinggi sama adalah interpretasi praktis, bukan rule
  tambahan di spec.
- Setelah aturan spec ditemukan, `relgeo_get_examples` dapat memberi contoh
  YAML persegi atau persegi panjang sebagai ilustrasi sekunder.
- `relgeo_get_active_document` membaca source, identitas, revisi, dan status
  perubahan dokumen aktif.
- Resource `relgeo://document/active` menyediakan snapshot yang sama.
- Resource `relgeo://document/active/diagnostics` menyediakan error YAML atau
  compiler yang sedang ditampilkan workbench.
- Server hanya baca. Pencarian normatif desktop saat ini baru mencakup rule
  `rect`, bukan seluruh spec. Belum ada validasi terpisah, render, atau
  perubahan dokumen melalui MCP.
- Protocol adapter desktop menegosiasikan versi MCP `2025-11-25` dan
  `2025-06-18` agar kompatibel dengan MCP client yang versinya berbeda.

Token berlaku hingga delapan jam selama server berjalan dan hanya ditampilkan
di dialog aplikasi. Tekan **Disable** untuk mencabutnya segera. Mengaktifkan
kembali server membuat endpoint dan token baru.
