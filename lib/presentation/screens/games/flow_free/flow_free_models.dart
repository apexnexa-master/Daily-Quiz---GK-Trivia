import 'package:flutter/material.dart';

class FlowCell {
  final int row;
  final int col;
  const FlowCell(this.row, this.col);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is FlowCell && row == other.row && col == other.col;

  @override
  int get hashCode => row.hashCode ^ col.hashCode;

  @override
  String toString() => '($row, $col)';
}

class FlowPair {
  final int id;
  final Color color;
  final FlowCell start;
  final FlowCell end;

  const FlowPair({
    required this.id,
    required this.color,
    required this.start,
    required this.end,
  });
}

class FlowLevel {
  final int number;
  final int rows;
  final int cols;
  final List<FlowPair> pairs;
  final List<List<int>> solution; // grid[r][c] = pairId or -1
  final String difficulty; // 'easy', 'medium', 'hard'

  const FlowLevel({
    required this.number,
    required this.rows,
    required this.cols,
    required this.pairs,
    required this.solution,
    required this.difficulty,
  });

  int get totalCells => rows * cols;
  int get pairCount => pairs.length;
}
