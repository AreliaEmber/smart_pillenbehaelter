import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // Für Clipboard
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';
import 'dart:math';

// --- DATENMODELLE ---

class Medication {
  String id;
  String name;
  String dose;
  String instructions; 
  int stock; 
  int maxStock; 
  List<TimeOfDay> alertTimes;
  List<bool> days; 

  Medication({
    required this.id,
    required this.name,
    required this.dose,
    this.instructions = '',
    this.stock = 0,
    this.maxStock = 20, 
    required this.alertTimes,
    required this.days,
  });
}

class HistoryItem {
  final String medName;
  final String dose;
  final DateTime timestamp;

  HistoryItem(this.medName, this.dose, this.timestamp);
}

class UserProfile {
  String name;
  String age;
  String address;
  String phone;
  String email;

  UserProfile({this.name = '', this.age = '', this.address = '', this.phone = '', this.email = ''});
}

class EmergencyContact {
  String name;
  String phone;
  String address;
  String relation;

  EmergencyContact({this.name = '', this.phone = '', this.address = '', this.relation = ''});
}

// --- APP START ---

void main() {
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  ThemeMode _themeMode = ThemeMode.system;

  void _toggleTheme(bool isDark) {
    setState(() {
      _themeMode = isDark ? ThemeMode.dark : ThemeMode.light;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Pill Guardian',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.teal),
        useMaterial3: true,
      ),
      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.teal,
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),
      themeMode: _themeMode,
      home: MainScreen(onThemeChanged: _toggleTheme, currentThemeMode: _themeMode),
    );
  }
}

// --- HAUPTSCREEN ---

class MainScreen extends StatefulWidget {
  final Function(bool) onThemeChanged;
  final ThemeMode currentThemeMode;

  const MainScreen({
    super.key, 
    required this.onThemeChanged, 
    required this.currentThemeMode
  });

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _currentIndex = 0;
  final TextEditingController _ipController = TextEditingController(text: '192.168.178.50');

  List<Medication> _medications = [];
  List<HistoryItem> _history = [];

  UserProfile _userProfile = UserProfile();
  EmergencyContact _emergencyContact = EmergencyContact();

  void _addMedication(Medication med) {
    setState(() {
      _medications.add(med);
    });
  }

  // Neue Funktion zum Bearbeiten
  void _editMedication(Medication updatedMed) {
    setState(() {
      final index = _medications.indexWhere((m) => m.id == updatedMed.id);
      if (index != -1) {
        _medications[index] = updatedMed;
      }
    });
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Änderungen gespeichert")));
  }

  void _deleteMedication(Medication med) {
    setState(() {
      _medications.removeWhere((m) => m.id == med.id);
    });
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${med.name} gelöscht'),
        action: SnackBarAction(
          label: 'Rückgängig',
          onPressed: () {
            setState(() {
              _medications.add(med);
            });
          },
        ),
      ),
    );
  }

  void _recordIntake(Medication med) {
    setState(() {
      _history.insert(0, HistoryItem(med.name, med.dose, DateTime.now()));
      if (med.stock > 0) {
        med.stock--;
      }
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('${med.name} eingenommen. Noch ${med.stock} übrig.')),
    );
  }

  void _saveProfileData(UserProfile user, EmergencyContact contact) {
    setState(() {
      _userProfile = user;
      _emergencyContact = contact;
    });
  }

  @override
  Widget build(BuildContext context) {
    final List<Widget> pages = [
      DashboardPage(
        userProfile: _userProfile,
        medications: _medications,
        onTake: _recordIntake,
      ),
      MedicationPlanPage(
        medications: _medications,
        onAdd: _addMedication,
        onEdit: _editMedication, 
        onDelete: _deleteMedication,
        onTake: _recordIntake,
        ipController: _ipController,
      ),
      HistoryVisualPage(history: _history), 
      CameraPage(ipController: _ipController),
      SettingsPage(
        onThemeChanged: widget.onThemeChanged, 
        isDarkMode: widget.currentThemeMode == ThemeMode.dark,
        userProfile: _userProfile,
        emergencyContact: _emergencyContact,
        onSaveProfile: _saveProfileData,
        ipController: _ipController, 
      ),
    ];

    return Scaffold(
      body: pages[_currentIndex],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (int index) {
          setState(() {
            _currentIndex = index;
          });
        },
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home), label: 'Heute'),
          NavigationDestination(icon: Icon(Icons.edit_calendar), label: 'Planen'),
          NavigationDestination(icon: Icon(Icons.bar_chart), label: 'Historie'),
          NavigationDestination(icon: Icon(Icons.videocam_outlined), label: 'Kamera'),
          NavigationDestination(icon: Icon(Icons.person_outline), label: 'Profil'),
        ],
      ),
    );
  }
}

// --- SEITE 1: DASHBOARD ---

class DashboardPage extends StatelessWidget {
  final UserProfile userProfile;
  final List<Medication> medications;
  final Function(Medication) onTake;

  const DashboardPage({
    super.key,
    required this.userProfile,
    required this.medications,
    required this.onTake,
  });

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final int todayIndex = now.weekday - 1; 
    
    final List<Map<String, dynamic>> tasksToday = [];
    
    for (var med in medications) {
      if (med.days[todayIndex]) {
        for (var time in med.alertTimes) {
          tasksToday.add({
            'time': time,
            'med': med,
            'sortVal': time.hour * 60 + time.minute
          });
        }
      }
    }

    tasksToday.sort((a, b) => (a['sortVal'] as int).compareTo(b['sortVal'] as int));

    return Scaffold(
      appBar: AppBar(
        title: const Text("Übersicht"),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Hallo, ${userProfile.name.isNotEmpty ? userProfile.name : 'Nutzer'}!", 
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold)
                ),
                Text(
                  "Hier ist dein Plan für heute:",
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: Colors.grey[600]),
                ),
              ],
            ),
          ),
          
          Expanded(
            child: tasksToday.isEmpty 
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.check_circle_outline, size: 80, color: Colors.green.withOpacity(0.5)),
                      const SizedBox(height: 16),
                      const Text("Für heute nichts geplant!", style: TextStyle(fontSize: 18)),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: tasksToday.length,
                  itemBuilder: (context, index) {
                    final task = tasksToday[index];
                    final Medication med = task['med'];
                    final TimeOfDay time = task['time'];
                    final isPast = (time.hour < now.hour) || (time.hour == now.hour && time.minute < now.minute);

                    return Card(
                      color: isPast ? Colors.grey[100] : null,
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: isPast ? Colors.grey : Theme.of(context).colorScheme.primary,
                          foregroundColor: Colors.white,
                          child: Text("${time.hour}:${time.minute.toString().padLeft(2, '0')}", style: const TextStyle(fontSize: 12)),
                        ),
                        title: Text(med.name, style: TextStyle(decoration: isPast ? TextDecoration.lineThrough : null)),
                        subtitle: Text(med.dose),
                        trailing: IconButton(
                          icon: const Icon(Icons.check_circle_outline, size: 32),
                          color: Colors.green,
                          onPressed: () => onTake(med),
                        ),
                      ),
                    );
                  },
                ),
          ),
        ],
      ),
    );
  }
}

// --- SEITE 2: PLAN VERWALTEN (MIT EDIT & EXPORT) ---

class MedicationPlanPage extends StatefulWidget {
  final List<Medication> medications;
  final Function(Medication) onAdd;
  final Function(Medication) onEdit; 
  final Function(Medication) onDelete;
  final Function(Medication) onTake;
  final TextEditingController ipController;

  const MedicationPlanPage({
    super.key, 
    required this.medications, 
    required this.onAdd,
    required this.onEdit,
    required this.onDelete,
    required this.onTake,
    required this.ipController,
  });

  @override
  State<MedicationPlanPage> createState() => _MedicationPlanPageState();
}

class _MedicationPlanPageState extends State<MedicationPlanPage> {
  bool _isSyncing = false;

  Future<void> _syncToEsp() async {
    if (widget.medications.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Keine Medikamente im Plan.")));
      return;
    }
    setState(() => _isSyncing = true);
    final ip = widget.ipController.text;
    final firstMed = widget.medications.first;
    if (firstMed.alertTimes.isEmpty) return;
    final nextTime = firstMed.alertTimes.first; 

    try {
      final data = {
        'hour': nextTime.hour,
        'minute': nextTime.minute,
        'days': firstMed.days,
        'task': 'pill_reminder',
      };
      await http.post(
        Uri.parse('http://$ip/set_schedule'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(data),
      ).timeout(const Duration(seconds: 5));

      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("An ESP gesendet!"), backgroundColor: Colors.green));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Fehler: $e"), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => _isSyncing = false);
    }
  }

  void _showExportDialog() {
    final sb = StringBuffer();
    sb.writeln("📋 MEIN MEDIKAMENTENPLAN");
    sb.writeln("========================");
    sb.writeln("Stand: ${DateTime.now().day}.${DateTime.now().month}.${DateTime.now().year}\n");
    
    for (var med in widget.medications) {
      sb.writeln("💊 ${med.name} (${med.dose})");
      
      List<String> days = [];
      List<String> wNames = ["Mo", "Di", "Mi", "Do", "Fr", "Sa", "So"];
      for(int i=0; i<7; i++) { if(med.days[i]) days.add(wNames[i]); }
      
      String dayStr = days.length == 7 ? "Täglich" : days.join(", ");
      
      sb.writeln("   🗓 $dayStr");
      sb.writeln("   ⏰ ${med.alertTimes.map((t) => "${t.hour}:${t.minute.toString().padLeft(2,'0')}").join(", ")}");
      if(med.instructions.isNotEmpty) sb.writeln("   ℹ️ Info: ${med.instructions}");
      sb.writeln("------------------------");
    }

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Plan exportieren"),
        content: SingleChildScrollView(
          child: Column(
            children: [
              const Text("Plan in die Zwischenablage kopieren:"),
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: Colors.grey[100], borderRadius: BorderRadius.circular(8)),
                child: SelectableText(sb.toString(), style: const TextStyle(fontFamily: 'monospace', fontSize: 12)),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Schließen")),
          FilledButton.icon(
            onPressed: () {
              Clipboard.setData(ClipboardData(text: sb.toString()));
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Plan kopiert!")));
            }, 
            icon: const Icon(Icons.copy),
            label: const Text("Kopieren"),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Alle Medikamente'),
        actions: [
          IconButton(
            icon: const Icon(Icons.share),
            onPressed: _showExportDialog,
            tooltip: "Plan teilen/drucken",
          ),
          IconButton(
            icon: _isSyncing 
              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)) 
              : const Icon(Icons.wifi_tethering),
            onPressed: _syncToEsp,
            tooltip: "Daten an ESP senden",
          )
        ],
      ),
      body: widget.medications.isEmpty 
        ? const Center(child: Text("Liste ist leer. Füge Medikamente hinzu."))
        : ListView.builder(
            itemCount: widget.medications.length,
            itemBuilder: (context, index) {
              final med = widget.medications[index];
              final double stockPercent = (med.stock / med.maxStock).clamp(0.0, 1.0);
              
              return Card(
                child: Column(
                  children: [
                    ListTile(
                      leading: const Icon(Icons.medication),
                      title: Text(med.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: Text("${med.dose}\n${med.stock} Stück übrig"),
                      isThreeLine: true,
                      // Hier ist der Edit Button
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.edit, color: Colors.blue),
                            onPressed: () {
                              // Dialog im Edit-Modus öffnen
                              showDialog(
                                context: context, 
                                builder: (ctx) => AddMedicationDialog(
                                  onAdd: widget.onAdd, 
                                  onEdit: widget.onEdit,
                                  medication: med, // Vorhandenes übergeben
                                )
                              );
                            },
                            tooltip: "Bearbeiten",
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete_outline, color: Colors.red),
                            onPressed: () => widget.onDelete(med),
                            tooltip: "Löschen",
                          ),
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                      child: LinearProgressIndicator(
                        value: stockPercent,
                        color: stockPercent < 0.2 ? Colors.red : Colors.green,
                        backgroundColor: Colors.grey[200],
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          if (widget.medications.length >= 12) {
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
              content: Text("Maximal 12 Medikamente erlaubt!"),
              backgroundColor: Colors.orange,
            ));
          } else {
            showDialog(context: context, builder: (ctx) => AddMedicationDialog(onAdd: widget.onAdd, onEdit: widget.onEdit));
          }
        },
        child: const Icon(Icons.add),
      ),
    );
  }
}

// --- SEITE 3: HISTORIE ---

class HistoryVisualPage extends StatelessWidget {
  final List<HistoryItem> history;

  const HistoryVisualPage({super.key, required this.history});

  Map<String, List<HistoryItem>> _groupByMedication() {
    final Map<String, List<HistoryItem>> grouped = {};
    for (var item in history) {
      if (!grouped.containsKey(item.medName)) {
        grouped[item.medName] = [];
      }
      grouped[item.medName]!.add(item);
    }
    return grouped;
  }

  @override
  Widget build(BuildContext context) {
    final groupedData = _groupByMedication();

    return Scaffold(
      appBar: AppBar(title: const Text("Einnahme-Historie")),
      body: history.isEmpty
          ? const Center(child: Text("Keine Daten verfügbar"))
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                const Text("Wochenübersicht", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                const SizedBox(height: 10),
                ...groupedData.entries.map((entry) {
                  return Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(entry.key, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                              Text("${entry.value.length}x gesamt", style: const TextStyle(color: Colors.grey)),
                            ],
                          ),
                          const SizedBox(height: 20),
                          SizedBox(
                            height: 120,
                            child: WeeklyChart(
                              intakeDates: entry.value.map((e) => e.timestamp).toList(),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }),
                const Divider(height: 40),
                const Text("Letzte Buchungen", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                ...history.take(5).map((item) => ListTile(
                  dense: true,
                  leading: const Icon(Icons.history),
                  title: Text(item.medName),
                  subtitle: Text("${item.timestamp.day}.${item.timestamp.month}. ${item.timestamp.hour}:${item.timestamp.minute.toString().padLeft(2, '0')} Uhr"),
                  trailing: Text(item.dose),
                ))
              ],
            ),
    );
  }
}

// Chart Widget
class WeeklyChart extends StatelessWidget {
  final List<DateTime> intakeDates;

  const WeeklyChart({super.key, required this.intakeDates});

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    List<DateTime> last7Days = [];
    for (int i = 6; i >= 0; i--) {
      last7Days.add(today.subtract(Duration(days: i)));
    }

    List<int> counts = [];
    int maxCount = 1; 

    for (var day in last7Days) {
      int count = intakeDates.where((date) {
        return date.year == day.year && date.month == day.month && date.day == day.day;
      }).length;
      counts.add(count);
      if (count > maxCount) maxCount = count;
    }

    final weekDays = ['Mo', 'Di', 'Mi', 'Do', 'Fr', 'Sa', 'So'];

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: List.generate(7, (index) {
        final count = counts[index];
        final double barHeightFactor = count / maxCount;

        return Column(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            Container(
              width: 12,
              height: 80 * barHeightFactor + (count > 0 ? 4 : 0), 
              decoration: BoxDecoration(
                color: count > 0 ? Colors.teal : Colors.grey.withOpacity(0.2),
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              weekDays[last7Days[index].weekday - 1], 
              style: const TextStyle(fontSize: 12)
            ),
          ],
        );
      }),
    );
  }
}

// Dialog: Kann jetzt Add und Edit
class AddMedicationDialog extends StatefulWidget {
  final Function(Medication) onAdd;
  final Function(Medication)? onEdit; // Optional
  final Medication? medication; // Wenn gesetzt -> Edit Mode

  const AddMedicationDialog({
    super.key, 
    required this.onAdd, 
    this.onEdit,
    this.medication,
  });

  @override
  State<AddMedicationDialog> createState() => _AddMedicationDialogState();
}

class _AddMedicationDialogState extends State<AddMedicationDialog> {
  late TextEditingController _nameController;
  late TextEditingController _doseController;
  late TextEditingController _stockController;
  late TextEditingController _notesController;
  
  List<TimeOfDay> _times = [];
  List<bool> _days = List.generate(7, (_) => true);
  final List<String> _weekDays = ["Mo", "Di", "Mi", "Do", "Fr", "Sa", "So"];

  @override
  void initState() {
    super.initState();
    // Vorhandene Daten laden oder Standardwerte
    if (widget.medication != null) {
      final m = widget.medication!;
      _nameController = TextEditingController(text: m.name);
      _doseController = TextEditingController(text: m.dose);
      _stockController = TextEditingController(text: m.stock.toString());
      _notesController = TextEditingController(text: m.instructions);
      _times = List.from(m.alertTimes);
      _days = List.from(m.days);
    } else {
      _nameController = TextEditingController();
      _doseController = TextEditingController();
      _stockController = TextEditingController(text: "20");
      _notesController = TextEditingController();
      _times = [const TimeOfDay(hour: 8, minute: 0)];
    }
  }

  void _addTime() async {
    final t = await showTimePicker(context: context, initialTime: const TimeOfDay(hour: 12, minute: 0));
    if (t != null) setState(() => _times.add(t));
  }

  bool get _isValid => _nameController.text.isNotEmpty;
  bool get _isEditMode => widget.medication != null;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(_isEditMode ? "Medikament bearbeiten" : "Neues Medikament"),
      scrollable: true,
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: _nameController, 
            decoration: const InputDecoration(labelText: "Name (z.B. Aspirin)", prefixIcon: Icon(Icons.edit)),
            onChanged: (_) => setState((){}),
          ),
          TextField(controller: _doseController, decoration: const InputDecoration(labelText: "Dosis (z.B. 500mg)", prefixIcon: Icon(Icons.numbers))),
          
          const SizedBox(height: 16),
          const Text("Einnahmetage:", style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: List.generate(7, (index) {
                return Padding(
                  padding: const EdgeInsets.only(right: 4.0),
                  child: FilterChip(
                    label: Text(_weekDays[index]),
                    selected: _days[index],
                    onSelected: (bool selected) {
                      setState(() {
                        _days[index] = selected;
                      });
                    },
                    showCheckmark: false,
                    selectedColor: Theme.of(context).colorScheme.primaryContainer,
                  ),
                );
              }),
            ),
          ),

          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(child: TextField(controller: _stockController, decoration: const InputDecoration(labelText: "Vorrat", prefixIcon: Icon(Icons.inventory_2)), keyboardType: TextInputType.number)),
            ],
          ),
          
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text("Uhrzeiten:", style: TextStyle(fontWeight: FontWeight.bold)),
              TextButton.icon(onPressed: _addTime, icon: const Icon(Icons.add), label: const Text("Zeit hinzufügen")),
            ],
          ),
          Wrap(
            spacing: 8,
            children: _times.map((t) => Chip(
              label: Text(t.format(context)), 
              deleteIcon: const Icon(Icons.close, size: 16),
              onDeleted: () => setState(() => _times.remove(t))
            )).toList(),
          ),
          
          const SizedBox(height: 8),
          TextField(controller: _notesController, decoration: const InputDecoration(labelText: "Hinweise (optional)", prefixIcon: Icon(Icons.info_outline))),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text("Abbrechen")),
        FilledButton(
          onPressed: _isValid ? () {
            final stock = int.tryParse(_stockController.text) ?? 20;
            final med = Medication(
              id: widget.medication?.id ?? DateTime.now().toString(), // ID behalten bei Edit
              name: _nameController.text,
              dose: _doseController.text,
              stock: stock,
              maxStock: _isEditMode ? widget.medication!.maxStock : stock, // MaxStock behalten
              instructions: _notesController.text,
              alertTimes: List.from(_times),
              days: List.from(_days),
            );
            
            if (_isEditMode && widget.onEdit != null) {
              widget.onEdit!(med);
            } else {
              widget.onAdd(med);
            }
            
            Navigator.pop(context);
          } : null,
          child: Text(_isEditMode ? "Speichern" : "Erstellen")
        ),
      ],
    );
  }
}

// --- KAMERA ---
class CameraPage extends StatefulWidget {
  final TextEditingController ipController;
  const CameraPage({super.key, required this.ipController});

  @override
  State<CameraPage> createState() => _CameraPageState();
}

class _CameraPageState extends State<CameraPage> {
  bool _isStreaming = false;
  Timer? _timer;
  int _imageKey = 0;

  void _startStream() {
    setState(() => _isStreaming = true);
    _timer = Timer.periodic(const Duration(milliseconds: 500), (timer) {
      if (mounted) setState(() => _imageKey++);
    });
  }

  void _stopStream() {
    _timer?.cancel();
    setState(() => _isStreaming = false);
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final String snapshotUrl = 'http://${widget.ipController.text}/capture?t=$_imageKey';
    return Scaffold(
      appBar: AppBar(title: const Text('Überwachung')),
      body: Center(
        child: _isStreaming 
          ? Image.network(
              snapshotUrl, 
              gaplessPlayback: true, 
              fit: BoxFit.contain, 
              errorBuilder: (c,e,s) => const Text("Keine Verbindung"),
            )
          : FilledButton.icon(onPressed: _startStream, icon: const Icon(Icons.play_arrow), label: const Text("Kamera starten")),
      ),
    );
  }
}

// --- EINSTELLUNGEN ---
class SettingsPage extends StatefulWidget {
  final Function(bool) onThemeChanged;
  final bool isDarkMode;
  final UserProfile userProfile;
  final EmergencyContact emergencyContact;
  final Function(UserProfile, EmergencyContact) onSaveProfile;
  final TextEditingController ipController;

  const SettingsPage({
    super.key, 
    required this.onThemeChanged,
    required this.isDarkMode,
    required this.userProfile,
    required this.emergencyContact,
    required this.onSaveProfile,
    required this.ipController,
  });

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  late TextEditingController _nameCtrl;
  late TextEditingController _ageCtrl;
  late TextEditingController _addrCtrl;
  late TextEditingController _phoneCtrl;
  late TextEditingController _emailCtrl;
  late TextEditingController _eNameCtrl;
  late TextEditingController _ePhoneCtrl;
  late TextEditingController _eAddrCtrl;
  late TextEditingController _eRelCtrl;
  bool _isScanning = false;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.userProfile.name);
    _ageCtrl = TextEditingController(text: widget.userProfile.age);
    _addrCtrl = TextEditingController(text: widget.userProfile.address);
    _phoneCtrl = TextEditingController(text: widget.userProfile.phone);
    _emailCtrl = TextEditingController(text: widget.userProfile.email);
    _eNameCtrl = TextEditingController(text: widget.emergencyContact.name);
    _ePhoneCtrl = TextEditingController(text: widget.emergencyContact.phone);
    _eAddrCtrl = TextEditingController(text: widget.emergencyContact.address);
    _eRelCtrl = TextEditingController(text: widget.emergencyContact.relation);
  }

  void _saveAll() {
    widget.onSaveProfile(
      UserProfile(name: _nameCtrl.text, age: _ageCtrl.text, address: _addrCtrl.text, phone: _phoneCtrl.text, email: _emailCtrl.text),
      EmergencyContact(name: _eNameCtrl.text, phone: _ePhoneCtrl.text, address: _eAddrCtrl.text, relation: _eRelCtrl.text)
    );
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Profil gespeichert!")));
  }

  Future<void> _testConnection() async {
    final ip = widget.ipController.text;
    if (ip.isEmpty) return;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Verbinde..."), duration: Duration(milliseconds: 500)));
    try {
      // Ping /off da Root oft nicht definiert ist beim ESP
      final response = await http.get(Uri.parse('http://$ip/off')).timeout(const Duration(seconds: 2));
      if (mounted) {
        if (response.statusCode == 200) {
           ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("✅ ESP32 verbunden!"), backgroundColor: Colors.green));
        } else {
           ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("⚠️ Antwortet mit Code ${response.statusCode}"), backgroundColor: Colors.orange));
        }
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("❌ Keine Verbindung (Timeout/Error)"), backgroundColor: Colors.red));
    }
  }

  Future<void> _toggleLed(bool state) async {
    final ip = widget.ipController.text;
    if (ip.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Bitte IP eingeben")));
        return;
    }
    final cmd = state ? "on" : "off";
    try {
      await http.get(Uri.parse('http://$ip/$cmd')).timeout(const Duration(seconds: 2));
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("LED $cmd gesendet"), duration: const Duration(milliseconds: 500)));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Fehler beim Senden"), backgroundColor: Colors.red));
    }
  }

  Future<void> _scanNetwork() async {
    setState(() => _isScanning = true);
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Scanne Netzwerk (ca. 10s)...")));
    final parts = widget.ipController.text.split('.');
    if (parts.length != 4) {
      setState(() => _isScanning = false); 
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Ungültige Basis-IP")));
      return;
    }
    final prefix = "${parts[0]}.${parts[1]}.${parts[2]}";
    String? foundIp;
    final List<Future> checks = [];
    
    // Scan range 1-254
    for (int i = 1; i < 255; i++) {
      final ip = "$prefix.$i";
      // Parallel requests to /off
      checks.add(
        http.get(Uri.parse('http://$ip/off'))
            .timeout(const Duration(milliseconds: 500))
            .then((r) { 
              if(r.statusCode==200 && foundIp==null) foundIp = ip; 
            })
            .catchError((_){})
      );
    }
    await Future.wait(checks);
    
    if (mounted) {
      if (foundIp != null) {
        widget.ipController.text = foundIp!;
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Gefunden: $foundIp"), backgroundColor: Colors.green));
      } else {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Kein ESP gefunden."), backgroundColor: Colors.orange));
      }
      setState(() => _isScanning = false);
    }
  }

  Widget _buildSectionHeader(String title, IconData icon, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 4),
      child: Row(
        children: [
          Icon(icon, color: color),
          const SizedBox(width: 8),
          Text(title, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: color)),
        ],
      ),
    );
  }

  Widget _buildTextField(TextEditingController ctrl, String label, IconData icon, {TextInputType type = TextInputType.text}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: TextField(
        controller: ctrl,
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon, size: 20),
          border: const OutlineInputBorder(),
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        ),
        keyboardType: type,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Profil & Einstellungen'), actions: [IconButton(onPressed: _saveAll, icon: const Icon(Icons.save))]),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // SEKTION 1: VERBINDUNG
          Card(
            surfaceTintColor: Theme.of(context).colorScheme.primary,
            child: ExpansionTile(
              title: const Text("ESP32 Verbindung"),
              leading: const Icon(Icons.wifi),
              initiallyExpanded: true, 
              children: [
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: widget.ipController,
                              decoration: const InputDecoration(hintText: "z.B. 192.168.178.50", labelText: "IP-Adresse", border: OutlineInputBorder()),
                              keyboardType: TextInputType.numberWithOptions(decimal: true),
                            ),
                          ),
                          const SizedBox(width: 8),
                          IconButton.filledTonal(onPressed: _testConnection, icon: const Icon(Icons.check), tooltip: "Verbindung prüfen"),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: FilledButton.icon(
                              onPressed: () => _toggleLed(true), 
                              icon: const Icon(Icons.lightbulb), 
                              label: const Text("LED AN"),
                              style: FilledButton.styleFrom(backgroundColor: Colors.amber.shade700),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: FilledButton.icon(
                              onPressed: () => _toggleLed(false), 
                              icon: const Icon(Icons.lightbulb_outline), 
                              label: const Text("LED AUS"),
                              style: FilledButton.styleFrom(backgroundColor: Colors.grey.shade700),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: _isScanning ? null : _scanNetwork,
                          icon: _isScanning 
                            ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)) 
                            : const Icon(Icons.radar),
                          label: Text(_isScanning ? "Suche läuft..." : "Automatisch im WLAN suchen"),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 20),

          // SEKTION 2: PERSÖNLICHE DATEN
          _buildSectionHeader("Persönliche Daten", Icons.person, Theme.of(context).colorScheme.primary),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  _buildTextField(_nameCtrl, "Name", Icons.badge),
                  Row(
                    children: [
                      Expanded(child: _buildTextField(_ageCtrl, "Alter", Icons.cake, type: TextInputType.number)),
                      const SizedBox(width: 12),
                      Expanded(flex: 2, child: _buildTextField(_phoneCtrl, "Telefon", Icons.phone, type: TextInputType.phone)),
                    ],
                  ),
                  _buildTextField(_addrCtrl, "Adresse", Icons.home),
                  _buildTextField(_emailCtrl, "E-Mail", Icons.email, type: TextInputType.emailAddress),
                ],
              ),
            ),
          ),

          const SizedBox(height: 10),

          // SEKTION 3: NOTFALLKONTAKT
          _buildSectionHeader("Notfallkontakt", Icons.emergency, Colors.red),
          Card(
            color: Theme.of(context).colorScheme.errorContainer.withOpacity(0.3),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  _buildTextField(_eNameCtrl, "Name des Kontakts", Icons.person_add),
                  _buildTextField(_eRelCtrl, "Beziehung (z.B. Sohn)", Icons.people),
                  _buildTextField(_ePhoneCtrl, "Notruf-Nummer", Icons.phone, type: TextInputType.phone),
                  _buildTextField(_eAddrCtrl, "Adresse des Kontakts", Icons.location_on),
                ],
              ),
            ),
          ),

          const Divider(height: 40),
          
          ListTile(
            leading: const Icon(Icons.dark_mode),
            title: const Text('Dunkelmodus'),
            trailing: Switch(value: widget.isDarkMode, onChanged: widget.onThemeChanged),
          ),
          const SizedBox(height: 40),
          FilledButton.icon(onPressed: _saveAll, icon: const Icon(Icons.save), label: const Text("Alle Daten speichern")),
        ],
      ),
    );
  }
}
