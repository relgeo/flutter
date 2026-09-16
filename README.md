# RelGeo Flutter Workbench (v0.5 Dart/Flutter Port)

Workbench dan port Flutter untuk surface aktif `RelGeo DSL v0.5`.

Status posisi repo saat ini:

1. targetnya adalah parity tinggi terhadap baseline TypeScript
2. parity dijaga bertahap melalui audit dan shared reference fixtures
3. README ini tidak mengklaim parity final absolut untuk seluruh surface
4. surface Flutter saat ini terutama mengikuti domain technical drawing sebagai baseline parity, bukan mendefinisikan seluruh identitas RelGeo
5. repository ini adalah workbench non-publishable; versi aplikasi Flutter tidak sama dengan versi DSL
6. active/runtime/invalid shared-fixture dan semantic projection sudah diverifikasi secara lokal; active, runtime-diagnostic, dan candidate boolean/intersection juga lulus pada operasi, scene projection, dan SVG semantic projection ter-normalisasi tanpa parent workspace, sedangkan candidate belum active, cakupan SVG penuh, dan CI masih terbuka

---

## 🚀 Key Features

1. **Topological Scene Resolver**
   * Utilizes Kahn's DAG topological sorting (`sortUnified`) to resolve complex relational constraints and derived variables between variables and objects in a single pass.
2. **Polymorphic Clipper2 Boolean Engine**
   * Integrates the legendary Clipper2 library to normalize closed shapes (Rects, Circles, Polygons, Paths) and execute high-precision floating-point 2D operations (`union`, `subtract`, `intersect`, `xor`) with automated hole/contour sorting.
3. **Canvas Rendering for Active Presentation Surfaces**
   * Custom-built `CanvasPainter` mapping `ResolvedScene` layers to GPU-accelerated graphics using Flutter's native `Canvas`.
   * Standard Technical Drawing Roles (neon green for `final`, dashed slate for `construction`, crimson rose for `centerline`, amber for `hidden`, etc.).
   * Engineering linear/radius/diameter dimensions with custom arrowheads and rotated text alignment.
   * Lead lines and micro-underline annotations for technical drafting callouts.
4. **Parametric Desktop Workbench IDE**
   * **Dual Panel Split**: Left editor utilizing the advanced `re_editor` editor for RelGeo YAML DSL code, alongside dynamic diagnostics & values tables.
   * **Interactive Viewport**: Right panel utilizing `InteractiveViewer` with smooth zooming, panning, reset, and fit gesture controls over a custom engineering grid.
   * **Real-time Parametric Sliders**: Modifying dynamic parameters recalculates the entire topological graph on-the-fly and refreshes the canvas instantly in real-time.
   * **Workbench-only controls**: sheet/view selection, role filters, visual profiles, persisted preferences, object inspection, and runtime diagnostics.
   * **Vector SVG Exporter**: Compiles active layers into beautiful vector XML outputs exported directly to the local folder at `exports/bracket_parametric.svg`.

---

## 📂 Project Architecture

```
relgeo_flutter/
├── lib/
│   ├── relgeo_flutter.dart       # Main library exporter
│   ├── main.dart                 # Parametric split-view desktop workbench UI
│   └── src/
│       ├── core/
│       │   ├── units.dart        # Normalizer for px, mm, cm, m, inch, rad, deg
│       │   ├── evaluator.dart    # Recursive descent parser for arithmetic, logic & functions
│       │   ├── graph.dart        # Khan's unified topological sorting DAG solver
│       │   └── resolver.dart     # Topological compiler mapping constraints & objects
│       ├── geometry/
│       │   ├── types.dart        # Pure typed Dart AST geometric specs
│       │   ├── transforms.dart   # Translation, Rotation, Scale, Mirror operations
│       │   ├── utils.dart        # Vector utilities & segment point samplers
│       │   ├── intersection.dart # Analytical curves intersection engine
│       │   └── clipper_boolean.dart # Clipper2 polymorphic shapes boolean parser
│       └── ui/
│           └── canvas_painter.dart # Technical presentation painter with rotated annotation text
└── test/
    ├── evaluator_test.dart       # Evaluates expressions, logic, & unit normalization
    ├── graph_test.dart           # Tests Kahn's unified DAG sorting & circular dependency errors
    ├── clipper_test.dart         # Validates Clipper2 shape normalizations & subtractions
    ├── resolver_test.dart        # Tests scene evaluations and multi-level anchor transforms
    └── widget_test.dart          # Automated desktop-sized widget smoke test for the Flutter workbench
```

---

## 🛠️ Getting Started & Verification

### Prerequisites
* Flutter macOS SDK installed.
* Standard Flutter CLI configuration.

### 1. Run Verification Test Suite
Execute the active Flutter test suite:
```bash
flutter test
```

Untuk menjalankan gate yang men-stage fixture canonical workspace, gunakan dari root
`relgeo/workspace`:

```bash
pnpm run flutter:conformance
```

Gate workspace lokal terakhir lulus pada Flutter `3.41.9` / Dart `3.11.5`, termasuk 119 test.
Checkout Flutter terisolasi juga lulus analyzer non-fatal dan `flutter test` dengan 99 test; 7 test shared-fixture dilewati secara eksplisit karena fixture canonical berada di root workspace.
Analyzer sengaja memakai baseline non-fatal untuk lint/info legacy; seluruh temuannya
tetap dicetak. CI memiliki job terpisah dan belum menggantikan verifikasi lokal ini.

Test yang membaca canonical fixture workspace dapat diarahkan secara portable
ke directory fixture yang memiliki subdirectory `reference/`:

```bash
RELGEO_FIXTURE_ROOT=../fixtures flutter test test/reference_fixtures_test.dart
```

Integration gate boleh menunjuk `RELGEO_FIXTURE_ROOT` ke staging directory
sementara. Repository Flutter tidak menyimpan absolute path operator dan tidak
mem-publish canonical fixture sebagai package Dart.

Compatibility line aktif adalah `RelGeo DSL 0.5`; `version: 1.0.0+1` pada
`pubspec.yaml` adalah application version Flutter. Status evidence dan gap
lintas consumer dicatat di workspace pada
`docs/plans/06-flutter-alignment.md`.

Untuk status parity terbaru, lihat audit aktif di:

1. [RelGeo documentation](https://relgeo.github.io/)

### 2. Run Interactive Desktop Workbench Playground
Launch the Flutter workbench in your macOS environment:
```bash
flutter run -d macos
```

### 3. Vector SVG Export
Lokasi dan alur export SVG sebaiknya dianggap implementation detail UI aktif, bukan kontrak path tetap repo.

---

## 📐 Mathematical Parity & Float Optimization
To prevent decimal precision issues common to coordinate conversions, `units.dart` includes a fast-track parser. Units ending with their target unit (e.g. `"25mm"` in a `LengthUnit.mm` workspace) skip pixel roundtrips, ensuring exact floating-point equality matches (e.g., `circle.radius == 25.0`) in TDD assertions.
