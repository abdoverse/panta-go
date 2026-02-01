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
    _locationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("New Pickup Request")),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text("What are we picking up?", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              const SizedBox(height: 12),
              TextFormField(
                controller: _titleController,
                decoration: const InputDecoration(
                  hintText: 'e.g. 2 bags of plastic bottles, Old TV',
                  prefixIcon: Icon(Icons.description_outlined),
                ),
                validator: (v) => v!.isEmpty ? 'Please describe the items' : null,
              ),

              const SizedBox(height: 24),
              const Text("Location", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              const SizedBox(height: 12),
              TypeAheadField<LocationSuggestion>(
                controller: _locationController,
                suggestionsCallback: (pattern) async {
                  return await LocationService().getSuggestions(pattern);
                },
                builder: (context, controller, focusNode) {
                  return TextFormField(
                    controller: controller,
                    focusNode: focusNode,
                    decoration: const InputDecoration(
                      hintText: 'Enter pickup address',
                      prefixIcon: Icon(Icons.location_on_outlined),
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
              const Text("Preferred Time Frame", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              const SizedBox(height: 12),

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

              const SizedBox(height: 40),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _submit,
                  child: const Text("Request Pickup"),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _submit() async {
    if (_formKey.currentState!.validate()) {
      // Show loading indicator or handle state properly

      // Use the full displayName if we have a valid selection object matching the current text.
      // Otherwise allow manual entry (which falls back to controller.text).
      final locationToSend = _selectedLocation != null
          ? _selectedLocation!.displayName
          : _locationController.text;

      final success = await context.read<PantaProvider>().createRequest(
        _titleController.text,
        _fromDate,
        _toDate,
        locationToSend,
      );

      if (!mounted) return;

      if (success) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Request Created!")));
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Failed to create request. Check console for details."),
            backgroundColor: Colors.red,
          )
        );
      }
    }
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
