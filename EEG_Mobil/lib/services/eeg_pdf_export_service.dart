import 'dart:typed_data';

import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../data/sensors.dart';
import '../models/participant.dart';
import '../repositories/eeg_storage_repository.dart';

/// Ham EEG'yi (Reels + Metin) tek PDF olarak üretir.
///
/// Yerel örnekler verilirse internet gerekmez. Aksi halde Storage'dan indirir.
/// Fontlar cihazda üretilir (Google font indirme yok).
class EegPdfExportService {
  EegPdfExportService._();

  static List<String> get _channelIds => sensorIds;
  static const _bandKeys = ['theta', 'alpha', 'beta', 'gamma', 'delta'];

  /// Dosya adı: `{Ad}_{Soyad}_EEG.pdf`
  static String buildFileName({
    required Participant? participant,
    String fallback = 'Denek',
  }) {
    final raw = participant == null
        ? fallback
        : '${participant.firstName} ${participant.lastName}'.trim();
    final name = raw.isEmpty ? fallback : raw;
    final safe = name
        .replaceAll(RegExp(r'[\\/:*?"<>|]'), '')
        .replaceAll(RegExp(r'\s+'), '_')
        .replaceAll(RegExp(r'_+'), '_')
        .replaceAll(RegExp(r'^_|_$'), '');
    return '${safe.isEmpty ? fallback : safe}_EEG.pdf';
  }

  static String resolveJsonPath({
    required String experimentId,
    String? storagePath,
  }) {
    final folder = (storagePath == null || storagePath.isEmpty)
        ? 'eeg/$experimentId'
        : storagePath;
    return folder.endsWith('.json') ? folder : '$folder/eeg.json';
  }

  /// [localSamples] doluysa Storage atlanır (offline / oturum sonu).
  static Future<void> download({
    required EegStorageRepository storage,
    required String experimentId,
    String? storagePath,
    Participant? participant,
    DateTime? experimentDate,
    List<Map<String, dynamic>>? localSamples,
  }) async {
    final samples = await _resolveSamples(
      storage: storage,
      experimentId: experimentId,
      storagePath: storagePath,
      localSamples: localSamples,
    );

    final reels =
        samples.where((s) => _isPhase(s['phase'], reels: true)).toList();
    final text =
        samples.where((s) => _isPhase(s['phase'], reels: false)).toList();

    if (reels.isEmpty && text.isEmpty) {
      throw StateError(
        'Reels/Metin ham ornegi yok (toplam ${samples.length} ornek).',
      );
    }

    final fileName = buildFileName(participant: participant);
    final bytes = await buildPdf(
      reelsSamples: reels,
      textSamples: text,
      participant: participant,
      experimentId: experimentId,
      experimentDate: experimentDate,
    );
    await Printing.sharePdf(bytes: bytes, filename: fileName);
  }

  static Future<List<Map<String, dynamic>>> _resolveSamples({
    required EegStorageRepository storage,
    required String experimentId,
    String? storagePath,
    List<Map<String, dynamic>>? localSamples,
  }) async {
    if (localSamples != null && localSamples.isNotEmpty) {
      return localSamples
          .map((e) => Map<String, dynamic>.from(e))
          .toList(growable: false);
    }

    final jsonPath = resolveJsonPath(
      experimentId: experimentId,
      storagePath: storagePath,
    );

    Map<String, dynamic>? payload;
    try {
      payload = await storage.downloadJson(jsonPath);
    } catch (e) {
      throw StateError(
        'Ham EEG Storage\'dan indirilemedi (internet gerekli): $e',
      );
    }
    if (payload == null) {
      throw StateError(
        'Ham EEG bulunamadi. Internet baglantisini kontrol edin '
        'veya deney bitiminde hemen PDF indirin. ($jsonPath)',
      );
    }

    final rawSamples = payload['samples'];
    if (rawSamples is! List || rawSamples.isEmpty) {
      throw StateError('Ham EEG ornekleri bos: $jsonPath');
    }

    return rawSamples
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList(growable: false);
  }

  static bool _isPhase(dynamic phase, {required bool reels}) {
    final p = '${phase ?? ''}'.toLowerCase().trim();
    if (reels) {
      return p == 'reels' || p == 'reel' || p == 'video';
    }
    return p == 'text' || p == 'metin' || p == 'reading' || p == 'metinler';
  }

  static Future<Uint8List> buildPdf({
    required List<Map<String, dynamic>> reelsSamples,
    required List<Map<String, dynamic>> textSamples,
    Participant? participant,
    required String experimentId,
    DateTime? experimentDate,
  }) async {
    final dateFmt = DateFormat('d MMM yyyy HH:mm', 'tr');
    final name = _ascii(
      participant?.fullName.trim().isNotEmpty == true
          ? participant!.fullName
          : 'Katilimci',
    );
    final when = experimentDate != null ? dateFmt.format(experimentDate) : '-';

    final doc = pw.Document();
    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4.landscape,
        margin: const pw.EdgeInsets.fromLTRB(18, 22, 18, 22),
        maxPages: 500,
        header: (context) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(
              'Ham EEG Verisi (cihaz)',
              style: pw.TextStyle(
                fontSize: 12,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
            pw.Text(
              '$name  |  $when  |  $experimentId',
              style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700),
            ),
            pw.Divider(color: PdfColors.grey400, thickness: 0.4),
            pw.SizedBox(height: 4),
          ],
        ),
        footer: (context) => pw.Align(
          alignment: pw.Alignment.centerRight,
          child: pw.Text(
            'Sayfa ${context.pageNumber} / ${context.pagesCount}',
            style: const pw.TextStyle(fontSize: 7, color: PdfColors.grey600),
          ),
        ),
        build: (context) => [
          ..._phasePages(
            title: '1. Reels — Ham EEG',
            samples: reelsSamples,
          ),
          pw.SizedBox(height: 14),
          ..._phasePages(
            title: '2. Metin — Ham EEG',
            samples: textSamples,
          ),
        ],
      ),
    );

    return doc.save();
  }

  static List<pw.Widget> _phasePages({
    required String title,
    required List<Map<String, dynamic>> samples,
  }) {
    if (samples.isEmpty) {
      return [
        pw.Text(
          title,
          style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold),
        ),
        pw.Text(
          'Bu asamada ham ornek yok.',
          style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700),
        ),
      ];
    }

    final header = _csvHeader();
    final first = samples.first['capturedAt'];
    final last = samples.last['capturedAt'];

    // Bellek dostu: tablo yerine satır satır CSV metni (sayfa sayfa).
    const chunkSize = 45;
    final widgets = <pw.Widget>[
      pw.Text(
        title,
        style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold),
      ),
      pw.Text(
        '${samples.length} ornek  |  ilk: $first  |  son: $last',
        style: const pw.TextStyle(fontSize: 7, color: PdfColors.grey700),
      ),
      pw.SizedBox(height: 4),
      pw.Text(
        'Sutunlar: $header',
        style: const pw.TextStyle(fontSize: 5.5, color: PdfColors.grey800),
      ),
      pw.SizedBox(height: 4),
    ];

    for (var start = 0; start < samples.length; start += chunkSize) {
      final end = (start + chunkSize).clamp(0, samples.length);
      final buf = StringBuffer();
      for (var i = start; i < end; i++) {
        buf.writeln(_csvRow(i + 1, samples[i]));
      }
      widgets.add(
        pw.Padding(
          padding: const pw.EdgeInsets.only(bottom: 6),
          child: pw.Text(
            buf.toString(),
            style: const pw.TextStyle(
              fontSize: 5.2,
              lineSpacing: 1.05,
              color: PdfColors.black,
            ),
          ),
        ),
      );
    }

    return widgets;
  }

  static String _csvHeader() {
    return [
      '#',
      'capturedAt',
      ..._channelIds,
      'signal',
      'quality',
      'battery',
      ..._bandKeys,
      for (final id in _channelIds) 'CQ_$id',
    ].join(';');
  }

  static String _csvRow(int index, Map<String, dynamic> sample) {
    final eeg = _asMap(sample['eeg']);
    final bands = _asMap(sample['bandPower']);
    final cq = _asMap(sample['contactQuality']);
    final cols = <String>[
      '$index',
      '${sample['capturedAt'] ?? ''}',
      for (final id in _channelIds) _num(eeg[id]),
      _num(sample['signal'], d: 4),
      '${sample['overallQuality'] ?? ''}',
      '${sample['batteryPercent'] ?? ''}',
      for (final k in _bandKeys) _num(bands[k], d: 4),
      for (final id in _channelIds) '${cq[id] ?? ''}',
    ];
    return cols.join(';');
  }

  static Map<String, dynamic> _asMap(dynamic v) {
    if (v is Map<String, dynamic>) return v;
    if (v is Map) {
      return v.map((k, val) => MapEntry(k.toString(), val));
    }
    return const {};
  }

  static String _num(dynamic v, {int d = 3}) {
    if (v == null) return '';
    if (v is num) return v.toStringAsFixed(d);
    final parsed = num.tryParse('$v');
    return parsed?.toStringAsFixed(d) ?? '$v';
  }

  /// Helvetica Türkçe karakterleri desteklemez.
  static String _ascii(String input) {
    const map = {
      'ç': 'c',
      'Ç': 'C',
      'ğ': 'g',
      'Ğ': 'G',
      'ı': 'i',
      'İ': 'I',
      'ö': 'o',
      'Ö': 'O',
      'ş': 's',
      'Ş': 'S',
      'ü': 'u',
      'Ü': 'U',
    };
    final buf = StringBuffer();
    for (final ch in input.split('')) {
      buf.write(map[ch] ?? ch);
    }
    return buf.toString();
  }
}
