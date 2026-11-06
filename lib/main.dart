
import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:hive_flutter/hive_flutter.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Hive.initFlutter();

  const secureStorage = FlutterSecureStorage();
  const encryptionKeyName = 'utility_app_encryption_key';

  String? savedKey = await secureStorage.read(
    key: encryptionKeyName,
  );

  if (savedKey == null) {
    final random = Random.secure();
    final keyBytes = List<int>.generate(
      32,
      (_) => random.nextInt(256),
    );

    savedKey = base64UrlEncode(keyBytes);

    await secureStorage.write(
      key: encryptionKeyName,
      value: savedKey,
    );
  }

  final encryptionKey = Uint8List.fromList(
    base64Url.decode(savedKey),
  );

  await Hive.openBox<String>(
    'utility_entries',
    encryptionCipher: HiveAesCipher(encryptionKey),
  );

  runApp(const UtilityApplication());
}

class UtilityEntry {
  final String id;
  final String title;
  final String description;
  final String type;
  final bool isCompleted;
  final DateTime createdAt;

  const UtilityEntry({
    required this.id,
    required this.title,
    required this.description,
    required this.type,
    required this.isCompleted,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'type': type,
      'isCompleted': isCompleted,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory UtilityEntry.fromMap(Map<String, dynamic> map) {
    return UtilityEntry(
      id: map['id'] as String,
      title: map['title'] as String,
      description: map['description'] as String,
      type: map['type'] as String,
      isCompleted: map['isCompleted'] as bool,
      createdAt: DateTime.parse(map['createdAt'] as String),
    );
  }
}

class UtilityApplication extends StatelessWidget {
  const UtilityApplication({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Cross-Platform Utility Application',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF5364C9),
        ),
        scaffoldBackgroundColor: const Color(0xFFF5F6FA),
      ),
      home: const UtilityHomePage(),
    );
  }
}

class UtilityHomePage extends StatefulWidget {
  const UtilityHomePage({super.key});

  @override
  State<UtilityHomePage> createState() => _UtilityHomePageState();
}

class _UtilityHomePageState extends State<UtilityHomePage> {
  final Box<String> database =
      Hive.box<String>('utility_entries');

  List<UtilityEntry> entries = [];
  String selectedFilter = 'All';

  @override
  void initState() {
    super.initState();
    loadEntries();
  }

  void loadEntries() {
    final loadedEntries = database.values.map((value) {
      final decoded = jsonDecode(value) as Map<String, dynamic>;
      return UtilityEntry.fromMap(decoded);
    }).toList();

    loadedEntries.sort(
      (a, b) => b.createdAt.compareTo(a.createdAt),
    );

    setState(() {
      entries = loadedEntries;
    });
  }

  Future<void> saveEntry(UtilityEntry entry) async {
    await database.put(
      entry.id,
      jsonEncode(entry.toMap()),
    );

    loadEntries();
  }

  Future<void> deleteEntry(UtilityEntry entry) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Entry'),
        content: const Text(
          'Are you sure you want to delete this entry?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await database.delete(entry.id);
      loadEntries();
    }
  }

  Future<void> toggleTask(UtilityEntry entry) async {
    final updatedEntry = UtilityEntry(
      id: entry.id,
      title: entry.title,
      description: entry.description,
      type: entry.type,
      isCompleted: !entry.isCompleted,
      createdAt: entry.createdAt,
    );

    await saveEntry(updatedEntry);
  }

  Future<void> openEditor({UtilityEntry? entry}) async {
    final result = await Navigator.push<UtilityEntry>(
      context,
      MaterialPageRoute(
        builder: (_) => EntryFormPage(entry: entry),
      ),
    );

    if (result != null) {
      await saveEntry(result);
    }
  }

  List<UtilityEntry> get filteredEntries {
    if (selectedFilter == 'Notes') {
      return entries.where((e) => e.type == 'Note').toList();
    }

    if (selectedFilter == 'Tasks') {
      return entries.where((e) => e.type == 'Task').toList();
    }

    return entries;
  }

  @override
  Widget build(BuildContext context) {
    final visibleEntries = filteredEntries;

    final noteCount =
        entries.where((e) => e.type == 'Note').length;

    final taskCount =
        entries.where((e) => e.type == 'Task').length;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Utility Application',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.transparent,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Cross-Platform Utility Application',
                style: TextStyle(
                  fontSize: 21,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Manage your notes and daily tasks in one place.',
                style: TextStyle(
                  color: Colors.grey.shade700,
                ),
              ),
              const SizedBox(height: 18),

              Row(
                children: [
                  Expanded(
                    child: SummaryCard(
                      title: 'Notes',
                      count: noteCount,
                      icon: Icons.description_outlined,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: SummaryCard(
                      title: 'Tasks',
                      count: taskCount,
                      icon: Icons.checklist,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 18),

              Wrap(
                spacing: 8,
                children: ['All', 'Notes', 'Tasks'].map((filter) {
                  return ChoiceChip(
                    label: Text(filter),
                    selected: selectedFilter == filter,
                    onSelected: (_) {
                      setState(() {
                        selectedFilter = filter;
                      });
                    },
                  );
                }).toList(),
              ),

              const SizedBox(height: 12),

              Expanded(
                child: visibleEntries.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.folder_open_outlined,
                              size: 65,
                              color: Colors.indigo.shade200,
                            ),
                            const SizedBox(height: 12),
                            const Text(
                              'No entries available',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 6),
                            const Text(
                              'Use the button below to add an entry.',
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      )
                    : ListView.separated(
                        itemCount: visibleEntries.length,
                        separatorBuilder: (_, _) =>
    const SizedBox(height: 8),
                        itemBuilder: (context, index) {
                          final entry = visibleEntries[index];
                          final isTask = entry.type == 'Task';

                          return Card(
                            color: Colors.white,
                            elevation: 1,
                            child: ListTile(
                              contentPadding:
                                  const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 6,
                              ),
                              leading: isTask
                                  ? Checkbox(
                                      value: entry.isCompleted,
                                      onChanged: (_) {
                                        toggleTask(entry);
                                      },
                                    )
                                  : const CircleAvatar(
                                      child: Icon(
                                        Icons.description_outlined,
                                      ),
                                    ),
                              title: Text(
                                entry.title,
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  decoration: entry.isCompleted
                                      ? TextDecoration.lineThrough
                                      : null,
                                ),
                              ),
                              subtitle: Text(
                                '${entry.type} • ${entry.description}',
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                              onTap: () {
                                openEditor(entry: entry);
                              },
                              trailing: PopupMenuButton<String>(
                                onSelected: (value) {
                                  if (value == 'edit') {
                                    openEditor(entry: entry);
                                  } else if (value == 'delete') {
                                    deleteEntry(entry);
                                  }
                                },
                                itemBuilder: (context) => const [
                                  PopupMenuItem(
                                    value: 'edit',
                                    child: Text('Edit'),
                                  ),
                                  PopupMenuItem(
                                    value: 'delete',
                                    child: Text('Delete'),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => openEditor(),
        icon: const Icon(Icons.add),
        label: const Text('Add Entry'),
      ),
    );
  }
}

class SummaryCard extends StatelessWidget {
  final String title;
  final int count;
  final IconData icon;

  const SummaryCard({
    super.key,
    required this.title,
    required this.count,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Colors.white,
      elevation: 1,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Icon(icon, color: Colors.indigo, size: 28),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    count.toString(),
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class EntryFormPage extends StatefulWidget {
  final UtilityEntry? entry;

  const EntryFormPage({super.key, this.entry});

  @override
  State<EntryFormPage> createState() => _EntryFormPageState();
}

class _EntryFormPageState extends State<EntryFormPage> {
  final formKey = GlobalKey<FormState>();

  late final TextEditingController titleController;
  late final TextEditingController descriptionController;

  late String selectedType;

  @override
  void initState() {
    super.initState();

    titleController = TextEditingController(
      text: widget.entry?.title ?? '',
    );

    descriptionController = TextEditingController(
      text: widget.entry?.description ?? '',
    );

    selectedType = widget.entry?.type ?? 'Note';
  }

  @override
  void dispose() {
    titleController.dispose();
    descriptionController.dispose();
    super.dispose();
  }

  void saveEntry() {
    if (!formKey.currentState!.validate()) return;

    final updatedEntry = UtilityEntry(
      id: widget.entry?.id ??
          DateTime.now().microsecondsSinceEpoch.toString(),
      title: titleController.text.trim(),
      description: descriptionController.text.trim(),
      type: selectedType,
      isCompleted: widget.entry?.isCompleted ?? false,
      createdAt: widget.entry?.createdAt ?? DateTime.now(),
    );

    Navigator.pop(context, updatedEntry);
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.entry != null;

    return Scaffold(
      appBar: AppBar(
        title: Text(isEditing ? 'Edit Entry' : 'Add Entry'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Entry Type',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 8),

              DropdownButtonFormField<String>(
               initialValue: selectedType,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.category_outlined),
                ),
                items: const [
                  DropdownMenuItem(
                    value: 'Note',
                    child: Text('Note'),
                  ),
                  DropdownMenuItem(
                    value: 'Task',
                    child: Text('Task'),
                  ),
                ],
                onChanged: (value) {
                  if (value != null) {
                    setState(() {
                      selectedType = value;
                    });
                  }
                },
              ),

              const SizedBox(height: 20),

              TextFormField(
                controller: titleController,
                decoration: const InputDecoration(
                  labelText: 'Title',
                  hintText: 'Enter title',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.title),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter a title.';
                  }
                  return null;
                },
              ),

              const SizedBox(height: 18),

              TextFormField(
                controller: descriptionController,
                maxLines: 5,
                decoration: const InputDecoration(
                  labelText: 'Description',
                  hintText: 'Enter details here...',
                  border: OutlineInputBorder(),
                  alignLabelWithHint: true,
                ),
              ),

              const SizedBox(height: 24),

              FilledButton.icon(
                onPressed: saveEntry,
                icon: const Icon(Icons.save_outlined),
                label: Text(
                  isEditing ? 'Update Entry' : 'Save Entry',
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
