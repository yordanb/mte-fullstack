/// Model FUI — kontrak fui.py + client.ts:276-302.
/// OilRow: baris oli lebar (SUG_COLS fui.py:103-112) untuk tabel dossier
/// dan suggestion. Nilai disimpan string apa adanya (ND/desimal diurus server).
class OilRow {
  final String labNo;
  final String vesselId;
  final String unitId;
  final String? model;
  final String? sampleDate;
  final String? dateTaken;
  final String? leadTime;
  final String? oilWeight;
  final String? unitTime;
  final String? unitTimeOils;
  final String? condition;
  final String? englishDescription;
  final String? unitType;
  final String? unitProduct;
  final Map<String, String> vals;
  final Map<String, String> grades;

  const OilRow({
    required this.labNo,
    required this.vesselId,
    required this.unitId,
    this.model,
    this.sampleDate,
    this.dateTaken,
    this.leadTime,
    this.oilWeight,
    this.unitTime,
    this.unitTimeOils,
    this.condition,
    this.englishDescription,
    this.unitType,
    this.unitProduct,
    this.vals = const {},
    this.grades = const {},
  });

  /// Urutan kolom parameter tabel (VesselTable web).
  static const params = [
    'visc', 'fuel', 'soot', 'oxi', 'nitr', 'water', 'tbn',
    'si', 'fe', 'cu', 'al', 'cr', 'pb', 'na',
  ];
  static const paramLabels = [
    'VISC', 'FUEL', 'SOOT', 'OXI', 'NITR', 'WTR', 'TBN',
    'Si', 'Fe', 'Cu', 'Al', 'Cr', 'Pb', 'Na',
  ];

  bool badGrade(String p) {
    final g = grades[p];
    return g != null && g.isNotEmpty && g != 'N';
  }

  factory OilRow.fromJson(Map<String, dynamic> j) {
    final vals = <String, String>{};
    final grades = <String, String>{};
    for (final p in params) {
      if (j[p] != null) vals[p] = '${j[p]}';
      final g = j['grade_$p'];
      if (g != null) grades[p] = '$g';
    }
    return OilRow(
      labNo: '${j['lab_no'] ?? ''}',
      vesselId: '${j['vesselid'] ?? ''}',
      unitId: '${j['unit_id'] ?? ''}',
      model: j['model']?.toString(),
      sampleDate: j['sample_date']?.toString(),
      dateTaken: j['date_taken']?.toString(),
      leadTime: j['lead_time']?.toString(),
      oilWeight: j['oil_weight']?.toString() ?? j['oil_type']?.toString(),
      unitTime: j['unit_time']?.toString(),
      unitTimeOils: j['unit_time_oils']?.toString(),
      condition: j['condition']?.toString(),
      englishDescription: j['english_description']?.toString(),
      unitType: j['unit_type']?.toString(),
      unitProduct: j['unit_product']?.toString(),
      vals: vals,
      grades: grades,
    );
  }
}

class Suggest {
  final String id;
  final String suggestion;
  final String? pic;
  final String? createdBy;
  final String? createdAt;

  const Suggest({
    required this.id,
    required this.suggestion,
    this.pic,
    this.createdBy,
    this.createdAt,
  });

  factory Suggest.fromJson(Map<String, dynamic> j) => Suggest(
        id: '${j['id']}',
        suggestion: '${j['suggestion'] ?? ''}',
        pic: j['pic']?.toString(),
        createdBy: j['created_by']?.toString(),
        createdAt: j['created_at']?.toString(),
      );
}

class SuggestReportRow {
  final String labNo;
  final String vesselId;
  final String unitId;
  final String sampleDate;
  final String? unitTime;
  final String condition;
  final String? unitType;
  final String? unitProduct;
  final int suggestCount;
  final String? latestSuggestion;
  final String? latestPic;
  final String? latestBy;
  final String? latestAt;

  const SuggestReportRow({
    required this.labNo,
    required this.vesselId,
    required this.unitId,
    required this.sampleDate,
    this.unitTime,
    required this.condition,
    this.unitType,
    this.unitProduct,
    this.suggestCount = 0,
    this.latestSuggestion,
    this.latestPic,
    this.latestBy,
    this.latestAt,
  });

  factory SuggestReportRow.fromJson(Map<String, dynamic> j) {
    var date = '${j['sample_date'] ?? ''}';
    if (date.length >= 10) date = date.substring(0, 10);
    return SuggestReportRow(
      labNo: '${j['lab_no'] ?? ''}',
      vesselId: '${j['vesselid'] ?? ''}',
      unitId: '${j['unit_id'] ?? ''}',
      sampleDate: date,
      unitTime: j['unit_time']?.toString(),
      condition: '${j['condition'] ?? ''}',
      unitType: j['unit_type']?.toString(),
      unitProduct: j['unit_product']?.toString(),
      suggestCount: (j['suggest_count'] as num?)?.toInt() ?? 0,
      latestSuggestion: j['latest_suggestion']?.toString(),
      latestPic: j['latest_pic']?.toString(),
      latestBy: j['latest_by']?.toString(),
      latestAt: j['latest_at']?.toString(),
    );
  }

  String get typeProduct =>
      [unitType, unitProduct].where((e) => (e ?? '').isNotEmpty).join(' / ');
}

class SuggestReportPageResult {
  final int total;
  final int page;
  final List<SuggestReportRow> rows;
  const SuggestReportPageResult({required this.total, required this.page, this.rows = const []});
}

/// Kelompok suggestion per vessel/unit (grouping konsekutif, SugFuiPage).
class SuggestGroup {
  final String key;
  final List<OilRow> rows;
  const SuggestGroup(this.key, this.rows);
}

List<SuggestGroup> groupSuggestions(List<OilRow> rows) {
  final groups = <SuggestGroup>[];
  for (final row in rows) {
    final key = '${row.vesselId} / ${row.unitId}';
    if (groups.isNotEmpty && groups.last.key == key) {
      groups.last.rows.add(row);
    } else {
      groups.add(SuggestGroup(key, [row]));
    }
  }
  return groups;
}
