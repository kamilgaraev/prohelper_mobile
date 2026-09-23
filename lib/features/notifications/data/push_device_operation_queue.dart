import 'dart:async';

class PushDeviceOperationQueue {
  Future<void> _tail = Future<void>.value();
  bool _authenticated = false;
  int _generation = 0;

  int get generation => _generation;

  bool isCurrent(int generation) => _authenticated && generation == _generation;

  bool isGenerationCurrent(int generation) => generation == _generation;

  int setAuthenticated(bool value) {
    if (_authenticated != value) {
      _authenticated = value;
      _generation++;
    }
    return _generation;
  }

  Future<void> enqueue(Future<void> Function() operation) {
    final result = Completer<void>();
    _tail = _tail.catchError((Object _) {}).then((_) async {
      try {
        await operation();
        result.complete();
      } catch (error, stackTrace) {
        result.completeError(error, stackTrace);
      }
    });
    return result.future;
  }
}
