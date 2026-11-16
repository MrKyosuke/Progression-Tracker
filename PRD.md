# Technical Specification & PRD Improvements: Cross-Platform Progression Tracker

> Target platform: **Windows (PC, native `.exe`)** dan **Android (APK)**.
> Dokumen ini merangkum rekomendasi teknis, perbaikan model data, celah PRD, dan roadmap.
> Status library/versi dapat berubah, verifikasi ulang sebelum implementasi.

---

## 1. Ringkasan Perubahan yang Diusulkan

| # | Area | Kondisi pada PRD Awal | Perubahan yang Diusulkan |
|---|------|----------------------|--------------------------|
| 1 | Database | Isar/Room disebut sebagai contoh | **Drift (SQLite)**: pemeliharaan aktif, format file standar |
| 2 | Model data | Tidak mencakup tag, tipe tracking, warna, intensitas | Perluas entity (lihat bagian 4) |
| 3 | Sync (P2) | Didesain belakangan | Schema *sync-ready* sejak MVP (UUIDv7, event log, soft delete) |
| 4 | Intensitas (Story 5) | Tidak berlaku untuk task biner | Aturan intensitas didefinisikan per tipe task |
| 5 | Success Criteria | Tidak ada metrik terukur | Tambahkan target performa & kualitas |

---

## 2. Tech Stack

### 2.1 Perbandingan Opsi Framework

| Opsi | Windows native | Android | Bahasa | Kelebihan | Kekurangan |
|------|:---:|:---:|--------|-----------|------------|
| **Flutter** | Ya | Ya | Dart | Satu codebase, rendering sendiri (cocok untuk grid custom), ekosistem matang, hot reload | Dart kurang umum dibanding JS/Kotlin, ukuran binary lebih besar |
| **Compose Multiplatform (KMP)** | Ya (JVM) | Ya | Kotlin | Android-first, Room KMP & SQLDelight tersedia, tipe aman | Desktop berbasis JVM (startup & RAM lebih berat), ekosistem desktop lebih kecil |
| **Tauri 2 + Svelte/React** | Ya | Ya (Tauri 2 mobile) | Rust + TS | Binary kecil, UI web tech, SVG/CSS grid mudah | Dukungan mobile relatif baru, dua sisi kode (Rust + JS), tooling Android lebih kompleks |
| **React Native** | Via React Native Windows | Ya | TypeScript | Ekosistem JS besar | Dukungan desktop lebih terbatas dibanding Flutter |

### 2.2 Framework Terpilih: Flutter

- Satu codebase menghasilkan `.exe` Windows dan `.apk`/`.aab` Android.
- Grid 365 hari digambar dengan **`CustomPainter`** dengan kontrol penuh atas rendering.
- **Hover** (`MouseRegion`) dan **long-press** (`GestureDetector`) tersedia dalam satu API, mendukung Story 6.
- Keyboard shortcut desktop melalui `Shortcuts` / `Actions` / `CallbackShortcuts`.

### 2.3 Database Terpilih: Drift (SQLite)

| Kriteria | Isar | **Drift (SQLite)** | Room |
|----------|------|--------------------|------|
| Cross-platform (Windows/Android) | Ya | **Ya** | Android + KMP (lebih rumit) |
| Status pemeliharaan | Stagnan, cek fork komunitas | **Aktif** | Aktif |
| Format file | Biner proprietary | **SQLite standar** | SQLite standar |
| Query agregasi (heatmap) | Terbatas | **SQL penuh (`GROUP BY date`)** | SQL penuh |
| Migrasi schema | Manual | **Terstruktur & dapat diuji** | Terstruktur |
| Export/Import (FR-05) | Perlu serializer sendiri | **Salin file `.db`** | Salin file |

Keunggulan utama: format SQLite bersifat universal. Backup = salin satu file, database dapat dibuka dengan DB Browser for SQLite, dan query heatmap (`SELECT date, SUM(count) ... GROUP BY date`) ditulis langsung dalam SQL.

Paket: `drift`, `drift_flutter`, `sqlite3_flutter_libs`, `drift_dev` (dev), `build_runner` (dev).

### 2.4 Stack Pendukung

| Kebutuhan | Pilihan | Catatan |
|-----------|---------|---------|
| State management | **Riverpod** | Testable, cocok dengan pola repository |
| Model immutable | `freezed` + `json_serializable` | Untuk export/import JSON |
| ID | **UUIDv7** (package `uuid`) | Terurut waktu, baik untuk indeks & sync |
| Routing | `go_router` | Cukup untuk app sederhana |
| Window desktop | `window_manager`, `tray_manager` | Ukuran jendela, system tray |
| Hotkey global | `hotkey_manager` | Quick check-in dari aplikasi lain |
| Notifikasi | `flutter_local_notifications` | Reminder harian |
| Widget Android | `home_widget` | Check-in dari home screen |
| File backup | `file_picker`, `share_plus` | Export/Import |
| Testing | `flutter_test`, Drift in-memory DB, golden tests | Termasuk pengujian grid |
| CI/CD | GitHub Actions (runner Windows) | Build `.exe` dan APK otomatis |

### 2.5 Struktur Proyek (Feature-First)

```
lib/
├── core/
│   ├── database/          # Drift tables, DAOs, migrations
│   ├── theme/
│   └── utils/             # date helpers, uuid
├── features/
│   ├── tasks/
│   │   ├── data/          # repository impl
│   │   ├── domain/        # entity, repository interface
│   │   └── presentation/  # screens, widgets, providers
│   ├── progress/          # check-in, heatmap
│   └── backup/            # export/import, (nanti) sync
└── main.dart
```

---

## 3. Arsitektur

### 3.1 Prinsip Utama

1. **Local-first, sync-ready.** Semua operasi menulis ke DB lokal terlebih dahulu. Schema dirancang agar dapat digabung dari beberapa device.
2. **Repository pattern.** UI tidak bergantung pada Drift, sehingga penambahan sync tidak mengubah lapisan UI.
3. **Heatmap = hasil query, bukan state.** Data diagregasi per task, di-cache, dan di-invalidate saat check-in.
4. **Optimistic UI.** Kotak grid langsung menyala saat check-in, penulisan DB berjalan di belakang.

### 3.2 Rendering Grid

- Seluruh grid digambar dalam **satu `CustomPainter`** (bukan 365 widget).
- Hit-testing: koordinat pointer dikonversi ke `(kolom, baris)` lalu dipetakan ke tanggal, dengan satu `MouseRegion` / `GestureDetector` di atas canvas.
- Tooltip hover (PC) dan long-press (Android) memakai logika hit-test yang sama.
- Layar sempit (HP): scroll horizontal otomatis ke tanggal terbaru, atau tampilan 6 bulan pada portrait dan 12 bulan pada landscape.

---

## 4. Model Data

### 4.1 Keterbatasan Model Awal

- `Task` tidak memiliki field untuk tipe tracking, tag, dan warna, padahal FR-01 dan Story 1 mensyaratkannya.
- `ProgressLog` hanya menyimpan `count` per hari, sehingga tidak ada jejak waktu check-in dan penggabungan antar device menimbulkan konflik.
- Tidak ada `updatedAt` / `deletedAt` untuk kebutuhan sync dan undo.
- `date` sebagai "Date/String ISO" belum mendefinisikan zona waktu dan batas ganti hari.

### 4.2 Schema yang Diusulkan

```text
Task
├── id               UUIDv7 (PK)
├── title            TEXT NOT NULL
├── type             ENUM('binary', 'counter')
├── dailyTarget      INT NULL            -- untuk counter, dasar intensitas
├── unit             TEXT NULL           -- "halaman", "menit", dll
├── color            INT (ARGB)          -- warna tema grid per task
├── sortOrder        INT
├── isArchived       BOOL
├── createdAt        INT (epoch ms, UTC)
├── updatedAt        INT (epoch ms, UTC)
└── deletedAt        INT NULL            -- soft delete (tombstone)

Tag
├── id, name, color

TaskTag (many-to-many)
├── taskId, tagId

ProgressEvent            -- APPEND-ONLY, sumber kebenaran
├── id               UUIDv7 (PK)
├── taskId           FK
├── deviceId         TEXT
├── occurredAt       INT (epoch ms, UTC)
├── localDate        TEXT 'YYYY-MM-DD'   -- hari "logis" menurut user
├── delta            INT                 -- +1 check-in, -1 undo
└── note             TEXT NULL           -- opsional

DailyProgress            -- cache/agregat, dapat dibangun ulang dari event
├── taskId, localDate    (PK gabungan)
└── count            INT

Meta
├── schemaVersion, deviceId, dayStartHour
```

### 4.3 Event Log Append-Only

| Pendekatan | Sync PC <-> HP | Undo | Audit/Analitik |
|------------|----------------|------|----------------|
| Update `count` langsung | Konflik (last-write-wins menghilangkan data) | Sulit | Tidak ada riwayat |
| **Event append-only** | **Union berdasarkan ID unik, tanpa konflik** | Tambah event `-1` | Jam check-in tersedia |

Dengan UUID unik per event, sync menjadi penggabungan dua set event.

### 4.4 Aturan yang Perlu Ditetapkan

| Isu | Usulan |
|-----|--------|
| **Batas ganti hari** | Setting `dayStartHour` (default 03:00). Check-in pukul 01:00 dihitung sebagai hari sebelumnya |
| **Zona waktu** | `occurredAt` disimpan UTC dan `localDate` dihitung saat check-in, sehingga stabil saat zona waktu berubah |
| **Intensitas (Story 5)** | Counter: level = `count / dailyTarget` dibagi 4 tingkat. Binary: 1 warna (selesai), atau 2 tingkat bila >1 kali diizinkan. Alternatif: kuantil per task (persentil 25/50/75/100) |
| **Undo/koreksi** | Tombol `-` atau tap ulang + snackbar "Undo" |
| **Backfill** | Edit count tanggal lampau (tap kotak lama -> dialog) |

---

## 5. Celah dan Inkonsistensi pada PRD

1. **Story 1 vs FR-01:** Story menyebut "tracking type" (daily check-in / numerical counter), FR-01 menyebut "tag selection, frequency type". Istilah *type* (binary/counter) dan *frequency* (harian/mingguan) perlu dipisahkan dan didefinisikan.
2. **Frekuensi tidak ada di model data.** Target seperti "3x seminggu" belum memiliki field. Perlu keputusan masuk MVP atau ditunda.
3. **Story 2 ("sorted by recent activity")** memerlukan `lastActivityAt` atau query `MAX(occurredAt)`, tersedia melalui event log.
4. **Story 3 (Archive)** belum menjelaskan nasib data log. Usulan: arsip hanya menyembunyikan task, data tetap tersimpan, ditambah opsi "Hapus permanen" dengan konfirmasi.
5. **Streak tidak ada.** Current streak dan longest streak dapat dihitung dari `DailyProgress`. Usulan: P1.
6. **Keyboard efficiency** tercantum pada persona tetapi tidak memiliki requirement. Lihat FR-10 pada bagian 11.
7. **Prioritas FR-05.** Export/Import dan auto-backup sebaiknya diprioritaskan karena menyangkut keamanan data jangka panjang.
8. **Strategi migrasi schema belum ada.** Diperlukan `schemaVersion` pada DB dan file export.
9. **Konflik versi saat import.** Perlu ditetapkan perilaku: *merge* (default yang diusulkan) atau *replace*.

---

## 6. Fitur Tambahan yang Diusulkan

### 6.1 Prioritas Tinggi

| Fitur | Penjelasan | Prioritas |
|-------|-----------|-----------|
| **Undo check-in** | Snackbar undo + tombol `-` | P0 |
| **Streak counter** | Current & longest streak per task | P1 |
| **Backfill hari lampau** | Edit count tanggal sebelumnya | P1 |
| **Keyboard shortcuts (PC)** | `N` task baru, `1-9` check-in task ke-N, `Ctrl+Z` undo, `Ctrl+F` cari, `Ctrl+E` export | P1 |
| **Auto-backup lokal** | Salinan DB harian/mingguan (retensi 7 terakhir) | P1 |
| **Reminder harian** | Notifikasi jika task belum di-check pada jam tertentu | P1 |

### 6.2 Prioritas Menengah

| Fitur | Penjelasan |
|-------|-----------|
| **Widget home screen Android** | Check-in satu tap tanpa membuka app |
| **System tray + global hotkey (PC)** | Check-in tanpa membuka jendela utama |
| **Palet ramah buta warna** | Opsi skala warna alternatif (mis. biru-oranye) |
| **Pilihan awal minggu** | Senin atau Minggu, memengaruhi layout grid |
| **Filter berdasarkan tag** | Pelengkap tag pada FR-01 |
| **Catatan per check-in** | Field `note` opsional |
| **Dashboard agregat** | Grid gabungan seluruh task |

### 6.3 Setelah MVP Stabil

- Statistik mingguan/bulanan (hari terbaik, jam paling sering check-in).
- Import dari CSV / aplikasi lain.
- Export grid sebagai gambar PNG.
- Dukungan multi-bahasa (ID/EN) melalui `intl`.

---

## 7. Strategi Sync (FR-07)

Opsi diurutkan dari usaha terendah:

| Tingkat | Pendekatan | Usaha | Catatan |
|:---:|-----------|:---:|---------|
| 0 | **Export/Import manual** (FR-05) | Rendah | MVP |
| 1 | **Folder tersinkron pihak ketiga** (Syncthing / Drive / Dropbox) berisi file export atau event log; app melakukan *merge* saat start | Rendah-Sedang | Tanpa kode server |
| 2 | **Google Drive `appDataFolder`** via API | Sedang | Perlu OAuth, data tersembunyi dari user |
| 3 | **WebDAV / self-hosted** (Nextcloud) | Sedang | Memerlukan server pribadi |
| 4 | **Sync LAN** (mDNS + HTTP lokal) | Sedang-Tinggi | Tanpa cloud, kedua device harus satu jaringan |
| 5 | **Backend sync penuh** (PowerSync, Supabase, cr-sqlite) | Tinggi | Melebihi kebutuhan single-user |

Karena menggunakan event log append-only dengan UUID, tingkat 1 dan 2 cukup dengan menggabungkan event berdasarkan ID tanpa resolusi konflik.

Persiapan sejak MVP:
- [x] UUIDv7 untuk semua entity
- [x] `deviceId` unik per instalasi
- [x] `updatedAt` + `deletedAt` (soft delete) pada Task/Tag
- [x] Event log append-only
- [x] `schemaVersion` pada file export

---

## 8. Success Criteria Terukur

| Metrik | Target |
|--------|--------|
| Cold start (Windows) | < 1 detik hingga daftar task tampil |
| Cold start (Android, perangkat menengah) | < 2 detik |
| Latensi check-in (tap -> kotak grid menyala) | < 100 ms |
| Render grid 365 hari x 20 task | 60 fps saat scroll |
| Skala data | Responsif dengan 10 tahun data (~100k event) |
| Integritas data | 0 kehilangan data pada force-close (diuji otomatis) |
| Export -> Import round-trip | Data identik 100% (diuji otomatis) |
| Ukuran APK | < 30 MB (release, split per ABI) |
| Cakupan test | Repository & logika tanggal/streak/intensitas > 80% |

---

## 9. Risiko dan Mitigasi

| Risiko | Peluang | Dampak | Mitigasi |
|--------|:---:|:---:|----------|
| Bug batas hari/zona waktu merusak streak | Tinggi | Tinggi | Util tanggal terpusat + unit test (DST, begadang, ganti zona) |
| Library DB tidak lagi dipelihara | Sedang | Tinggi | Menggunakan SQLite (Drift) |
| Scope creep fitur tambahan | Tinggi | Sedang | Roadmap per fase; fitur 6.2/6.3 ditahan hingga MVP dipakai nyata |
| Data hilang karena salah import/replace | Sedang | Tinggi | Backup otomatis sebelum import, mode merge sebagai default |
| Grid lambat di HP lama | Sedang | Sedang | `CustomPainter` tunggal, cache agregat, profiling dini |
| Perubahan schema merusak DB lama | Sedang | Tinggi | Migrasi Drift bertahap + test migrasi dari tiap versi |

---

## 10. Roadmap

### Fase 0: Fondasi (1 minggu)
- Setup Flutter (Windows, Android), Riverpod, Drift, lint, CI build.
- Util tanggal terpusat + unit test.
- Schema v1 + migrasi pertama.

### Fase 1: MVP (P0) (2-3 minggu)
- FR-01 Task creation (title, type, tag, warna)
- FR-03 Database lokal
- FR-04 Fast check-in + undo
- FR-02 Grid 365 hari dengan intensitas dan tooltip hover/long-press
- Archive task
- Test round-trip dan force-close

### Fase 2: Kualitas Hidup (P1) (2 minggu)
- FR-05 Export/Import (JSON + file SQLite) dengan mode merge, auto-backup
- FR-06 Tema gelap/terang
- Streak, backfill, keyboard shortcuts, reminder
- Filter tag, pilihan awal minggu

### Fase 3: Platform-Native (1-2 minggu)
- Widget Android, system tray + global hotkey Windows
- Palet buta warna, dashboard agregat

### Fase 4: Sync (P2)
- Tingkat 1 (folder tersinkron), lalu tingkat 2 (Drive `appDataFolder`) bila diperlukan

---

## 11. Functional Requirements (Revisi)

| ID | Fitur | Deskripsi | Prioritas |
|----|-------|-----------|:---:|
| FR-01 | Task Creation | Judul, tipe (binary/counter), target harian (opsional), tag, warna | P0 |
| FR-02 | Grid View | Heatmap 365 hari per task, intensitas berbasis tipe & target, tooltip tanggal + count | P0 |
| FR-03 | Local-First DB | Drift/SQLite, schema sync-ready (UUIDv7, event log, soft delete), migrasi terversi | P0 |
| FR-04 | Fast Check-In | Satu klik/tap menambah progres hari ini, optimistic UI | P0 |
| FR-04b | Undo | Batalkan check-in terakhir (snackbar + `Ctrl+Z`) | P0 |
| FR-05 | Export/Import | JSON & SQLite, mode merge/replace, backup otomatis sebelum import | P1 |
| FR-05b | Auto-Backup | Salinan lokal berkala (retensi 7) | P1 |
| FR-06 | Tema | Gelap/terang/ikut sistem + palet ramah buta warna | P1 |
| FR-08 | Streak | Current & longest streak per task | P1 |
| FR-09 | Backfill | Edit progres tanggal lampau | P1 |
| FR-10 | Keyboard Shortcuts | Navigasi dan check-in tanpa mouse (PC) | P1 |
| FR-11 | Reminder | Notifikasi harian per task | P1 |
| FR-12 | Quick-Access Native | Widget Android, tray + hotkey global Windows | P2 |
| FR-07 | Sync Otomatis | Bertahap: folder tersinkron -> Drive appData | P2 |

---

## 12. Pertanyaan Terbuka

1. Apakah tipe task cukup **binary** dan **counter**, atau perlu **durasi (menit)** / **rating 1-5**?
2. Apakah **target frekuensi** (mis. "3x/minggu") masuk MVP, atau cukup harian?
3. Apakah **batas ganti hari** dapat diatur user, atau dikunci ke 00:00 pada awalnya?
4. Default saat import: **merge** atau **replace**?
5. Format distribusi Windows: file `.exe` portabel, installer, atau MSIX?
6. Apakah platform Apple (iOS/macOS) mungkin dibutuhkan di masa depan? Pilihan framework dapat terpengaruh.

---

## 13. Ringkasan Keputusan Teknis

| Aspek | Keputusan |
|-------|-----------|
| Platform | Windows (`.exe`) + Android (APK) |
| Framework | Flutter |
| Database | Drift (SQLite) |
| State management | Riverpod |
| Model data | Event log append-only, UUIDv7, soft delete |
| Grid | Satu `CustomPainter` dengan hit-testing manual |
| Sync | Bertahap: manual -> folder tersinkron -> Drive `appDataFolder` |
| CI/CD | GitHub Actions (runner Windows) |
