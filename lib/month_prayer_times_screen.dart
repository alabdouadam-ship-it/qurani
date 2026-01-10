import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:intl/intl.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart' as pwc;
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart';
import 'package:qurani/l10n/app_localizations.dart';
import 'package:qurani/services/prayer_times_service.dart';

enum MonthViewMode { gregorian, hijri }

class MonthPrayerTimesScreen extends StatefulWidget {
  final DateTime baseDate;
  final MonthViewMode mode;
  const MonthPrayerTimesScreen({super.key, required this.baseDate, required this.mode});

  @override
  State<MonthPrayerTimesScreen> createState() => _MonthPrayerTimesScreenState();
}

class _MonthPrayerTimesScreenState extends State<MonthPrayerTimesScreen> {
  Map<String, dynamic>? _monthJson; // full month JSON from cache (gregorian month when mode=gregorian)
  List<Map<String, dynamic>> _rows = const [];
  bool _loading = true;
  bool _needsInternet = false;
  bool _needsService = false;
  bool _needsPermission = false;
  bool _generatingPdf = false;

  @override
  void initState() {
    super.initState();
    // ignore: discarded_futures
    _loadMonth();
  }

  Future<void> _loadMonth() async {
    setState(() {
      _loading = true;
      _needsInternet = false;
      _needsService = false;
      _needsPermission = false;
    });
    final y = widget.baseDate.year;
    final m = widget.baseDate.month;
    try {
      if (widget.mode == MonthViewMode.gregorian) {
        var monthData = await PrayerTimesService.getMonthData(y, m);
        if (monthData == null) {
          final ok = await _ensureFetchGregorianMonth(y, m);
          if (!ok) return;
          monthData = await PrayerTimesService.getMonthData(y, m);
        }
        if (!mounted) return;
        _monthJson = monthData;
        _rows = _buildRowsFromGregorianMonth(_monthJson!);
      } else {
        // Hijri month view: collect days from prev/curr/next gregorian months whose hijri month matches base hijri month
        var baseHijri = await PrayerTimesService.getHijriForDate(year: y, month: m, day: widget.baseDate.day);
        if (baseHijri == null) {
          final ok = await _ensureFetchGregorianMonth(y, m);
          if (!ok) return;
          baseHijri = await PrayerTimesService.getHijriForDate(year: y, month: m, day: widget.baseDate.day);
        }
        final targetMonthNameEn = baseHijri?['monthEn']?.toString() ?? '';
        final targetYear = baseHijri?['year']?.toString() ?? '';
        final prev = DateTime(y, m - 1, 1);
        final curr = DateTime(y, m, 1);
        final next = DateTime(y, m + 1, 1);
        await _ensureFetchGregorianMonth(prev.year, prev.month);
        await _ensureFetchGregorianMonth(curr.year, curr.month);
        await _ensureFetchGregorianMonth(next.year, next.month);
        final parts = <Map<String, dynamic>>[];
        for (final ym in [prev, curr, next]) {
          final data = await PrayerTimesService.getMonthData(ym.year, ym.month);
          final list = (data?['data'] as List?)?.cast<dynamic>() ?? const [];
          for (final dayEntry in list) {
            final hijri = ((dayEntry['date'] as Map)['hijri'] as Map).cast<String, dynamic>();
            final monthMap = (hijri['month'] as Map).cast<String, dynamic>();
            final monthEn = (monthMap['en'] as String?) ?? '';
            final yearStr = (hijri['year'] as String?) ?? '';
            if (monthEn.toLowerCase() == targetMonthNameEn.toLowerCase() && yearStr == targetYear) {
              parts.add(dayEntry as Map<String, dynamic>);
            }
          }
        }
        parts.sort((a, b) {
          final hA = (((a['date'] as Map)['hijri'] as Map)['day'] as String?) ?? '0';
          final hB = (((b['date'] as Map)['hijri'] as Map)['day'] as String?) ?? '0';
          return int.parse(hA).compareTo(int.parse(hB));
        });
        _rows = parts;
      }
      if (!mounted) return;
      setState(() { _loading = false; });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
      });
    }
  }

  Future<bool> _ensureFetchGregorianMonth(int year, int month) async {
    var monthData = await PrayerTimesService.getMonthData(year, month);
    if (monthData != null) return true;
    final hasNet = await _hasInternet();
    if (!hasNet) {
      if (!mounted) return false;
      setState(() { _needsInternet = true; _loading = false; });
      return false;
    }
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      if (!mounted) return false;
      setState(() { _needsService = true; _loading = false; });
      return false;
    }
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) {
      if (!mounted) return false;
      setState(() { _needsPermission = true; _loading = false; });
      return false;
    }
    final pos = await PrayerTimesService.getCurrentPosition();
    final method = await PrayerTimesService.resolveMethodForRegionFromPosition(pos);
    await PrayerTimesService.fetchAndCacheMonth(year: year, month: month, latitude: pos.latitude, longitude: pos.longitude, method: method);
    return true;
  }

  String _hijriMonthLabel(BuildContext context) {
    if (_rows.isEmpty) return '';
    try {
      final first = _rows.first;
      final hijri = ((first['date'] as Map)['hijri'] as Map).cast<String, dynamic>();
      final monthMap = (hijri['month'] as Map).cast<String, dynamic>();
      final isAr = Localizations.localeOf(context).languageCode == 'ar';
      final name = (isAr ? (monthMap['ar'] as String?) : (monthMap['en'] as String?)) ?? '';
      final year = (hijri['year'] as String?) ?? '';
      return '$name $year';
    } catch (_) {
      return '';
    }
  }

  List<Map<String, dynamic>> _buildRowsFromGregorianMonth(Map<String, dynamic> monthJson) {
    final list = (monthJson['data'] as List?)?.cast<dynamic>() ?? const [];
    return list.cast<Map<String, dynamic>>();
  }

  Future<bool> _hasInternet() async {
    try {
      final result = await InternetAddress.lookup('example.com');
      return result.isNotEmpty && result.first.rawAddress.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final localeName = Localizations.localeOf(context).toString();
    final monthLabel = widget.mode == MonthViewMode.gregorian
        ? DateFormat.yMMMM(localeName).format(DateTime(widget.baseDate.year, widget.baseDate.month))
        : _hijriMonthLabel(context);
    return Scaffold(
      appBar: AppBar(
        title: Text('${l10n.prayerTimes} • $monthLabel'),
        actions: [
          if (!kIsWeb)
            _generatingPdf
                ? const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    child: SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2)),
                  )
                : IconButton(
                    tooltip: l10n.share,
                    icon: const Icon(Icons.picture_as_pdf_outlined),
                    onPressed: _sharePdf,
                  ),
        ],
      ),
      body: _buildBody(context, l10n),
    );
  }

  Widget _buildBody(BuildContext context, AppLocalizations l10n) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_needsInternet || _needsService || _needsPermission) {
      final theme = Theme.of(context);
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.info_outline, size: 48, color: theme.colorScheme.primary),
              const SizedBox(height: 12),
              Text(
                _needsInternet
                    ? l10n.prayerInternetGpsRequired
                    : _needsService
                        ? l10n.qiblaLocationDisabled
                        : l10n.qiblaPermissionRequired,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyLarge,
              ),
              const SizedBox(height: 16),
              TextButton(onPressed: _loadMonth, child: Text(l10n.retry)),
            ],
          ),
        ),
      );
    }

    if (_rows.isEmpty) {
      return Center(child: Text(l10n.unknownError));
    }
    // Always include Imsak column for clarity
    // Imsak is always included as a separate column for clarity

    // Second column header: 'Hijri' when viewing Gregorian, 'Gregorian' when viewing Hijri
    String secondHeader = widget.mode == MonthViewMode.gregorian
        ? l10n.hijriHeader
        : l10n.gregorianHeader;

    List<DataColumn> columns = [
      DataColumn(label: Text(l10n.dayColumn)),
      DataColumn(label: Text(secondHeader)),
      DataColumn(label: Text(l10n.fajr)),
      DataColumn(label: Text(l10n.sunrise)),
      DataColumn(label: Text(l10n.dhuhr)),
      DataColumn(label: Text(l10n.asr)),
      DataColumn(label: Text(l10n.maghrib)),
      DataColumn(label: Text(l10n.isha)),
    ];
    // Insert Imsak as third column (after Day and Date)
    columns.insert(2, DataColumn(label: Text(l10n.imsak)));

    String fmt(String? s) {
      if (s == null || s.isEmpty) return '—';
      final hhmm = s.split(' ').first; // drop timezone part if any
      return hhmm;
    }

    final rows = <DataRow>[];
    for (int i = 0; i < _rows.length; i++) {
      final row = _rows[i];
      final timings = ((row['timings'] as Map).cast<String, dynamic>());
      final dateMap = (row['date'] as Map);
      final greg = (dateMap['gregorian'] as Map).cast<String, dynamic>();
      final hijri = (dateMap['hijri'] as Map).cast<String, dynamic>();
      final cells = <DataCell>[];
      if (widget.mode == MonthViewMode.gregorian) {
        // First column: Gregorian day number
        cells.add(DataCell(Text(_toWesternDigits(greg['day'] as String? ?? ''))));
        // Second column: full Hijri date (day month year)
        final hMonth = (hijri['month'] as Map).cast<String, dynamic>();
        final hMonthLabel = ((Localizations.localeOf(context).languageCode == 'ar') ? (hMonth['ar'] as String?) : (hMonth['en'] as String?)) ?? '';
        cells.add(DataCell(Text('${hijri['day'] ?? ''} $hMonthLabel ${hijri['year'] ?? ''}')));
      } else {
        // First column: Hijri day number only
        cells.add(DataCell(Text('${hijri['day'] ?? ''}')));
        // Second column: full Gregorian date (day month year)
        final raw = greg['date'] as String?;
        DateTime? gDate;
        if (raw != null && raw.isNotEmpty) {
          try { gDate = DateFormat('dd-MM-yyyy').parse(raw); } catch (_) { try { gDate = DateFormat('yyyy-MM-dd').parse(raw); } catch (_) {} }
        }
        final localeName = Localizations.localeOf(context).toString();
        final gFull = gDate != null ? DateFormat('dd MMMM yyyy', localeName).format(gDate) : '';
        cells.add(DataCell(Text(_toWesternDigits(gFull))));
      }
      cells.add(DataCell(Text(fmt(timings['Imsak'] as String?))));
      cells.add(DataCell(Text(fmt(timings['Fajr'] as String?))));
      cells.add(DataCell(Text(fmt(timings['Sunrise'] as String?))));
      cells.add(DataCell(Text(fmt(timings['Dhuhr'] as String?))));
      cells.add(DataCell(Text(fmt(timings['Asr'] as String?))));
      cells.add(DataCell(Text(fmt(timings['Maghrib'] as String?))));
      cells.add(DataCell(Text(fmt(timings['Isha'] as String?))));
      rows.add(DataRow(cells: cells));
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
      scrollDirection: Axis.horizontal,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minWidth: 720),
        child: SingleChildScrollView(
          child: Column(
            children: [
              DataTable(columns: columns, rows: rows),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  String _toWesternDigits(String input) {
    final buffer = StringBuffer();
    for (final ch in input.runes) {
      // Arabic-Indic 0-9: U+0660..U+0669
      if (ch >= 0x0660 && ch <= 0x0669) {
        buffer.writeCharCode('0'.codeUnitAt(0) + (ch - 0x0660));
        continue;
      }
      // Extended Arabic-Indic (Persian) 0-9: U+06F0..U+06F9
      if (ch >= 0x06F0 && ch <= 0x06F9) {
        buffer.writeCharCode('0'.codeUnitAt(0) + (ch - 0x06F0));
        continue;
      }
      buffer.writeCharCode(ch);
    }
    return buffer.toString();
  }

  Future<void> _sharePdf() async {
    if (_rows.isEmpty) return;
    final l10n = AppLocalizations.of(context)!;
    final localeName = Localizations.localeOf(context).toString();
    final isGregorian = widget.mode == MonthViewMode.gregorian;
    final titleMonth = isGregorian
        ? DateFormat.yMMMM(localeName).format(DateTime(widget.baseDate.year, widget.baseDate.month))
        : _hijriMonthLabel(context);
    final title = '${l10n.prayerTimes} • $titleMonth';

    final isArabic = Localizations.localeOf(context).languageCode == 'ar';
    // Second column header in PDF: 'Hijri' when Gregorian view, 'Gregorian' when Hijri view
    String secondHeaderPdf = isGregorian ? l10n.hijriHeader : l10n.gregorianHeader;

    List<String> tableHeaders = <String>[
      l10n.dayColumn,
      secondHeaderPdf,
      l10n.fajr,
      l10n.sunrise,
      l10n.dhuhr,
      l10n.asr,
      l10n.maghrib,
      l10n.isha,
    ];

    // Always include Imsak in the exported PDF header
    tableHeaders.insert(2, l10n.imsak);

    List<List<String>> dataRows = [];
    String fmt(String? s) {
      if (s == null || s.isEmpty) return '—';
      return s.split(' ').first;
    }
    for (final row in _rows) {
      final timings = ((row['timings'] as Map).cast<String, dynamic>());
      final dateMap = (row['date'] as Map);
      final greg = (dateMap['gregorian'] as Map).cast<String, dynamic>();
      final hijri = (dateMap['hijri'] as Map).cast<String, dynamic>();
      final cells = <String>[];
      if (isGregorian) {
        // First column: Gregorian day number
        cells.add(_toWesternDigits(greg['day'] as String? ?? ''));
        // Second column: full Hijri date (day month year)
        final hMonth = (hijri['month'] as Map).cast<String, dynamic>();
        final hLabel = (Localizations.localeOf(context).languageCode == 'ar') ? (hMonth['ar'] as String?) : (hMonth['en'] as String?);
        final hijriFull = '${hijri['day'] ?? ''} ${hLabel ?? ''} ${hijri['year'] ?? ''}';
        cells.add(hijriFull);
        cells.add(fmt(timings['Imsak'] as String?));
      } else {
        // First column: Hijri day number
        cells.add(hijri['day'] as String? ?? '');
        // Second column: full Gregorian date (day month year)
        final raw = greg['date'] as String?;
        DateTime? gDate;
        if (raw != null && raw.isNotEmpty) {
          try { gDate = DateFormat('dd-MM-yyyy').parse(raw); } catch (_) { try { gDate = DateFormat('yyyy-MM-dd').parse(raw); } catch (_) {} }
        }
        final gFull = gDate != null ? DateFormat('dd MMMM yyyy', localeName).format(gDate) : '';
        cells.add(_toWesternDigits(gFull));
        cells.add(fmt(timings['Imsak'] as String?));
      }
      cells.add(fmt(timings['Fajr'] as String?));
      cells.add(fmt(timings['Sunrise'] as String?));
      cells.add(fmt(timings['Dhuhr'] as String?));
      cells.add(fmt(timings['Asr'] as String?));
      cells.add(fmt(timings['Maghrib'] as String?));
      cells.add(fmt(timings['Isha'] as String?));
      dataRows.add(cells);
    }

    // Pre-render Arabic text to images (headers and title) to avoid broken shaping
    List<Uint8List?> headerImages = List.filled(tableHeaders.length, null);
    List<Uint8List?> rowFirstImages = const [];
    Uint8List? titleImage;
    if (isArabic) {
      // Render headers
      for (int i = 0; i < tableHeaders.length; i++) {
        final label = tableHeaders[i];
        if (label.isNotEmpty) {
          headerImages[i] = await _rasterizeTextToPng(label, rtl: true, bold: true);
        }
      }
      titleImage = await _rasterizeTextToPng(title, rtl: true, bold: true);
      // Replace headers with placeholders so the PDF builder knows a cell exists
      for (int i = 0; i < tableHeaders.length; i++) {
        if (headerImages[i] != null) tableHeaders[i] = ' ';
      }
    }

    setState(() => _generatingPdf = true);
    try {
      final packageInfo = await PackageInfo.fromPlatform();
      final playLink = 'https://play.google.com/store/apps/details?id=${packageInfo.packageName}';
      final fontData = await rootBundle.load('assets/fonts/AmiriQuran-Regular.ttf');
      final bytes = await compute(_generatePdfBytes, {
        'title': title,
        'headers': tableHeaders,
        'rows': dataRows,
        'isArabic': isArabic,
        'playLink': playLink,
        'font': fontData.buffer.asUint8List(),
        'locale': localeName,
        'headerImages': headerImages,
        'rowFirstImages': rowFirstImages,
        'titleImage': titleImage,
        'singlePage': false,
      });
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/qurani_prayer_times_${DateTime.now().millisecondsSinceEpoch}.pdf');
      await file.writeAsBytes(bytes, flush: true);
      
      // Calculate share position origin for iPad
      if (!mounted) return;
      final box = context.findRenderObject() as RenderBox?;
      
      await Share.shareXFiles(
        [XFile(file.path)],
        text: title,
        subject: title,
        sharePositionOrigin: box!.localToGlobal(Offset.zero) & box.size,
      );
    } catch (_) {
      // ignore share or generation failures silently for now
    } finally {
      if (mounted) setState(() => _generatingPdf = false);
    }
  }
}

Future<Uint8List> _rasterizeTextToPng(String text, {bool rtl = false, bool bold = false}) async {
  final textStyle = TextStyle(
    fontFamily: 'Amiri Quran',
    fontSize: 14,
    fontWeight: bold ? FontWeight.bold : FontWeight.w400,
    color: Colors.black,
  );
  final tp = TextPainter(
    text: TextSpan(text: text, style: textStyle),
    textDirection: rtl ? ui.TextDirection.rtl : ui.TextDirection.ltr,
    textAlign: rtl ? TextAlign.right : TextAlign.left,
    maxLines: 1,
  );
  tp.layout();
  final width = (tp.width + 6).ceil();
  final height = (tp.height + 6).ceil();
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  final bgPaint = Paint()..color = const Color(0x00000000);
  canvas.drawRect(Rect.fromLTWH(0, 0, width.toDouble(), height.toDouble()), bgPaint);
  tp.paint(canvas, const Offset(3, 3));
  final picture = recorder.endRecording();
  final img = await picture.toImage(width, height);
  final byteData = await img.toByteData(format: ui.ImageByteFormat.png);
  return byteData!.buffer.asUint8List();
}

Future<Uint8List> _generatePdfBytes(Map<String, dynamic> args) async {
  final title = args['title'] as String;
  final headers = (args['headers'] as List).cast<String>();
  final rows = (args['rows'] as List).map<List<String>>((e) => (e as List).cast<String>()).toList();
  final isArabic = args['isArabic'] as bool;
  final playLink = args['playLink'] as String;
  final fontBytes = args['font'] as Uint8List;
  final headerImages = (args['headerImages'] as List).cast<Uint8List?>();
  final rowFirstImages = ((args['rowFirstImages'] as List?) ?? const <Uint8List?>[]).cast<Uint8List?>();
  final titleImage = args['titleImage'] as Uint8List?;
  final singlePage = (args['singlePage'] as bool?) ?? false;

  final arabicFont = pw.Font.ttf(fontBytes.buffer.asByteData());
  final doc = pw.Document(
    theme: pw.ThemeData.withFont(
      base: arabicFont,
      bold: arabicFont,
      italic: arabicFont,
      boldItalic: arabicFont,
    ),
  );

  String shapeIfArabic(String s) => s;

  List<pw.Widget> buildTables() {
    const chunkSize = 10;
    final widgets = <pw.Widget>[];
    for (int i = 0; i < rows.length; i += chunkSize) {
      final sub = rows.sublist(i, i + chunkSize > rows.length ? rows.length : i + chunkSize);
      // Build a manual table so we can mix images (for Arabic) and text
      List<String> shapedHeaders = headers.map(shapeIfArabic).toList();
      List<Uint8List?> hdrImgs = headerImages;
      List<List<String>> useRows = sub;
      if (isArabic) {
        shapedHeaders = shapedHeaders.reversed.toList();
        hdrImgs = hdrImgs.reversed.toList();
        useRows = sub.map((r) => r.reversed.toList()).toList();
      }
      final table = pw.Table(
        border: pw.TableBorder.all(width: 0.5, color: const pwc.PdfColor(0.7,0.7,0.7)),
        defaultVerticalAlignment: pw.TableCellVerticalAlignment.middle,
        defaultColumnWidth: const pw.FlexColumnWidth(),
        children: [
          pw.TableRow(
            children: List.generate(shapedHeaders.length, (h) {
              final img = (h < hdrImgs.length) ? hdrImgs[h] : null;
              if (isArabic && img != null) {
                return pw.Padding(padding: const pw.EdgeInsets.all(4), child: pw.Image(pw.MemoryImage(img), height: 14));
              }
              return pw.Padding(padding: const pw.EdgeInsets.all(4), child: pw.Text(shapedHeaders[h], style: pw.TextStyle(fontWeight: pw.FontWeight.bold)));
            }),
          ),
          ...List.generate(useRows.length, (rIdx) {
            final row = useRows[rIdx];
            return pw.TableRow(
              children: List.generate(row.length, (cIdx) {
                return pw.Padding(
                  padding: const pw.EdgeInsets.all(4),
                  child: pw.Text(shapeIfArabic(row[cIdx])),
                );
              }),
            );
          }),
        ],
      );
      widgets.add(table);
      widgets.add(pw.SizedBox(height: 12));
    }
    return widgets;
  }

  final content = <pw.Widget>[
    if (titleImage != null)
      pw.Image(pw.MemoryImage(titleImage), height: 18)
    else
      pw.Text(shapeIfArabic(title), style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
    pw.SizedBox(height: 8),
  ];

  if (singlePage) {
    // Build one compact table
    final compactTable = pw.Table(
      border: pw.TableBorder.all(width: 0.5, color: const pwc.PdfColor(0.7,0.7,0.7)),
      defaultVerticalAlignment: pw.TableCellVerticalAlignment.middle,
      children: [
        pw.TableRow(
          children: List.generate(headers.length, (h) {
            final img = (h < headerImages.length) ? headerImages[h] : null;
            if (isArabic && img != null) {
              return pw.Padding(padding: const pw.EdgeInsets.all(2), child: pw.Image(pw.MemoryImage(img), height: 12));
            }
            return pw.Padding(padding: const pw.EdgeInsets.all(2), child: pw.Text(shapeIfArabic(headers[h]), style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)));
          }),
        ),
        ...List.generate(rows.length, (rIdx) {
          final row = rows[rIdx];
          return pw.TableRow(
            children: List.generate(row.length, (cIdx) {
              final firstImage = (rIdx < rowFirstImages.length) ? rowFirstImages[rIdx] : null;
              if (isArabic && cIdx == 0 && firstImage != null) {
                return pw.Padding(padding: const pw.EdgeInsets.all(2), child: pw.Image(pw.MemoryImage(firstImage), height: 12));
              }
              return pw.Padding(padding: const pw.EdgeInsets.all(2), child: pw.Text(shapeIfArabic(row[cIdx]), style: const pw.TextStyle(fontSize: 9)));
            }),
          );
        }),
      ],
    );
    content.add(compactTable);
    content.add(pw.SizedBox(height: 6));
    content.add(pw.Divider());
    content.add(pw.SizedBox(height: 4));
    content.add(pw.Text('Qurani • $playLink', style: const pw.TextStyle(fontSize: 8)));

    doc.addPage(
      pw.Page(
        pageFormat: pwc.PdfPageFormat.a4.landscape,
        build: (ctx) => isArabic
            ? pw.Directionality(textDirection: pw.TextDirection.rtl, child: pw.Column(children: content))
            : pw.Directionality(textDirection: pw.TextDirection.ltr, child: pw.Column(children: content)),
      ),
    );
  } else {
    final listContent = <pw.Widget>[
      ...content,
      ...buildTables(),
      pw.SizedBox(height: 8),
      pw.Divider(),
      pw.SizedBox(height: 6),
      pw.Text('Qurani • $playLink', style: const pw.TextStyle(fontSize: 10)),
    ];
    doc.addPage(
      pw.MultiPage(
        pageFormat: pwc.PdfPageFormat.a4,
        build: (ctx) => isArabic
            ? [pw.Directionality(textDirection: pw.TextDirection.rtl, child: pw.Column(children: listContent))]
            : [pw.Directionality(textDirection: pw.TextDirection.ltr, child: pw.Column(children: listContent))],
      ),
    );
  }

  return await doc.save();
}


