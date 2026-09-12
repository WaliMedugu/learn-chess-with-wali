import 'dart:math';
import 'package:chess/chess.dart' as chess_pkg;

// Piece-Square Tables (from White's perspective)
// Flipped vertically for Black when querying
const List<List<int>> pawnTable = [
  [0,  0,  0,  0,  0,  0,  0,  0],
  [50, 50, 50, 50, 50, 50, 50, 50],
  [10, 10, 20, 30, 30, 20, 10, 10],
  [5,  5, 10, 25, 25, 10,  5,  5],
  [0,  0,  0, 20, 20,  0,  0,  0],
  [5, -5,-10,  0,  0,-10, -5,  5],
  [5, 10, 10,-20,-20, 10, 10,  5],
  [0,  0,  0,  0,  0,  0,  0,  0]
];

const List<List<int>> knightTable = [
  [-50,-40,-30,-30,-30,-30,-40,-50],
  [-40,-20,  0,  0,  0,  0,-20,-40],
  [-30,  0, 10, 15, 15, 10,  0,-30],
  [-30,  5, 15, 20, 20, 15,  5,-30],
  [-30,  0, 15, 20, 20, 15,  0,-30],
  [-30,  5, 10, 15, 15, 10,  5,-30],
  [-40,-20,  0,  5,  5,  0,-20,-40],
  [-50,-40,-30,-30,-30,-30,-40,-50]
];

const List<List<int>> bishopTable = [
  [-20,-10,-10,-10,-10,-10,-10,-20],
  [-10,  0,  0,  0,  0,  0,  0,-10],
  [-10,  0,  5, 10, 10,  5,  0,-10],
  [-10,  5,  5, 10, 10,  5,  5,-10],
  [-10,  0, 10, 10, 10, 10,  0,-10],
  [-10, 10, 10, 10, 10, 10, 10,-10],
  [-10,  5,  0,  0,  0,  0,  5,-10],
  [-20,-10,-10,-10,-10,-10,-10,-20]
];

const List<List<int>> rookTable = [
  [0,  0,  0,  0,  0,  0,  0,  0],
  [5, 10, 10, 10, 10, 10, 10,  5],
  [-5,  0,  0,  0,  0,  0,  0, -5],
  [-5,  0,  0,  0,  0,  0,  0, -5],
  [-5,  0,  0,  0,  0,  0,  0, -5],
  [-5,  0,  0,  0,  0,  0,  0, -5],
  [-5,  0,  0,  0,  0,  0,  0, -5],
  [0,  0,  0,  5,  5,  0,  0,  0]
];

const List<List<int>> queenTable = [
  [-20,-10,-10, -5, -5,-10,-10,-20],
  [-10,  0,  0,  0,  0,  0,  0,-10],
  [-10,  0,  5,  5,  5,  5,  0,-10],
  [-5,  0,  5,  5,  5,  5,  0, -5],
  [0,  0,  5,  5,  5,  5,  0, -5],
  [-10,  5,  5,  5,  5,  5,  0,-10],
  [-10,  0,  5,  0,  0,  5,  0,-10],
  [-20,-10,-10, -5, -5,-10,-10,-20]
];

const List<List<int>> kingMiddleGameTable = [
  [-30,-40,-40,-50,-50,-40,-40,-30],
  [-30,-40,-40,-50,-50,-40,-40,-30],
  [-30,-40,-40,-50,-50,-40,-40,-30],
  [-30,-40,-40,-50,-50,-40,-40,-30],
  [-20,-30,-30,-40,-40,-30,-30,-20],
  [-10,-20,-20,-20,-20,-20,-20,-10],
  [20, 20,  0,  0,  0,  0, 20, 20],
  [20, 30, 10,  0,  0, 10, 30, 20]
];

int getPieceSquareValue(chess_pkg.PieceType type, chess_pkg.Color color, int row, int col) {
  int r = (color == chess_pkg.Color.WHITE) ? row : (7 - row);
  if (type == chess_pkg.PieceType.PAWN) return pawnTable[r][col];
  if (type == chess_pkg.PieceType.KNIGHT) return knightTable[r][col];
  if (type == chess_pkg.PieceType.BISHOP) return bishopTable[r][col];
  if (type == chess_pkg.PieceType.ROOK) return rookTable[r][col];
  if (type == chess_pkg.PieceType.QUEEN) return queenTable[r][col];
  if (type == chess_pkg.PieceType.KING) return kingMiddleGameTable[r][col];
  return 0;
}

int evaluateBoard(chess_pkg.Chess game) {
  int totalEvaluation = 0;
  
  // Iterate through all 64 squares
  for (int row = 0; row < 8; row++) {
    for (int col = 0; col < 8; col++) {
      String square = '${"abcdefgh"[col]}${8 - row}';
      var piece = game.get(square);
      if (piece != null) {
        int value = 0;
        if (piece.type == chess_pkg.PieceType.PAWN) {
          value = 100;
        } else if (piece.type == chess_pkg.PieceType.KNIGHT) {
          value = 320;
        } else if (piece.type == chess_pkg.PieceType.BISHOP) {
          value = 330;
        } else if (piece.type == chess_pkg.PieceType.ROOK) {
          value = 500;
        } else if (piece.type == chess_pkg.PieceType.QUEEN) {
          value = 900;
        } else if (piece.type == chess_pkg.PieceType.KING) {
          value = 20000;
        }
        
        int pst = getPieceSquareValue(piece.type, piece.color, row, col);
        int pieceVal = value + pst;
        
        if (piece.color == chess_pkg.Color.WHITE) {
          totalEvaluation += pieceVal;
        } else {
          totalEvaluation -= pieceVal;
        }
      }
    }
  }
  
  return totalEvaluation;
}

class ChessAI {
  // Finds the best move for the active turn in the game
  // difficulty: 0 = Easy (depth 1), 1 = Medium (depth 2), 2 = Hard (depth 3)
  static Map<String, dynamic>? getBestMove(chess_pkg.Chess game, int difficulty) {
    int depth = 1;
    double mistakeChance = 0.0;

    switch (difficulty) {
      case 0: // beginner (600)
        depth = 1;
        mistakeChance = 0.40;
        break;
      case 1: // strong beginner (900)
        depth = 1;
        mistakeChance = 0.15;
        break;
      case 2: // intermediate (1200)
        depth = 2;
        mistakeChance = 0.25;
        break;
      case 3: // strong intermediate (1500)
        depth = 2;
        mistakeChance = 0.0;
        break;
      case 4: // advanced (1800)
        depth = 3;
        mistakeChance = 0.20;
        break;
      case 5: // strong advanced (2100)
        depth = 3;
        mistakeChance = 0.05;
        break;
      case 6: // expert (2400)
        depth = 3;
        mistakeChance = 0.0;
        break;
      case 7: // Prof. Solomon (2700)
        depth = 4;
        mistakeChance = 0.0;
        break;
      default:
        depth = 2;
        mistakeChance = 0.0;
    }

    var moves = game.moves({'verbose': true});
    if (moves.isEmpty) return null;

    // Check mistake chance to simulate a human error
    if (Random().nextDouble() < mistakeChance) {
      moves.shuffle(Random());
      return moves.first;
    }

    // Shuffle to avoid deterministic moves when evaluations are identical
    moves.shuffle(Random());
    
    // Sort moves to speed up alpha-beta pruning (captures and promotions first)
    moves.sort((a, b) {
      int scoreA = 0;
      int scoreB = 0;
      if (a['captured'] != null) scoreA += 10;
      if (b['captured'] != null) scoreB += 10;
      if (a['promotion'] != null) scoreA += 5;
      if (b['promotion'] != null) scoreB += 5;
      return scoreB.compareTo(scoreA);
    });
    
    Map<String, dynamic>? bestMove;
    int bestValue = (game.turn == chess_pkg.Color.WHITE) ? -999999 : 999999;
    
    int alpha = -999999;
    int beta = 999999;
    
    for (var move in moves) {
      game.move(move);
      int boardValue = _minimax(game, depth - 1, alpha, beta, game.turn == chess_pkg.Color.WHITE);
      game.undo();
      
      if (game.turn == chess_pkg.Color.WHITE) {
        if (boardValue > bestValue) {
          bestValue = boardValue;
          bestMove = Map<String, dynamic>.from(move);
        }
        alpha = max(alpha, boardValue);
      } else {
        if (boardValue < bestValue) {
          bestValue = boardValue;
          bestMove = Map<String, dynamic>.from(move);
        }
        beta = min(beta, boardValue);
      }
    }
    
    return bestMove;
  }
  
  static int _minimax(chess_pkg.Chess game, int depth, int alpha, int beta, bool isMaximizingPlayer) {
    if (depth == 0 || game.game_over) {
      return evaluateBoard(game);
    }
    
    var moves = game.moves({'verbose': true});
    
    // Sort moves
    moves.sort((a, b) {
      int scoreA = 0;
      int scoreB = 0;
      if (a['captured'] != null) scoreA += 10;
      if (b['captured'] != null) scoreB += 10;
      if (a['promotion'] != null) scoreA += 5;
      if (b['promotion'] != null) scoreB += 5;
      return scoreB.compareTo(scoreA);
    });
    
    if (isMaximizingPlayer) {
      int maxEval = -999999;
      for (var move in moves) {
        game.move(move);
        int eval = _minimax(game, depth - 1, alpha, beta, false);
        game.undo();
        maxEval = max(maxEval, eval);
        alpha = max(alpha, eval);
        if (beta <= alpha) break;
      }
      return maxEval;
    } else {
      int minEval = 999999;
      for (var move in moves) {
        game.move(move);
        int eval = _minimax(game, depth - 1, alpha, beta, true);
        game.undo();
        minEval = min(minEval, eval);
        beta = min(beta, eval);
        if (beta <= alpha) break;
      }
      return minEval;
    }
  }
}
