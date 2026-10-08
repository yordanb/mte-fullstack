/// Model Equipment — kontrak equipment.py + client.ts:225-235.
/// Kolom list (EQ_COLS web): cn, unit_type, unit_product, unit_model,
/// engine (merk+model), aktif. Sort server: cn|unit_type|unit_product|
/// unit_model|category|status|aktif|engine.
class Equipment {
  final String cn;
  final String category;
  final String? unitModel;
  final String? unitType;
  final String? unitProduct;
  final String? cnSerialNo;
  final int? cnYear;
  final String? cnLokasi;
  final String? status;
  final String? operasional;
  final String? pumpGroup;
  final String? engineModel;
  final String? engineMerk;
  final String? engineSerialNo;
  final String? arrivedDate;
  final int? arrivedYear;
  final int? arrivedMonth;
  final double? arrivedHm;
  final String? lokasi;
  final String? remark;
  final String? offhire;
  final bool aktif;
  final Map<String, dynamic> specs;

  const Equipment({
    required this.cn,
    required this.category,
    this.unitModel,
    this.unitType,
    this.unitProduct,
    this.cnSerialNo,
    this.cnYear,
    this.cnLokasi,
    this.status,
    this.operasional,
    this.pumpGroup,
    this.engineModel,
    this.engineMerk,
    this.engineSerialNo,
    this.arrivedDate,
    this.arrivedYear,
    this.arrivedMonth,
    this.arrivedHm,
    this.lokasi,
    this.remark,
    this.offhire,
    this.aktif = true,
    this.specs = const {},
  });

  static String? _s(Map<String, dynamic> j, String k) => j[k]?.toString();
  static int? _i(Map<String, dynamic> j, String k) =>
      (j[k] as num?)?.toInt();

  factory Equipment.fromJson(Map<String, dynamic> j) => Equipment(
        cn: '${j['cn'] ?? ''}',
        category: '${j['category'] ?? ''}',
        unitModel: _s(j, 'unit_model'),
        unitType: _s(j, 'unit_type'),
        unitProduct: _s(j, 'unit_product'),
        cnSerialNo: _s(j, 'cn_serial_no'),
        cnYear: _i(j, 'cn_year'),
        cnLokasi: _s(j, 'cn_lokasi'),
        status: _s(j, 'status'),
        operasional: _s(j, 'operasional'),
        pumpGroup: _s(j, 'pump_group'),
        engineModel: _s(j, 'engine_model'),
        engineMerk: _s(j, 'engine_merk'),
        engineSerialNo: _s(j, 'engine_serial_no'),
        arrivedDate: _s(j, 'arrived_date'),
        arrivedYear: _i(j, 'arrived_year'),
        arrivedMonth: _i(j, 'arrived_month'),
        arrivedHm: (j['arrived_hm'] as num?)?.toDouble(),
        lokasi: _s(j, 'lokasi'),
        remark: _s(j, 'remark'),
        offhire: _s(j, 'offhire'),
        aktif: j['aktif'] != false,
        specs: (j['specs'] as Map?)?.cast<String, dynamic>() ?? {},
      );

  /// Sel engine list: merk - model (eqCell web).
  String get engineCell =>
      [engineMerk, engineModel].where((e) => (e ?? '').isNotEmpty).join(' - ');

  /// Tgl Datang detail: date slice(0,10) atau month/year.
  String get arrivedCell {
    if ((arrivedDate ?? '').isNotEmpty) {
      return arrivedDate!.length >= 10 ? arrivedDate!.substring(0, 10) : arrivedDate!;
    }
    final parts = [
      if (arrivedMonth != null) '$arrivedMonth',
      if (arrivedYear != null) '$arrivedYear',
    ];
    return parts.join('/');
  }
}

class EqPageResult {
  final int total;
  final int page;
  final List<Equipment> rows;
  const EqPageResult({required this.total, required this.page, this.rows = const []});
}
