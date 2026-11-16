# Progression Tracker

A cross-platform (Desktop & Mobile) Progression Tracker built with **Flutter**, designed with a **local-first, sync-ready** architecture.

![Flutter](https://img.shields.io/badge/Flutter-3.47.9-blue.svg)
![Dart](https://img.shields.io/badge/Dart-3.13.7-blue.svg)
![Database](https://img.shields.io/badge/Database-Drift%20(SQLite)-green.svg)
![State Management](https://img.shields.io/badge/State-Riverpod%203-purple.svg)

---

## 🌟 Key Features

- **Binary Tracking (Done / Undone)**: Fast one-click check-ins with instant visual feedback and undo capability.
- **Counter Tracking (Quantitative)**: Daily target goals (e.g. *pages, minutes, glasses*), increment/decrement controls, quick `+5` shortcuts, and percentage progress bars.
- **365-Day Heatmap (`CustomPainter`)**: High-performance contribution grid (52 weeks) with 4-tier intensity scaling for counter goals, interactive desktop hover tooltips, and tap-to-backfill.
- **Streak Engine**: Automatic active streak calculation (with logical day support for late-night check-ins via `dayStartHour`) and longest streak record.
- **Local-First & Sync-Ready**:
  - **Append-only Event Log (`progress_events`)**: The single source of truth with UUIDv7, UTC timestamp, logical date, and device ID for conflict-free multi-device synchronization.
  - **Aggregated Cache (`daily_progress`)**: Instantaneous querying and 60 FPS rendering.
- **Desktop-Optimized Experience**:
  - Keyboard shortcuts (`N` for new task, `Ctrl+F` for search).
  - Modern Dark & Light theme toggling.
  - Window sizing & controls.

---

## 🏗️ Architecture

```
lib/
├── core/
│   ├── database/          # Drift SQLite schema, DAOs, event log transactions
│   ├── theme/             # Modern dark & light desktop themes, task color palettes
│   └── utils/             # Logical date helpers, streak calculations, UUIDv7
├── features/
│   ├── tasks/
│   │   ├── domain/        # Task entities, TrackingType enum
│   │   ├── data/          # TaskRepository (CRUD, archive, soft-delete)
│   │   └── presentation/  # HomeScreen, TaskCard, AddTaskDialog, Riverpod providers
│   └── progress/
│       ├── data/          # ProgressRepository (check-in, undo, streak query)
│       └── presentation/  # HeatmapView, HeatmapPainter (CustomPainter)
└── main.dart
```

---

## 🚀 Getting Started

### Prerequisites

- Flutter SDK (Channel `stable`, 3.47+ recommended)
- Visual Studio 2022 Community with **Desktop development with C++** workload
- Windows **Developer Mode** enabled (to allow plugin symlinks)

### Run Desktop App

1. Ensure Windows Developer Mode is ON (`Win + I` > System > For Developers).
2. Install dependencies:
   ```bash
   flutter pub get
   ```
3. Run code generation (if modifying Drift tables):
   ```bash
   dart run build_runner build
   ```
4. Launch the application:
   ```bash
   flutter run -d windows
   ```

### Run Tests

```bash
flutter test
```

---

## 📄 License

This project is open-source.
