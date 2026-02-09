import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_typeahead/flutter_typeahead.dart';
import '../../providers/panta_provider.dart';
import '../../core/theme/app_theme.dart';
import '../../services/location_service.dart';
import 'package:intl/intl.dart';

class CreateRequestPage extends StatefulWidget {
  const CreateRequestPage({super.key});

  @override
  State<CreateRequestPage> createState() => _CreateRequestPageState();
}

class _CreateRequestPageState extends State<CreateRequestPage> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _rewardController = TextEditingController();
  final _locationController = TextEditingController();
  LocationSuggestion? _selectedLocation;

  DateTime _fromDate = DateTime.now();
  DateTime _toDate = DateTime.now().add(const Duration(hours: 2));

  @override
  void initState() {
    super.initState();
    _locationController.addListener(_onLocationChanged);
  }

  void _onLocationChanged() {
    if (_selectedLocation != null) {
      // If user types something different than the selected title, invalidate the selection
      // This happens when user edits the text after selection.
      // We check safe access just in case
      if (_locationController.text != _selectedLocation!.title) {
        // We only clear if strictly different.
        // Note: setting text in onSelected will trigger this, so we need to be careful.
        // But in onSelected we set text = title. So they ARE equal.
        // If user subsequently types, they won't be equal.
        setState(() {
          _selectedLocation = null;
        });
      }
    }
  }

  @override
  void dispose() {
    _locationController.removeListener(_onLocationChanged);
    _titleController.dispose();
    _descriptionController.dispose();
    _rewardController.dispose();
    _locationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text("New Pickup Request"),
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Photo Placeholder Area
              Center(
                child: Container(
                  height: 180,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.grey[300]!, style: BorderStyle.dash),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.camera_alt, size: 48, color: Colors.grey[400]),
                      const SizedBox(height: 8),
                      Text("Add a photo", style: TextStyle(color: Colors.grey[600], fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),

              const Text("What are you getting rid of?", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
              const SizedBox(height: 8),
              TextFormField(
                controller: _titleController,
                decoration: InputDecoration(
                  hintText: 'e.g. Old Sofa, Garden Waste',
                  filled: true,
                  fillColor: Colors.grey[50],
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                  prefixIcon: const Icon(Icons.title),
                ),
                validator: (v) => v!.isEmpty ? 'Please enter a title' : null,
              ),

              const SizedBox(height: 16),
              const Text("Description", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              const SizedBox(height: 8),
              TextFormField(
                controller: _descriptionController,
                maxLines: 3,
                decoration: InputDecoration(
                  hintText: 'Any details? (e.g. heavy, 3rd floor, dismantled)',
                  filled: true,
                  fillColor: Colors.grey[50],
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                ),
              ),

              const SizedBox(height: 24),
              const Text("Location", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
              const SizedBox(height: 8),
              TypeAheadField<LocationSuggestion>(
                controller: _locationController,
                suggestionsCallback: (pattern) async {
                  return await LocationService().getSuggestions(pattern);
                },
                builder: (context, controller, focusNode) {
                  return TextFormField(
                    controller: controller,
                    focusNode: focusNode,
                    decoration: InputDecoration(
                      hintText: 'Enter pickup address',
                      prefixIcon: const Icon(Icons.location_on_outlined),
                      filled: true,
                      fillColor: Colors.grey[50],
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                    ),
                    validator: (v) => v!.isEmpty ? 'Please enter location' : null,
                  );
                },
                itemBuilder: (context, suggestion) {
                  return ListTile(
                    leading: const Icon(Icons.location_on_outlined),
                    title: Text(suggestion.title, style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text(suggestion.subtitle, maxLines: 1, overflow: TextOverflow.ellipsis),
                  );
                },
                onSelected: (suggestion) {
                   setState(() {
                     _selectedLocation = suggestion;
                     // Set user-friendly text: "Title, Subtitle" but simplified
                     // User requested "keep the city name" but "shorter"

                     // Construct a short display text
                     String displayText = suggestion.title;
                     if (suggestion.city != null && suggestion.city!.isNotEmpty) {
                        if (!displayText.contains(suggestion.city!)) {
                            displayText = "$displayText, ${suggestion.city}";
                        }
                     } else if (suggestion.subtitle.isNotEmpty) {
                        // Fallback to subtitle if no specific city field found but avoid very long strings
                        // Take the first part of subtitle (often city or area)
                        String firstPart = suggestion.subtitle.split(',')[0];
                        if (!displayText.contains(firstPart)) {
                             displayText = "$displayText, $firstPart";
                        }
                     }

                     _locationController.text = displayText;
                   });
                },
              ),

              const SizedBox(height: 24),
              const Text("When?", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
              const SizedBox(height: 8),

              Row(
                children: [
                  Expanded(
                    child: _DateSelector(
                      label: "From",
                      date: _fromDate,
                      onTap: () async {
                        final date = await showDatePicker(
                          context: context,
                          firstDate: DateTime.now().subtract(const Duration(days: 1)),
                          lastDate: DateTime(2030),
                          initialDate: _fromDate,
                        );
                        if (date != null && context.mounted) {
                          final time = await showTimePicker(
                            context: context,
                            initialTime: TimeOfDay.fromDateTime(_fromDate),
                            builder: (BuildContext context, Widget? child) {
                              return MediaQuery(
                                data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true),
                                child: child!,
                              );
                            },
                          );
                          final newTime = time ?? TimeOfDay.fromDateTime(_fromDate);
                          setState(() => _fromDate = DateTime(
                            date.year,
                            date.month,
                            date.day,
                            newTime.hour,
                            newTime.minute,
                          ));
                        }
                      },
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _DateSelector(
                      label: "To",
                      date: _toDate,
                      onTap: () async {
                        final date = await showDatePicker(
                          context: context,
                          firstDate: DateTime.now().subtract(const Duration(days: 1)),
                          lastDate: DateTime(2030),
                          initialDate: _toDate,
                        );
                        if (date != null && context.mounted) {
                          final time = await showTimePicker(
                            context: context,
                            initialTime: TimeOfDay.fromDateTime(_toDate),
                            builder: (BuildContext context, Widget? child) {
                              return MediaQuery(
                                data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true),
                                child: child!,
                              );
                            },
                          );
                          final newTime = time ?? TimeOfDay.fromDateTime(_toDate);
                          setState(() => _toDate = DateTime(
                            date.year,
                            date.month,
                            date.day,
                            newTime.hour,
                            newTime.minute,
                          ));
                        }
                      },
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 24),
              const Text("Your Price (Reward)", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
              const SizedBox(height: 8),
              TextFormField(
                controller: _rewardController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(
                  hintText: '0.00',
                  prefixIcon: const Padding(padding: EdgeInsets.all(12), child: Text("€", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20))),
                  suffixText: "EUR",
                  filled: true,
                  fillColor: Colors.green.withOpacity(0.05),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                ),
                validator: (v) {
                  if (v == null || v.isEmpty) return 'Please set a price';
                  if (double.tryParse(v) == null) return 'Invalid number';
                  return null;
                },
              ),

              const SizedBox(height: 40),
              SizedBox(
                width: double.infinity,
                height: 56,
                child: Consumer<PantaProvider>(
                  builder: (context, provider, child) {
                    return ElevatedButton(
                      onPressed: provider.isLoading ? null : () async {
                        if (_formKey.currentState!.validate()) {
                          final success = await provider.createRequest(
                            _titleController.text,
                            _fromDate,
                            _toDate,
                            _locationController.text,
                            description: _descriptionController.text,
                            reward: double.tryParse(_rewardController.text) ?? 0.0,
                          );
                          if (success && context.mounted) {
                            Navigator.pop(context);
                            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Request Created!")));
                          }
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primaryGreen,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        elevation: 0,
                      ),
                      child: provider.isLoading
                          ? const CircularProgressIndicator(color: Colors.white)
                          : const Text("Post Request", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    );
                  },
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}

class _DateSelector extends StatelessWidget {
  final String label;
  final DateTime date;
  final VoidCallback onTap;

  const _DateSelector({required this.label, required this.date, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey.withOpacity(0.2)),
          borderRadius: BorderRadius.circular(16),
          color: Colors.white,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: TextStyle(color: Colors.grey[600], fontSize: 12)),
            const SizedBox(height: 4),
            Row(
              children: [
                const Icon(Icons.event, size: 16, color: AppTheme.primaryGreen),
                const SizedBox(width: 8),
                // Force strict patterns like 24:00 usage in display
                Text(DateFormat('MMM dd, HH:mm').format(date), style: const TextStyle(fontWeight: FontWeight.bold)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
