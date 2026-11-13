# Learn Chess with Sol

> A Flutter chess trainer: play against a built-in engine with eight difficulty levels, get move-by-move commentary from a coach personality, track your Elo rating, and work through guided lessons.

![Flutter](https://img.shields.io/badge/Flutter-Dart%203.8-02569B?logo=flutter&logoColor=white)
![Platforms](https://img.shields.io/badge/platforms-Android%20%7C%20Windows%20%7C%20Web-lightgrey)
![State](https://img.shields.io/badge/state-Provider-blue)

The app is titled **Learn Chess with Sol** (this repository: `learn-chess-with-wali`). The engine, rating system, coach commentary and lesson flow are all implemented locally in Dart, with no external AI service or network calls.

---

## Features

**Play**
- **Two modes:** play against the computer or pass-and-play locally with a friend.
- **Side selection:** play as White, Black, or let the app pick at random.
- **Eight difficulty levels** labelled by Elo, from *beginner (600)* up to *Prof. Solomon (2700)*.
- **Built-in chess engine** (`lib/chess_ai.dart`): minimax search with alpha-beta pruning, piece-square-table evaluation and capture/promotion move ordering. Search depth scales from 1 to 4 plies, and most lower levels play a random move some of the time so they are easier to beat.
- **Full rules** via the [`chess`](https://pub.dev/packages/chess) package: legal-move generation, check, checkmate and draw detection.
- **In-game tools:** coach tips on request, undo, resign, board flip, and three board themes (Terracotta, Charcoal, Ocean).
- **Sound effects** for moves and captures, generated procedurally by `generate_sounds.py`.

**Coach**
- **16 coach personalities**, each based on an MBTI type and with its own portrait (`assets/mbti_coaches/`).
- **Context-aware commentary** (`lib/coach_personality.dart`): the coach reacts to categories such as checks, captures, hanging pieces, castling, early queen moves, wasted tempo, material swings, blunder streaks and comebacks.
- **Session memory:** commentary tracks what has happened this game and across games, and avoids repeating lines.

**Progress**
- **Elo rating system:** your rating updates after each game against the engine using the standard expected-score formula (K = 32).
- **Stats dashboard:** Elo progression line chart and win-rate ring, both drawn with `CustomPainter`.
- **Game history and review:** finished games are saved on the device and can be replayed move by move.
- **Persistence:** rating, stats, settings, chosen coach and game history are stored locally with `shared_preferences`.

**Training academy** (`lib/training_lessons.dart`)
- Five lessons: *The Italian Game* (openings), *The Knight Fork Tactic* (middlegame), *King and Pawn Endgame* (endgames), *Back-Rank Checkmate* (checkmates) and *Escaping the Back Rank* (avoiding checkmate).
- Each lesson runs in phases: **watch** the moves with commentary, **assist** by playing them with guidance, then solve **challenges** from set FEN positions, with feedback on correct and incorrect moves.

---

## Tech Stack

| Area | Technology |
| :--- | :--- |
| Framework | Flutter, Dart (SDK `^3.8.1`) |
| Chess rules | [`chess`](https://pub.dev/packages/chess) `^0.8.1` |
| State management | [`provider`](https://pub.dev/packages/provider) (`ChangeNotifier`) |
| Local storage | [`shared_preferences`](https://pub.dev/packages/shared_preferences) |
| Audio | [`audioplayers`](https://pub.dev/packages/audioplayers) |
| Graphics | [`flutter_svg`](https://pub.dev/packages/flutter_svg), [`chess_vectors_flutter`](https://pub.dev/packages/chess_vectors_flutter), custom `CustomPainter` charts |
| Tooling | `flutter_lints`, `flutter_launcher_icons`, Python script for sound generation |
| Platforms in repo | Android, Windows, Web |

---

## Getting Started

### Prerequisites
- [Flutter SDK](https://docs.flutter.dev/get-started/install) (stable channel) with Dart 3.8.1 or newer
- For Android: Android Studio or the Android SDK with an emulator or device
- For Windows desktop: Visual Studio with the "Desktop development with C++" workload

### Install and run
```bash
git clone https://github.com/WaliMedugu/learn-chess-with-wali.git
cd learn-chess-with-wali
flutter pub get
flutter run                 # choose a connected device
```

Target a specific platform:
```bash
flutter run -d windows
flutter run -d chrome
```

### Regenerate sound effects (optional)
```bash
python generate_sounds.py   # writes move.wav and capture.wav to assets/sounds/
```

---

## Project Structure

```
learn-chess-with-wali/
├── lib/
│   ├── main.dart                # App entry, home / play / train screens, stats charts, game history, move list
│   ├── chess_game_state.dart    # Game state (Provider): modes, difficulty, Elo, persistence, review, training flow
│   ├── chess_ai.dart            # Minimax engine with alpha-beta pruning and piece-square tables
│   ├── chess_board.dart         # Interactive board widget with piece animation
│   ├── coach_personality.dart   # Coach commentary engine, MBTI content banks, session memory
│   ├── training_lessons.dart    # Lesson definitions (watch moves, assist moves, FEN challenges)
│   └── theme_arguuu.dart        # Colours, typography and shared UI components
├── assets/
│   ├── mbti_coaches/            # 16 coach portraits
│   ├── sounds/                  # Move and capture sound effects
│   └── fonts/                   # App typefaces
├── android/  windows/  web/     # Platform projects
├── generate_sounds.py           # Procedural sound-effect generator
└── pubspec.yaml                 # Dependencies and asset configuration
```

---

## Author

**Medugu Wali** · [github.com/WaliMedugu](https://github.com/WaliMedugu) · [linkedin.com/in/meduguwali](https://www.linkedin.com/in/meduguwali)
