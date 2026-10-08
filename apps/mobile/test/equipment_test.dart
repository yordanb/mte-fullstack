import 'package:flutter_test/flutter_test.dart';

import 'package:mte_data_center/src/features/equipment/domain/equipment_models.dart';

void main() {
  test('engineCell menggabung merk - model', () {
    const e = Equipment(cn: 'TL960', category: 'BIGWHEEL', engineMerk: 'CAT', engineModel: '3512');
    expect(e.engineCell, 'CAT - 3512');
    const e2 = Equipment(cn: 'X', category: 'MOBILE', engineModel: 'M');
    expect(e2.engineCell, 'M');
  });

  test('arrivedCell: tanggal penuh atau month/year', () {
    const a = Equipment(cn: 'A', category: 'MOBILE', arrivedDate: '2024-03-15T00:00:00');
    expect(a.arrivedCell, '2024-03-15');
    const b = Equipment(cn: 'B', category: 'MOBILE', arrivedMonth: 3, arrivedYear: 2024);
    expect(b.arrivedCell, '3/2024');
    const c = Equipment(cn: 'C', category: 'MOBILE');
    expect(c.arrivedCell, '');
  });

  test('aktif default true, false bila eksplisit', () {
    expect(Equipment.fromJson({'cn': 'A', 'category': 'M'}).aktif, isTrue);
    expect(
        Equipment.fromJson({'cn': 'A', 'category': 'M', 'aktif': false}).aktif, isFalse);
  });
}
