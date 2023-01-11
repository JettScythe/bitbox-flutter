import 'dart:typed_data';

import 'opcodes.dart';

isValidOutput(Uint8List data) {
  return data.length == 34 && data[0] == Opcodes.OP_0 && data[1] == 0x20;
}
