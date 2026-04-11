import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:flutter_typeahead/flutter_typeahead.dart';
import '../../providers/panta_provider.dart';
import '../../core/theme/app_theme.dart';
import '../../services/location_service.dart';
import 'package:intl/intl.dart';
import 'package:dotted_border/dotted_border.dart';
import '../../core/constants/app_constants.dart';

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
  final ImagePicker _imagePicker = ImagePicker();

  DateTime _fromDate = DateTime.now();
  DateTime _toDate = DateTime.now().add(const Duration(hours: 2));
  Uint8List? _selectedPhotoBytes;
  String? _selectedPhotoDataUrl;

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
      appBar: AppBar(
        title: const Text("New Pickup Request"),
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
                child: InkWell(
                  borderRadius: BorderRadius.circular(24),
                  onTap: _pickPhoto,
                  child: DottedBorder(
                    borderType: BorderType.RRect,
                    radius: const Radius.circular(24),
                    color: Colors.grey[400]!,
                    dashPattern: const [8, 4],
                    strokeWidth: 2,
                    child: Container(
                      height: 200,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: AppTheme.surfaceGrey,
                        borderRadius: BorderRadius.circular(24),
                      ),
                      child: _selectedPhotoBytes == null
                          ? Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.add_a_photo_outlined,
                                    size: 48,
                                    color:
                                        AppTheme.primaryGreen.withOpacity(0.5)),
                                const SizedBox(height: 12),
                                Text(
                                  "Add a photo",
                                  style: TextStyle(
                                    color: AppTheme.textSecondary,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  "Tap to choose an image",
                                  style: TextStyle(color: Colors.grey[600]),
                                ),
                              ],
                            )
                          : ClipRRect(
                              borderRadius: BorderRadius.circular(24),
                              child: Stack(
                                fit: StackFit.expand,
                                children: [
                                  Image.memory(
                                    _selectedPhotoBytes!,
                                    fit: BoxFit.cover,
                                  ),
                                  Positioned(
                                    right: 12,
                                    top: 12,
                                    child: DecoratedBox(
                                      decoration: BoxDecoration(
                                        color: Colors.black54,
                                        borderRadius:
                                            BorderRadius.circular(999),
                                      ),
                                      child: IconButton(
                                        onPressed: () {
                                          setState(() {
                                            _selectedPhotoBytes = null;
                                            _selectedPhotoDataUrl = null;
                                          });
                                        },
                                        icon: const Icon(Icons.close,
                                            color: Colors.white),
                                        tooltip: 'Remove photo',
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Center(
                child: OutlinedButton.icon(
                  onPressed: _pickPhoto,
                  icon: const Icon(Icons.photo_library_outlined),
                  label: Text(_selectedPhotoBytes == null
                      ? 'Choose Photo'
                      : 'Change Photo'),
                ),
              ),
              const SizedBox(height: 32),

              Text("What are you getting rid of?",
                  style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 12),
              TextFormField(
                controller: _titleController,
                style: const TextStyle(fontWeight: FontWeight.w600),
                decoration: const InputDecoration(
                  hintText: 'e.g. Old Sofa, Garden Waste',
                  prefixIcon: Icon(Icons.inventory_2_outlined),
                ),
                validator: (v) => v!.isEmpty ? 'Please enter a title' : null,
              ),

              const SizedBox(height: 24),
              Text("Description",
                  style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 12),
              TextFormField(
                controller: _descriptionController,
                maxLines: 3,
                decoration: const InputDecoration(
                  hintText: 'Any details? (e.g. heavy, 3rd floor, dismantled)',
                  alignLabelWithHint: true,
                ),
              ),

              const SizedBox(height: 24),
              Text("Location", style: Theme.of(context).textTheme.titleLarge),
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
                    validator: (v) =>
                        v!.isEmpty ? 'Please enter location' : null,
                  );
                },
                itemBuilder: (context, suggestion) {
                  return ListTile(
                    leading: const Icon(Icons.location_on_outlined),
                    title: Text(suggestion.title,
                        style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text(suggestion.subtitle,
                        maxLines: 1, overflow: TextOverflow.ellipsis),
                  );
                },
                onSelected: (suggestion) {
                  setState(() {
                    _selectedLocation = suggestion;
                    // Set user-friendly text: "Title, Subtitle" but simplified
                    // User requested "keep the city name" but "shorter"

                    // Construct a short display text
                    String displayText = suggestion.title;
                    if (suggestion.city != null &&
                        suggestion.city!.isNotEmpty) {
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
              Text("When?", style: Theme.of(context).textTheme.titleLarge),
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
                          firstDate:
                              DateTime.now().subtract(const Duration(days: 1)),
                          lastDate: DateTime(2030),
                          initialDate: _fromDate,
                        );
                        if (date != null && context.mounted) {
                          final time = await showTimePicker(
                            context: context,
                            initialTime: TimeOfDay.fromDateTime(_fromDate),
                            builder: (BuildContext context, Widget? child) {
                              return MediaQuery(
                                data: MediaQuery.of(context)
                                    .copyWith(alwaysUse24HourFormat: true),
                                child: child!,
                              );
                            },
                          );
                          final newTime =
                              time ?? TimeOfDay.fromDateTime(_fromDate);
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
                          firstDate:
                              DateTime.now().subtract(const Duration(days: 1)),
                          lastDate: DateTime(2030),
                          initialDate: _toDate,
                        );
                        if (date != null && context.mounted) {
                          final time = await showTimePicker(
                            context: context,
                            initialTime: TimeOfDay.fromDateTime(_toDate),
                            builder: (BuildContext context, Widget? child) {
                              return MediaQuery(
                                data: MediaQuery.of(context)
                                    .copyWith(alwaysUse24HourFormat: true),
                                child: child!,
                              );
                            },
                          );
                          final newTime =
                              time ?? TimeOfDay.fromDateTime(_toDate);
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
              Text("Your Price (Reward)",
                  style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 12),
              TextFormField(
                controller: _rewardController,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.primaryGreen),
                decoration: InputDecoration(
                  hintText: '0.00',
                  prefixIcon: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Text(AppConstants.currencySymbol,
                          style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 20,
                              color: AppTheme.primaryGreen))),
                  suffixText: AppConstants.currencyCode,
                  fillColor:
                      AppTheme.primaryGreen.withOpacity(0.05), // Subtle tint
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none),
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
                      onPressed: provider.isLoading
                          ? null
                          : () async {
                              if (_formKey.currentState!.validate()) {
                                final success = await provider.createRequest(
                                  _titleController.text,
                                  _fromDate,
                                  _toDate,
                                  _locationController.text,
                                  description: _descriptionController.text,
                                  reward:
                                      double.tryParse(_rewardController.text) ??
                                          0.0,
                                  imageUrl: _selectedPhotoDataUrl,
                                );
                                if (success && context.mounted) {
                                  Navigator.pop(context);
                                  ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                          content: Text("Request Created!")));
                                }
                              }
                            },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primaryGreen,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16)),
                        elevation: 0,
                      ),
                      child: provider.isLoading
                          ? const CircularProgressIndicator(color: Colors.white)
                          : const Text("Post Request",
                              style: TextStyle(
                                  fontSize: 18, fontWeight: FontWeight.bold)),
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

  Future<void> _pickPhoto() async {
    try {
      final file = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 70,
        maxWidth: 1280,
      );

      if (file == null) return;

      final bytes = await file.readAsBytes();
      final mimeType = _mimeTypeForPath(file.path);

      setState(() {
        _selectedPhotoBytes = bytes;
        _selectedPhotoDataUrl = 'data:$mimeType;base64,${base64Encode(bytes)}';
      });
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not pick the photo.')),
      );
    }
  }

  String _mimeTypeForPath(String path) {
    final normalizedPath = path.toLowerCase();

    if (normalizedPath.endsWith('.png')) {
      return 'image/png';
    }
    if (normalizedPath.endsWith('.webp')) {
      return 'image/webp';
    }
    if (normalizedPath.endsWith('.gif')) {
      return 'image/gif';
    }

    return 'image/jpeg';
  }
}

class _DateSelector extends StatelessWidget {
  final String label;
  final DateTime date;
  final VoidCallback onTap;

  const _DateSelector(
      {required this.label, required this.date, required this.onTap});

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
            Text(label,
                style: TextStyle(color: Colors.grey[600], fontSize: 12)),
            const SizedBox(height: 4),
            Row(
              children: [
                const Icon(Icons.event, size: 16, color: AppTheme.primaryGreen),
                const SizedBox(width: 8),
                // Force strict patterns like 24:00 usage in display
                Text(
                    DateFormat('d MMM, HH:mm', AppConstants.defaultLocaleId)
                        .format(date),
                    style: const TextStyle(fontWeight: FontWeight.bold)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
