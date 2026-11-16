import 'package:uuid/uuid.dart';

class UuidHelper {
  static const Uuid _uuid = Uuid();

  /// Generates a time-ordered UUIDv7
  static String newId() {
    return _uuid.v7();
  }
}

