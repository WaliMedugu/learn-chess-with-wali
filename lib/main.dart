import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'chess_game_state.dart';
import 'chess_board.dart';
import 'theme_arguuu.dart';
import 'training_lessons.dart';

// Simple ISO date formatting helper
String formatHistoryDate(String dateIso) {
  try {
    final dt = DateTime.parse(dateIso);
    final months = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"];
    return "${months[dt.month - 1]} ${dt.day}, ${dt.year}";
  } catch (_) {
    return dateIso;
  }
}

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);
  
  runApp(
    ChangeNotifierProvider(
      create: (_) => ChessGameState(),
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Learn Chess with Sol',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.light,
        fontFamily: AppFonts.sansFamily,
        scaffoldBackgroundColor: AppColors.cream,
        primaryColor: AppColors.copper,
        colorScheme: const ColorScheme.light(
          primary: AppColors.copper,
          secondary: AppColors.rust,
          surface: AppColors.cottonWhite,
          onSurface: AppColors.ink,
          error: AppColors.lossTxt,
        ),
      ),
      home: const ChessGameScreen(),
    );
  }
}

enum AppScreen { home, play, train }

class ChessGameScreen extends StatefulWidget {
  const ChessGameScreen({super.key});

  @override
  State<ChessGameScreen> createState() => _ChessGameScreenState();
}

class _ChessGameScreenState extends State<ChessGameScreen> {
  AppScreen _activeScreen = AppScreen.play;
  
  // Starting level option choice tracking
  int _selectedEloOption = 800;

  @override
  Widget build(BuildContext context) {
    final state = Provider.of<ChessGameState>(context);

    return Scaffold(
      body: Stack(
        children: [
          // Main App Content Layout
          Container(
            color: Theme.of(context).scaffoldBackgroundColor,
            child: SafeArea(
              child: Column(
                children: [
                  Expanded(
                    child: _buildActiveView(state),
                  ),
                ],
              ),
            ),
          ),
          
          // Bottom Navigation Bar (Only interactive/visible once level is selected)
          if (state.hasSelectedLevel)
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: Container(
                height: 76,
                decoration: BoxDecoration(
                  color: AppColors.cream,
                  border: Border(
                    top: BorderSide(color: AppColors.sand.withOpacity(0.5), width: 1.0),
                  ),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildNavItem(AppScreen.home, Icons.home_outlined, "Home", hasDot: true),
                    _buildNavItem(AppScreen.play, null, "Play", useCustomPawn: true),
                    _buildNavItem(AppScreen.train, Icons.sync_alt, "Train"),
                  ],
                ),
              ),
            ),

          // Onboarding Dialog Popup Overlay (Locks screen until starting level selection is confirmed)
          if (!state.hasSelectedLevel)
            _buildOnboardingPopupOverlay(state),
        ],
      ),
    );
  }

  Widget _buildOnboardingPopupOverlay(ChessGameState state) {
    return Positioned.fill(
      child: PopScope(
        canPop: false,
        child: Stack(
          children: [
            // Glassmorphic blurred backdrop
            Positioned.fill(
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                child: Container(
                  color: Colors.black.withOpacity(0.35),
                ),
              ),
            ),
            
            // Onboarding popup dialog card
            Center(
              child: Container(
                width: MediaQuery.of(context).size.width * 0.90,
                margin: const EdgeInsets.symmetric(vertical: 24),
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(context).size.height * 0.85,
                ),
                decoration: BoxDecoration(
                  color: AppColors.cream,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.sand, width: 1.5),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.2),
                      blurRadius: 20,
                      offset: const Offset(0, 10),
                    )
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Header text description in lay terms
                    Padding(
                      padding: const EdgeInsets.only(top: 24.0, left: 20.0, right: 20.0, bottom: 12.0),
                      child: Column(
                        children: [
                          Container(
                            width: 72,
                            height: 72,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(color: AppColors.copper, width: 1.5),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.1),
                                  blurRadius: 8,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                              image: const DecorationImage(
                                image: AssetImage('assets/logo.png'),
                                fit: BoxFit.cover,
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            "Select your skill level",
                            textAlign: TextAlign.center,
                            style: AppFonts.serif(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: AppColors.copper,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            "Choose the option that describes you best:",
                            textAlign: TextAlign.center,
                            style: AppFonts.sans(
                              fontSize: 13,
                              color: AppColors.textLight,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Divider(color: AppColors.sand, height: 1),
                    
                    // Compact options list fitted to screen height
                    Flexible(
                      child: ListView(
                        shrinkWrap: true,
                        physics: const BouncingScrollPhysics(),
                        padding: const EdgeInsets.all(16),
                        children: [
                          _buildOnboardingOptionCard(400, "Never played before", "I don't know the rules or how pieces move. I want to learn the very basics."),
                          const SizedBox(height: 12),
                          _buildOnboardingOptionCard(800, "Just started learning", "I know how pieces move and have played a few games, but I still make easy mistakes."),
                          const SizedBox(height: 12),
                          _buildOnboardingOptionCard(1200, "Play casually", "I play for fun with friends or family. I understand simple strategies."),
                          const SizedBox(height: 12),
                          _buildOnboardingOptionCard(1600, "Experienced player", "I study openings, love solving puzzles, and play chess regularly."),
                        ],
                      ),
                    ),
                    
                    const Divider(color: AppColors.sand, height: 1),
                    
                    // Confirm and start game trigger button
                    Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: ArguuuButton(
                        label: "CONFIRM & START",
                        fullWidth: true,
                        onPressed: () {
                          // 1. Set Starting user ELO level
                          state.setUserStartingLevel(_selectedEloOption);
                          
                          // 2. Set Solomon's difficulty index accordingly
                          int solomonDiffIndex = 2; // default
                          if (_selectedEloOption == 400) solomonDiffIndex = 0;
                          if (_selectedEloOption == 800) solomonDiffIndex = 2;
                          if (_selectedEloOption == 1200) solomonDiffIndex = 4;
                          if (_selectedEloOption == 1600) solomonDiffIndex = 6;
                          
                          state.setDifficulty(solomonDiffIndex);
                          
                          // 3. Set game mode to VS Computer Solomon
                          state.setGameMode(GameMode.vsComputer);
                          
                          // 4. Force reset game setup playing white against Solomon
                          state.resetGame();
                          
                          // 5. Instantly route user to Play screen
                          setState(() {
                            _activeScreen = AppScreen.play;
                          });
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOnboardingOptionCard(int elo, String title, String description) {
    bool isSelected = _selectedEloOption == elo;
    
    return InkWell(
      onTap: () {
        setState(() {
          _selectedEloOption = elo;
        });
      },
      borderRadius: BorderRadius.circular(8),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(vertical: 12.0, horizontal: 16.0),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.cottonWhite : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? AppColors.copper : AppColors.sand,
            width: isSelected ? 1.5 : 1.0,
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: AppFonts.serif(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: isSelected ? AppColors.copper : AppColors.darkWood,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    description,
                    style: AppFonts.sans(
                      fontSize: 12,
                      color: AppColors.textMain,
                      height: 1.3,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            // Custom Radio Circle indicator
            Container(
              width: 18,
              height: 18,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: isSelected ? AppColors.copper : AppColors.textLight,
                  width: 1.5,
                ),
              ),
              alignment: Alignment.center,
              child: isSelected
                  ? Container(
                      width: 10,
                      height: 10,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppColors.copper,
                      ),
                    )
                  : null,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileRowButton({required Widget child, required VoidCallback? onTap}) {
    final bool disabled = onTap == null;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(4),
      child: Opacity(
        opacity: disabled ? 0.3 : 1.0,
        child: Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: AppColors.cottonWhite,
            borderRadius: BorderRadius.circular(4),
            border: Border.all(color: AppColors.sand, width: 1.0),
          ),
          alignment: Alignment.center,
          child: child,
        ),
      ),
    );
  }

  Widget _buildNavItem(AppScreen screen, IconData? icon, String label, {bool hasDot = false, bool useCustomPawn = false}) {
    bool isSelected = _activeScreen == screen;
    Color color = isSelected ? AppColors.copper : AppColors.darkWood;
    
    Widget iconWidget;
    if (useCustomPawn) {
      iconWidget = SizedBox(
        width: 24,
        height: 24,
        child: CustomPaint(
          painter: ChessPawnPainter(color: color),
        ),
      );
    } else {
      iconWidget = Icon(icon, color: color, size: 24);
    }

    if (hasDot) {
      iconWidget = Stack(
        clipBehavior: Clip.none,
        children: [
          iconWidget,
          Positioned(
            right: -2,
            top: -2,
            child: Container(
              width: 8,
              height: 8,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.copper, // Terracotta indicator dot
              ),
            ),
          ),
        ],
      );
    }

    return InkWell(
      onTap: () {
        setState(() {
          _activeScreen = screen;
        });
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            iconWidget,
            const SizedBox(height: 4),
            Text(
              label,
              style: AppFonts.serif(
                fontSize: 13,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChatBubble(String text) {
    return CustomPaint(
      painter: ChatBubblePainter(
        bgColor: Colors.white,
        borderColor: AppColors.sand,
      ),
      child: Container(
        constraints: const BoxConstraints(minHeight: 48),
        padding: const EdgeInsets.only(
          left: 20.0,
          right: 12.0,
          top: 10.0,
          bottom: 10.0,
        ),
        child: Text(
          text,
          style: AppFonts.serif(
            fontSize: 13,
            color: AppColors.textMain,
            height: 1.3,
          ),
        ),
      ),
    );
  }

  Widget _buildChatOptionBubble(String text, VoidCallback onTap) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(4),
        splashColor: AppColors.copper.withOpacity(0.12),
        highlightColor: AppColors.copper.withOpacity(0.06),
        child: CustomPaint(
          painter: ChatBubblePainter(
            bgColor: Colors.white,
            borderColor: AppColors.sand,
          ),
          child: Container(
            constraints: const BoxConstraints(minHeight: 44),
            padding: const EdgeInsets.only(
              left: 20.0,
              right: 12.0,
              top: 10.0,
              bottom: 10.0,
            ),
            child: Text(
              text,
              style: AppFonts.serif(
                fontSize: 13,
                color: AppColors.textMain,
                height: 1.3,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildActiveView(ChessGameState state) {
    switch (_activeScreen) {
      case AppScreen.play:
        final bool isReview = state.isReviewMode;
        
        // Define speech bubble text dynamically in review mode vs live mode
        String speechText = state.lastCommentary;
        if (isReview) {
          if (state.reviewIndex == 0) {
            speechText = "This is the starting position of our match.";
          } else if (state.reviewIndex == state.reviewFens.length - 1) {
            speechText = "The game ended here. Result: ${state.reviewResult}.";
          } else {
            speechText = "Move ${state.reviewIndex} of ${state.reviewFens.length - 1}. Reviewing game against ${state.reviewOpponentName}.";
          }
        }

        final bool isLandscape = MediaQuery.of(context).orientation == Orientation.landscape;
        final double bottomPadding = state.hasSelectedLevel ? 88.0 : 16.0;

        if (isLandscape) {
          return Padding(
            padding: EdgeInsets.only(left: 16.0, right: 16.0, top: 12.0, bottom: bottomPadding),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Left Column: Chess Board
                Expanded(
                  flex: 5,
                  child: Center(
                    child: AspectRatio(
                      aspectRatio: 1.0,
                      child: ChessBoardWidget(
                        state: state,
                        onSquareTap: (square, ctx) => state.handleSquareTap(square, ctx),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 24),
                // Right Column: Solomon Coach & Chat Options
                Expanded(
                  flex: 5,
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Solomon photo + buttons (smaller in landscape)
                            Column(
                              children: [
                                GestureDetector(
                                  onTap: () => _showCoachSelectionDialog(context, state),
                                  behavior: HitTestBehavior.opaque,
                                  child: CustomPaint(
                                    painter: GradientBorderPainter(
                                      color: AppColors.copper,
                                      strokeWidth: 1.5,
                                    ),
                                    child: Container(
                                      width: 130,
                                      height: 160,
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(4),
                                        image: DecorationImage(
                                          image: AssetImage('assets/mbti_coaches/${state.currentCoach}.png'),
                                          fit: BoxFit.cover,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 6),
                                SizedBox(
                                  width: 130,
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: isReview
                                        ? [
                                            _buildProfileRowButton(
                                              child: const Icon(Icons.arrow_back, size: 16, color: AppColors.darkWood),
                                              onTap: state.reviewIndex > 0 ? () => state.stepReview(-1) : null,
                                            ),
                                            _buildProfileRowButton(
                                              child: const Icon(Icons.arrow_forward, size: 16, color: AppColors.darkWood),
                                              onTap: state.reviewIndex < state.reviewFens.length - 1 ? () => state.stepReview(1) : null,
                                            ),
                                            _buildProfileRowButton(
                                              child: const Icon(Icons.close, size: 16, color: AppColors.lossTxt),
                                              onTap: () => state.exitReviewMode(),
                                            ),
                                          ]
                                        : [
                                            _buildProfileRowButton(
                                              child: Text(
                                                "?",
                                                style: AppFonts.serif(
                                                  fontSize: 16,
                                                  fontWeight: FontWeight.bold,
                                                  color: AppColors.darkWood,
                                                ),
                                              ),
                                              onTap: () => state.triggerWittyHint(),
                                            ),
                                            _buildProfileRowButton(
                                              child: const Icon(Icons.undo, size: 16, color: AppColors.darkWood),
                                              onTap: state.isThinking || state.fenHistory.length <= 1
                                                  ? null
                                                  : () => state.undoMove(),
                                            ),
                                            _buildProfileRowButton(
                                              child: const Icon(Icons.more_vert, size: 16, color: AppColors.darkWood),
                                              onTap: () => _showGameOptionsBottomSheet(state),
                                            ),
                                          ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(width: 12),
                            // Chat speech bubble & options
                            Expanded(
                              child: AnimatedSwitcher(
                                duration: const Duration(milliseconds: 400),
                                switchInCurve: Curves.easeOutQuart,
                                switchOutCurve: Curves.easeInQuart,
                                transitionBuilder: (Widget child, Animation<double> animation) {
                                  return FadeTransition(
                                    opacity: animation,
                                    child: SlideTransition(
                                      position: Tween<Offset>(
                                        begin: const Offset(0.0, 0.08),
                                        end: Offset.zero,
                                      ).animate(animation),
                                      child: child,
                                    ),
                                  );
                                },
                                child: Column(
                                  key: ValueKey<String>(
                                    "${speechText}_${state.previousCommentary ?? ''}_${state.isPendingSideSelection}"
                                  ),
                                  crossAxisAlignment: CrossAxisAlignment.stretch,
                                  children: [
                                    _buildChatBubble(speechText),
                                    if (state.isPendingSideSelection && !isReview) ...[
                                      const SizedBox(height: 8),
                                      _buildChatOptionBubble("Play as White", () => state.chooseSide('white')),
                                      const SizedBox(height: 6),
                                      _buildChatOptionBubble("Play as Black", () => state.chooseSide('black')),
                                      const SizedBox(height: 6),
                                      _buildChatOptionBubble("Or let me choose", () => state.chooseSide('random')),
                                    ] else if (state.previousCommentary != null && !isReview) ...[
                                      const SizedBox(height: 6),
                                      _buildChatBubble(state.previousCommentary!),
                                    ],
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        MoveHistoryPanel(state: state),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        }

        return SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Column(
              children: [
                const SizedBox(height: 18),
                
                // Solomon Coach profile + speech bubble
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Left Column: Solomon photo + buttons
                    Column(
                      children: [
                        GestureDetector(
                          onTap: () => _showCoachSelectionDialog(context, state),
                          behavior: HitTestBehavior.opaque,
                          child: CustomPaint(
                            painter: GradientBorderPainter(
                              color: AppColors.copper,
                              strokeWidth: 1.5,
                            ),
                            child: Container(
                              width: 140,
                              height: 180,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(4),
                                image: DecorationImage(
                                  image: AssetImage('assets/mbti_coaches/${state.currentCoach}.png'),
                                  fit: BoxFit.cover,
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        SizedBox(
                          width: 140,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: isReview 
                            ? [
                                // Review Button 1: Prev Move
                                _buildProfileRowButton(
                                  child: const Icon(Icons.arrow_back, size: 20, color: AppColors.darkWood),
                                  onTap: state.reviewIndex > 0 
                                      ? () => state.stepReview(-1) 
                                      : null,
                                ),
                                // Review Button 2: Next Move
                                _buildProfileRowButton(
                                  child: const Icon(Icons.arrow_forward, size: 20, color: AppColors.darkWood),
                                  onTap: state.reviewIndex < state.reviewFens.length - 1 
                                      ? () => state.stepReview(1) 
                                      : null,
                                ),
                                // Review Button 3: Exit Review Mode
                                _buildProfileRowButton(
                                  child: const Icon(Icons.close, size: 20, color: AppColors.lossTxt),
                                  onTap: () => state.exitReviewMode(),
                                ),
                              ]
                            : [
                                // Normal Button 1: Dynamic hints from Solomon "?"
                                _buildProfileRowButton(
                                  child: Text(
                                    "?",
                                    style: AppFonts.serif(
                                      fontSize: 20,
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.darkWood,
                                    ),
                                  ),
                                  onTap: () {
                                    state.triggerWittyHint();
                                  },
                                ),
                                // Normal Button 2: Undo Move
                                _buildProfileRowButton(
                                  child: const Icon(Icons.undo, size: 20, color: AppColors.darkWood),
                                  onTap: state.isThinking || state.fenHistory.length <= 1 
                                      ? null 
                                      : () => state.undoMove(),
                                ),
                                // Normal Button 3: 3-dots sheet
                                _buildProfileRowButton(
                                  child: const Icon(Icons.more_vert, size: 20, color: AppColors.darkWood),
                                  onTap: () => _showGameOptionsBottomSheet(state),
                                ),
                              ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(width: 12),
                    // Right Column: Speech bubbles (expanded height for chat space & side options)
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.only(top: 8.0),
                        child: SizedBox(
                          height: 290, // Expanded height to give chat more room & show side options
                          child: SingleChildScrollView(
                            physics: const BouncingScrollPhysics(),
                            child: AnimatedSwitcher(
                              duration: const Duration(milliseconds: 400),
                              switchInCurve: Curves.easeOutQuart,
                              switchOutCurve: Curves.easeInQuart,
                              transitionBuilder: (Widget child, Animation<double> animation) {
                                return FadeTransition(
                                  opacity: animation,
                                  child: SlideTransition(
                                    position: Tween<Offset>(
                                      begin: const Offset(0.0, 0.08),
                                      end: Offset.zero,
                                    ).animate(animation),
                                    child: child,
                                  ),
                                );
                              },
                              child: Column(
                                key: ValueKey<String>(
                                  "${speechText}_${state.previousCommentary ?? ''}_${state.isPendingSideSelection}"
                                ),
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  _buildChatBubble(speechText),
                                  if (state.isPendingSideSelection && !isReview) ...[
                                    const SizedBox(height: 10),
                                    _buildChatOptionBubble("Play as White", () {
                                      state.chooseSide('white');
                                    }),
                                    const SizedBox(height: 8),
                                    _buildChatOptionBubble("Play as Black", () {
                                      state.chooseSide('black');
                                    }),
                                    const SizedBox(height: 8),
                                    _buildChatOptionBubble("Or let me choose", () {
                                      state.chooseSide('random');
                                    }),
                                  ] else if (state.previousCommentary != null && !isReview) ...[
                                    const SizedBox(height: 8),
                                    _buildChatBubble(state.previousCommentary!),
                                  ],
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 36), // Pushes chess board down so chat area has ample space
                
                // Chess board
                ChessBoardWidget(
                  state: state,
                  onSquareTap: (square, ctx) => state.handleSquareTap(square, ctx),
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        );
      case AppScreen.home:
        double winRate = state.gamesPlayed == 0
            ? 0.0
            : ((state.gamesWon + 0.5 * state.gamesDrawn) / state.gamesPlayed) * 100;

        final displayedGames = state.gameHistory.take(5).toList();

        return ListView(
          padding: const EdgeInsets.only(top: 24, left: 16, right: 16),
          children: [
            ArguuuCard(
              padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildProfileStat("Rating", "${state.userElo} ELO"),
                  _buildProfileStat("Games", "${state.gamesPlayed}"),
                  _buildProfileStat("Win Rate", "${winRate.toStringAsFixed(0)}%"),
                ],
              ),
            ),
            const SizedBox(height: 16),
            ArguuuCard(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Performance Insights",
                    style: AppFonts.serif(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: AppColors.darkWood,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      // Circular Win Rate ring
                      Expanded(
                        flex: 4,
                        child: Column(
                          children: [
                            SizedBox(
                              width: 80,
                              height: 80,
                              child: TweenAnimationBuilder<double>(
                                tween: Tween<double>(begin: 0.0, end: winRate / 100.0),
                                duration: const Duration(milliseconds: 1200),
                                curve: Curves.easeOutCubic,
                                builder: (context, value, child) {
                                  return CustomPaint(
                                    painter: WinRateRingPainter(
                                      progress: value,
                                      color: AppColors.copper,
                                      bgColor: AppColors.sand.withOpacity(0.3),
                                    ),
                                    child: Center(
                                      child: Text(
                                        "${(value * 100).toStringAsFixed(0)}%",
                                        style: AppFonts.serif(
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold,
                                          color: AppColors.darkWood,
                                        ),
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              "Win Rate",
                              style: AppFonts.sans(
                                fontSize: 13,
                                color: AppColors.textLight,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 16),
                      // ELO history line chart
                      Expanded(
                        flex: 6,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                              SizedBox(
                                height: 80,
                                child: TweenAnimationBuilder<double>(
                                  tween: Tween<double>(begin: 0.0, end: 1.0),
                                  duration: const Duration(milliseconds: 1500),
                                  curve: Curves.easeInOutCubic,
                                  builder: (context, value, child) {
                                    return CustomPaint(
                                      painter: EloLineChartPainter(
                                        history: state.gameHistory,
                                        animationValue: value,
                                        lineColor: AppColors.copper,
                                        fillColor: AppColors.copper.withOpacity(0.15),
                                        currentElo: state.userElo,
                                      ),
                                    );
                                  },
                                ),
                              ),
                              const SizedBox(height: 8),
                              Center(
                                child: Text(
                                  "ELO Progress",
                                  style: AppFonts.sans(
                                    fontSize: 13,
                                    color: AppColors.textLight,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 16),
            ArguuuCard(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Game History",
                    style: AppFonts.serif(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.darkWood),
                  ),
                  const SizedBox(height: 12),
                  if (state.gameHistory.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 16.0),
                      child: Center(
                        child: Text(
                          "No matches recorded yet.\nPlay a match to start your history!",
                          textAlign: TextAlign.center,
                          style: AppFonts.sans(color: AppColors.textLight, fontSize: 13, height: 1.4),
                        ),
                      ),
                    )
                  else ...[
                    ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: displayedGames.length,
                      itemBuilder: (context, index) {
                        final game = displayedGames[index];
                        final String dateIso = game['date'] ?? '';
                        final String dateStr = formatHistoryDate(dateIso);
                        final String result = game['result'] ?? '';
                        final String opponent = game['opponent'] ?? 'Prof. Solomon';
                        final int startElo = game['playerEloStart'] ?? 800;
                        final int endElo = game['playerEloEnd'] ?? 800;
                        final eloDiff = endElo - startElo;
                        final String eloDiffSign = eloDiff >= 0 ? "+$eloDiff" : "$eloDiff";
                        final String eloText = eloDiff != 0 ? " ($eloDiffSign ELO)" : "";

                        Color resultColor = AppColors.textLight;
                        if (result == "Won") {
                          resultColor = AppColors.copper;
                        } else if (result == "Lost") {
                          resultColor = AppColors.lossTxt;
                        }

                        return Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          decoration: BoxDecoration(
                            border: Border(bottom: BorderSide(color: AppColors.sand.withOpacity(0.3))),
                          ),
                          child: ListTile(
                            contentPadding: EdgeInsets.zero,
                            title: Text(
                              opponent,
                              style: AppFonts.serif(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.darkWood),
                            ),
                            subtitle: Text(
                              "$dateStr • $result$eloText",
                              style: AppFonts.sans(fontSize: 12, color: resultColor, fontWeight: FontWeight.w600),
                            ),
                            trailing: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: AppColors.cottonWhite,
                                borderRadius: BorderRadius.circular(4),
                                border: Border.all(color: AppColors.sand, width: 0.8),
                              ),
                              child: Text(
                                "Review",
                                style: AppFonts.serif(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.copper),
                              ),
                            ),
                            onTap: () {
                              state.startReviewMode(game);
                              setState(() {
                                _activeScreen = AppScreen.play;
                              });
                            },
                          ),
                        );
                      },
                    ),
                    if (state.gameHistory.length > 5) ...[
                      const SizedBox(height: 8),
                      GestureDetector(
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => GameHistoryScreen(
                                state: state,
                                onScreenChange: (screen) {
                                  setState(() {
                                    _activeScreen = screen;
                                  });
                                },
                              ),
                            ),
                          );
                        },
                        child: Center(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 8.0),
                            child: Text(
                              "Show More",
                              style: AppFonts.serif(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: AppColors.copper,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ],
                ],
              ),
            ),
          ],
        );
      case AppScreen.train:
        if (state.isTrainingMode) {
          final lesson = trainingLessons[state.trainingLessonIndex];
          String phaseTitle = "";
          Color phaseColor = AppColors.copper;
          Widget actionButton = const SizedBox.shrink();

          if (state.trainingPhase == 'watch') {
            phaseTitle = "Phase 1: Watch & Learn";
            phaseColor = AppColors.copper;
            if (state.trainingWatchStep < lesson.watchMoves.length) {
              actionButton = ArguuuButton(
                label: "Next Demo Move",
                icon: const Icon(Icons.arrow_forward, size: 18),
                onPressed: () => state.advanceWatch(),
              );
            } else {
              actionButton = ArguuuButton(
                label: "Start Assisted Practice",
                icon: const Icon(Icons.play_arrow, size: 18),
                onPressed: () => state.startAssistPhase(),
              );
            }
          } else if (state.trainingPhase == 'assist') {
            phaseTitle = "Phase 2: Assisted Practice";
            phaseColor = AppColors.darkWood;
            if (state.trainingAssistStep >= lesson.assistMoves.length) {
              actionButton = ArguuuButton(
                label: "Start Real Challenges",
                icon: const Icon(Icons.flash_on, size: 18),
                onPressed: () => state.startRealPhase(),
              );
            }
          } else if (state.trainingPhase == 'real') {
            phaseTitle = "Phase 3: Real Counter-play (${state.trainingChallengeIndex + 1}/4)";
            phaseColor = Colors.deepOrange;
          } else if (state.trainingPhase == 'success') {
            phaseTitle = "Lesson Passed!";
            phaseColor = Colors.green;
            actionButton = ArguuuButton(
              label: "Exit to Lessons",
              icon: const Icon(Icons.check, size: 18),
              onPressed: () => state.exitTraining(),
            );
          }

          final bool isLandscape = MediaQuery.of(context).orientation == Orientation.landscape;
          final double bottomPadding = state.hasSelectedLevel ? 88.0 : 16.0;

          if (isLandscape) {
            return Padding(
              padding: EdgeInsets.only(left: 16.0, right: 16.0, top: 8.0, bottom: bottomPadding),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Left side: The Chessboard
                  Expanded(
                    flex: 5,
                    child: Center(
                      child: AspectRatio(
                        aspectRatio: 1.0,
                        child: ChessBoardWidget(
                          state: state,
                          onSquareTap: (square, ctx) => state.handleSquareTap(square, ctx),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 24),
                  // Right side: The training controls and instructions
                  Expanded(
                    flex: 5,
                    child: SingleChildScrollView(
                      physics: const BouncingScrollPhysics(),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              IconButton(
                                icon: const Icon(Icons.arrow_back, color: AppColors.darkWood),
                                onPressed: () => state.exitTraining(),
                              ),
                              Expanded(
                                child: Text(
                                  lesson.title,
                                  style: AppFonts.serif(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.darkWood,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              TextButton.icon(
                                icon: const Icon(Icons.exit_to_app, size: 16, color: AppColors.lossTxt),
                                label: Text("Quit", style: AppFonts.sans(color: AppColors.lossTxt, fontSize: 13, fontWeight: FontWeight.bold)),
                                onPressed: () => state.exitTraining(),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
                            decoration: BoxDecoration(
                              color: phaseColor.withOpacity(0.12),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: phaseColor.withOpacity(0.3), width: 1),
                            ),
                            child: Text(
                              phaseTitle,
                              textAlign: TextAlign.center,
                              style: AppFonts.serif(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: phaseColor,
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              GestureDetector(
                                onTap: () => _showCoachSelectionDialog(context, state),
                                child: Container(
                                  width: 44,
                                  height: 44,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    border: Border.all(color: AppColors.copper, width: 1.5),
                                    image: DecorationImage(
                                      image: AssetImage('assets/mbti_coaches/${state.currentCoach}.png'),
                                      fit: BoxFit.cover,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: AppColors.sand, width: 0.8),
                                  ),
                                  child: Text(
                                    state.lastCommentary,
                                    style: AppFonts.sans(fontSize: 13, color: AppColors.textMain, height: 1.3),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          actionButton,
                          if (state.trainingPhase == 'assist' && state.trainingAssistStep < lesson.assistMoves.length) ...[
                            const SizedBox(height: 8),
                            Text(
                              "Goal: Complete the moves as prompted. Follow Solomon's guidance.",
                              style: AppFonts.sans(fontSize: 12, color: AppColors.textLight, fontStyle: FontStyle.italic),
                            ),
                          ],
                          if (state.trainingPhase == 'real') ...[
                            const SizedBox(height: 8),
                            Text(
                              "Goal: Find the winning sequence for Challenge ${state.trainingChallengeIndex + 1} of 4.",
                              style: AppFonts.sans(fontSize: 12, color: AppColors.textLight, fontStyle: FontStyle.italic),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            );
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 16.0),
            child: Column(
              children: [
                Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back, color: AppColors.darkWood),
                      onPressed: () => state.exitTraining(),
                    ),
                    Expanded(
                      child: Text(
                        lesson.title,
                        style: AppFonts.serif(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: AppColors.darkWood,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    TextButton.icon(
                      icon: const Icon(Icons.exit_to_app, size: 16, color: AppColors.lossTxt),
                      label: Text("Quit", style: AppFonts.sans(color: AppColors.lossTxt, fontSize: 13, fontWeight: FontWeight.bold)),
                      onPressed: () => state.exitTraining(),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
                  decoration: BoxDecoration(
                    color: phaseColor.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: phaseColor.withOpacity(0.3), width: 1),
                  ),
                  child: Text(
                    phaseTitle,
                    textAlign: TextAlign.center,
                    style: AppFonts.serif(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: phaseColor,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    GestureDetector(
                      onTap: () => _showCoachSelectionDialog(context, state),
                      child: Container(
                        width: 50,
                        height: 50,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: AppColors.copper, width: 1.5),
                          image: DecorationImage(
                            image: AssetImage('assets/mbti_coaches/${state.currentCoach}.png'),
                            fit: BoxFit.cover,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: AppColors.sand, width: 0.8),
                        ),
                        child: Text(
                          state.lastCommentary,
                          style: AppFonts.sans(fontSize: 13, color: AppColors.textMain, height: 1.3),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                ChessBoardWidget(
                  state: state,
                  onSquareTap: (square, ctx) => state.handleSquareTap(square, ctx),
                ),
                const SizedBox(height: 16),
                actionButton,
                if (state.trainingPhase == 'assist' && state.trainingAssistStep < lesson.assistMoves.length) ...[
                  const SizedBox(height: 8),
                  Text(
                    "Goal: Complete the moves as prompted. Follow Solomon's guidance.",
                    style: AppFonts.sans(fontSize: 12, color: AppColors.textLight, fontStyle: FontStyle.italic),
                  ),
                ],
                if (state.trainingPhase == 'real') ...[
                  const SizedBox(height: 8),
                  Text(
                    "Goal: Find the winning sequence for Challenge ${state.trainingChallengeIndex + 1} of 4.",
                    style: AppFonts.sans(fontSize: 12, color: AppColors.textLight, fontStyle: FontStyle.italic),
                  ),
                ],
              ],
            ),
          );
        }

        final categories = ["Openings", "Middlegame", "Endgames", "Checkmates", "Avoiding Checkmates"];
        return ListView(
          padding: const EdgeInsets.only(top: 24, left: 16, right: 16, bottom: 24),
          children: [
            ArguuuCard(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Interactive Training Academy",
                    style: AppFonts.serif(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.copper),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    "Train openings, tactics, and endgames step-by-step with Prof. Solomon. Follow his 4-stage active learning session: Watch, Try with Help, Counter-play, and Pass!",
                    style: AppFonts.sans(fontSize: 13, color: AppColors.textMain, height: 1.4),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            for (var category in categories) ...[
              Padding(
                padding: const EdgeInsets.only(left: 4, bottom: 8, top: 12),
                child: Text(
                  category.toUpperCase(),
                  style: AppFonts.sans(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textLight,
                    letterSpacing: 1.2,
                  ),
                ),
              ),
              ...trainingLessons.asMap().entries.where((entry) => entry.value.category == category).map((entry) {
                final int index = entry.key;
                final lesson = entry.value;
                return ArguuuCard(
                  margin: const EdgeInsets.only(bottom: 10),
                  onTap: () => state.startLesson(index),
                  child: Row(
                    children: [
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: AppColors.copper.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: AppColors.copper.withOpacity(0.2)),
                        ),
                        alignment: Alignment.center,
                        child: Icon(
                          category == "Openings" 
                              ? Icons.explore 
                              : (category == "Middlegame" 
                                  ? Icons.military_tech 
                                  : (category == "Endgames" 
                                      ? Icons.flag 
                                      : Icons.stars)),
                          color: AppColors.copper,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              lesson.title,
                              style: AppFonts.serif(
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                                color: AppColors.darkWood,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              lesson.description,
                              style: AppFonts.sans(
                                fontSize: 12,
                                color: AppColors.textMain,
                                height: 1.3,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Icon(Icons.arrow_forward_ios, size: 14, color: AppColors.textLight),
                    ],
                  ),
                );
              }),
            ],
          ],
        );
    }
  }

  Widget _buildProfileStat(String label, String value) {
    return Column(
      children: [
        Text(value, style: AppFonts.serif(fontSize: 22, fontWeight: FontWeight.bold, color: AppColors.textMain)),
        const SizedBox(height: 4),
        Text(label, style: AppFonts.mono(fontSize: 11, color: AppColors.textLight)),
      ],
    );
  }

  void _showGameOptionsBottomSheet(ChessGameState state) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.cream,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.sand,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 24),
                _buildBottomSheetOptionTile(
                  icon: Icons.refresh,
                  label: "Restart Game",
                  onTap: () {
                    Navigator.pop(context);
                    state.resetGame();
                  },
                ),
                _buildBottomSheetOptionTile(
                  icon: Icons.flip_camera_android,
                  label: "Flip Board",
                  onTap: () {
                    Navigator.pop(context);
                    state.toggleBoardFlip();
                  },
                ),
                _buildBottomSheetOptionTile(
                  icon: Icons.handshake,
                  label: "Propose Draw",
                  onTap: () {
                    Navigator.pop(context);
                    _proposeDraw(state);
                  },
                ),
                _buildBottomSheetOptionTile(
                  icon: Icons.flag,
                  label: "Resign Match",
                  onTap: () {
                    Navigator.pop(context);
                    state.resign(context);
                  },
                  isDestructive: true,
                ),
                _buildBottomSheetOptionTile(
                  icon: Icons.tune,
                  label: "Adjust Level",
                  onTap: () {
                    Navigator.pop(context);
                    _showAdjustLevelBottomSheet(context, state);
                  },
                ),
                _buildBottomSheetOptionTile(
                  icon: Icons.settings,
                  label: "Game Settings",
                  onTap: () {
                    Navigator.pop(context);
                    _showSettingsBottomSheet(context, state);
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showAdjustLevelBottomSheet(BuildContext context, ChessGameState state) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.cream,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: AppColors.sand,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      'Adjust ${state.currentCoach} Level',
                      style: AppFonts.serif(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.copper),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Select difficulty (applies immediately):',
                      style: AppFonts.sans(fontSize: 13, color: AppColors.textLight),
                    ),
                    const SizedBox(height: 20),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: List.generate(state.difficultyLabels.length, (index) {
                        final label = state.difficultyLabels[index];
                        final isSelected = state.aiDifficulty == index;
                        return ChoiceChip(
                          label: Text(label),
                          selected: isSelected,
                          selectedColor: AppColors.copper,
                          labelStyle: AppFonts.serif(
                            fontSize: 12,
                            color: isSelected ? AppColors.cream : AppColors.darkWood,
                          ),
                          onSelected: (selected) {
                            if (selected) {
                              state.setDifficulty(index);
                              setModalState(() {});
                            }
                          },
                        );
                      }),
                    ),
                    const SizedBox(height: 24),
                    ArguuuButton(
                      label: 'CONFIRM',
                      fullWidth: true,
                      onPressed: () {
                        Navigator.pop(context);
                      },
                    ),
                  ],
                ),
              ),
            );
          }
        );
      },
    );
  }

  void _showSettingsBottomSheet(BuildContext context, ChessGameState state) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.cream,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: AppColors.sand,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      'Match Configuration',
                      style: AppFonts.serif(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.copper),
                    ),
                    const SizedBox(height: 20),
                    
                    Text('Game Mode', style: AppFonts.serif(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.textLight)),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: ChoiceChip(
                            label: const Center(child: Text('VS Solomon')),
                            selected: state.gameMode == GameMode.vsComputer,
                            onSelected: (selected) {
                              if (selected) {
                                state.setGameMode(GameMode.vsComputer);
                                setModalState(() {});
                              }
                            },
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: ChoiceChip(
                            label: const Center(child: Text('Pass & Play')),
                            selected: state.gameMode == GameMode.localPlay,
                            onSelected: (selected) {
                              if (selected) {
                                state.setGameMode(GameMode.localPlay);
                                setModalState(() {});
                              }
                            },
                          ),
                        ),
                      ],
                    ),
                    
                    const SizedBox(height: 20),
                    Text('${state.currentCoach} Difficulty', style: AppFonts.serif(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.textLight)),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: List.generate(state.difficultyLabels.length, (index) {
                        final label = state.difficultyLabels[index];
                        final isSelected = state.aiDifficulty == index;
                        return ChoiceChip(
                          label: Text(label),
                          selected: isSelected,
                          selectedColor: AppColors.copper,
                          labelStyle: AppFonts.serif(
                            fontSize: 12,
                            color: isSelected ? AppColors.cream : AppColors.darkWood,
                          ),
                          onSelected: (selected) {
                            if (selected) {
                              state.setDifficulty(index);
                              setModalState(() {});
                            }
                          },
                        );
                      }),
                    ),

                    const SizedBox(height: 24),
                    ArguuuButton(
                      label: 'APPLY CONFIG',
                      fullWidth: true,
                      onPressed: () {
                        state.resetGame();
                        Navigator.pop(context);
                        setState(() {
                          _activeScreen = AppScreen.play;
                        });
                      },
                    ),
                  ],
                ),
              ),
            );
          }
        );
      },
    );
  }

  Widget _buildBottomSheetOptionTile({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    bool isDestructive = false,
  }) {
    Color color = isDestructive ? AppColors.lossTxt : AppColors.darkWood;
    return ListTile(
      leading: Icon(icon, color: color),
      title: Text(
        label,
        style: AppFonts.serif(
          fontSize: 16,
          fontWeight: FontWeight.bold,
          color: color,
        ),
      ),
      onTap: onTap,
    );
  }

  void _proposeDraw(ChessGameState state) {
    showDialog(
      context: context,
      builder: (context) => ArguuuConfirmDialog(
        title: "Propose Draw?",
        message: "Propose a draw to ${state.currentCoach}?",
        yesLabel: "Propose",
        noLabel: "Cancel",
        onYes: () {
          Navigator.pop(context);
          showDialog(
            context: context,
            builder: (context) => ArguuuConfirmDialog(
              title: "Draw Proposed",
              message: "${state.currentCoach} accepts the draw proposal.",
              yesLabel: "New Game",
              noLabel: "Close",
              onYes: () {
                state.resetGame();
                Navigator.pop(context);
              },
              onNo: () => Navigator.pop(context),
            ),
          );
        },
        onNo: () => Navigator.pop(context),
      ),
    );
  }
}

// Custom Chess Pawn outline icon matching image exactly
class ChessPawnPainter extends CustomPainter {
  final Color color;
  ChessPawnPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;

    final path = Path();
    double w = size.width;
    double h = size.height;

    // Head circle
    path.addOval(Rect.fromCircle(
      center: Offset(w / 2, h * 0.3),
      radius: h * 0.14,
    ));

    // Neck line / collar
    path.moveTo(w * 0.35, h * 0.44);
    path.lineTo(w * 0.65, h * 0.44);

    // Body curves fanning out to base
    path.moveTo(w * 0.40, h * 0.44);
    path.quadraticBezierTo(w * 0.32, h * 0.68, w * 0.22, h * 0.82);
    path.quadraticBezierTo(w * 0.22, h * 0.88, w * 0.28, h * 0.88);
    path.lineTo(w * 0.72, h * 0.88);
    path.quadraticBezierTo(w * 0.78, h * 0.88, w * 0.78, h * 0.82);
    path.quadraticBezierTo(w * 0.68, h * 0.68, w * 0.60, h * 0.44);

    // Bottom base line
    path.moveTo(w * 0.20, h * 0.88);
    path.lineTo(w * 0.80, h * 0.88);

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant ChessPawnPainter oldDelegate) => color != oldDelegate.color;
}

// Custom Chat Bubble painter with left-pointing tail pointer
class ChatBubblePainter extends CustomPainter {
  final Color bgColor;
  final Color borderColor;

  ChatBubblePainter({required this.bgColor, required this.borderColor});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = bgColor
      ..style = PaintingStyle.fill;

    final borderPaint = Paint()
      ..color = borderColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    final path = Path();
    double w = size.width;
    double h = size.height;
    double radius = 8.0;
    double arrowSize = 6.0;

    // Start drawing the bubble shape
    path.moveTo(arrowSize + radius, 0);
    path.lineTo(w - radius, 0);
    path.quadraticBezierTo(w, 0, w, radius);
    path.lineTo(w, h - radius);
    path.quadraticBezierTo(w, h, w - radius, h);
    path.lineTo(arrowSize + radius, h);
    path.quadraticBezierTo(arrowSize, h, arrowSize, h - radius);
    
    // Left side tail/pointer at the middle vertical height
    path.lineTo(arrowSize, h / 2 + arrowSize);
    path.lineTo(0, h / 2);
    path.lineTo(arrowSize, h / 2 - arrowSize);
    
    path.lineTo(arrowSize, radius);
    path.quadraticBezierTo(arrowSize, 0, arrowSize + radius, 0);
    path.close();

    // Draw shadow/fill
    canvas.drawPath(path, paint);
    // Draw border
    canvas.drawPath(path, borderPaint);
  }

  @override
  bool shouldRepaint(covariant ChatBubblePainter oldDelegate) => false;
}

class GradientBorderPainter extends CustomPainter {
  final Color color;
  final double strokeWidth;

  GradientBorderPainter({required this.color, this.strokeWidth = 1.5});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    // Create a linear gradient that is solid at the bottom (y = height)
    // and fades out fully to transparent at the top (y = 0).
    final Rect rect = Rect.fromLTWH(0, 0, size.width, size.height);
    final gradient = LinearGradient(
      begin: Alignment.bottomCenter,
      end: Alignment.topCenter,
      colors: [color, color, color.withOpacity(0)],
      stops: const [0.0, 0.3, 1.0], // stays solid for bottom 30% then fades to transparent
    );
    paint.shader = gradient.createShader(rect);

    final path = Path();
    path.moveTo(0, 0); // start at top-left
    path.lineTo(0, size.height - 4); // left edge down to before bottom-left corner
    path.quadraticBezierTo(0, size.height, 4, size.height); // bottom-left corner
    path.lineTo(size.width - 4, size.height); // bottom edge
    path.quadraticBezierTo(size.width, size.height, size.width, size.height - 4); // bottom-right corner
    path.lineTo(size.width, 0); // right edge up to top-right

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant GradientBorderPainter oldDelegate) {
    return oldDelegate.color != color || oldDelegate.strokeWidth != strokeWidth;
  }
}

class WinRateRingPainter extends CustomPainter {
  final double progress;
  final Color color;
  final Color bgColor;

  WinRateRingPainter({
    required this.progress,
    required this.color,
    required this.bgColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final double strokeWidth = 8.0;
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width - strokeWidth) / 2;

    final bgPaint = Paint()
      ..color = bgColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;
    canvas.drawCircle(center, radius, bgPaint);

    final fgPaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    final double startAngle = -math.pi / 2;
    final double sweepAngle = 2 * math.pi * progress;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      startAngle,
      sweepAngle,
      false,
      fgPaint,
    );
  }

  @override
  bool shouldRepaint(covariant WinRateRingPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.color != color ||
        oldDelegate.bgColor != bgColor;
  }
}

class EloLineChartPainter extends CustomPainter {
  final List<Map<String, dynamic>> history;
  final double animationValue;
  final Color lineColor;
  final Color fillColor;
  final int currentElo;

  EloLineChartPainter({
    required this.history,
    required this.animationValue,
    required this.lineColor,
    required this.fillColor,
    required this.currentElo,
  });

  @override
  void paint(Canvas canvas, Size size) {
    List<int> eloValues = [];
    if (history.isEmpty) {
      eloValues = [800, currentElo];
    } else {
      final recentHistory = history.length > 8 
          ? history.sublist(0, 8) 
          : history;
      final chronological = recentHistory.reversed.toList();
      final startVal = chronological.first['playerEloStart'];
      eloValues.add(startVal is num ? startVal.toInt() : 800);
      for (var game in chronological) {
        final endVal = game['playerEloEnd'];
        eloValues.add(endVal is num ? endVal.toInt() : 800);
      }
    }

    if (eloValues.length < 2) {
      eloValues = [800, 800];
    }

    int maxElo = eloValues.reduce(math.max);
    int minElo = eloValues.reduce(math.min);
    
    int range = maxElo - minElo;
    if (range == 0) {
      maxElo += 50;
      minElo -= 50;
      range = 100;
    } else {
      maxElo += (range * 0.1).round();
      minElo -= (range * 0.1).round();
      range = maxElo - minElo;
    }

    final double width = size.width;
    final double height = size.height;
    final double dx = width / (eloValues.length - 1);

    final linePath = Path();
    final fillPath = Path();

    double getX(int index) => index * dx;
    double getY(int val) {
      double ratio = (val - minElo) / range;
      return height - (ratio * height * animationValue);
    }

    linePath.moveTo(getX(0), getY(eloValues.first));
    fillPath.moveTo(getX(0), height);
    fillPath.lineTo(getX(0), getY(eloValues.first));

    for (int i = 1; i < eloValues.length; i++) {
      double cx1 = getX(i - 1) + dx / 2;
      double cy1 = getY(eloValues[i - 1]);
      double cx2 = getX(i) - dx / 2;
      double cy2 = getY(eloValues[i]);
      
      linePath.cubicTo(cx1, cy1, cx2, cy2, getX(i), getY(eloValues[i]));
      fillPath.cubicTo(cx1, cy1, cx2, cy2, getX(i), getY(eloValues[i]));
    }

    fillPath.lineTo(getX(eloValues.length - 1), height);
    fillPath.close();

    final fillPaint = Paint()
      ..style = PaintingStyle.fill
      ..color = fillColor;
    canvas.drawPath(fillPath, fillPaint);

    final linePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..color = lineColor
      ..strokeCap = StrokeCap.round;
    canvas.drawPath(linePath, linePaint);

    final dotPaint = Paint()
      ..style = PaintingStyle.fill
      ..color = lineColor;
    canvas.drawCircle(
      Offset(getX(eloValues.length - 1), getY(eloValues.last)),
      4.0,
      dotPaint,
    );
  }

  @override
  bool shouldRepaint(covariant EloLineChartPainter oldDelegate) {
    return oldDelegate.history != history ||
        oldDelegate.animationValue != animationValue ||
        oldDelegate.lineColor != lineColor ||
        oldDelegate.fillColor != fillColor ||
        oldDelegate.currentElo != currentElo;
  }
}

class GameHistoryScreen extends StatelessWidget {
  final ChessGameState state;
  final Function(AppScreen) onScreenChange;

  const GameHistoryScreen({
    Key? key,
    required this.state,
    required this.onScreenChange,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.cream,
      appBar: AppBar(
        backgroundColor: AppColors.cream,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.darkWood),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          "Match History",
          style: AppFonts.serif(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: AppColors.darkWood,
          ),
        ),
      ),
      body: SafeArea(
        child: state.gameHistory.isEmpty
            ? Center(
                child: Text(
                  "No matches recorded yet.",
                  style: AppFonts.sans(color: AppColors.textLight, fontSize: 14),
                ),
              )
            : ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: state.gameHistory.length,
                itemBuilder: (context, index) {
                  final game = state.gameHistory[index];
                  final String dateIso = game['date'] ?? '';
                  final String dateStr = formatHistoryDate(dateIso);
                  final String result = game['result'] ?? '';
                  final String opponent = game['opponent'] ?? 'Prof. Solomon';
                  final int startElo = game['playerEloStart'] ?? 800;
                  final int endElo = game['playerEloEnd'] ?? 800;
                  final eloDiff = endElo - startElo;
                  final String eloDiffSign = eloDiff >= 0 ? "+$eloDiff" : "$eloDiff";
                  final String eloText = eloDiff != 0 ? " ($eloDiffSign ELO)" : "";

                  Color resultColor = AppColors.textLight;
                  if (result == "Won") {
                    resultColor = AppColors.copper;
                  } else if (result == "Lost") {
                    resultColor = AppColors.lossTxt;
                  }

                  return ArguuuCard(
                    margin: const EdgeInsets.only(bottom: 12),
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      title: Text(
                        opponent,
                        style: AppFonts.serif(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: AppColors.darkWood,
                        ),
                      ),
                      subtitle: Text(
                        "$dateStr • $result$eloText",
                        style: AppFonts.sans(
                          fontSize: 13,
                          color: resultColor,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      trailing: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: AppColors.cottonWhite,
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: AppColors.sand, width: 0.8),
                        ),
                        child: Text(
                          "Review",
                          style: AppFonts.serif(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: AppColors.copper,
                          ),
                        ),
                      ),
                      onTap: () {
                        Navigator.pop(context);
                        state.startReviewMode(game);
                        onScreenChange(AppScreen.play);
                      },
                    ),
                  );
                },
              ),
      ),
    );
  }
}

void _showCoachSelectionDialog(BuildContext context, ChessGameState state) {
  showDialog(
    context: context,
    builder: (BuildContext context) {
      return Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          width: 320,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: AppColors.cream,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: AppColors.copper.withOpacity(0.3), width: 1.5),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.12),
                blurRadius: 28,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Choose Coach',
                style: AppFonts.serif(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: AppColors.darkWood,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Select your preferred chess coach.',
                style: TextStyle(
                  fontSize: 12,
                  color: AppColors.textLight.withOpacity(0.7),
                ),
              ),
              const SizedBox(height: 16),
              Flexible(
                child: GridView.builder(
                  shrinkWrap: true,
                  physics: const BouncingScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                    childAspectRatio: 0.8,
                  ),
                  itemCount: state.mbtiCoaches.length,
                  itemBuilder: (context, index) {
                    final coach = state.mbtiCoaches[index];
                    final isSelected = state.currentCoach == coach;
                    
                    return GestureDetector(
                      onTap: () {
                        state.selectCoach(coach);
                        Navigator.pop(context);
                      },
                      child: Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: isSelected ? AppColors.copper : AppColors.sand.withOpacity(0.6),
                            width: isSelected ? 2.5 : 1.0,
                          ),
                        ),
                        clipBehavior: Clip.antiAlias,
                        child: Image.asset(
                          'assets/mbti_coaches/$coach.png',
                          fit: BoxFit.cover,
                        ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 16),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text(
                    'Cancel',
                    style: TextStyle(
                      color: AppColors.copper,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
}

class MoveHistoryPanel extends StatefulWidget {
  final ChessGameState state;
  const MoveHistoryPanel({super.key, required this.state});

  @override
  State<MoveHistoryPanel> createState() => _MoveHistoryPanelState();
}

class _MoveHistoryPanelState extends State<MoveHistoryPanel> {
  bool _analysisEnabled = false;
  final ScrollController _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients && _scrollController.position.maxScrollExtent > 0) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = widget.state;
    final moves = state.activeMoveLog;
    final int currentIdx = state.activeMoveHistoryIndex;

    // Auto-scroll to bottom when in live mode (-1)
    if (currentIdx == -1 && moves.isNotEmpty) {
      _scrollToBottom();
    }

    // Group moves into pairs (White / Black)
    final List<List<Map<String, dynamic>?>> pairs = [];
    for (int i = 0; i < moves.length; i += 2) {
      pairs.add([
        moves[i],
        i + 1 < moves.length ? moves[i + 1] : null,
      ]);
    }

    // Find max time for bar scaling
    double maxTime = 1.0;
    for (var m in moves) {
      final double t = (m['time'] as num?)?.toDouble() ?? 0.0;
      if (t > maxTime) maxTime = t;
    }

    return Container(
      decoration: BoxDecoration(
        color: AppColors.cottonWhite,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.sand, width: 1.5),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header Bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: const BoxDecoration(
              color: AppColors.cream,
              borderRadius: BorderRadius.vertical(top: Radius.circular(14)),
              border: Border(bottom: BorderSide(color: AppColors.sand)),
            ),
            child: Row(
              children: [
                Text(
                  'Moves',
                  style: AppFonts.serif(
                    color: AppColors.textMain,
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                ),
                const Spacer(),
                // Analysis / Engine Toggle
                GestureDetector(
                  onTap: () => setState(() => _analysisEnabled = !_analysisEnabled),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: _analysisEnabled
                          ? AppColors.winBg
                          : AppColors.cottonWhite,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: _analysisEnabled ? AppColors.winTxt : AppColors.sand,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.analytics_rounded,
                          size: 14,
                          color: _analysisEnabled ? AppColors.winTxt : AppColors.textLight,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          _analysisEnabled ? 'Engine ON' : 'Analysis',
                          style: AppFonts.mono(
                            color: _analysisEnabled ? AppColors.winTxt : AppColors.textLight,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Scrollable Moves List
          Container(
            height: 180,
            color: AppColors.cottonWhite,
            child: moves.isEmpty
                ? Center(
                    child: Text(
                      'No moves played yet.',
                      style: AppFonts.sans(
                        color: AppColors.textLight,
                        fontSize: 13,
                      ),
                    ),
                  )
                : ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 12),
                    itemCount: pairs.length,
                    itemBuilder: (context, pairIdx) {
                      final whiteMove = pairs[pairIdx][0];
                      final blackMove = pairs[pairIdx][1];
                      final int moveNum = pairIdx + 1;
                      final int wi = pairIdx * 2;
                      final int bi = pairIdx * 2 + 1;

                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 2.0),
                        child: Row(
                          children: [
                            // Move number
                            SizedBox(
                              width: 24,
                              child: Text(
                                '$moveNum.',
                                style: AppFonts.mono(
                                  color: AppColors.textLight,
                                  fontSize: 11,
                                ),
                              ),
                            ),
                            // White Move
                            Expanded(
                              child: _MoveCell(
                                move: whiteMove,
                                maxTime: maxTime,
                                isSelected: currentIdx == wi,
                                onTap: () => currentIdx == wi
                                    ? state.exitMoveHistoryNav()
                                    : state.jumpToMoveHistoryIndex(wi),
                                showAnalysis: _analysisEnabled,
                              ),
                            ),
                            const SizedBox(width: 8),
                            // Black Move
                            Expanded(
                              child: blackMove != null
                                  ? _MoveCell(
                                      move: blackMove,
                                      maxTime: maxTime,
                                      isSelected: currentIdx == bi,
                                      onTap: () => currentIdx == bi
                                          ? state.exitMoveHistoryNav()
                                          : state.jumpToMoveHistoryIndex(bi),
                                      showAnalysis: _analysisEnabled,
                                    )
                                  : const SizedBox.shrink(),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),

          // Navigation Controls at the bottom
          Container(
            decoration: const BoxDecoration(
              color: AppColors.cream,
              borderRadius: BorderRadius.vertical(bottom: Radius.circular(14)),
              border: Border(top: BorderSide(color: AppColors.sand)),
            ),
            padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _NavButton(
                  icon: Icons.first_page_rounded,
                  tooltip: 'Start',
                  onTap: moves.isEmpty ? null : () => state.jumpToMoveHistoryIndex(-1),
                ),
                _NavButton(
                  icon: Icons.chevron_left_rounded,
                  tooltip: 'Previous',
                  onTap: (moves.isEmpty || currentIdx <= -1)
                      ? null
                      : () => state.jumpToMoveHistoryIndex(currentIdx - 1),
                ),
                _NavButton(
                  icon: currentIdx == -1
                      ? Icons.play_circle_filled_rounded
                      : Icons.play_circle_outline_rounded,
                  tooltip: 'Live',
                  accent: currentIdx == -1,
                  onTap: currentIdx == -1 ? null : () => state.exitMoveHistoryNav(),
                ),
                _NavButton(
                  icon: Icons.chevron_right_rounded,
                  tooltip: 'Next',
                  onTap: (moves.isEmpty || currentIdx >= moves.length - 1)
                      ? null
                      : () => state.jumpToMoveHistoryIndex(currentIdx + 1),
                ),
                _NavButton(
                  icon: Icons.last_page_rounded,
                  tooltip: 'End',
                  onTap: moves.isEmpty
                      ? null
                      : () => state.jumpToMoveHistoryIndex(moves.length - 1),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MoveCell extends StatelessWidget {
  final Map<String, dynamic>? move;
  final double maxTime;
  final bool isSelected;
  final VoidCallback onTap;
  final bool showAnalysis;

  const _MoveCell({
    required this.move,
    required this.maxTime,
    required this.isSelected,
    required this.onTap,
    required this.showAnalysis,
  });

  @override
  Widget build(BuildContext context) {
    if (move == null) return const SizedBox.shrink();
    final String san = move!['san'] as String? ?? '?';
    final double time = (move!['time'] as num?)?.toDouble() ?? 0.0;
    final String quality = move!['quality'] as String? ?? 'normal';
    final bool isUser = move!['isUser'] as bool? ?? false;

    Color qualityColor;
    IconData? qualityIcon;
    switch (quality) {
      case 'best':
        qualityColor = AppColors.winTxt;
        qualityIcon = Icons.star_rounded;
        break;
      case 'miss':
        qualityColor = AppColors.lossTxt;
        qualityIcon = Icons.cancel_rounded;
        break;
      case 'mistake':
        qualityColor = const Color(0xFFC4724A);
        qualityIcon = Icons.help_rounded;
        break;
      default:
        qualityColor = Colors.transparent;
        qualityIcon = null;
    }

    final double barFraction = maxTime > 0 ? (time / maxTime).clamp(0.0, 1.0) : 0.0;
    final String timeStr = time < 10 ? '${time.toStringAsFixed(1)}s' : '${time.toStringAsFixed(0)}s';

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.cream
              : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? AppColors.sand : Colors.transparent,
            width: 1.5,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                if (qualityIcon != null && isUser) ...[
                  Icon(qualityIcon, size: 12, color: qualityColor),
                  const SizedBox(width: 4),
                ],
                Expanded(
                  child: Text(
                    san,
                    style: AppFonts.sans(
                      color: isSelected ? AppColors.copper : AppColors.textMain,
                      fontSize: 13,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (showAnalysis)
                  Text(
                    timeStr,
                    style: AppFonts.mono(
                      color: AppColors.textLight,
                      fontSize: 10,
                    ),
                  ),
              ],
            ),
            if (showAnalysis && time > 0) ...[
              const SizedBox(height: 2),
              ClipRRect(
                borderRadius: BorderRadius.circular(2),
                child: SizedBox(
                  height: 3,
                  child: Stack(
                    children: [
                      Container(
                        width: double.infinity,
                        color: AppColors.sand.withOpacity(0.3),
                      ),
                      FractionallySizedBox(
                        widthFactor: barFraction,
                        child: Container(
                          color: isUser
                              ? AppColors.copper
                              : AppColors.textLight,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _NavButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;
  final String tooltip;
  final bool accent;

  const _NavButton({
    required this.icon,
    required this.onTap,
    required this.tooltip,
    this.accent = false,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          width: 38,
          height: 32,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: accent
                ? AppColors.sand.withOpacity(0.3)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            icon,
            size: 20,
            color: onTap == null
                ? AppColors.textLight.withOpacity(0.4)
                : accent
                    ? AppColors.copper
                    : AppColors.textMain,
          ),
        ),
      ),
    );
  }
}


