import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Control de atrasos',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.indigo),
        useMaterial3: true,
      ),
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('es'),
        Locale('en'),
      ],
      home: const AttendancePage(),
    );
  }
}

class AttendancePage extends StatefulWidget {
  const AttendancePage({super.key});

  @override
  State<AttendancePage> createState() => _AttendancePageState();
}

class _AttendancePageState extends State<AttendancePage> {
  static const _storageKey = 'attendance_records_v1';
  static const _entryHour = 9;

  static const List<String> _weekDays = [
    'Lun',
    'Mar',
    'Mié',
    'Jue',
    'Vie',
    'Sáb',
    'Dom',
  ];
  static const List<String> _months = [
    'enero',
    'febrero',
    'marzo',
    'abril',
    'mayo',
    'junio',
    'julio',
    'agosto',
    'septiembre',
    'octubre',
    'noviembre',
    'diciembre',
  ];

  Map<String, int> _records = {};
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadRecords();
  }

  Future<void> _loadRecords() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_storageKey);
    if (raw == null) {
      setState(() => _loading = false);
      return;
    }

    final decoded = jsonDecode(raw);
    if (decoded is! Map<String, dynamic>) {
      setState(() => _loading = false);
      return;
    }

    _records = decoded.map(
      (key, value) => MapEntry(key, (value as num).toInt()),
    );

    setState(() => _loading = false);
  }

  Future<void> _saveRecords() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_storageKey, jsonEncode(_records));
  }

  Future<void> _registerTodayEntry() async {
    final today = DateTime.now();
    await _registerEntryForDate(today);
  }

  Future<void> _registerEntryOtherDay() async {
    final today = DateTime.now();
    final pickedDay = await showDatePicker(
      context: context,
      initialDate: today,
      firstDate: DateTime(today.year - 1),
      lastDate: DateTime(today.year + 1),
      locale: const Locale('es'),
    );

    if (pickedDay == null || !mounted) {
      return;
    }

    await _registerEntryForDate(pickedDay);
  }

  Future<void> _registerEntryForDate(DateTime selectedDay) async {
    if (selectedDay.weekday == DateTime.saturday ||
        selectedDay.weekday == DateTime.sunday) {
      _showMessage('Solo se permiten registros de lunes a viernes.');
      return;
    }

    final dayKey = _dateKey(selectedDay);
    if (_records.containsKey(dayKey)) {
      _showMessage('Ya existe una entrada registrada para este día.');
      return;
    }

    final now = TimeOfDay.now();
    final pickedTime = await showTimePicker(
      context: context,
      initialTime: now,
      helpText: 'Selecciona la hora de marcado',
    );

    if (pickedTime == null) {
      return;
    }

    final pickedMinutes = pickedTime.hour * 60 + pickedTime.minute;
    const entryMinutes = _entryHour * 60;
    final lateMinutes = (pickedMinutes - entryMinutes).clamp(0, 24 * 60);

    setState(() {
      _records[dayKey] = lateMinutes;
    });
    await _saveRecords();

    final message = lateMinutes == 0
        ? 'Registro guardado sin atraso.'
        : 'Registro guardado: ${_formatDuration(lateMinutes)} de atraso.';
    _showMessage(message);
  }

  Future<void> _deleteEntry(String key) async {
    setState(() {
      _records.remove(key);
    });
    await _saveRecords();
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  String _dateKey(DateTime date) {
    final normalized = DateTime(date.year, date.month, date.day);
    return normalized.toIso8601String().split('T').first;
  }

  DateTime _parseDateKey(String key) => DateTime.parse(key);

  String _formatMonthYear(DateTime date) {
    return '${_months[date.month - 1]} ${date.year}';
  }

  String _formatDay(DateTime date) {
    final weekDay = _weekDays[date.weekday - 1];
    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    return '$weekDay $day/$month/${date.year}';
  }

  String _formatDuration(int minutes) {
    final hours = minutes ~/ 60;
    final mins = minutes % 60;
    return '${hours}h ${mins.toString().padLeft(2, '0')}m';
  }

  int _monthlyTotalLateMinutes(DateTime month) {
    return _records.entries
        .where((entry) {
          final date = _parseDateKey(entry.key);
          return date.year == month.year && date.month == month.month;
        })
        .map((entry) => entry.value)
        .fold(0, (sum, item) => sum + item);
  }

  List<MapEntry<String, int>> _sortedCurrentMonthEntries(DateTime month) {
    final entries = _records.entries.where((entry) {
      final date = _parseDateKey(entry.key);
      return date.year == month.year && date.month == month.month;
    }).toList();

    entries.sort((a, b) => b.key.compareTo(a.key));
    return entries;
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final monthEntries = _sortedCurrentMonthEntries(now);
    final monthlyLateMinutes = _monthlyTotalLateMinutes(now);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Control de Atrasos'),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _loading ? null : _registerTodayEntry,
        icon: const Icon(Icons.add_alarm),
        label: const Text('Registrar entrada (hoy)'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Card(
                    child: ListTile(
                      title: Text(
                        'Atraso total (${_formatMonthYear(now)})',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      subtitle: const Text('Hora de ingreso esperada: 09:00'),
                      trailing: Text(
                        _formatDuration(monthlyLateMinutes),
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Registros del mes',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 8),
                  FilledButton.tonalIcon(
                    onPressed: _loading ? null : _registerEntryOtherDay,
                    icon: const Icon(Icons.edit_calendar),
                    label: const Text('Registrar otro día (si olvidé marcar)'),
                  ),
                  const SizedBox(height: 8),
                  Expanded(
                    child: monthEntries.isEmpty
                        ? const Center(
                            child: Text(
                              'No hay registros para este mes.',
                              textAlign: TextAlign.center,
                            ),
                          )
                        : ListView.builder(
                            itemCount: monthEntries.length,
                            itemBuilder: (context, index) {
                              final entry = monthEntries[index];
                              final date = _parseDateKey(entry.key);

                              return Card(
                                child: ListTile(
                                  leading: const Icon(Icons.calendar_today),
                                  title: Text(_formatDay(date)),
                                  subtitle: Text(
                                    entry.value == 0
                                        ? 'Sin atraso'
                                        : 'Atraso: ${_formatDuration(entry.value)}',
                                  ),
                                  trailing: IconButton(
                                    icon: const Icon(Icons.delete_outline),
                                    tooltip: 'Eliminar registro',
                                    onPressed: () => _deleteEntry(entry.key),
                                  ),
                                ),
                              );
                            },
                          ),
                  ),
                ],
              ),
            ),
    );
  }
}
