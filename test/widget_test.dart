import 'package:flutter_test/flutter_test.dart';

import 'package:recorder_app/api/esp32_api.dart';
import 'package:recorder_app/data/huruf.dart';

void main() {
  test('take paths match the firmware naming convention', () {
    final take = Take(
      take: 3,
      done: true,
      bytes: const [0, 0, 0, 0],
      responden: 2,
      huruf: 5,
      variasi: 1,
    );
    expect(take.basePath, '/RSPDN2/HRF5/VRS1/RSPDN2_HRF5_VRS1_3');
    expect(take.micPath(4), '/RSPDN2/HRF5/VRS1/RSPDN2_HRF5_VRS1_3_MIC4.wav');
  });

  test('there are exactly 28 huruf and indices line up', () {
    expect(hurufList.length, 28);
    for (var i = 0; i < hurufList.length; i++) {
      expect(hurufList[i].index, i + 1);
    }
    expect(hurufByIndex(6).glyph, 'ح');
    expect(hurufByIndex(27).glyph, 'ه');
  });
}
