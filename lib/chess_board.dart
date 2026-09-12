import 'package:flutter/material.dart';
import 'package:chess_vectors_flutter/chess_vectors_flutter.dart';
import 'package:chess/chess.dart' as chess_pkg;
import 'chess_game_state.dart';
import 'theme_arguuu.dart';

class StripedSquarePainter extends CustomPainter {
  final Color baseColor;
  final Color stripeColor;

  StripedSquarePainter({required this.baseColor, required this.stripeColor});

  @override
  void paint(Canvas canvas, Size size) {
    // 1. Draw base background square
    final Paint bgPaint = Paint()..color = baseColor;
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), bgPaint);

    // 2. Draw diagonal stripes (top-left to bottom-right)
    final Paint stripePaint = Paint()
      ..color = stripeColor
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke;

    double step = 8.0; // Distance between stripes
    for (double i = -size.height; i < size.width; i += step) {
      canvas.drawLine(
        Offset(i, 0),
        Offset(i + size.height, size.height),
        stripePaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant StripedSquarePainter oldDelegate) {
    return oldDelegate.baseColor != baseColor || oldDelegate.stripeColor != stripeColor;
  }
}

class StripedSquareWidget extends StatelessWidget {
  final Color baseColor;
  final Color stripeColor;
  final Widget child;

  const StripedSquareWidget({
    super.key,
    required this.baseColor,
    required this.stripeColor,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: StripedSquarePainter(baseColor: baseColor, stripeColor: stripeColor),
      child: child,
    );
  }
}

class ChessBoardWidget extends StatefulWidget {
  final ChessGameState state;
  final Function(String, BuildContext) onSquareTap;

  const ChessBoardWidget({
    super.key,
    required this.state,
    required this.onSquareTap,
  });

  @override
  State<ChessBoardWidget> createState() => _ChessBoardWidgetState();
}

class AnimatedPiece {
  final String id;
  final chess_pkg.PieceType type;
  final chess_pkg.Color color;
  String square;

  AnimatedPiece({
    required this.id,
    required this.type,
    required this.color,
    required this.square,
  });
}

class _ChessBoardWidgetState extends State<ChessBoardWidget> {
  final List<AnimatedPiece> _pieces = [];
  String? _lastFen;

  @override
  void initState() {
    super.initState();
    _initializePieces();
  }

  @override
  void didUpdateWidget(covariant ChessBoardWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.state.game.fen != _lastFen) {
      _updatePieces();
    }
  }

  void _initializePieces() {
    _pieces.clear();
    final game = widget.state.game;
    for (int r = 0; r < 8; r++) {
      for (int c = 0; c < 8; c++) {
        final squareName = '${"abcdefgh"[c]}${8 - r}';
        final piece = game.get(squareName);
        if (piece != null) {
          final id = '${piece.color.name}_${piece.type.name}_$squareName';
          _pieces.add(AnimatedPiece(
            id: id,
            type: piece.type,
            color: piece.color,
            square: squareName,
          ));
        }
      }
    }
    _lastFen = game.fen;
  }

  void _updatePieces() {
    final game = widget.state.game;
    final String currentFen = game.fen;
    
    final from = widget.state.lastMoveFrom;
    final to = widget.state.lastMoveTo;
    
    // 1. Get all pieces currently on the board from the chess engine
    final List<Map<String, dynamic>> newBoardPieces = [];
    for (int r = 0; r < 8; r++) {
      for (int c = 0; c < 8; c++) {
        final squareName = '${"abcdefgh"[c]}${8 - r}';
        final piece = game.get(squareName);
        if (piece != null) {
          newBoardPieces.add({
            'square': squareName,
            'type': piece.type,
            'color': piece.color,
          });
        }
      }
    }
    
    // 2. We will build a new list of AnimatedPiece objects
    final List<AnimatedPiece> nextPieces = [];
    
    // Track which old pieces from _pieces have been matched/consumed
    final Set<String> matchedOldPieceIds = {};
    
    // Track special castling rook movements
    String? castlingRookFrom;
    String? castlingRookTo;
    if (from != null && to != null) {
      AnimatedPiece? oldKing;
      for (final p in _pieces) {
        if (p.square == from && p.type == chess_pkg.PieceType.KING) {
          oldKing = p;
          break;
        }
      }
      if (oldKing != null) {
        final fromCol = from[0];
        final toCol = to[0];
        final rowChar = from[1];
        if (fromCol == 'e') {
          if (toCol == 'g') {
            castlingRookFrom = 'h$rowChar';
            castlingRookTo = 'f$rowChar';
          } else if (toCol == 'c') {
            castlingRookFrom = 'a$rowChar';
            castlingRookTo = 'd$rowChar';
          }
        }
      }
    }

    // First pass: Match pieces that didn't move at all (same square, type, and color)
    for (final newPiece in newBoardPieces) {
      final sq = newPiece['square'] as String;
      final type = newPiece['type'] as chess_pkg.PieceType;
      final color = newPiece['color'] as chess_pkg.Color;
      
      // Don't match the destination square of the move or the castling rook destination in the first pass
      if (sq == to || sq == castlingRookTo) {
        continue;
      }
      
      final oldMatchIndex = _pieces.indexWhere((p) => 
        p.square == sq && 
        p.type == type && 
        p.color == color && 
        !matchedOldPieceIds.contains(p.id)
      );
      
      if (oldMatchIndex != -1) {
        final oldPiece = _pieces[oldMatchIndex];
        matchedOldPieceIds.add(oldPiece.id);
        nextPieces.add(AnimatedPiece(
          id: oldPiece.id,
          type: type,
          color: color,
          square: sq,
        ));
      }
    }
    
    // Second pass: Match the moving piece(s)
    for (final newPiece in newBoardPieces) {
      final sq = newPiece['square'] as String;
      final type = newPiece['type'] as chess_pkg.PieceType;
      final color = newPiece['color'] as chess_pkg.Color;
      
      // Skip if already added in the first pass
      if (nextPieces.any((p) => p.square == sq)) {
        continue;
      }
      
      if (sq == to && from != null) {
        // This is the primary moving piece!
        // Find the old piece that was at 'from'
        final oldMatchIndex = _pieces.indexWhere((p) => 
          p.square == from && 
          p.color == color &&
          !matchedOldPieceIds.contains(p.id)
        );
        
        if (oldMatchIndex != -1) {
          final oldPiece = _pieces[oldMatchIndex];
          matchedOldPieceIds.add(oldPiece.id);
          nextPieces.add(AnimatedPiece(
            id: oldPiece.id,
            type: type, // Use the new type in case of promotion!
            color: color,
            square: sq,
          ));
          continue;
        }
      }
      
      if (sq == castlingRookTo && castlingRookFrom != null) {
        // This is the castling rook!
        final oldMatchIndex = _pieces.indexWhere((p) => 
          p.square == castlingRookFrom && 
          p.color == color &&
          !matchedOldPieceIds.contains(p.id)
        );
        
        if (oldMatchIndex != -1) {
          final oldPiece = _pieces[oldMatchIndex];
          matchedOldPieceIds.add(oldPiece.id);
          nextPieces.add(AnimatedPiece(
            id: oldPiece.id,
            type: type,
            color: color,
            square: sq,
          ));
          continue;
        }
      }
    }
    
    // Third pass: Fallback for any unmatched pieces currently on the board
    for (final newPiece in newBoardPieces) {
      final sq = newPiece['square'] as String;
      final type = newPiece['type'] as chess_pkg.PieceType;
      final color = newPiece['color'] as chess_pkg.Color;
      
      if (nextPieces.any((p) => p.square == sq)) {
        continue;
      }
      
      // Try to find any remaining unmatched old piece of same color and type
      final oldMatchIndex = _pieces.indexWhere((p) => 
        p.type == type && 
        p.color == color && 
        !matchedOldPieceIds.contains(p.id)
      );
      
      if (oldMatchIndex != -1) {
        final oldPiece = _pieces[oldMatchIndex];
        matchedOldPieceIds.add(oldPiece.id);
        nextPieces.add(AnimatedPiece(
          id: oldPiece.id,
          type: type,
          color: color,
          square: sq,
        ));
      } else {
        // Create a new unique ID
        final id = '${color.name}_${type.name}_${sq}_${DateTime.now().microsecondsSinceEpoch}';
        nextPieces.add(AnimatedPiece(
          id: id,
          type: type,
          color: color,
          square: sq,
        ));
      }
    }
    
    _pieces.clear();
    _pieces.addAll(nextPieces);
    _lastFen = currentFen;
  }

  @override
  Widget build(BuildContext context) {
    final state = widget.state;
    return AspectRatio(
      aspectRatio: 1.0,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.08),
              blurRadius: 24,
              spreadRadius: 2,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: LayoutBuilder(
          builder: (context, constraints) {
            double boardSize = constraints.maxWidth;
            double squareSize = boardSize / 8;
            
            return Stack(
              children: [
                _buildBoardGrid(),
                ..._pieces.map((piece) {
                  int col = "abcdefgh".indexOf(piece.square[0]);
                  int row = 8 - int.parse(piece.square[1]);
                  
                  int gridCol = state.isBoardFlipped ? (7 - col) : col;
                  int gridRow = state.isBoardFlipped ? (7 - row) : row;
                  
                  return AnimatedPositioned(
                    key: ValueKey(piece.id),
                    duration: const Duration(milliseconds: 280),
                    curve: Curves.easeInOutCubic,
                    left: gridCol * squareSize,
                    top: gridRow * squareSize,
                    width: squareSize,
                    height: squareSize,
                    child: IgnorePointer(
                      child: Center(
                        child: _buildPiece(piece.type, piece.color, squareSize * 0.82),
                      ),
                    ),
                  );
                }),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildBoardGrid() {
    final state = widget.state;
    return GridView.builder(
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 8,
      ),
      itemCount: 64,
      itemBuilder: (context, index) {
        int gridRow = index ~/ 8;
        int gridCol = index % 8;
        
        int row = state.isBoardFlipped ? (7 - gridRow) : gridRow;
        int col = state.isBoardFlipped ? (7 - gridCol) : gridCol;
        
        String squareName = '${"abcdefgh"[col]}${8 - row}';
        bool isLightSquare = (row + col) % 2 == 0;
        
        Color baseColor = isLightSquare
            ? state.getThemeLightSquareColor()
            : state.getThemeDarkSquareColor();
        
        bool isLastMove = squareName == state.lastMoveFrom || squareName == state.lastMoveTo;
        bool isSelected = squareName == state.selectedSquare;
        bool isLegalDestination = state.legalDestinations.contains(squareName);
        
        Color squareColor = baseColor;
        if (isSelected) {
          squareColor = Color.alphaBlend(
            state.getThemeAccentColor().withOpacity(0.5),
            baseColor,
          );
        } else if (isLastMove) {
          squareColor = Color.alphaBlend(
            state.getThemeAccentColor().withOpacity(0.25),
            baseColor,
          );
        }
        
        var piece = state.game.get(squareName);
        
        Widget cellStack = Stack(
          children: [
            if (isLegalDestination)
              Center(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    double squareSize = constraints.maxWidth;
                    return Container(
                      width: piece != null ? squareSize * 0.8 : squareSize * 0.28,
                      height: piece != null ? squareSize * 0.8 : squareSize * 0.28,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: piece != null
                            ? Border.all(
                                color: state.getThemeAccentColor().withOpacity(0.85),
                                width: 3.5,
                              )
                            : null,
                        color: piece != null
                            ? Colors.transparent
                            : state.getThemeAccentColor().withOpacity(0.85),
                      ),
                    );
                  }
                ),
              ),
              
            if (gridCol == 0)
              Positioned(
                top: 4,
                left: 6,
                child: Text(
                  (8 - row).toString(),
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    color: isLightSquare
                        ? const Color(0x997A5C4A)
                        : const Color(0x99FAF6F0),
                  ),
                ),
              ),
            if (gridRow == 7)
              Positioned(
                bottom: 4,
                right: 6,
                child: Text(
                  "abcdefgh"[col],
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    color: isLightSquare
                        ? const Color(0x997A5C4A)
                        : const Color(0x99FAF6F0),
                  ),
                ),
              ),
          ],
        );

        Widget squareContainer = isLightSquare
            ? Container(
                color: squareColor,
                child: cellStack,
              )
            : StripedSquareWidget(
                baseColor: squareColor,
                stripeColor: AppColors.cream.withOpacity(0.65),
                child: cellStack,
              );

        return GestureDetector(
          onTap: () => widget.onSquareTap(squareName, context),
          behavior: HitTestBehavior.opaque,
          child: squareContainer,
        );
      },
    );
  }

  Widget _buildPiece(chess_pkg.PieceType type, chess_pkg.Color color, double size) {
    final bool isWhite = color == chess_pkg.Color.WHITE;
    switch (type) {
      case chess_pkg.PieceType.PAWN:
        return isWhite ? WhitePawn(size: size) : BlackPawn(size: size);
      case chess_pkg.PieceType.KNIGHT:
        return isWhite ? WhiteKnight(size: size) : BlackKnight(size: size);
      case chess_pkg.PieceType.BISHOP:
        return isWhite ? WhiteBishop(size: size) : BlackBishop(size: size);
      case chess_pkg.PieceType.ROOK:
        return isWhite ? WhiteRook(size: size) : BlackRook(size: size);
      case chess_pkg.PieceType.QUEEN:
        return isWhite ? WhiteQueen(size: size) : BlackQueen(size: size);
      case chess_pkg.PieceType.KING:
        return isWhite ? WhiteKing(size: size) : BlackKing(size: size);
    }
    return const SizedBox.shrink();
  }
}
