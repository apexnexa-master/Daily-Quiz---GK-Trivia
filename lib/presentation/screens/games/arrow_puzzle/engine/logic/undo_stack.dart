import 'grid_matrix.dart';

class UndoRecord {
  final String arrowId;
  final double tailX;
  final double tailY;
  final Direction direction;

  UndoRecord({
    required this.arrowId,
    required this.tailX,
    required this.tailY,
    required this.direction,
  });
}

class UndoStack {
  final List<UndoRecord> _stack = [];
  int _freeUndos = 3;

  void push(UndoRecord record) {
    _stack.add(record);
  }

  UndoRecord? pop() {
    if (_stack.isEmpty) return null;
    return _stack.removeLast();
  }

  void clear() {
    _stack.clear();
    _freeUndos = 3;
  }

  bool get canUndo => _stack.isNotEmpty;
  bool get hasFreeUndo => _freeUndos > 0;
  int get freeUndosRemaining => _freeUndos;
  int get stackSize => _stack.length;

  void useFreeUndo() {
    if (_freeUndos > 0) _freeUndos--;
  }
}
