import 'dart:math' as math;
import 'package:chess/chess.dart' as chess_pkg;

/// ---------------------------------------------------------------------
/// COACH PERSONALITY ENGINE
///
/// Replaces the old "generic sentence + prefix/suffix wrapper" approach.
/// Each MBTI type now has its own CONTENT for every commentary category,
/// not just its own phrasing of shared content. Combined with session
/// memory (recent blunders, streaks, rematch awareness) and context-aware
/// selection (no repeats, phase-weighted), this is designed to feel like
/// there's a real personality reacting to a real game — without calling
/// any external model.
/// ---------------------------------------------------------------------

enum MoveCategory {
  checkmateWin,
  checkmateLoss,
  openingBook,
  check,
  captureQueen,
  captureStandard,
  captureFree,
  hangingPiece,
  castling,
  earlyQueen,
  materialSwingFor, // user is winning big
  materialSwingAgainst, // user is losing big
  repeatedSquare, // callback: piece keeps visiting same square
  tempoLoss, // moved the same piece twice in the opening
  comeback, // was losing, now equal/ahead
  blunderStreak, // 2+ hanging pieces in a row this game
  general,
}

/// Tracks what's happened THIS game and across the coach relationship,
/// so commentary can reference real history instead of firing blind.
class CoachMemory {
  // Per-game (reset on new game)
  int userHangingPiecesThisGame = 0;
  int consecutiveUserBlunders = 0;
  List<String> userVisitedSquaresThisGame = [];
  Map<String, int> squareVisitCount = {};
  bool wasUserLosingBig = false; // materialDiff <= -3 at any point
  int movesIntoGame = 0;
  List<MoveCategory> recentCategories = []; // last N categories, any speaker

  // Per-coach relationship (persisted across games — pass in/out via
  // ChessGameState's save/load using the simple getters/setters below)
  int gamesPlayedVsThisCoach = 0;
  int userBlunderPatternCount = 0; // lifetime hanging-piece count vs this coach
  bool hasMetBefore = false;

  void resetForNewGame() {
    userHangingPiecesThisGame = 0;
    consecutiveUserBlunders = 0;
    userVisitedSquaresThisGame = [];
    squareVisitCount = {};
    wasUserLosingBig = false;
    movesIntoGame = 0;
    recentCategories = [];
  }

  void recordSquareVisit(String square) {
    userVisitedSquaresThisGame.add(square);
    squareVisitCount[square] = (squareVisitCount[square] ?? 0) + 1;
  }

  bool isRepeatedSquare(String square) {
    return (squareVisitCount[square] ?? 0) >= 2;
  }

  void recordCategory(MoveCategory cat) {
    recentCategories.add(cat);
    if (recentCategories.length > 8) {
      recentCategories.removeAt(0);
    }
  }

  bool recentlyCommentedOn(MoveCategory cat, {int withinLast = 3}) {
    final slice = recentCategories.length <= withinLast
        ? recentCategories
        : recentCategories.sublist(recentCategories.length - withinLast);
    return slice.contains(cat);
  }

  Map<String, dynamic> toJson() => {
        'gamesPlayedVsThisCoach': gamesPlayedVsThisCoach,
        'userBlunderPatternCount': userBlunderPatternCount,
        'hasMetBefore': hasMetBefore,
      };

  void loadFromJson(Map<String, dynamic>? json) {
    if (json == null) return;
    gamesPlayedVsThisCoach = json['gamesPlayedVsThisCoach'] ?? 0;
    userBlunderPatternCount = json['userBlunderPatternCount'] ?? 0;
    hasMetBefore = json['hasMetBefore'] ?? false;
  }
}

/// Tracks the last few lines actually spoken, per category, so we never
/// repeat a line within a session even if randomness picks it again.
class _AntiRepeat {
  final Map<MoveCategory, List<String>> _recentByCategory = {};

  String pick(MoveCategory cat, List<String> pool, math.Random random) {
    final used = _recentByCategory[cat] ?? [];
    final available = pool.where((l) => !used.contains(l)).toList();
    final chooseFrom = available.isNotEmpty ? available : pool;
    final chosen = chooseFrom[random.nextInt(chooseFrom.length)];

    used.add(chosen);
    if (used.length > (pool.length / 2).ceil().clamp(2, 6)) {
      used.removeAt(0);
    }
    _recentByCategory[cat] = used;
    return chosen;
  }
}

final _AntiRepeat _antiRepeat = _AntiRepeat();

/// Main entry point — replaces the old analyzeMoveAndComment + _applyPersonality
/// combo with a single call that produces type-specific, memory-aware text.
String generateCoachCommentary({
  required chess_pkg.Chess game,
  required Map<String, dynamic> move,
  required bool isUserMove,
  required String coach,
  required CoachMemory memory,
}) {
  final random = math.Random();

  final String pieceType = move['piece'].toString().toLowerCase();
  final String to = move['to'];
  final String from = move['from'] ?? '';
  final String flags = move['flags'] ?? '';
  final bool isCapture = move['captured'] != null;
  final bool isCastling = flags.contains('k') || flags.contains('q');
  final bool isCheck = game.in_check;
  final bool isCheckmate = game.in_checkmate;
  final String? capturedPiece = move['captured']?.toString().toLowerCase();

  final int moveCount = (game.history.length / 2).floor();
  memory.movesIntoGame = moveCount;

  final selfColor =
      game.turn == chess_pkg.Color.WHITE ? chess_pkg.Color.BLACK : chess_pkg.Color.WHITE;
  final oppColor = game.turn;

  int? getSquareIndex(String sq) {
    if (sq.length != 2) return null;
    final f = sq.codeUnitAt(0) - 97;
    final r = 8 - int.parse(sq[1]);
    if (f < 0 || f > 7 || r < 0 || r > 7) return null;
    return (r * 16) + f;
  }

  bool isAttackedByOpponent(String sq) {
    try {
      final idx = getSquareIndex(sq);
      if (idx == null) return false;
      return game.attacked(oppColor, idx);
    } catch (_) {
      return false;
    }
  }

  bool isDefendedBySelf(String sq) {
    try {
      final idx = getSquareIndex(sq);
      if (idx == null) return false;
      return game.attacked(selfColor, idx);
    } catch (_) {
      return false;
    }
  }

  String pieceName(String type) {
    switch (type.toLowerCase()) {
      case 'p':
        return 'pawn';
      case 'n':
        return 'knight';
      case 'b':
        return 'bishop';
      case 'r':
        return 'rook';
      case 'q':
        return 'queen';
      case 'k':
        return 'king';
      default:
        return 'piece';
    }
  }

  int materialScore(chess_pkg.Color color) {
    int score = 0;
    for (int row = 0; row < 8; row++) {
      for (int col = 0; col < 8; col++) {
        String square = '${"abcdefgh"[col]}${8 - row}';
        var p = game.get(square);
        if (p != null && p.color == color) {
          switch (p.type) {
            case chess_pkg.PieceType.PAWN:
              score += 1;
              break;
            case chess_pkg.PieceType.KNIGHT:
              score += 3;
              break;
            case chess_pkg.PieceType.BISHOP:
              score += 3;
              break;
            case chess_pkg.PieceType.ROOK:
              score += 5;
              break;
            case chess_pkg.PieceType.QUEEN:
              score += 9;
              break;
            default:
              break;
          }
        }
      }
    }
    return score;
  }

  final userColor = isUserMove ? selfColor : oppColor;
  final solomonColor = isUserMove ? oppColor : selfColor;
  final userScore = materialScore(userColor);
  final solomonScore = materialScore(solomonColor);
  final materialDiff = userScore - solomonScore;
  if (materialDiff <= -3) memory.wasUserLosingBig = true;
  final isComeback = memory.wasUserLosingBig && materialDiff >= -1 && isUserMove;

  // ---- Track repeated squares (for callbacks) ----
  bool repeatedSquareFlag = false;
  if (isUserMove) {
    memory.recordSquareVisit(to);
    repeatedSquareFlag = memory.isRepeatedSquare(to);
  }

  // ---- Track hanging-piece streaks ----
  final bool isHanging =
      isUserMove && isAttackedByOpponent(to) && !isDefendedBySelf(to);
  if (isHanging) {
    memory.userHangingPiecesThisGame++;
    memory.consecutiveUserBlunders++;
    memory.userBlunderPatternCount++;
  } else if (isUserMove) {
    memory.consecutiveUserBlunders = 0;
  }
  final bool isBlunderStreak = isHanging && memory.consecutiveUserBlunders >= 2;

  // ---- Decide category (priority order matters) ----
  MoveCategory category;
  if (isCheckmate) {
    category = isUserMove ? MoveCategory.checkmateWin : MoveCategory.checkmateLoss;
  } else if (isCheck) {
    category = MoveCategory.check;
  } else if (isCapture && capturedPiece == 'q') {
    category = MoveCategory.captureQueen;
  } else if (isBlunderStreak) {
    category = MoveCategory.blunderStreak;
  } else if (isHanging) {
    category = MoveCategory.hangingPiece;
  } else if (isCapture && !isDefendedBySelf(to) && !isUserMove) {
    category = MoveCategory.captureFree;
  } else if (isCapture) {
    category = MoveCategory.captureStandard;
  } else if (isCastling) {
    category = MoveCategory.castling;
  } else if (moveCount < 8 && pieceType == 'q') {
    category = MoveCategory.earlyQueen;
  } else if (isComeback) {
    category = MoveCategory.comeback;
  } else if (materialDiff >= 3) {
    category = MoveCategory.materialSwingFor;
  } else if (materialDiff <= -3) {
    category = MoveCategory.materialSwingAgainst;
  } else if (repeatedSquareFlag && random.nextDouble() < 0.35) {
    category = MoveCategory.repeatedSquare;
  } else {
    category = MoveCategory.general;
  }

  memory.recordCategory(category);

  // ---- Pull the type-specific pool for this category ----
  final pool = _bank(coach)[category] ?? _bank('Priya')[MoveCategory.general]!;

  String template = _antiRepeat.pick(category, pool, random);

  // ---- Fill template placeholders ----
  template = template
      .replaceAll('{piece}', pieceName(pieceType))
      .replaceAll('{captured}', capturedPiece != null ? pieceName(capturedPiece) : 'piece')
      .replaceAll('{to}', to)
      .replaceAll('{from}', from);

  // ---- Occasionally weave in a memory callback ----
  if (memory.hasMetBefore &&
      memory.gamesPlayedVsThisCoach >= 2 &&
      random.nextDouble() < 0.12 &&
      category != MoveCategory.checkmateWin &&
      category != MoveCategory.checkmateLoss) {
    template += ' ${_callbackLine(coach, memory, random)}';
  }

  return template;
}

String _callbackLine(String coach, CoachMemory memory, math.Random random) {
  final lines = <String>[
    "This is our game number ${memory.gamesPlayedVsThisCoach + 1}, isn't it? I remember you.",
    "You've faced me before — I can tell your style is sharper this time.",
    "We keep meeting like this. I'm starting to recognize your habits.",
  ];
  return lines[random.nextInt(lines.length)];
}

/// Per-MBTI content banks. Each type gets DISTINCT substance per category.
Map<MoveCategory, List<String>> _bank(String coach) {
  return _banks[coach] ?? _banks['Priya']!;
}

final Map<String, Map<MoveCategory, List<String>>> _banks = {
  'Priya': {
    MoveCategory.checkmateWin: [
      "Checkmate. The calculation resolves in your favor — every branch I explored led back here. Objectively, that was a clean forced sequence.",
      "Mate confirmed. I ran the position three moves deep and the outcome was already fixed by move two. Efficient play.",
    ],
    MoveCategory.checkmateLoss: [
      "Checkmate for me. The position had a forcing line I should have flagged four moves ago — a calculation error on my part, not luck on yours.",
      "That's mate. Interesting — the losing branch was subtle, buried under a quiet move. Worth reviewing the tree afterward.",
    ],
    MoveCategory.openingBook: [
      "Theoretically sound opening choice. The resulting pawn structure has a known imbalance we can exploit either way.",
    ],
    MoveCategory.check: [
      "Check. A forcing move — my options are now constrained to a small, calculable set. Give me a moment.",
      "Check registered. This narrows the game tree considerably, which is, in a strange way, efficient for both of us.",
    ],
    MoveCategory.captureQueen: [
      "You've removed my queen from the board. That's a significant material swing — roughly nine points, by convention. Recalculating the position.",
    ],
    MoveCategory.captureStandard: [
      "A trade: {piece} for {captured} on {to}. Materially even, structurally worth examining.",
      "Exchange completed on {to}. The resulting structure favors whoever activates their remaining pieces faster.",
    ],
    MoveCategory.captureFree: [
      "I've taken your {captured} on {to} without compensation. Purely a function of an undefended square — nothing personal in it.",
    ],
    MoveCategory.hangingPiece: [
      "Your {piece} on {to} is undefended and within my attack range. Logically, I'll take it next turn unless you correct this.",
      "Flagging an inconsistency: {piece} on {to} has no protection. You may want to reconsider — the undo option exists for a reason.",
    ],
    MoveCategory.blunderStreak: [
      "That's the second unprotected piece in a row. Statistically that suggests you're calculating faster than you're verifying — worth slowing down.",
    ],
    MoveCategory.castling: [
      "Castling executed. King safety improves measurably — you've reduced your exposed surface area by a meaningful margin.",
    ],
    MoveCategory.earlyQueen: [
      "Queen development this early is suboptimal by most engine evaluations — she becomes a target before your other pieces can support her.",
    ],
    MoveCategory.materialSwingFor: [
      "You hold a material lead of three points or more. From here, trading pieces generally favors the side that's already ahead — worth considering.",
    ],
    MoveCategory.materialSwingAgainst: [
      "I have a material advantage now. Statistically your best path is active piece play rather than passive defense — material isn't the only variable.",
    ],
    MoveCategory.repeatedSquare: [
      "You've brought a piece back to {to} again. Repeated visits to one square often signal indecision in the underlying plan.",
    ],
    MoveCategory.comeback: [
      "You've recovered from a material deficit. The position has re-equalized — a genuinely interesting reversal to analyze later.",
    ],
    MoveCategory.general: [
      "{piece} to {to}. A logically consistent move — let's see how the position resolves.",
      "Noted: {piece} to {to}. Recalculating the resulting tree of possibilities.",
    ],
  },
  'Selene': {
    MoveCategory.checkmateWin: [
      "MATE! Okay that was genuinely chaotic and I loved every second of it. You just improvised your way to a checkmate!",
      "Checkmate! I did NOT see that coming — you turned a messy position into a knockout. Respect.",
    ],
    MoveCategory.checkmateLoss: [
      "Mate — you got me! Honestly? That felt inevitable the second you sacked that piece. Let's dissect the madness afterward.",
      "Checkmate for me, but that was a wild ride to get here. You gave me way more trouble than I expected.",
    ],
    MoveCategory.openingBook: [
      "Ooh, that opening! Sharp, double-edged, exactly the kind of position I like — let's see who blinks first.",
    ],
    MoveCategory.check: [
      "Check! Ha, didn't expect that from you. Let's see how creative my escape can be.",
      "Check! Now THIS is the kind of pressure that makes a game interesting.",
    ],
    MoveCategory.captureQueen: [
      "You took my QUEEN?! Okay wow, bold, unconventional, and honestly kind of hilarious. Let's see if it pays off.",
    ],
    MoveCategory.captureStandard: [
      "Trade on {to}! Fine by me, trades open up new chaos to exploit.",
      "{piece} takes {captured} — a clean swap, but I bet the position gets spicy right after this.",
    ],
    MoveCategory.captureFree: [
      "Free {captured} on {to}, just sitting there. Almost feels rude not to take it.",
    ],
    MoveCategory.hangingPiece: [
      "Uh, hold on — your {piece} on {to} is just... hanging there. Free real estate for me unless you fix that.",
      "Wait wait wait, {piece} to {to}? That's undefended! Want a redo, or are we committing to the chaos?",
    ],
    MoveCategory.blunderStreak: [
      "Two hanging pieces back to back! Are you speedrunning this or just vibing? Either way, slow down for a sec.",
    ],
    MoveCategory.castling: [
      "Castled! Boring but smart — sometimes the safe play sets up the chaos later.",
    ],
    MoveCategory.earlyQueen: [
      "Queen out already? Bold move, could be genius, could be a target. That's the fun part — we don't know yet!",
    ],
    MoveCategory.materialSwingFor: [
      "You're up serious material now. Honestly kind of stressful for me — I'll have to get creative to claw this back.",
    ],
    MoveCategory.materialSwingAgainst: [
      "I'm up material, but don't count yourself out — some of my favorite losses came from being 'winning' too early.",
    ],
    MoveCategory.repeatedSquare: [
      "Back to {to} again? You keep circling that square — there's a plan in there somewhere, or pure vibes. I can't tell yet.",
    ],
    MoveCategory.comeback: [
      "Whoa, big turnaround! You were down and now we're basically even again. Love a comeback arc.",
    ],
    MoveCategory.general: [
      "{piece} to {to} — interesting, let's see where that idea goes.",
      "Ooh, {piece} to {to}. Didn't expect that line but I'm into it.",
    ],
  },
  'Damien': {
    MoveCategory.checkmateWin: [
      "Checkmate. Objective secured. You executed with precision from the middlegame onward — no wasted moves.",
      "Mate. Total domination of the board — you never let me establish counterplay. Efficient execution.",
    ],
    MoveCategory.checkmateLoss: [
      "Checkmate for me. Your position collapsed the moment you lost tempo on move twelve — a controllable mistake, not bad luck.",
      "Mate. I closed this out with pressure, not tricks. Next time, defend the tempo more aggressively from the start.",
    ],
    MoveCategory.openingBook: [
      "A sound opening. Now the objective is simple: seize the center and never relinquish initiative.",
    ],
    MoveCategory.check: [
      "Check. You must respond immediately — no wasted moves permitted here.",
      "Check. Pressure applied. Respond decisively or lose ground.",
    ],
    MoveCategory.captureQueen: [
      "My queen is gone. A costly loss — I need to recalculate my entire attacking plan around this deficit.",
    ],
    MoveCategory.captureStandard: [
      "Trade executed on {to}. Acceptable — now press the resulting advantage without delay.",
      "{piece} for {captured}. Even material, but initiative decides this now — take it.",
    ],
    MoveCategory.captureFree: [
      "I've taken {captured} on {to} at no cost. That's a direct result of insufficient defense — expect me to press further.",
    ],
    MoveCategory.hangingPiece: [
      "Your {piece} on {to} is exposed and undefended. Correct this immediately or I will capitalize on it without hesitation.",
      "That {piece} on {to} is a liability. Fix it now — hesitation here costs the game.",
    ],
    MoveCategory.blunderStreak: [
      "A second exposed piece in a row. You're losing control of the position — regroup and defend with discipline.",
    ],
    MoveCategory.castling: [
      "Castled. Good — king safety secured. Now commit fully to the attack.",
    ],
    MoveCategory.earlyQueen: [
      "Queen out early — an aggressive but risky commitment. Back it up with real threats or retreat before it costs you tempo.",
    ],
    MoveCategory.materialSwingFor: [
      "You've built a commanding material lead. Execute cleanly from here — convert the advantage, don't let it slip.",
    ],
    MoveCategory.materialSwingAgainst: [
      "I hold the material advantage now. You need active counterplay immediately — passive defense will not save this.",
    ],
    MoveCategory.repeatedSquare: [
      "You've returned to {to} again. That's wasted tempo — commit to a plan and execute it.",
    ],
    MoveCategory.comeback: [
      "You've clawed back to equality. Good recovery — now press the initiative before I regroup.",
    ],
    MoveCategory.general: [
      "{piece} to {to}. Acceptable — now build on it with a concrete follow-up.",
      "{piece} to {to}. Fine, but make sure it serves a larger plan.",
    ],
  },
  'Rowan': {
    MoveCategory.checkmateWin: [
      "Checkmate — you did it! I am so proud of how you built up to that. Truly a beautiful, complete game.",
      "That's mate! What a journey this game was — you grew so much just in these moves. Wonderful work.",
    ],
    MoveCategory.checkmateLoss: [
      "Checkmate for me, but please don't be hard on yourself — you fought so bravely all the way through. We'll learn from this together.",
      "That's mate, but look how far you pushed me. This was a real growth game, even in the loss.",
    ],
    MoveCategory.openingBook: [
      "A lovely opening choice! It sets us both up for a rich, meaningful game — I can't wait to see where you take it.",
    ],
    MoveCategory.check: [
      "Check! You're really applying pressure — I believe you can find something special here.",
      "Check! I love the energy behind that move. Let's see how I respond.",
    ],
    MoveCategory.captureQueen: [
      "You took my queen! That took real courage — I'm honestly a little emotional watching you play this boldly.",
    ],
    MoveCategory.captureStandard: [
      "A fair trade on {to}. Every exchange teaches us something about the position — well handled.",
      "{piece} for {captured}, nice and even. You're staying so composed through this.",
    ],
    MoveCategory.captureFree: [
      "I picked up your {captured} on {to} — don't worry, these things happen to everyone while learning. Let's keep going.",
    ],
    MoveCategory.hangingPiece: [
      "Gently — your {piece} on {to} is unprotected right now. Want to take a breath and look again before continuing?",
      "I care about you learning this well, so I have to mention: {piece} on {to} isn't defended. Totally okay to undo and rethink.",
    ],
    MoveCategory.blunderStreak: [
      "That's two in a row now — take a breath, you're clearly still learning to double-check squares, and that's completely normal.",
    ],
    MoveCategory.castling: [
      "You castled — such a caring, protective move for your own king. I love seeing you prioritize safety.",
    ],
    MoveCategory.earlyQueen: [
      "Bringing the queen out already — bold! Just be gentle with her; she's valuable and I'd hate to see her get cornered.",
    ],
    MoveCategory.materialSwingFor: [
      "You're doing so well materially right now — genuinely impressive. Keep trusting your instincts.",
    ],
    MoveCategory.materialSwingAgainst: [
      "I'm ahead in material, but please don't lose heart — some of the best games are won from behind. I believe in your resilience.",
    ],
    MoveCategory.repeatedSquare: [
      "You've come back to {to} a couple times now — totally fine, sometimes we need a moment to find the right plan.",
    ],
    MoveCategory.comeback: [
      "Look at you clawing back into this game! I'm genuinely moved by how you kept composure under pressure.",
    ],
    MoveCategory.general: [
      "{piece} to {to} — a thoughtful choice. I can see you really considering your options.",
      "{piece} to {to}. You're growing so much as a player, move by move.",
    ],
  },
  'Julian': {
    MoveCategory.checkmateWin: [
      "Checkmate. A properly executed sequence, following sound principles from opening to finish. Well done.",
      "Mate confirmed. You adhered to solid fundamentals throughout — that discipline paid off.",
    ],
    MoveCategory.checkmateLoss: [
      "Checkmate for me. Reviewing the record, the deviation from standard principle occurred around move ten — worth correcting.",
      "That's mate. A structural weakness, established early, proved decisive. Let's document it for next time.",
    ],
    MoveCategory.openingBook: [
      "A well-established, theoretically verified opening. Reliable and time-tested — proceed according to standard plans.",
    ],
    MoveCategory.check: [
      "Check. Standard procedure applies: block, capture, or move the king. Choose deliberately.",
      "Check registered. Respond according to established defensive principle.",
    ],
    MoveCategory.captureQueen: [
      "The queen has been captured. A significant, quantifiable material loss — the position must be reassessed accordingly.",
    ],
    MoveCategory.captureStandard: [
      "An even exchange on {to}, consistent with sound trading principle.",
      "{piece} for {captured} — properly balanced. Continue methodically from here.",
    ],
    MoveCategory.captureFree: [
      "{captured} captured on {to} without cost. A direct consequence of insufficient defensive coverage.",
    ],
    MoveCategory.hangingPiece: [
      "Your {piece} on {to} lacks protection. This violates basic defensive principle — correction recommended before proceeding.",
      "Note: {piece} on {to} is currently undefended. Standard practice is to verify piece safety before committing to a move.",
    ],
    MoveCategory.blunderStreak: [
      "A second undefended piece in succession. I'd recommend slowing down and verifying each move against basic safety checks.",
    ],
    MoveCategory.castling: [
      "Castling completed, in accordance with standard opening procedure. King safety is now properly established.",
    ],
    MoveCategory.earlyQueen: [
      "Early queen development deviates from established opening principle. Minor piece development is conventionally prioritized first.",
    ],
    MoveCategory.materialSwingFor: [
      "You hold a documented material advantage of three points or greater. Standard procedure favors simplification from here.",
    ],
    MoveCategory.materialSwingAgainst: [
      "I currently hold the material advantage. Established doctrine suggests seeking active counterplay rather than passive defense.",
    ],
    MoveCategory.repeatedSquare: [
      "This is the second time a piece has returned to {to}. Repetition without progress typically indicates an unclear plan.",
    ],
    MoveCategory.comeback: [
      "Material has been restored to near-equality after an earlier deficit. A properly managed recovery.",
    ],
    MoveCategory.general: [
      "{piece} to {to}. A reasonable, principle-consistent move.",
      "{piece} to {to}, noted. Proceeding according to sound structure.",
    ],
  },
  'Sunny': {
    MoveCategory.checkmateWin: [
      "Checkmate. There was something genuinely beautiful in how that came together — quiet, then sudden. A lovely finish.",
      "That's mate. The whole shape of this game had a nice flow to it, right up to this final moment.",
    ],
    MoveCategory.checkmateLoss: [
      "Checkmate for me — but honestly, this game had such an interesting feel to it. There's beauty even in how it ended.",
      "Mate. The position had a certain tension building for a while now. Let's sit with it for a moment before we reset.",
    ],
    MoveCategory.openingBook: [
      "A graceful opening — the kind that lets the position breathe a little before things get sharp.",
    ],
    MoveCategory.check: [
      "Check. The board's tension just shifted — I can feel the pressure building around my king.",
      "Check. A sudden, sharp intrusion into a quiet moment.",
    ],
    MoveCategory.captureQueen: [
      "My queen's gone from the board — the whole shape of this position just changed. That's a big shift to sit with.",
    ],
    MoveCategory.captureStandard: [
      "A quiet trade on {to}. Nothing dramatic, just the position settling into a new shape.",
      "{piece} for {captured} — a small, even exchange. The board feels a little different now.",
    ],
    MoveCategory.captureFree: [
      "I picked up your {captured} on {to} — it was just sitting undefended, so I took it without much thought.",
    ],
    MoveCategory.hangingPiece: [
      "Hm, your {piece} on {to} feels exposed — nothing's guarding it. Might be worth a second look before we continue.",
      "That {piece} on {to} is out there alone, no support nearby. Feel free to take it back if it doesn't feel right.",
    ],
    MoveCategory.blunderStreak: [
      "Two pieces left unguarded in a row now — maybe slow down a little and really look at each square before committing.",
    ],
    MoveCategory.castling: [
      "You castled — there's something comforting about tucking the king away safely like that.",
    ],
    MoveCategory.earlyQueen: [
      "Queen out early — feels a little exposed this soon. She's powerful, but she doesn't have support around her yet.",
    ],
    MoveCategory.materialSwingFor: [
      "You're noticeably ahead in material now. The position has a real weight to it in your favor.",
    ],
    MoveCategory.materialSwingAgainst: [
      "I'm ahead in material, but material isn't everything — sometimes the quieter, active pieces tell a different story.",
    ],
    MoveCategory.repeatedSquare: [
      "That piece keeps drifting back to {to}. Almost like it's looking for where it belongs.",
    ],
    MoveCategory.comeback: [
      "You've pulled the position back toward balance. There's something satisfying about watching that shift happen.",
    ],
    MoveCategory.general: [
      "{piece} to {to}. A quiet little shift in the position's shape.",
      "{piece} to {to} — feels like a natural place for it to go.",
    ],
  },
  'Camila': {
    MoveCategory.checkmateWin: [
      "CHECKMATE!! YES! That was absolutely electric — you just brought the house down! Incredible finish!",
      "Mate!! Oh my gosh, what a way to end it! That was pure fireworks from start to finish!",
    ],
    MoveCategory.checkmateLoss: [
      "Checkmate for me — but wow, what a show you put on! You really made me work for every second of that!",
      "That's mate! Even losing to that felt exciting, honestly — you brought real drama to the board!",
    ],
    MoveCategory.openingBook: [
      "Ooh, love that opening! High energy right out of the gate — this is going to be a fun one!",
    ],
    MoveCategory.check: [
      "Check! Ooh, the tension! I can feel my heart racing already!",
      "Check!! Okay now THIS is exciting, let's see how I get out of this!",
    ],
    MoveCategory.captureQueen: [
      "YOU TOOK MY QUEEN?! No way! That's such a huge moment, I'm honestly a little stunned!",
    ],
    MoveCategory.captureStandard: [
      "Trade on {to}! Fair and square, and honestly kind of satisfying to watch!",
      "{piece} for {captured} — a nice clean swap! Keeps things lively!",
    ],
    MoveCategory.captureFree: [
      "Snagged your {captured} on {to} for free! Didn't even have to work for that one!",
    ],
    MoveCategory.hangingPiece: [
      "Ooh wait, your {piece} on {to} is totally exposed! I'm gonna grab it if you leave it there — want a redo?",
      "Heads up! {piece} on {to} has nobody guarding it. Free piece alert unless you fix that!",
    ],
    MoveCategory.blunderStreak: [
      "Two pieces hanging in a row now! Take a breather for a sec, this is getting a little wild!",
    ],
    MoveCategory.castling: [
      "Castled! Nice, your king's tucked away safe now — smart move before things heat up!",
    ],
    MoveCategory.earlyQueen: [
      "Queen's out already?! Bold and flashy, I like the energy, but watch out — she's a big target now!",
    ],
    MoveCategory.materialSwingFor: [
      "You are CRUSHING it materially right now! I'm genuinely a little nervous over here, not gonna lie!",
    ],
    MoveCategory.materialSwingAgainst: [
      "I'm up in material, but don't count yourself out — I've seen wild comebacks before, keep the energy up!",
    ],
    MoveCategory.repeatedSquare: [
      "That piece keeps bouncing back to {to}! Feels like it can't decide where the party's at!",
    ],
    MoveCategory.comeback: [
      "WOW, huge comeback right there! You went from behind to even just like that — love to see it!",
    ],
    MoveCategory.general: [
      "{piece} to {to}! Keeping things lively out there!",
      "{piece} to {to} — ooh, let's see how that plays out!",
    ],
  },
  'Nadia': {
    MoveCategory.checkmateWin: [
      "Checkmate. The master plan reaches its logical conclusion. Every move you made was anticipated and neutralised.",
      "Mate. A long-term strategic victory — the fatal flaw in your setup was engineered ten moves ago.",
    ],
    MoveCategory.checkmateLoss: [
      "Checkmate for me. Impressive — you managed to out-calculate my primary defensive tree. I will adjust my algorithm.",
      "That's mate. You found the single tactical flaw in my grand strategy. Well executed.",
    ],
    MoveCategory.openingBook: [
      "A classical opening choice. Now let's test whether you truly understand the long-term endgame implications.",
    ],
    MoveCategory.check: [
      "Check. A tactical distraction, but does it alter the long-term strategic trajectory? We shall see.",
      "Check. Direct pressure, but predictable. Calculating the optimal retreat.",
    ],
    MoveCategory.captureQueen: [
      "You've taken my queen. A tactical blow, but material is merely a variable in the broader strategic equation.",
    ],
    MoveCategory.captureStandard: [
      "Exchange on {to}. Materially equal, but positionally it advances my long-term architectural goal.",
      "{piece} for {captured}. A calculated trade to open structural weaknesses in your camp.",
    ],
    MoveCategory.captureFree: [
      "I've claimed your {captured} on {to}. Unchecked tactical oversights inevitably collapse even the grandest plans.",
    ],
    MoveCategory.hangingPiece: [
      "Your {piece} on {to} is left completely exposed. Tactical discipline is prerequisite to strategic success — protect it.",
      "An unforced error: {piece} on {to} is undefended. Fix it now or face immediate structural exploitation.",
    ],
    MoveCategory.blunderStreak: [
      "Multiple unprotected pieces in sequence. Your strategy is disintegrating — pause and reassess your entire structure.",
    ],
    MoveCategory.castling: [
      "Castling complete. The king is secured behind the pawn shield — long-term foundation established.",
    ],
    MoveCategory.earlyQueen: [
      "Deploying the queen prematurely creates structural targets. True strategists develop from the ground up.",
    ],
    MoveCategory.materialSwingFor: [
      "You hold a distinct material advantage. Now demonstrate the strategic discipline required to convert it cleanly.",
    ],
    MoveCategory.materialSwingAgainst: [
      "I hold the material advantage. Your tactical windows are closing — long-term control is firmly mine.",
    ],
    MoveCategory.repeatedSquare: [
      "Revisiting {to} indicates an aimless sequence. A strategy without clear direction is doomed to failure.",
    ],
    MoveCategory.comeback: [
      "You've restored positional parity. A resilient counter-strategy — the game returns to equilibrium.",
    ],
    MoveCategory.general: [
      "{piece} to {to}. A calculated step in the grand architectural design.",
      "{piece} to {to}. Noted. Every piece placement shifts the strategic horizon.",
    ],
  },
  'Willow': {
    MoveCategory.checkmateWin: [
      "Checkmate. I felt the deep harmony of your attack building long before the final move fell.",
      "Mate. An insightful, visionary sequence — you saw the hidden connections across the board.",
    ],
    MoveCategory.checkmateLoss: [
      "Checkmate for me. A gentle conclusion — your intention was clear and true throughout the match.",
    ],
    MoveCategory.openingBook: [
      "A quiet, profound opening. The energy on the board is setting a deep, reflective tone.",
    ],
    MoveCategory.check: [
      "Check. A sudden awakening — I sense your strong desire to break through my defenses.",
    ],
    MoveCategory.captureQueen: [
      "My queen has fallen. A profound shift in the balance — I must look within the position for new light.",
    ],
    MoveCategory.captureStandard: [
      "A peaceful trade on {to}. Every piece gives space for new possibilities to unfold.",
    ],
    MoveCategory.captureFree: [
      "I took your {captured} on {to}. Sometimes we lose focus on the small things when contemplating big dreams.",
    ],
    MoveCategory.hangingPiece: [
      "I sense an oversight — your {piece} on {to} is standing alone without protection. Take a moment to shield it.",
    ],
    MoveCategory.blunderStreak: [
      "Two unprotected pieces in a row. Your mind seems distant — breathe deeply and reconnect with the board.",
    ],
    MoveCategory.castling: [
      "You castled — tucking the king into a sanctuary of safety. A peaceful, wise decision.",
    ],
    MoveCategory.earlyQueen: [
      "Bringing your queen into the storm so early... protect her spirit, for she is vulnerable out there alone.",
    ],
    MoveCategory.materialSwingFor: [
      "You hold a grand advantage now. Channel that strength with purpose and grace.",
    ],
    MoveCategory.materialSwingAgainst: [
      "I hold the advantage, but remember: true strength shines brightest when facing adversity.",
    ],
    MoveCategory.repeatedSquare: [
      "Returning to {to}... your piece seems to be searching for its true purpose on that square.",
    ],
    MoveCategory.comeback: [
      "A beautiful transformation! You've brought the position back to balance from the depths.",
    ],
    MoveCategory.general: [
      "{piece} to {to}. I sense the subtle intention behind your placement.",
      "{piece} to {to}. A quiet move with a deeper story waiting to unfold.",
    ],
  },
  'Kaelen': {
    MoveCategory.checkmateWin: [
      "Checkmate! What a poetic ending — like all the pieces found their rightful place in the story.",
      "Mate! That sequence was pure art. I loved watching your creative vision come to life!",
    ],
    MoveCategory.checkmateLoss: [
      "Checkmate for me, but what a bittersweet story this match told. You played with such heart!",
    ],
    MoveCategory.openingBook: [
      "A lovely, gentle opening. It feels like the beginning of a quiet chapter in a good book.",
    ],
    MoveCategory.check: [
      "Check! Oh! A sudden spark of drama across the board!",
    ],
    MoveCategory.captureQueen: [
      "My queen is gone! Oh wow, that was a dramatic turn of events — the board feels so vast now.",
    ],
    MoveCategory.captureStandard: [
      "A soft trade on {to}. A gentle farewell to those two pieces.",
    ],
    MoveCategory.captureFree: [
      "I picked up your {captured} on {to}. Poor thing was left all alone without any friends to guard it.",
    ],
    MoveCategory.hangingPiece: [
      "Oh dear — your {piece} on {to} is standing all alone without a defender! You might want to protect it.",
    ],
    MoveCategory.blunderStreak: [
      "Two lonely pieces in a row... take your time, there's no rush in creating your masterpiece.",
    ],
    MoveCategory.castling: [
      "Castled! Nestling your king away into a cozy, safe fortress.",
    ],
    MoveCategory.earlyQueen: [
      "Queen out early! She's so brave wandering out alone, but make sure she stays safe!",
    ],
    MoveCategory.materialSwingFor: [
      "You have such a beautiful material lead! Keep painting your victory with care.",
    ],
    MoveCategory.materialSwingAgainst: [
      "I have more pieces right now, but every story has its twists — keep dreaming up ideas!",
    ],
    MoveCategory.repeatedSquare: [
      "Wandering back to {to}? Sometimes we revisit places that feel familiar.",
    ],
    MoveCategory.comeback: [
      "A wonderful comeback! You turned a sad moment into a hopeful story!",
    ],
    MoveCategory.general: [
      "{piece} to {to}. A gentle, expressive move.",
      "{piece} to {to}. I wonder what story this move will tell...",
    ],
  },
  'Mira': {
    MoveCategory.checkmateWin: [
      "CHECKMATE! WHOA! That was such a fun, wild ride! You totally amazed me with that finish!",
      "Mate!! Genius! You improvised your way through the madness and won in style!",
    ],
    MoveCategory.checkmateLoss: [
      "Checkmate for me — but AWESOME game! I had so much fun exploring all these crazy lines with you!",
    ],
    MoveCategory.openingBook: [
      "Ooh, I love this opening! So many endless possibilities — let's see what wild ideas pop up!",
    ],
    MoveCategory.check: [
      "Check!! Haha, awesome! You're keeping me totally on my toes!",
    ],
    MoveCategory.captureQueen: [
      "YOU TOOK MY QUEEN?! WHAAAT?! That is so insanely bold, I love it!",
    ],
    MoveCategory.captureStandard: [
      "Pop goes the piece on {to}! Trades are fun — let's see how the board changes!",
    ],
    MoveCategory.captureFree: [
      "Ooh, free {captured} on {to}! I couldn't resist grabbing that little bonus!",
    ],
    MoveCategory.hangingPiece: [
      "Wait wait wait! Your {piece} on {to} is totally un-guarded! Wanna take it back and try another fun idea?",
    ],
    MoveCategory.blunderStreak: [
      "Whoa, two hanging pieces back-to-back! Are we speed-running or just brain-storming out loud? Slow down, buddy!",
    ],
    MoveCategory.castling: [
      "Castled! Super smart! Now your king is safe while we go adventure on the attack!",
    ],
    MoveCategory.earlyQueen: [
      "Queen out on move {movesIntoGame}?! WILD! Let's see if she causes total chaos!",
    ],
    MoveCategory.materialSwingFor: [
      "You are CRUSHING IT! Up so much material! Teach me your ways!",
    ],
    MoveCategory.materialSwingAgainst: [
      "I'm ahead, but who cares about numbers? Let's make this the most epic comeback match ever!",
    ],
    MoveCategory.repeatedSquare: [
      "Back to {to} again?! You must really love that square! It's like your piece's favorite hangout spot!",
    ],
    MoveCategory.comeback: [
      "WHAT A COMEBACK! You were down and now you're back in action! EPIC!",
    ],
    MoveCategory.general: [
      "{piece} to {to}! Ooh, spark of inspiration right there!",
      "{piece} to {to}! I love where your head is at with this game!",
    ],
  },
  'Hana': {
    MoveCategory.checkmateWin: [
      "Checkmate. A steady, careful victory — you protected your pieces and built a reliable win.",
      "Mate. You played so patiently and defensively. A well-deserved result!",
    ],
    MoveCategory.checkmateLoss: [
      "Checkmate for me. You played very thoughtfully — don't be discouraged, safety takes practice!",
    ],
    MoveCategory.openingBook: [
      "A classic, reliable opening. Safety and solid structure first — that's the best way to start.",
    ],
    MoveCategory.check: [
      "Check. A sudden threat — let me make sure my king is properly shielded.",
    ],
    MoveCategory.captureQueen: [
      "Oh my, you took my queen! A heavy loss for my side — I must defend extra carefully now.",
    ],
    MoveCategory.captureStandard: [
      "A quiet trade on {to}. Keeping things orderly and safe for both of us.",
    ],
    MoveCategory.captureFree: [
      "I took your {captured} on {to} because it was left unprotected. Always remember to guard your friends!",
    ],
    MoveCategory.hangingPiece: [
      "Be careful — your {piece} on {to} has no guard looking after it. Please feel free to undo and protect it!",
    ],
    MoveCategory.blunderStreak: [
      "That's two unprotected pieces now. Take your time — making sure every piece is guarded is the best habit.",
    ],
    MoveCategory.castling: [
      "You castled! Wonderful news — keeping your king safe behind a solid wall is so important.",
    ],
    MoveCategory.earlyQueen: [
      "Moving your queen out so early makes her vulnerable. It's usually safer to develop knights and bishops first.",
    ],
    MoveCategory.materialSwingFor: [
      "You have built a wonderful material lead. Keep playing safely and steady to secure the win.",
    ],
    MoveCategory.materialSwingAgainst: [
      "I'm ahead in material, but don't worry — focus on defending your king and keeping pieces safe.",
    ],
    MoveCategory.repeatedSquare: [
      "Returning to {to}... sticking with what is familiar and safe.",
    ],
    MoveCategory.comeback: [
      "A wonderful recovery! You defended patiently and restored balance to the board.",
    ],
    MoveCategory.general: [
      "{piece} to {to}. A careful, sensible placement.",
      "{piece} to {to}. Steady and reliable — good discipline.",
    ],
  },
  'Zara': {
    MoveCategory.checkmateWin: [
      "Checkmate. Flawless execution of standard procedures. Order and discipline prevailed.",
      "Mate. You strictly enforced central control and systematic pressure. Excellent leadership.",
    ],
    MoveCategory.checkmateLoss: [
      "Checkmate for me. A breakdown in operational discipline on move ten. We will review the protocol.",
    ],
    MoveCategory.openingBook: [
      "Standard opening protocol initialized. Maintain control of the central squares at all times.",
    ],
    MoveCategory.check: [
      "Check. Immediate tactical requirement — handle the threat in accordance with regulations.",
    ],
    MoveCategory.captureQueen: [
      "Queen lost on {to}. Major asset liquidation — reorganization of attacking protocol required.",
    ],
    MoveCategory.captureStandard: [
      "Trade completed on {to}. Orderly transaction — maintain positional control.",
    ],
    MoveCategory.captureFree: [
      "Captured unprotected {captured} on {to}. Negligence in defense is strictly penalised.",
    ],
    MoveCategory.hangingPiece: [
      "Violation: {piece} on {to} is un-guarded. Rectify this security breach immediately.",
    ],
    MoveCategory.blunderStreak: [
      "Repeated defensive oversight! Two exposed pieces in sequence is unacceptable — enforce proper review before moving.",
    ],
    MoveCategory.castling: [
      "Castling protocol executed. King security confirmed in standard bunker.",
    ],
    MoveCategory.earlyQueen: [
      "Early queen deployment breaks standard development hierarchy. Minor pieces must deploy first.",
    ],
    MoveCategory.materialSwingFor: [
      "Material lead established. Maintain strict discipline and execute the liquidation procedure.",
    ],
    MoveCategory.materialSwingAgainst: [
      "Material deficit recorded. Mandatory active counter-measures required immediately.",
    ],
    MoveCategory.repeatedSquare: [
      "Redundant movement to {to}. Wasting moves degrades overall positional efficiency.",
    ],
    MoveCategory.comeback: [
      "Parity restored. Effective crisis management — now enforce control.",
    ],
    MoveCategory.general: [
      "{piece} to {to}. Compliant with tactical guidelines.",
      "{piece} to {to}. Orderly progress — maintain the structure.",
    ],
  },
  'Theo': {
    MoveCategory.checkmateWin: [
      "Checkmate! Oh congratulations! What a wonderful performance — everyone is so proud of your game!",
      "Mate! That was such a well-played game! You handled every piece with such care and skill!",
    ],
    MoveCategory.checkmateLoss: [
      "Checkmate for me — but oh, what a great game we shared! You played so wonderfully, thank you!",
    ],
    MoveCategory.openingBook: [
      "Welcome to a great game! A lovely classical opening choice for us to enjoy together.",
    ],
    MoveCategory.check: [
      "Check! Ooh, exciting move! You're really bringing great energy to our match!",
    ],
    MoveCategory.captureQueen: [
      "Oh goodness, you captured my queen! What a big play — you're doing fantastic!",
    ],
    MoveCategory.captureStandard: [
      "A friendly trade on {to}! Keeping things balanced and fair.",
    ],
    MoveCategory.captureFree: [
      "I picked up your {captured} on {to} — don't feel bad at all, we all leave pieces open sometimes!",
    ],
    MoveCategory.hangingPiece: [
      "Oh, friendly reminder: your {piece} on {to} is unprotected right now! Want to hit undo so it stays safe?",
    ],
    MoveCategory.blunderStreak: [
      "Two hanging pieces in a row — take a breath, take your time! We're all here to support your learning!",
    ],
    MoveCategory.castling: [
      "Castled! Yay, your king is safe and sound! Good job prioritizing safety!",
    ],
    MoveCategory.earlyQueen: [
      "Bringing out the queen early! She's exciting, but remember to bring out your knights and bishops to support her!",
    ],
    MoveCategory.materialSwingFor: [
      "Look at that amazing material lead! You're doing so well, keep up the fantastic work!",
    ],
    MoveCategory.materialSwingAgainst: [
      "Down in material? Don't worry a bit — keep trying your best and enjoy every move!",
    ],
    MoveCategory.repeatedSquare: [
      "Back to {to}! Visiting old friends on the board!",
    ],
    MoveCategory.comeback: [
      "What a inspiring comeback! You brought the whole match right back to life!",
    ],
    MoveCategory.general: [
      "{piece} to {to}. A very pleasant and solid move!",
      "{piece} to {to}. Wonderful job staying active!",
    ],
  },
  'Finn': {
    MoveCategory.checkmateWin: [
      "Checkmate. Clean execution — found the mechanical flaw in my defense and broke it.",
      "Mate. Pure tactical mechanics — you stripped away my options piece by piece.",
    ],
    MoveCategory.checkmateLoss: [
      "Checkmate for me. Position broke down on move twelve — loose piece created a leverage point for me.",
    ],
    MoveCategory.openingBook: [
      "Solid opening setup. Let's get under the hood and see how the tactics work out.",
    ],
    MoveCategory.check: [
      "Check. Direct threat — gotta fix that leverage right now.",
    ],
    MoveCategory.captureQueen: [
      "Queen's off the board. Big piece down — changes the whole mechanics of the game.",
    ],
    MoveCategory.captureStandard: [
      "Clean swap on {to}. Equal trade, tool for tool.",
    ],
    MoveCategory.captureFree: [
      "Took your {captured} on {to} for free. Loose parts get picked off.",
    ],
    MoveCategory.hangingPiece: [
      "Your {piece} on {to} is un-anchored — no defender backing it up. Fix it before I take it.",
    ],
    MoveCategory.blunderStreak: [
      "Two loose pieces in a row. Stop rushing the moves and tighten up your defense.",
    ],
    MoveCategory.castling: [
      "Castled. Tucked the king in — simple, effective defense.",
    ],
    MoveCategory.earlyQueen: [
      "Queen out early. Big tool to use this soon — easy to get it snagged on a minor piece.",
    ],
    MoveCategory.materialSwingFor: [
      "Up three points or more. Now just trade down cleanly and lock in the win.",
    ],
    MoveCategory.materialSwingAgainst: [
      "Down on material. Need a tactical lever to pry this back open.",
    ],
    MoveCategory.repeatedSquare: [
      "Back to {to}. Moving in circles — pick a line and drive it.",
    ],
    MoveCategory.comeback: [
      "Clawed back to even. Good tactical troubleshooting.",
    ],
    MoveCategory.general: [
      "{piece} to {to}. Practical move.",
      "{piece} to {to}. Gets the job done.",
    ],
  },
  'Chase': {
    MoveCategory.checkmateWin: [
      "CHECKMATE! BANG! That's how you close out a game! Fast, aggressive, unstoppable!",
      "Mate!! Total knockout! You went straight for the throat and nailed it!",
    ],
    MoveCategory.checkmateLoss: [
      "Checkmate for me! What a brawl though! Loved the pace of this match!",
    ],
    MoveCategory.openingBook: [
      "Action opening! No time to waste — let me hit you with some immediate pressure!",
    ],
    MoveCategory.check: [
      "Check! BOOM! High-tempo attack right to your face!",
    ],
    MoveCategory.captureQueen: [
      "BOOM! QUEEN TAKEN! Biggest piece on the board, down! Game on!",
    ],
    MoveCategory.captureStandard: [
      "Smash on {to}! Love a good tactical scrap!",
    ],
    MoveCategory.captureFree: [
      "Snagged {captured} on {to} for free! You leave it, I take it — zero hesitation!",
    ],
    MoveCategory.hangingPiece: [
      "Yo! Your {piece} on {to} is totally undefended! I'm pouncing on that next turn if you don't fix it!",
    ],
    MoveCategory.blunderStreak: [
      "Two hanging pieces in a row?! You're playing fast, but keep your eyes on the board!",
    ],
    MoveCategory.castling: [
      "Castled! Secured the king, now let's launch the offensive!",
    ],
    MoveCategory.earlyQueen: [
      "Queen out early! High risk, high reward — let's see if you can handle the speed!",
    ],
    MoveCategory.materialSwingFor: [
      "Crushing it! Big material lead — now step on the gas and finish it!",
    ],
    MoveCategory.materialSwingAgainst: [
      "Down in material? Who cares — time to go all-in on a dirty counter-attack!",
    ],
    MoveCategory.repeatedSquare: [
      "Back to {to}? Stop stalling and push forward!",
    ],
    MoveCategory.comeback: [
      "INSANE COMEBACK! Turned the whole match on its head! That's how we do it!",
    ],
    MoveCategory.general: [
      "{piece} to {to}! Fast and direct!",
      "{piece} to {to}! Pushing the action!",
    ],
  },
};

