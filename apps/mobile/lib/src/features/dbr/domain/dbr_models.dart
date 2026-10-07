/// Model DBR — kontrak apps/api/app/api/v1/dbr.py:97-134 + client.ts:183-190.
/// Kolom tampil (DBR_COLS web Pages.tsx:247-254): date, cn, section,
/// trouble, code, hm_start, loc, start_breakdown, action, mechanic, gl.
class DbrRow {
  final int id;
  final String date; // YYYY-MM-DD
  final String cn;
  final String? section;
  final String? trouble;
  final String? code;
  final String? hmStart;
  final String? loc;
  final String? startBreakdown;
  final String? action;
  final String? mechanic;
  final String? gl;

  const DbrRow({
    required this.id,
    required this.date,
    required this.cn,
    this.section,
    this.trouble,
    this.code,
    this.hmStart,
    this.loc,
    this.startBreakdown,
    this.action,
    this.mechanic,
    this.gl,
  });

  static String? _s(Map<String, dynamic> j, String k) => j[k]?.toString();

  factory DbrRow.fromJson(Map<String, dynamic> j) {
    var date = '${j['date'] ?? ''}';
    if (date.length >= 10) date = date.substring(0, 10);
    return DbrRow(
      id: (j['id'] as num?)?.toInt() ?? 0,
      date: date,
      cn: '${j['cn'] ?? ''}',
      section: _s(j, 'section'),
      trouble: _s(j, 'trouble'),
      code: _s(j, 'code'),
      hmStart: _s(j, 'hm_start'),
      loc: _s(j, 'loc'),
      startBreakdown: _s(j, 'start_breakdown'),
      action: _s(j, 'action'),
      mechanic: _s(j, 'mechanic'),
      gl: _s(j, 'gl'),
    );
  }

  bool get isContinue => (action ?? '').toUpperCase() == 'CONTINUE';
}

class DbrPageResult {
  final int total;
  final int page;
  final List<DbrRow> rows;
  const DbrPageResult({required this.total, required this.page, this.rows = const []});
}
