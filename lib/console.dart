import 'package:flutter/foundation.dart';

void writeLine(String message) {
  if (kDebugMode) {
    debugPrint(message);
  }
}
