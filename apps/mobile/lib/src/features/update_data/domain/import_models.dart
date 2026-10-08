/// Model Update Data — kontrak imports.py:upload_excel + dbr.py:upload_dbr.
/// Dry-run oli: {total, ok, fail, errors[50], preview}.
/// Commit (202): {import_id, status}. Polling: {status, total_rows,
/// processed_rows, ok_rows, fail_rows}.
class DryRunError {
  final int row;
  final String error;
  const DryRunError({required this.row, required this.error});

  factory DryRunError.fromJson(Map<String, dynamic> j) => DryRunError(
        row: (j['row'] as num?)?.toInt() ?? 0,
        error: '${j['error'] ?? ''}',
      );
}

class DryRunPreview {
  final String labNo;
  final String vesselId;
  final String unitId;
  final String sampleDate;
  final String condition;
  const DryRunPreview({
    required this.labNo,
    required this.vesselId,
    required this.unitId,
    required this.sampleDate,
    required this.condition,
  });

  factory DryRunPreview.fromJson(Map<String, dynamic> j) => DryRunPreview(
        labNo: '${j['lab_no'] ?? ''}',
        vesselId: '${j['vesselid'] ?? ''}',
        unitId: '${j['unit_id'] ?? ''}',
        sampleDate: '${j['sample_date'] ?? ''}',
        condition: '${j['condition'] ?? ''}',
      );
}

class DryRunResult {
  final int total;
  final int ok;
  final int fail;
  final List<DryRunError> errors;
  final List<DryRunPreview> preview;
  const DryRunResult({
    required this.total,
    required this.ok,
    required this.fail,
    this.errors = const [],
    this.preview = const [],
  });

  factory DryRunResult.fromJson(Map<String, dynamic> j) => DryRunResult(
        total: (j['total'] as num?)?.toInt() ?? 0,
        ok: (j['ok'] as num?)?.toInt() ?? 0,
        fail: (j['fail'] as num?)?.toInt() ?? 0,
        errors: ((j['errors'] as List? ?? [])
            .map((e) => DryRunError.fromJson((e as Map).cast<String, dynamic>()))
            .toList()),
        preview: ((j['preview'] as List? ?? [])
            .map((e) => DryRunPreview.fromJson((e as Map).cast<String, dynamic>()))
            .toList()),
      );
}

class ImportProgress {
  final String id;
  final String filename;
  final String status; // PROCESSING | COMMITTED | FAILED
  final int totalRows;
  final int processedRows;
  final int okRows;
  final int failRows;

  const ImportProgress({
    required this.id,
    required this.filename,
    required this.status,
    required this.totalRows,
    required this.processedRows,
    required this.okRows,
    required this.failRows,
  });

  factory ImportProgress.fromJson(Map<String, dynamic> j) => ImportProgress(
        id: '${j['id'] ?? ''}',
        filename: '${j['filename'] ?? ''}',
        status: '${j['status'] ?? ''}',
        totalRows: (j['total_rows'] as num?)?.toInt() ?? 0,
        processedRows: (j['processed_rows'] as num?)?.toInt() ?? 0,
        okRows: (j['ok_rows'] as num?)?.toInt() ?? 0,
        failRows: (j['fail_rows'] as num?)?.toInt() ?? 0,
      );
}
