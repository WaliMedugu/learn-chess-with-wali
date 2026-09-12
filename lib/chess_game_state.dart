import 'dart:math' as math;
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:chess/chess.dart' as chess_pkg;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:audioplayers/audioplayers.dart';
import 'chess_ai.dart';
import 'theme_arguuu.dart';
import 'training_lessons.dart';
import 'coach_personality.dart';

enum GameMode { vsComputer, localPlay }
enum PlayerColor { white, black, random }
enum BoardTheme { terracotta, charcoal, ocean }

class ChessGameState extends ChangeNotifier {
  late chess_pkg.Chess game;
  final AudioPlayer _audioPlayer = AudioPlayer();
  
  String currentCoach = 'Priya';
  final List<String> mbtiCoaches = [
    'Priya', 'Nadia', 'Selene', 'Damien',
    'Kaelen', 'Willow', 'Mira', 'Rowan',
    'Julian', 'Hana', 'Zara', 'Theo',
    'Finn', 'Sunny', 'Chase', 'Camila'
  ];
  final CoachMemory coachMemory = CoachMemory();

  void selectCoach(String coach) {
    if (mbtiCoaches.contains(coach)) {
      currentCoach = coach;
      saveState();
      notifyListeners();
    }
  }

  void _triggerSound(bool isCapture) {
    try {
      final String path = isCapture ? 'sounds/capture.wav' : 'sounds/move.wav';
      _audioPlayer.stop().then((_) {
        _audioPlayer.play(AssetSource(path));
      });
    } catch (e) {
      debugPrint("Error playing sound: $e");
    }
  }

  bool makeMoveWithSound(dynamic moveArgs) {
    String from;
    String to;
    if (moveArgs is Map) {
      from = moveArgs['from'] as String;
      to = moveArgs['to'] as String;
    } else {
      return game.move(moveArgs);
    }
    
    final bool isPawnDiagonal = (game.get(from)?.type == chess_pkg.PieceType.PAWN && from[0] != to[0]);
    final bool isCapture = game.get(to) != null || isPawnDiagonal;
    
    final bool success = game.move(moveArgs);
    if (success) {
      _triggerSound(isCapture);
    }
    return success;
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    super.dispose();
  }
  
  // Solomon coach difficulty ELO levels configuration
  final List<int> opponentElos = [600, 900, 1200, 1500, 1800, 2100, 2400, 2700];
  final List<String> difficultyLabels = [
    "beginner",
    "strong beginner",
    "intermediate",
    "strong intermediate",
    "advanced",
    "strong advanced",
    "expert",
    "Prof. Solomon"
  ];

  // Specific user-requested Solomon dialogue and commentary text decks
  static final List<String> welcomes = [
    "Welcome back to the board!",
    "Are you ready for another game?",
    "Let's see what we can learn today.",
    "I have the white pieces, so I will start.",
    "You have the white pieces; feel free to make the first move.",
    "Take your time; there is no rush.",
    "It is good to see you practicing again.",
    "Let us review some concepts from our last session.",
    "Shall we dive straight into a new match?",
    "I will play a bit more defensively this time.",
    "Let's try an opening you haven't seen much yet.",
    "Remember to focus on the center right from the start.",
    "I am looking forward to seeing your strategy today.",
    "We can pause and analyze whenever you feel stuck.",
    "Would you like a guided lesson, or just a free game?",
    "Your progress lately has been quite impressive.",
    "Let us set up the pieces and begin.",
    "I will try to challenge your pawn structure today.",
    "Deep breath; let's play some thoughtful chess.",
    "Let's see how you handle this particular opening variation."
  ];

  static final List<String> centerControl = [
    "Notice how that move fights for the middle of the board.",
    "It is usually best to develop knights before bishops.",
    "Bringing the queen out too early can make her a target.",
    "See how your pawns are blocking your own bishop's diagonal.",
    "Castling early is a cornerstone of good king safety.",
    "Moving the same piece twice in the opening wastes valuable time.",
    "By pushing that pawn, you have claimed significant central space.",
    "I am challenging your control of the dark squares.",
    "Developing with a threat is an excellent way to gain tempo.",
    "Your pieces are working together beautifully to dominate the center.",
    "Leaving the king in the center too long invites disaster.",
    "That fianchetto gives your bishop a commanding view of the long diagonal.",
    "You are letting me establish a strong pawn center.",
    "It is important to connect your rooks along the back rank.",
    "I am developing my final minor piece into the action.",
    "That move prepares to castle on the queenside.",
    "A strong center restricts my pieces from finding active outposts.",
    "You have successfully completed your opening development.",
    "We are now transitioning into the middlegame.",
    "My knight is well-placed here, putting pressure on your territory."
  ];

  static final List<String> praises = [
    "That is a truly excellent move.",
    "I did not see that coming; well played!",
    "You found the absolute best continuation.",
    "That tactic wins material by force.",
    "You have trapped my piece beautifully.",
    "This is a very sophisticated positional idea.",
    "What a precise calculation!",
    "You are applying tremendous pressure right now.",
    "That sacrifice opens up my king's defenses completely.",
    "You punished my mistake perfectly.",
    "I love how you capitalized on that weak square.",
    "That is a grandmaster-level concept.",
    "You are squeezing the life out of my position.",
    "A very patient and prophylactic move.",
    "You spotted the weakness in my back rank.",
    "That combination was completely sound.",
    "You have navigated a very complicated position flawlessly.",
    "I must admit, I am struggling to defend against this attack.",
    "That move improves your worst-placed piece.",
    "You have seized the initiative brilliantly."
  ];

  static final List<String> blunders = [
    "Let's look at why that move might get you into trouble.",
    "Are you sure you want to leave that piece hanging?",
    "That is a blunder, I am afraid.",
    "I think you missed a golden opportunity there.",
    "Notice how my bishop is now eyeing your rook.",
    "You have walked directly into a mating net.",
    "That move unfortunately loses a lot of material.",
    "I can simply capture that for free.",
    "You might want to take that move back and try again.",
    "Let us pause; do you see the threat I just created?",
    "That pawn push weakens your king's shelter permanently.",
    "You have allowed me to fork your major pieces.",
    "I think you overlooked my knight's reach.",
    "That exchange favors me heavily.",
    "You are moving a piece that was essential for defense.",
    "Let me show you how I can exploit that gap.",
    "That allows me to force a checkmate in two moves.",
    "You have trapped your own bishop with that pawn.",
    "I believe you focused on the attack and forgot about your own safety.",
    "That is the wrong capture; let's rewind and find the right one."
  ];

  static final List<String> pinsAndSkewers = [
    "You have successfully pinned my knight to the king.",
    "This is an absolute pin; that piece cannot legally move.",
    "I am pinning your defender to win the exchange.",
    "See how my rook skewers your queen and the bishop behind it.",
    "You must break this pin before it causes serious damage.",
    "By moving the king, you step out of the troublesome pin.",
    "That skewer forces you to give up the more valuable piece.",
    "My bishop is paralyzed because it is pinned to my queen.",
    "You can exploit that pin by adding more attackers to the pinned piece.",
    "I am using a pawn to attack your pinned knight.",
    "This relative pin is annoying, but I can still move the piece if I must.",
    "You missed a chance to skewer my rooks along the open file.",
    "That tactical shot relies entirely on the pin along the diagonal.",
    "Breaking the pin with a tempo is a highly effective defensive resource.",
    "Notice how the pinned piece is a terrible defender.",
    "I am shifting my queen to escape the x-ray attack.",
    "You have set up a nasty skewer on the seventh rank.",
    "The pressure on that pinned pawn is becoming unbearable.",
    "Unpinning your piece allows it to rejoin the battle.",
    "A well-placed skewer often decides the game on the spot."
  ];

  static final List<String> forksAndDiscovered = [
    "That knight fork is devastating!",
    "You have discovered an attack on my queen while giving check.",
    "A royal fork! You are attacking my king and queen simultaneously.",
    "I am using this pawn to fork your two minor pieces.",
    "Moving that bishop unleashed a discovered check from the rook.",
    "You overlooked a simple two-move fork tactic.",
    "Discovered attacks are powerful because they create two separate threats.",
    "That double attack is impossible to defend against completely.",
    "You missed a beautiful family fork with the knight.",
    "I am retreating to avoid the impending discovered attack.",
    "This tactical sequence culminates in a lethal rook fork.",
    "When you moved the knight, it opened a line for your queen.",
    "A double check forces the king to move; it cannot be blocked.",
    "You used a sacrifice to lure my king into a knight fork.",
    "That discovered attack wins a clean tempo.",
    "I must give up material to escape this double threat.",
    "Your queen and bishop battery is extremely dangerous here.",
    "That fork relies on the fact that my defender is overworked.",
    "A simple pawn fork can completely ruin an opponent's center.",
    "You have perfectly orchestrated a discovered attack on my loose piece."
  ];

  static final List<String> defensesAndSafety = [
    "Sometimes, the best move is simply to improve your defenses.",
    "You need to create some breathing room for your king.",
    "That move overextends your position and leaves weaknesses behind.",
    "A solid pawn structure is your best shield in the endgame.",
    "You are doing a good job of keeping your king tucked away safely.",
    "I am trying to rip open the files leading to your monarch.",
    "Prophylaxis is about stopping your opponent's plan before it starts.",
    "You must defend that critical square at all costs.",
    "Traded queens often drastically reduce the attacking potential.",
    "You have successfully blockaded my dangerous passed pawn.",
    "It is vital to coordinate your pieces to cover all entry points.",
    "I am forcing a trade to relieve the pressure on my position.",
    "Pushing the pawns in front of your castled king is highly risky.",
    "You found the only defensive move to keep the game going.",
    "A timely counterattack is sometimes the best form of defense.",
    "You are passively defending; try to find some active counterplay.",
    "Do not panic; calculate the threats calmly and respond.",
    "My attack has fizzled out because of your resilient defense.",
    "You have built a fortress that I simply cannot break through.",
    "Always evaluate your opponent's most forcing replies when defending."
  ];

  static final List<String> endgames = [
    "In the endgame, the king becomes a powerful attacking piece.",
    "We must activate the king and bring it toward the center.",
    "You have secured the opposition, which is crucial in pawn endings.",
    "This is a theoretical draw if defended correctly.",
    "A passed pawn must be pushed!",
    "You are navigating this rook endgame with great precision.",
    "I am trying to create a passed pawn on the queenside.",
    "This bishop of opposite colors endgame is notoriously drawish.",
    "You need to put your rook behind the passed pawn to support it.",
    "A knight struggles against pawns on both sides of the board.",
    "You must cut off my king's path to the promotion square.",
    "This pawn race will come down to a single tempo.",
    "Be very careful not to stalemate me here!",
    "You have successfully forced my king to the edge of the board.",
    "This is a classic Philidor position; do you know the drawing method?",
    "You are squeezing me into zugzwang; any move I make loses.",
    "The principle of two weaknesses is the key to winning this position.",
    "You need to shoulder away my king to secure the promotion.",
    "A queen easily defeats a lone pawn, provided there are no stalemate tricks.",
    "You have demonstrated an excellent understanding of endgame technique."
  ];

  static final List<String> postGameReviews = [
    "That was a tough game, but you played well overall.",
    "Let's review some mistakes from our game to see where things went wrong.",
    "I saved a few key moments from earlier that we should examine.",
    "Try to find a better move here; what else could you have played?",
    "Do you want to swap perspectives and look at this from my side?",
    "Let's try this position again, utilizing the spaced repetition method.",
    "You missed this tactic last time; let's see if you can spot it now.",
    "Understanding why this move fails is more important than memorizing the right one.",
    "Notice how your position collapsed after this specific inaccuracy.",
    "If you had played this instead, the evaluation would be completely equal.",
    "Let's isolate this tactical pattern so you recognize it in the future.",
    "I want you to focus on the pawn structure in this particular review.",
    "You correctly identified the threat this time; excellent progress!",
    "We will revisit this specific endgame scenario in a few days.",
    "It is perfectly normal to struggle with this complex opening trap.",
    "Reviewing these painful blunders is how you forge true chess mastery.",
    "I am adding this position to your customized training deck.",
    "Let's walk through the engine's top choice and understand its logic.",
    "You are making fewer of these one-move blunders; your board vision is improving.",
    "Let's clear the board and start fresh with these lessons in mind."
  ];

  static final List<String> hintsAndFarewells = [
    "You are really getting the hang of this concept.",
    "I can give you a hint if you are struggling to find a plan.",
    "Look at the weak dark squares around my king for inspiration.",
    "Don't be discouraged; chess is a lifelong journey of learning.",
    "Think about which of your pieces is currently doing the least amount of work.",
    "Consider how you might exploit the lack of defenders on the queenside.",
    "I admire your persistence in trying to crack this defensive shell.",
    "Would you like me to highlight the piece that is in danger?",
    "You have a solid positional advantage; now you just need to convert it.",
    "Trust your intuition here, but verify it with concrete calculation.",
    "This is a critical moment in the game; take all the time you need.",
    "I will leave you to ponder this position for a moment.",
    "You are playing like a seasoned tournament veteran today.",
    "Every master was once a beginner who refused to give up.",
    "Would you like to stop here for today and resume later?",
    "I hope this lesson clarified the concepts we discussed.",
    "You have earned a rest after that grueling tactical battle.",
    "Keep practicing these patterns, and they will become second nature.",
    "Thank you for the excellent game; I always enjoy our matches.",
    "I look forward to our next training session!"
  ];

  // Configuration
  GameMode gameMode = GameMode.vsComputer;
  PlayerColor playerColor = PlayerColor.white;
  int aiDifficulty = 2; // Default to intermediate (index 2)
  BoardTheme boardTheme = BoardTheme.terracotta;
  bool isBoardFlipped = false;
  
  // Game State Variables
  String? selectedSquare;
  List<String> legalDestinations = [];
  String? lastMoveFrom;
  String? lastMoveTo;
  bool isThinking = false;
  
  // Undo/Redo support using FEN history
  List<String> fenHistory = [];
  
  // User ELO rating and persistent stats
  int userElo = 800;
  bool hasSelectedLevel = false;
  int gamesPlayed = 0;
  int gamesWon = 0;
  int gamesDrawn = 0;
  int gamesLost = 0;

  // Completed Game History
  List<Map<String, dynamic>> gameHistory = [];

  // Training Mode state variables
  bool isTrainingMode = false;
  int trainingLessonIndex = 0;
  String trainingPhase = 'watch'; // 'watch', 'assist', 'real', 'success'
  int trainingWatchStep = 0;
  int trainingAssistStep = 0;
  int trainingChallengeIndex = 0;
  int trainingChallengeStep = 0;

  // Review Mode state
  bool isReviewMode = false;
  List<String> reviewFens = [];
  int reviewIndex = 0;
  String? reviewOpponentName;
  String? reviewDate;
  String? reviewResult;
  List<Map<String, dynamic>> reviewMoveLog = [];

  List<Map<String, dynamic>> get activeMoveLog => isReviewMode ? reviewMoveLog : moveLog;
  int get activeMoveHistoryIndex => isReviewMode ? reviewIndex - 1 : moveHistoryIndex;

  // Solomon's dynamic commentary bubble text
  String lastCommentary = "Welcome back to the board!";
  String? previousCommentary;
  
  // Side selection popup state before every game start
  bool isPendingSideSelection = true;

  // ELO calculation state check
  bool isEloCalculatedForCurrentGame = false;

  // Game Status
  String gameStatusMessage = 'Your turn';

  // ─── Move History Tracking ───────────────────────────────────────────────
  // Each entry: { 'san': String, 'time': double (seconds), 'quality': 'best'|'miss'|'mistake'|'normal', 'isUser': bool }
  List<Map<String, dynamic>> moveLog = [];
  DateTime? _lastMoveTime;  // timestamp just before current turn

  // Quick-stats derived from moveLog (user moves only)
  int get statBest     => moveLog.where((m) => m['isUser'] == true && m['quality'] == 'best').length;
  int get statMisses   => moveLog.where((m) => m['isUser'] == true && m['quality'] == 'miss').length;
  int get statMistakes => moveLog.where((m) => m['isUser'] == true && m['quality'] == 'mistake').length;

  // Current review index for the move-history panel (separate from full review mode)
  int moveHistoryIndex = -1; // -1 means "live" (not navigating history)

  ChessGameState() {
    _initGame();
    loadState();
  }

  void _initGame() {
    game = chess_pkg.Chess();
    selectedSquare = null;
    legalDestinations = [];
    lastMoveFrom = null;
    lastMoveTo = null;
    isThinking = false;
    fenHistory = [game.fen];
    isEloCalculatedForCurrentGame = false;
    isPendingSideSelection = true;
    coachMemory.resetForNewGame();
    moveLog = [];
    moveHistoryIndex = -1;
    _lastMoveTime = null;
    
    // Auto flip board if playing as Black
    if (gameMode == GameMode.vsComputer && playerColor == PlayerColor.black) {
      isBoardFlipped = true;
    } else {
      isBoardFlipped = false;
    }
    
    _updateStatusMessage();
  }

  // Review Mode navigation controls
  void startReviewMode(Map<String, dynamic> gameRecord) {
    isReviewMode = true;
    reviewFens = List<String>.from(gameRecord['fens']);
    reviewIndex = 0;
    reviewOpponentName = gameRecord['opponent'] as String?;
    reviewDate = gameRecord['date'] as String?;
    reviewResult = gameRecord['result'] as String?;
    
    if (gameRecord['moveLog'] != null) {
      try {
        final List<dynamic> rawLog = gameRecord['moveLog'] as List<dynamic>;
        reviewMoveLog = rawLog.map((m) => Map<String, dynamic>.from(m as Map)).toList();
      } catch (_) {
        reviewMoveLog = [];
      }
    } else {
      reviewMoveLog = [];
    }

    // Load the starting move FEN
    game.load(reviewFens[reviewIndex]);
    lastMoveFrom = null;
    lastMoveTo = null;
    notifyListeners();
  }

  void stepReview(int offset) {
    if (!isReviewMode) return;
    int newIndex = (reviewIndex + offset).clamp(0, reviewFens.length - 1);
    if (newIndex != reviewIndex) {
      reviewIndex = newIndex;
      game.load(reviewFens[reviewIndex]);
      
      // Pull a random review text to simulate coached walkthrough comments
      final random = math.Random();
      final newComment = postGameReviews[random.nextInt(postGameReviews.length)];
      if (newComment != lastCommentary) {
        previousCommentary = lastCommentary;
        lastCommentary = newComment;
      }
      
      notifyListeners();
    }
  }

  void exitReviewMode() {
    isReviewMode = false;
    reviewFens = [];
    reviewIndex = 0;
    reviewOpponentName = null;
    reviewDate = null;
    reviewResult = null;
    reviewMoveLog = [];
    // Restore live active match exactly from persistent state
    loadState();
  }

  // Set user starting ELO level selection
  Future<void> setUserStartingLevel(int elo) async {
    userElo = elo;
    hasSelectedLevel = true;
    previousCommentary = null;
    final random = math.Random();
    lastCommentary = welcomes[random.nextInt(welcomes.length)];
    saveState();
    notifyListeners();
  }

  // Load state from SharedPreferences
  Future<void> loadState() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      userElo = prefs.getInt('userElo') ?? 800;
      hasSelectedLevel = prefs.getBool('hasSelectedLevel') ?? false;
      gamesPlayed = prefs.getInt('gamesPlayed') ?? 0;
      gamesWon = prefs.getInt('gamesWon') ?? 0;
      gamesDrawn = prefs.getInt('gamesDrawn') ?? 0;
      gamesLost = prefs.getInt('gamesLost') ?? 0;
      
      aiDifficulty = prefs.getInt('aiDifficulty') ?? 2;
      gameMode = GameMode.values[prefs.getInt('gameMode') ?? 0];
      playerColor = PlayerColor.values[prefs.getInt('playerColor') ?? 0];
      boardTheme = BoardTheme.values[prefs.getInt('boardTheme') ?? 0];
      isBoardFlipped = prefs.getBool('isBoardFlipped') ?? false;
      isEloCalculatedForCurrentGame = prefs.getBool('isEloCalculatedForCurrentGame') ?? false;
      lastCommentary = prefs.getString('lastCommentary') ?? "Welcome back to the board!";
      previousCommentary = prefs.getString('previousCommentary');
      currentCoach = prefs.getString('currentCoach') ?? 'Priya';
      final memJson = prefs.getString('coachMemory');
      if (memJson != null) {
        try {
          coachMemory.loadFromJson(jsonDecode(memJson) as Map<String, dynamic>);
        } catch (_) {}
      }

      // Load Game History
      String? historyJson = prefs.getString('gameHistory');
      if (historyJson != null) {
        try {
          final decoded = jsonDecode(historyJson);
          if (decoded is List) {
            gameHistory = decoded.map((item) {
              if (item is Map) {
                return Map<String, dynamic>.from(item);
              }
              return <String, dynamic>{};
            }).where((item) => item.isNotEmpty).toList();
          } else {
            gameHistory = [];
          }
        } catch (_) {
          gameHistory = [];
        }
      } else {
        gameHistory = [];
      }
      _recalculateStats();

      String? savedFen = prefs.getString('savedFen');
      List<String>? savedHistory = prefs.getStringList('savedHistory');
      if (savedFen != null) {
        game = chess_pkg.Chess();
        game.load(savedFen);
        fenHistory = savedHistory ?? [savedFen];
      }
      isPendingSideSelection = prefs.getBool('isPendingSideSelection') ?? (fenHistory.length <= 1);
      
      _updateStatusMessage();
      notifyListeners();

      if (!isPendingSideSelection && isAiTurn && !isThinking) {
        triggerAiMove();
      }
    } catch (e) {
      // SharedPreferences failsafe
    }
  }

  // Save state to SharedPreferences
  Future<void> saveState() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('userElo', userElo);
      await prefs.setBool('hasSelectedLevel', hasSelectedLevel);
      await prefs.setInt('gamesPlayed', gamesPlayed);
      await prefs.setInt('gamesWon', gamesWon);
      await prefs.setInt('gamesDrawn', gamesDrawn);
      await prefs.setInt('gamesLost', gamesLost);
      
      await prefs.setInt('aiDifficulty', aiDifficulty);
      await prefs.setInt('gameMode', gameMode.index);
      await prefs.setInt('playerColor', playerColor.index);
      await prefs.setInt('boardTheme', boardTheme.index);
      await prefs.setBool('isBoardFlipped', isBoardFlipped);
      await prefs.setBool('isEloCalculatedForCurrentGame', isEloCalculatedForCurrentGame);
      await prefs.setBool('isPendingSideSelection', isPendingSideSelection);
      await prefs.setString('lastCommentary', lastCommentary);
      await prefs.setString('currentCoach', currentCoach);
      await prefs.setString('coachMemory', jsonEncode(coachMemory.toJson()));
      if (previousCommentary != null) {
        await prefs.setString('previousCommentary', previousCommentary!);
      } else {
        await prefs.remove('previousCommentary');
      }

      // Save Game History
      await prefs.setString('gameHistory', jsonEncode(gameHistory));

      // Don't overwrite saved FEN parameters if we are in review mode
      if (!isReviewMode) {
        await prefs.setString('savedFen', game.fen);
        await prefs.setStringList('savedHistory', fenHistory);
      }
    } catch (e) {
      // SharedPreferences failsafe
    }
  }

  void resetGame() {
    if (mbtiCoaches.isNotEmpty) {
      final availableCoaches = mbtiCoaches.where((c) => c != currentCoach).toList();
      if (availableCoaches.isNotEmpty) {
        final random = math.Random();
        currentCoach = availableCoaches[random.nextInt(availableCoaches.length)];
      }
    }
    _initGame();
    previousCommentary = null;
    isPendingSideSelection = true;
    lastCommentary = "Before we begin our game, which side would you prefer to play on?";
    saveState();
    notifyListeners();
  }

  Future<void> chooseSide(String choice) async {
    PlayerColor selectedColor;
    if (choice == 'random') {
      final random = math.Random();
      selectedColor = random.nextBool() ? PlayerColor.white : PlayerColor.black;
    } else if (choice == 'black') {
      selectedColor = PlayerColor.black;
    } else {
      selectedColor = PlayerColor.white;
    }

    playerColor = selectedColor;
    isPendingSideSelection = false;

    if (playerColor == PlayerColor.white) {
      isBoardFlipped = false;
      previousCommentary = lastCommentary;
      lastCommentary = "Excellent! You are playing as White. Make your first move when ready.";
    } else {
      isBoardFlipped = true;
      previousCommentary = lastCommentary;
      lastCommentary = choice == 'random'
          ? "I've assigned you Black! I will open the game for us as White."
          : "Very well! You are playing as Black. I will open the game as White.";
    }

    _updateStatusMessage();
    saveState();
    notifyListeners();

    if (isAiTurn) {
      await triggerAiMove();
    } else {
      // Player goes first (White) – start timing their first move
      startMoveTimer();
    }
  }

  void setGameMode(GameMode mode) {
    gameMode = mode;
    resetGame();
  }

  void setPlayerColor(PlayerColor color) {
    playerColor = color;
    resetGame();
  }

  void setDifficulty(int diff) {
    aiDifficulty = diff;
    saveState();
    notifyListeners();
  }

  void setBoardTheme(BoardTheme theme) {
    boardTheme = theme;
    saveState();
    notifyListeners();
  }

  void toggleBoardFlip() {
    isBoardFlipped = !isBoardFlipped;
    saveState();
    notifyListeners();
  }

  // Check if AI needs to move
  bool get isAiTurn {
    if (gameMode != GameMode.vsComputer || game.game_over) return false;
    if (playerColor == PlayerColor.white && game.turn == chess_pkg.Color.BLACK) return true;
    if (playerColor == PlayerColor.black && game.turn == chess_pkg.Color.WHITE) return true;
    return false;
  }

  // Taps a square
  Future<void> handleSquareTap(String square, BuildContext context) async {
    if (isReviewMode || isThinking || isAiTurn || isPendingSideSelection) return;

    var piece = game.get(square);
    
    // If a piece of current turn color is tapped, select it
    if (piece != null && piece.color == game.turn) {
      selectedSquare = square;
      
      // Fetch legal destinations
      var moves = game.moves({'square': square, 'verbose': true});
      legalDestinations = moves.map<String>((m) => m['to'] as String).toList();
      notifyListeners();
      return;
    }
    
    // If a destination square is tapped, execute the move
    if (selectedSquare != null && legalDestinations.contains(square)) {
      String from = selectedSquare!;
      String to = square;
      
      // Determine if this is a pawn promotion move
      bool isPromotion = false;
      var moves = game.moves({'square': from, 'verbose': true});
      var matchedMove = moves.firstWhere(
        (m) => m['to'] == to, 
        orElse: () => null
      );
      
      if (matchedMove != null && matchedMove['flags'].contains('p')) {
        isPromotion = true;
      }
      
      String promotionPiece = 'q'; // Default to Queen
      if (isPromotion) {
        String? selected = await _showPromotionDialog(context);
        if (!context.mounted) return;
        if (selected == null) {
          selectedSquare = null;
          legalDestinations = [];
          notifyListeners();
          return;
        }
        promotionPiece = selected;
      }
      
      // Look up verbose move details
      var verboseMoves = game.moves({'square': from, 'verbose': true});
      var verboseMove = verboseMoves.firstWhere(
        (m) => m['to'] == to && (!isPromotion || m['promotion'] == promotionPiece),
        orElse: () => null
      );

      if (isTrainingMode) {
        selectedSquare = null;
        legalDestinations = [];
        await _handleTrainingTapMove(from, to, promotionPiece, context);
        notifyListeners();
        return;
      }

      // Evaluate move quality BEFORE making the move (need pre-move state)
      String moveQuality = _classifyUserMove(from, to, promotionPiece);

      // Perform move
      bool success = makeMoveWithSound({
        'from': from,
        'to': to,
        'promotion': promotionPiece,
      });
      
      if (success) {
        lastMoveFrom = from;
        lastMoveTo = to;
        selectedSquare = null;
        legalDestinations = [];
        fenHistory.add(game.fen);
        _updateStatusMessage();

        // Record move in log
        final double elapsed = _consumeMoveTime();
        final String san = verboseMove?['san'] as String? ?? '$from$to';
        moveLog.add({
          'san': san,
          'time': elapsed,
          'quality': moveQuality,
          'isUser': true,
          'moveNum': ((moveLog.length ~/ 2) + 1),
        });
        moveHistoryIndex = -1;
        
        // Analyze user move and update comment
        if (verboseMove != null) {
          _updateCommentary(Map<String, dynamic>.from(verboseMove), true);
        }
        
        saveState();
        notifyListeners();
        
        // Trigger AI move if VS Computer
        if (isAiTurn) {
          await triggerAiMove();
        }
        
        // Prompt Game Over dialog if the match has concluded
        if (game.game_over && context.mounted) {
          _showGameOverDialog(context);
        }
      }
    } else {
      selectedSquare = null;
      legalDestinations = [];
      notifyListeners();
    }
  }

  // Prompts user for promotion choice
  Future<String?> _showPromotionDialog(BuildContext context) async {
    return showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        final double btnSize = 60.0;
        final bool isWhite = game.turn == chess_pkg.Color.WHITE;
        final accentColor = getThemeAccentColor();
        
        return AlertDialog(
          backgroundColor: Colors.grey[900]?.withOpacity(0.95),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: BorderSide(color: accentColor.withOpacity(0.5), width: 1.5),
          ),
          title: const Text(
            'Promote Pawn',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
          ),
          content: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildPromotionButton(context, 'q', isWhite ? '♕' : '♛', btnSize),
              _buildPromotionButton(context, 'r', isWhite ? '♖' : '♜', btnSize),
              _buildPromotionButton(context, 'b', isWhite ? '♗' : '♝', btnSize),
              _buildPromotionButton(context, 'n', isWhite ? '♘' : '♞', btnSize),
            ],
          ),
        );
      },
    );
  }

  Widget _buildPromotionButton(BuildContext context, String value, String icon, double size) {
    return InkWell(
      onTap: () => Navigator.of(context).pop(value),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: Colors.white10,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white24),
        ),
        alignment: Alignment.center,
        child: Text(
          icon,
          style: const TextStyle(color: Colors.white, fontSize: 32),
        ),
      ),
    );
  }

  // AI execution
  Future<void> triggerAiMove() async {
    isThinking = true;
    gameStatusMessage = 'Solomon is thinking...';
    _lastMoveTime = DateTime.now(); // start timing AI move
    notifyListeners();
    
    // Increased delay (2500ms) so user can read Solomon's comment on their move before Solomon plays
    await Future.delayed(const Duration(milliseconds: 2500));
    
    try {
      var bestMove = ChessAI.getBestMove(game, aiDifficulty);
      if (bestMove != null) {
        final double elapsed = _consumeMoveTime();
        makeMoveWithSound(bestMove);
        lastMoveFrom = bestMove['from'] as String;
        lastMoveTo = bestMove['to'] as String;
        fenHistory.add(game.fen);
        
        // Record AI move in log
        final String san = bestMove['san'] as String? ?? '${bestMove['from']}${bestMove['to']}';
        moveLog.add({
          'san': san,
          'time': elapsed,
          'quality': 'normal', // AI moves don't get quality classification
          'isUser': false,
          'moveNum': ((moveLog.length ~/ 2) + 1),
        });
        moveHistoryIndex = -1;
        
        // Analyze Solomon's own move and comment
        _updateCommentary(bestMove, false);
        
        saveState();
      }
    } catch (e) {
      // AI play failsafe
    } finally {
      isThinking = false;
      _updateStatusMessage();
      // Reset timer for user's next move
      _lastMoveTime = DateTime.now();
      notifyListeners();
    }
  }

  // Undo move
  void undoMove() {
    if (isThinking || fenHistory.length <= 1) return;
    
    if (gameMode == GameMode.vsComputer) {
      if (fenHistory.length >= 3) {
        fenHistory.removeLast();
        fenHistory.removeLast();
        game.load(fenHistory.last);
      } else {
        _initGame();
      }
    } else {
      fenHistory.removeLast();
      game.load(fenHistory.last);
    }
    
    selectedSquare = null;
    legalDestinations = [];
    lastMoveFrom = null;
    lastMoveTo = null;
    _updateStatusMessage();
    
    // Solomon's response to undo is drawn from postGameReviews / spaced repetitions
    final random = math.Random();
    final undoMsg = postGameReviews[random.nextInt(postGameReviews.length)];
    if (undoMsg != lastCommentary) {
      previousCommentary = lastCommentary;
      lastCommentary = undoMsg;
    }
    
    saveState();
    notifyListeners();
  }

  void _updateStatusMessage() {
    if (game.in_checkmate) {
      String winner = game.turn == chess_pkg.Color.WHITE ? 'Black' : 'White';
      gameStatusMessage = 'Checkmate! $winner wins!';
    } else if (game.in_stalemate) {
      gameStatusMessage = 'Stalemate! Draw.';
    } else if (game.in_draw) {
      gameStatusMessage = 'Draw!';
    } else if (game.in_check) {
      String activePlayer = game.turn == chess_pkg.Color.WHITE ? 'White' : 'Black';
      gameStatusMessage = 'Check! $activePlayer\'s turn';
    } else {
      String activePlayer = game.turn == chess_pkg.Color.WHITE ? 'White' : 'Black';
      if (gameMode == GameMode.vsComputer) {
        bool isUserTurn = !isAiTurn;
        gameStatusMessage = isUserTurn ? 'Your turn ($activePlayer)' : 'Solomon is thinking...';
      } else {
        gameStatusMessage = '$activePlayer\'s turn';
      }
    }
  }

  // Calculate material advantages
  Map<String, int> getCapturedPieces() {
    Map<String, int> currentCounts = {
      'w_p': 0, 'w_n': 0, 'w_b': 0, 'w_r': 0, 'w_q': 0,
      'b_p': 0, 'b_n': 0, 'b_b': 0, 'b_r': 0, 'b_q': 0,
    };
    
    for (int row = 0; row < 8; row++) {
      for (int col = 0; col < 8; col++) {
        String square = '${"abcdefgh"[col]}${8 - row}';
        var piece = game.get(square);
        if (piece != null && piece.type != chess_pkg.PieceType.KING) {
          String key = '${piece.color == chess_pkg.Color.WHITE ? 'w' : 'b'}_${piece.type.name}';
          if (currentCounts.containsKey(key)) {
            currentCounts[key] = currentCounts[key]! + 1;
          }
        }
      }
    }
    
    Map<String, int> initialCounts = {
      'w_p': 8, 'w_n': 2, 'w_b': 2, 'w_r': 2, 'w_q': 1,
      'b_p': 8, 'b_n': 2, 'b_b': 2, 'b_r': 2, 'b_q': 1,
    };
    
    Map<String, int> captured = {};
    initialCounts.forEach((key, initialVal) {
      int currentVal = currentCounts[key] ?? 0;
      int diff = initialVal - currentVal;
      if (diff > 0) {
        captured[key] = diff;
      }
    });
    
    return captured;
  }

  // Theme Helpers
  Color getThemeAccentColor() {
    switch (boardTheme) {
      case BoardTheme.terracotta: return AppColors.copper;
      case BoardTheme.charcoal: return AppColors.copper;
      case BoardTheme.ocean: return AppColors.forStroke;
    }
  }

  Color getThemeLightSquareColor() {
    switch (boardTheme) {
      case BoardTheme.terracotta: return AppColors.cream;
      case BoardTheme.charcoal: return AppColors.sand;
      case BoardTheme.ocean: return AppColors.cream;
    }
  }

  Color getThemeDarkSquareColor() {
    switch (boardTheme) {
      case BoardTheme.terracotta: return AppColors.sand;
      case BoardTheme.charcoal: return AppColors.brown;
      case BoardTheme.ocean: return AppColors.forStroke;
    }
  }

  // ─── Move Time Tracking Helpers ──────────────────────────────────────────
  void startMoveTimer() {
    _lastMoveTime = DateTime.now();
  }

  double _consumeMoveTime() {
    if (_lastMoveTime == null) return 0.0;
    final double elapsed = DateTime.now().difference(_lastMoveTime!).inMilliseconds / 1000.0;
    _lastMoveTime = DateTime.now();
    return elapsed;
  }

  // ─── Move Quality Classification ─────────────────────────────────────────
  // Compares played move eval delta vs the best available move. Uses depth-1
  // evaluation so it stays fast and non-blocking.
  String _classifyUserMove(String from, String to, String promotion) {
    try {
      final int evalBefore = evaluateBoard(game);
      final bool isWhite = game.turn == chess_pkg.Color.WHITE;

      // Find best eval among all legal moves (depth-1 look-ahead)
      var allMoves = game.moves({'verbose': true});
      if (allMoves.isEmpty) return 'normal';

      int bestEval = isWhite ? -999999 : 999999;
      String? bestFrom, bestTo;
      for (var m in allMoves) {
        game.move(m);
        int eval = evaluateBoard(game);
        game.undo();
        if (isWhite && eval > bestEval) {
          bestEval = eval;
          bestFrom = m['from'] as String?;
          bestTo = m['to'] as String?;
        } else if (!isWhite && eval < bestEval) {
          bestEval = eval;
          bestFrom = m['from'] as String?;
          bestTo = m['to'] as String?;
        }
      }

      // Eval of the actual move played
      game.move({'from': from, 'to': to, 'promotion': promotion});
      int playedEval = evaluateBoard(game);
      game.undo();

      // Delta between played and best (from player's perspective)
      int bestDelta = isWhite ? (bestEval - evalBefore) : (evalBefore - bestEval);
      int playedDelta = isWhite ? (playedEval - evalBefore) : (evalBefore - playedEval);

      // Is this the best move?
      if (bestFrom == from && bestTo == to) return 'best';

      int loss = bestDelta - playedDelta; // positive = worse than best
      if (loss >= 200) return 'miss';      // missed winning material / checkmate sequence
      if (loss >= 60)  return 'mistake';   // meaningful positional or tactical error
      return 'normal';
    } catch (_) {
      return 'normal';
    }
  }

  // Jump to a specific move in the move log (for history panel navigation)
  void jumpToMoveHistoryIndex(int index) {
    if (isTrainingMode) return;
    final targetFen = index < 0 ? fenHistory.first : fenHistory[index + 1];
    game.load(targetFen);
    moveHistoryIndex = index;
    notifyListeners();
  }

  void exitMoveHistoryNav() {
    game.load(fenHistory.last);
    moveHistoryIndex = -1;
    notifyListeners();
  }

  // Standard ELO rating algorithm
  Map<String, int>? _updateEloAfterGame(double result) {
    if (isEloCalculatedForCurrentGame) return null;

    int oldElo = userElo;
    int change = 0;
    
    if (gameMode == GameMode.vsComputer) {
      double opponentElo = opponentElos[aiDifficulty].toDouble();
      double expected = 1.0 / (1.0 + math.pow(10.0, (opponentElo - userElo) / 400.0));
      double K = 32.0;
      change = (K * (result - expected)).round();
      
      userElo = (userElo + change).clamp(100, 3000);
    }

    // Save game record to history list
    final opponentName = gameMode == GameMode.vsComputer 
        ? "$currentCoach (${difficultyLabels[aiDifficulty]})" 
        : "Pass & Play";

    final gameRecord = {
      'id': DateTime.now().millisecondsSinceEpoch.toString(),
      'date': DateTime.now().toIso8601String(),
      'opponent': opponentName,
      'opponentElo': gameMode == GameMode.vsComputer ? opponentElos[aiDifficulty] : 0,
      'playerEloStart': oldElo,
      'playerEloEnd': gameMode == GameMode.vsComputer ? userElo : oldElo,
      'result': result == 1.0 ? "Won" : (result == 0.5 ? "Draw" : "Lost"),
      'fens': List<String>.from(fenHistory),
      'moveLog': List<Map<String, dynamic>>.from(moveLog),
      'statBest': statBest,
      'statMisses': statMisses,
      'statMistakes': statMistakes,
    };
    
    gameHistory.insert(0, gameRecord);
    coachMemory.gamesPlayedVsThisCoach++;
    coachMemory.hasMetBefore = true;
    _recalculateStats();

    isEloCalculatedForCurrentGame = true;
    saveState();

    if (gameMode == GameMode.vsComputer) {
      return {
        'old': oldElo,
        'new': userElo,
        'change': change,
      };
    }
    return null;
  }

  Map<String, int>? _getEloCalculationForGameOver() {
    if (isEloCalculatedForCurrentGame) return null;

    double result = 0.5; // default draw
    if (game.in_checkmate) {
      if (game.turn == chess_pkg.Color.WHITE) {
        result = (playerColor == PlayerColor.white) ? 0.0 : 1.0;
      } else {
        result = (playerColor == PlayerColor.white) ? 1.0 : 0.0;
      }
    }
    
    return _updateEloAfterGame(result);
  }

  void _updateCommentary(Map<String, dynamic> move, bool isUserMove) {
    final String newComment = generateCoachCommentary(
      game: game,
      move: move,
      isUserMove: isUserMove,
      coach: currentCoach,
      memory: coachMemory,
    );
    if (newComment != lastCommentary) {
      previousCommentary = lastCommentary;
      lastCommentary = newComment;
    }
  }

  void triggerWittyHint() {
    if (isReviewMode) return;
    
    final random = math.Random();
    final String newHint = hintsAndFarewells[random.nextInt(hintsAndFarewells.length)];
    
    if (newHint != lastCommentary) {
      previousCommentary = lastCommentary;
      lastCommentary = newHint;
    }
    notifyListeners();
  }

  // Dialog flow triggers
  void resign(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return ArguuuConfirmDialog(
          title: 'Resign?',
          message: 'Are you sure you want to resign this game?',
          yesLabel: 'Resign',
          noLabel: 'Cancel',
          isDanger: true,
          onYes: () {
            Navigator.of(context).pop();
            _executeResignation(context);
          },
          onNo: () => Navigator.of(context).pop(),
        );
      },
    );
  }

  void _executeResignation(BuildContext context) {
    String winner = game.turn == chess_pkg.Color.WHITE ? 'Black' : 'White';
    gameStatusMessage = 'Resigned. $winner wins!';
    notifyListeners();
    
    final eloRes = _updateEloAfterGame(0.0);
    showMatchOverDialog(context, eloRes: eloRes);
  }

  void _showGameOverDialog(BuildContext context) {
    final eloRes = _getEloCalculationForGameOver();
    showMatchOverDialog(context, eloRes: eloRes);
  }

  void showMatchOverDialog(BuildContext context, {Map<String, int>? eloRes}) {
    final int best     = statBest;
    final int misses   = statMisses;
    final int mistakes = statMistakes;
    final int newElo   = eloRes?['new'] ?? userElo;
    final int eloChange = eloRes?['change'] ?? 0;

    String resultTitle;
    if (gameStatusMessage.contains('Resigned')) {
      resultTitle = 'You Resigned';
    } else if (gameStatusMessage.contains('Checkmate')) {
      final bool playerWon = (playerColor == PlayerColor.white && gameStatusMessage.contains('White wins')) ||
                             (playerColor == PlayerColor.black && gameStatusMessage.contains('Black wins'));
      resultTitle = playerWon ? 'You Won!' : 'You Lost';
    } else if (gameStatusMessage.contains('Draw') || gameStatusMessage.contains('Stalemate')) {
      resultTitle = 'Game Drawn';
    } else {
      resultTitle = 'Game Over';
    }

    final String coachTip = _getPostGameCoachTip(best, misses, mistakes);

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext ctx) {
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
          child: ChessComResultModal(
            resultTitle: resultTitle,
            newElo: newElo,
            eloChange: eloChange,
            statBest: best,
            statMisses: misses,
            statMistakes: mistakes,
            coachTip: coachTip,
            coachAsset: 'assets/mbti_coaches/$currentCoach.png',
            onGameReview: () {
              Navigator.of(ctx).pop();
              if (gameHistory.isNotEmpty) {
                startReviewMode(gameHistory.first);
              }
            },
            onNewGame: () {
              resetGame();
              Navigator.of(ctx).pop();
            },
          ),
        );
      },
    );
  }

  String _getPostGameCoachTip(int best, int misses, int mistakes) {
    if (misses > 2) return "You missed some big opportunities — let's review those moments together.";
    if (mistakes > 3) return "A few inaccuracies crept in. Review shows where you can tighten up.";
    if (best > 3) return "You found some excellent moves! Let's reinforce those patterns.";
    return "That game didn't go to waste — there's always something to learn. Let's review it together.";
  }

  void _recalculateStats() {
    gamesPlayed = gameHistory.length;
    gamesWon = gameHistory.where((g) => g['result'] == 'Won').length;
    gamesDrawn = gameHistory.where((g) => g['result'] == 'Draw').length;
    gamesLost = gameHistory.where((g) => g['result'] == 'Lost').length;
  }

  // Training Mode controls
  void startLesson(int index) {
    isTrainingMode = true;
    trainingLessonIndex = index;
    trainingPhase = 'watch';
    trainingWatchStep = 0;
    trainingAssistStep = 0;
    trainingChallengeIndex = 0;
    trainingChallengeStep = 0;
    
    final lesson = trainingLessons[index];
    game = chess_pkg.Chess();
    game.load(lesson.startFen);
    fenHistory = [game.fen];
    lastMoveFrom = null;
    lastMoveTo = null;
    previousCommentary = null;
    lastCommentary = "Solomon: Welcome to '${lesson.title}'! First, let's watch how it's done. Click the 'Next' button to see the moves.";
    
    notifyListeners();
  }

  void advanceWatch() {
    if (!isTrainingMode || trainingPhase != 'watch') return;
    
    final lesson = trainingLessons[trainingLessonIndex];
    if (trainingWatchStep < lesson.watchMoves.length) {
      final moveStr = lesson.watchMoves[trainingWatchStep];
      final from = moveStr.substring(0, 2);
      final to = moveStr.substring(2, 4);
      
      makeMoveWithSound({'from': from, 'to': to});
      lastMoveFrom = from;
      lastMoveTo = to;
      fenHistory.add(game.fen);
      
      previousCommentary = lastCommentary;
      lastCommentary = "Solomon: ${lesson.watchComments[trainingWatchStep]}";
      
      trainingWatchStep++;
      if (trainingWatchStep == lesson.watchMoves.length) {
        lastCommentary += "\n\n(Demo complete! Click 'Start Practice' to begin the assisted practice phase.)";
      }
      notifyListeners();
    }
  }

  void startAssistPhase() {
    if (!isTrainingMode) return;
    trainingPhase = 'assist';
    trainingAssistStep = 0;
    
    final lesson = trainingLessons[trainingLessonIndex];
    game = chess_pkg.Chess();
    game.load(lesson.startFen);
    fenHistory = [game.fen];
    lastMoveFrom = null;
    lastMoveTo = null;
    previousCommentary = null;
    lastCommentary = "Solomon: ${lesson.assistInstruction}";
    notifyListeners();
  }

  void startRealPhase() {
    if (!isTrainingMode) return;
    trainingPhase = 'real';
    trainingChallengeIndex = 0;
    trainingChallengeStep = 0;
    
    final lesson = trainingLessons[trainingLessonIndex];
    final challenge = lesson.challenges[0];
    game = chess_pkg.Chess();
    game.load(challenge.fen);
    fenHistory = [game.fen];
    lastMoveFrom = null;
    lastMoveTo = null;
    previousCommentary = null;
    lastCommentary = "Solomon: Challenge 1/4: ${challenge.instruction}";
    notifyListeners();
  }

  void exitTraining() {
    isTrainingMode = false;
    previousCommentary = null;
    loadState();
  }

  Future<void> _handleTrainingTapMove(String from, String to, String promotionPiece, BuildContext context) async {
    final lesson = trainingLessons[trainingLessonIndex];
    
    if (trainingPhase == 'assist') {
      final expectedMove = lesson.assistMoves[trainingAssistStep];
      final userMove = "$from$to";
      
      if (userMove == expectedMove) {
        makeMoveWithSound({
          'from': from,
          'to': to,
          'promotion': promotionPiece,
        });
        lastMoveFrom = from;
        lastMoveTo = to;
        fenHistory.add(game.fen);
        trainingAssistStep++;
        
        previousCommentary = lastCommentary;
        
        if (trainingAssistStep < lesson.assistMoves.length) {
          final solomonMoveStr = lesson.assistMoves[trainingAssistStep];
          final sFrom = solomonMoveStr.substring(0, 2);
          final sTo = solomonMoveStr.substring(2, 4);
          
          isThinking = true;
          notifyListeners();
          await Future.delayed(const Duration(milliseconds: 1500));
          
          makeMoveWithSound({'from': sFrom, 'to': sTo});
          lastMoveFrom = sFrom;
          lastMoveTo = sTo;
          fenHistory.add(game.fen);
          trainingAssistStep++;
          isThinking = false;
          
          lastCommentary = "Solomon: I play $sFrom to $sTo. Now it's your turn!";
        } else {
          lastCommentary = "Solomon: Excellent job completing the assisted practice! Now, let's test your skills in 4 real challenges. Are you ready?";
        }
      } else {
        final expectedFrom = expectedMove.substring(0, 2);
        final expectedTo = expectedMove.substring(2, 4);
        previousCommentary = lastCommentary;
        lastCommentary = "Solomon: No, that is not the right move here. We want to play $expectedFrom to $expectedTo. Try it again!";
      }
    } else if (trainingPhase == 'real') {
      final challenge = lesson.challenges[trainingChallengeIndex];
      final expectedMove = challenge.winningMoves[trainingChallengeStep];
      final userMove = "$from$to";
      
      if (userMove == expectedMove) {
        makeMoveWithSound({
          'from': from,
          'to': to,
          'promotion': promotionPiece,
        });
        lastMoveFrom = from;
        lastMoveTo = to;
        fenHistory.add(game.fen);
        trainingChallengeStep++;
        
        previousCommentary = lastCommentary;
        
        if (trainingChallengeStep < challenge.winningMoves.length) {
          if (challenge.responseMove.isNotEmpty) {
            final sFrom = challenge.responseMove.substring(0, 2);
            final sTo = challenge.responseMove.substring(2, 4);
            
            isThinking = true;
            notifyListeners();
            await Future.delayed(const Duration(milliseconds: 1500));
            
            makeMoveWithSound({'from': sFrom, 'to': sTo});
            lastMoveFrom = sFrom;
            lastMoveTo = sTo;
            fenHistory.add(game.fen);
            isThinking = false;
            
            lastCommentary = "Solomon: I counter with $sFrom to $sTo. Find the final winning move!";
          }
        } else {
          lastCommentary = "Solomon: ${challenge.successComment}";
          
          isThinking = true;
          notifyListeners();
          await Future.delayed(const Duration(milliseconds: 3000));
          isThinking = false;
          
          trainingChallengeIndex++;
          trainingChallengeStep = 0;
          
          if (trainingChallengeIndex >= 4) {
            trainingPhase = 'success';
            lastCommentary = "Solomon: Congratulations, Wali! You have successfully passed all 4 challenges and mastered this lesson. I am very proud of you!";
          } else {
            final nextChallenge = lesson.challenges[trainingChallengeIndex];
            game = chess_pkg.Chess();
            game.load(nextChallenge.fen);
            fenHistory = [game.fen];
            lastMoveFrom = null;
            lastMoveTo = null;
            previousCommentary = null;
            lastCommentary = "Solomon: Challenge ${trainingChallengeIndex + 1}/4: ${nextChallenge.instruction}";
          }
        }
      } else {
        previousCommentary = lastCommentary;
        lastCommentary = "Solomon: ${challenge.failComment} Let's try this challenge again.";
        
        isThinking = true;
        notifyListeners();
        await Future.delayed(const Duration(milliseconds: 2500));
        isThinking = false;
        
        game = chess_pkg.Chess();
        game.load(challenge.fen);
        fenHistory = [game.fen];
        lastMoveFrom = null;
        lastMoveTo = null;
        trainingChallengeStep = 0;
        lastCommentary = "Solomon: Challenge ${trainingChallengeIndex + 1}/4: ${challenge.instruction}";
      }
    }
  }
}

class TrainingLesson {
  final String title;
  final String category;
  final String description;
  final String startFen;
  final List<String> watchMoves;
  final List<String> watchComments;
  final List<String> assistMoves;
  final String assistInstruction;
  final List<TrainingChallenge> challenges;

  TrainingLesson({
    required this.title,
    required this.category,
    required this.description,
    required this.startFen,
    required this.watchMoves,
    required this.watchComments,
    required this.assistMoves,
    required this.assistInstruction,
    required this.challenges,
  });
}

class TrainingChallenge {
  final String fen;
  final String instruction;
  final List<String> winningMoves;
  final String responseMove;
  final String successComment;
  final String failComment;

  TrainingChallenge({
    required this.fen,
    required this.instruction,
    required this.winningMoves,
    this.responseMove = '',
    required this.successComment,
    required this.failComment,
  });
}

class ChessComResultModal extends StatelessWidget {
  final String resultTitle;
  final int newElo;
  final int eloChange;
  final int statBest;
  final int statMisses;
  final int statMistakes;
  final String coachTip;
  final String coachAsset;
  final VoidCallback onGameReview;
  final VoidCallback onNewGame;

  const ChessComResultModal({
    super.key,
    required this.resultTitle,
    required this.newElo,
    required this.eloChange,
    required this.statBest,
    required this.statMisses,
    required this.statMistakes,
    required this.coachTip,
    required this.coachAsset,
    required this.onGameReview,
    required this.onNewGame,
  });

  @override
  Widget build(BuildContext context) {
    final String eloSign = eloChange >= 0 ? '+$eloChange' : '$eloChange';
    final Color eloColor = eloChange >= 0 ? AppColors.winTxt : AppColors.lossTxt;

    return Container(
      decoration: BoxDecoration(
        color: AppColors.cottonWhite,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.sand, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: AppColors.ink.withOpacity(0.08),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header section
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 18),
            decoration: const BoxDecoration(
              color: AppColors.cream,
              borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
            ),
            child: Column(
              children: [
                Text(
                  resultTitle,
                  style: AppFonts.serif(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textMain,
                    letterSpacing: 0.3,
                  ),
                ),
                const SizedBox(height: 12),
                // Elo pill
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: AppColors.cottonWhite,
                    borderRadius: BorderRadius.circular(50),
                    border: Border.all(color: AppColors.sand),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.bolt, size: 18, color: AppColors.copper),
                      const SizedBox(width: 4),
                      Text(
                        '$newElo',
                        style: AppFonts.serif(
                          color: AppColors.textMain,
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        eloSign,
                        style: TextStyle(
                          color: eloColor,
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        'Rating',
                        style: AppFonts.mono(
                          color: AppColors.textLight,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Coach advice tip section
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ClipOval(
                  child: Image.asset(
                    coachAsset,
                    width: 44,
                    height: 44,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(
                      width: 44,
                      height: 44,
                      color: AppColors.cream,
                      child: const Icon(Icons.person, color: AppColors.textLight),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      color: AppColors.cream,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.sand),
                    ),
                    child: Text(
                      coachTip,
                      style: AppFonts.sans(
                        color: AppColors.textMain,
                        fontSize: 13,
                        height: 1.4,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Move Stats Section
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                ResultStatChip(
                  count: statBest,
                  label: 'Best',
                  icon: Icons.star_rounded,
                  color: AppColors.winTxt,
                  bgColor: AppColors.winBg,
                ),
                const SizedBox(width: 8),
                ResultStatChip(
                  count: statMisses,
                  label: 'Misses',
                  icon: Icons.cancel_rounded,
                  color: AppColors.lossTxt,
                  bgColor: AppColors.lossBg,
                ),
                const SizedBox(width: 8),
                ResultStatChip(
                  count: statMistakes,
                  label: 'Mistakes',
                  icon: Icons.help_rounded,
                  bgColor: const Color(0xFFFAF2E6),
                  color: const Color(0xFFC4724A),
                ),
              ],
            ),
          ),

          // Action Buttons
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
            child: Column(
              children: [
                // Game Review Button (primary, solid copper background)
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: onGameReview,
                    icon: const Icon(Icons.manage_search_rounded, size: 20, color: AppColors.cottonWhite),
                    label: const Text(
                      'Game Review',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                        color: AppColors.cottonWhite,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.copper,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 0,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                // New Game Button (secondary, outlined)
                SizedBox(
                  width: double.infinity,
                  child: TextButton(
                    onPressed: onNewGame,
                    style: TextButton.styleFrom(
                      backgroundColor: AppColors.cream,
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: const BorderSide(color: AppColors.sand, width: 1.5),
                      ),
                    ),
                    child: Text(
                      'New Game',
                      style: AppFonts.sans(
                        color: AppColors.textMain,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class ResultStatChip extends StatelessWidget {
  final int count;
  final String label;
  final IconData icon;
  final Color color;
  final Color bgColor;

  const ResultStatChip({
    super.key,
    required this.count,
    required this.label,
    required this.icon,
    required this.color,
    required this.bgColor,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.2)),
        ),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, color: color, size: 16),
                const SizedBox(width: 4),
                Text(
                  '$count',
                  style: AppFonts.serif(
                    color: color,
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: AppFonts.mono(
                color: color.withOpacity(0.8),
                fontSize: 10,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

