import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:flutter_typeahead/flutter_typeahead.dart';
import '../../core/localization/app_localizations.dart';
import '../../providers/panta_provider.dart';
import '../../core/theme/app_theme.dart';
import '../../services/location_service.dart';
import 'package:intl/intl.dart';
import 'package:dotted_border/dotted_border.dart';
import '../../core/constants/app_constants.dart';
import '../../models/request_model.dart';

class CreateRequestPage extends StatefulWidget {
  const CreateRequestPage({
    super.key,
    this.initialRequest,
    this.startInQuickMode = false,
  });

  final RecyclingRequest? initialRequest;
  final bool startInQuickMode;

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
  String? _selectedPhotoMimeType;
  String? _selectedPhotoFileName;
  bool _saveAsAddress = false;
  bool _saveAsTemplate = false;
  late bool _isQuickMode = widget.startInQuickMode;
  bool _didInitializeQuickDefaults = false;
  double _splitPercentage = 70.0;

  @override
  void initState() {
    super.initState();
    _locationController.addListener(_onLocationChanged);
    _applyInitialRequest();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_didInitializeQuickDefaults) {
      return;
    }
    _didInitializeQuickDefaults = true;
    if (_isQuickMode) {
      _applyQuickDefaults(context.read<PantaProvider>());
    }
  }

  void _applyInitialRequest() {
    final initialRequest = widget.initialRequest;
    if (initialRequest == null) return;
    final now = DateTime.now();
    final requestWindow =
        initialRequest.scheduledTo.difference(initialRequest.scheduledFrom);
    final fallbackFrom = now.add(const Duration(hours: 1));
    final fallbackTo = fallbackFrom.add(
      requestWindow.isNegative || requestWindow == Duration.zero
          ? const Duration(hours: 2)
          : requestWindow,
    );

    _titleController.text = initialRequest.title;
    _descriptionController.text = initialRequest.description;
    _rewardController.text = _formatReward(initialRequest.reward ?? 0);
    _splitPercentage = initialRequest.splitPercentage;
    _locationController.text = initialRequest.location;
    if (initialRequest.locationLatitude != null &&
        initialRequest.locationLongitude != null) {
      _selectedLocation = LocationSuggestion(
        displayName: initialRequest.location,
        title: initialRequest.location,
        subtitle: '',
        lat: initialRequest.locationLatitude!,
        lon: initialRequest.locationLongitude!,
      );
    }
    _fromDate = initialRequest.scheduledFrom.isAfter(now)
        ? initialRequest.scheduledFrom
        : fallbackFrom;
    _toDate = initialRequest.scheduledTo.isAfter(_fromDate)
        ? initialRequest.scheduledTo
        : fallbackTo;
  }

  String _formatReward(double reward) {
    return reward == reward.roundToDouble()
        ? reward.toStringAsFixed(0)
        : reward.toStringAsFixed(2);
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
    final l10n = context.l10n;
    final provider = context.watch<PantaProvider>();
    final canShowQuickSummary = _isQuickMode;
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.newPickupRequest),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (canShowQuickSummary) ...[
                _QuickRequestSummaryCard(
                  title: _titleController.text,
                  location: _locationController.text,
                  fromDate: _fromDate,
                  toDate: _toDate,
                  rewardText: _rewardController.text,
                  onEditPressed: () {
                    setState(() {
                      _isQuickMode = false;
                    });
                  },
                ),
                const SizedBox(height: 24),
              ],
              if (widget.initialRequest != null) ...[
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryGreen.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.history_toggle_off,
                          color: AppTheme.primaryGreen),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Booking again from your request history. Update any details before posting.',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
              ],
              if (!_isQuickMode) ...[
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
                                      color: AppTheme.primaryGreen
                                          .withValues(alpha: 0.5)),
                                  const SizedBox(height: 12),
                                  Text(
                                    l10n.addPhoto,
                                    style: TextStyle(
                                      color: AppTheme.textSecondary,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    l10n.tapToChooseImage,
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
                                              _selectedPhotoMimeType = null;
                                              _selectedPhotoFileName = null;
                                            });
                                          },
                                          icon: const Icon(Icons.close,
                                              color: Colors.white),
                                          tooltip: l10n.removePhoto,
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
                        ? l10n.choosePhoto
                        : l10n.changePhoto),
                  ),
                ),
                const SizedBox(height: 32),
              ],
              Text(l10n.whatAreYouGettingRidOf,
                  style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 12),
              if (provider.requestTemplates.isNotEmpty) ...[
                Text(
                  'Use a saved template',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: provider.requestTemplates.map((template) {
                    return ActionChip(
                      label: Text(template.name),
                      avatar: const Icon(Icons.copy_all_rounded, size: 18),
                      onPressed: () => _applyTemplate(template),
                    );
                  }).toList(growable: false),
                ),
                const SizedBox(height: 16),
              ],
              TextFormField(
                controller: _titleController,
                style: const TextStyle(fontWeight: FontWeight.w600),
                decoration: InputDecoration(
                  hintText: l10n.requestTitleHint,
                  prefixIcon: const Icon(Icons.inventory_2_outlined),
                ),
                validator: (v) => v!.isEmpty ? l10n.pleaseEnterTitle : null,
              ),
              if (!_isQuickMode) ...[
                const SizedBox(height: 24),
                Text(l10n.description,
                    style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _descriptionController,
                  maxLines: 3,
                  decoration: InputDecoration(
                    hintText: l10n.descriptionHint,
                    alignLabelWithHint: true,
                  ),
                ),
              ],
              const SizedBox(height: 24),
              Text(l10n.location,
                  style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 12),
              if (provider.savedAddresses.isNotEmpty) ...[
                Text(
                  _isQuickMode ? 'Recent addresses' : 'Saved addresses',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: provider.savedAddresses.map((address) {
                    return ActionChip(
                      label: Text(address.label),
                      avatar: const Icon(Icons.location_on_outlined, size: 18),
                      onPressed: () => _applySavedAddress(address),
                    );
                  }).toList(growable: false),
                ),
                const SizedBox(height: 16),
              ],
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
                      hintText: l10n.enterPickupAddress,
                      prefixIcon: const Icon(Icons.location_on_outlined),
                    ),
                    validator: (v) =>
                        v!.isEmpty ? l10n.pleaseEnterLocation : null,
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
              if (!_isQuickMode) ...[
                const SizedBox(height: 24),
                Text(l10n.when, style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _DateSelector(
                        label: l10n.from,
                        date: _fromDate,
                        onTap: () async {
                          final date = await showDatePicker(
                            context: context,
                            firstDate: DateTime.now()
                                .subtract(const Duration(days: 1)),
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
                        label: l10n.to,
                        date: _toDate,
                        onTap: () async {
                          final date = await showDatePicker(
                            context: context,
                            firstDate: DateTime.now()
                                .subtract(const Duration(days: 1)),
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
                Text(l10n.yourPriceReward,
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
                    fillColor: AppTheme.primaryGreen.withValues(alpha: 0.05),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none),
                  ),
                  validator: (v) {
                    if (v == null || v.isEmpty) return l10n.pleaseSetPrice;
                    if (double.tryParse(v) == null) return l10n.invalidNumber;
                    return null;
                  },
                ),
                const SizedBox(height: 20),
                Text(
                  'Pant Refund Split',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const SizedBox(height: 4),
                Text(
                  'How would you like to split the scanned recycling receipt?',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Colors.grey[600],
                      ),
                ),
                const SizedBox(height: 10),
                SegmentedButton<double>(
                  segments: const [
                    ButtonSegment(
                      value: 70.0,
                      label: Text('70% Me / 30% Helper'),
                      icon: Icon(Icons.star_outline, size: 16),
                    ),
                    ButtonSegment(
                      value: 50.0,
                      label: Text('50% / 50%'),
                    ),
                    ButtonSegment(
                      value: 0.0,
                      label: Text('100% Helper'),
                      icon: Icon(Icons.volunteer_activism_outlined, size: 16),
                    ),
                  ],
                  selected: {_splitPercentage},
                  onSelectionChanged: (set) {
                    setState(() {
                      _splitPercentage = set.first;
                    });
                  },
                ),
                const SizedBox(height: 16),
                SwitchListTile.adaptive(
                  contentPadding: EdgeInsets.zero,
                  value: _saveAsAddress,
                  title: const Text('Save this address for later'),
                  subtitle:
                      const Text('Keep this pickup location one tap away.'),
                  onChanged: (value) {
                    setState(() {
                      _saveAsAddress = value;
                    });
                  },
                ),
                SwitchListTile.adaptive(
                  contentPadding: EdgeInsets.zero,
                  value: _saveAsTemplate,
                  title: const Text('Save as reusable template'),
                  subtitle: const Text(
                    'Reuse the title, notes, and reward next time.',
                  ),
                  onChanged: (value) {
                    setState(() {
                      _saveAsTemplate = value;
                    });
                  },
                ),
              ],
              const SizedBox(height: 40),
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: provider.isLoading
                      ? null
                      : () async {
                          await _submitRequest(provider);
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryGreen,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    elevation: 0,
                  ),
                  child: provider.isLoading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : Text(
                          _isQuickMode
                              ? 'Confirm quick request'
                              : l10n.postRequest,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
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
        _selectedPhotoMimeType = mimeType;
        _selectedPhotoFileName = _normalizedFileName(file.name, mimeType);
      });
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.couldNotPickPhoto)),
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

  String _normalizedFileName(String name, String mimeType) {
    final trimmed = name.trim();
    if (trimmed.isNotEmpty && trimmed.contains('.')) {
      return trimmed;
    }

    return 'request-image.${_extensionForMimeType(mimeType)}';
  }

  String _extensionForMimeType(String mimeType) {
    switch (mimeType) {
      case 'image/png':
        return 'png';
      case 'image/webp':
        return 'webp';
      case 'image/gif':
        return 'gif';
      default:
        return 'jpg';
    }
  }

  void _applySavedAddress(SavedAddress address) {
    setState(() {
      _locationController.text = address.location;
      if (address.latitude != null && address.longitude != null) {
        _selectedLocation = LocationSuggestion(
          displayName: address.location,
          title: address.location,
          subtitle: address.label,
          city: null,
          lat: address.latitude!,
          lon: address.longitude!,
        );
      } else {
        _selectedLocation = null;
      }
    });
  }

  void _applyTemplate(RequestTemplate template) {
    setState(() {
      _titleController.text = template.title;
      _descriptionController.text = template.description;
      _rewardController.text = template.reward.toStringAsFixed(2);
      _saveAsTemplate = false;
    });
  }

  void _applyQuickDefaults(PantaProvider provider) {
    final latestRequest = provider.previousRequests.isNotEmpty
        ? (provider.previousRequests.toList()
              ..sort((a, b) => b.scheduledTo.compareTo(a.scheduledTo)))
            .first
        : null;

    if (latestRequest != null && widget.initialRequest == null) {
      _applyInitialRequestValues(latestRequest);
    } else if (provider.requestTemplates.isNotEmpty) {
      _applyTemplate(provider.requestTemplates.first);
    }

    if (_locationController.text.trim().isEmpty) {
      if (provider.savedAddresses.isNotEmpty) {
        _applySavedAddress(provider.savedAddresses.first);
      } else if (latestRequest != null) {
        _locationController.text = latestRequest.location;
        if (latestRequest.locationLatitude != null &&
            latestRequest.locationLongitude != null) {
          _selectedLocation = LocationSuggestion(
            displayName: latestRequest.location,
            title: latestRequest.location,
            subtitle: 'Recent pickup',
            lat: latestRequest.locationLatitude!,
            lon: latestRequest.locationLongitude!,
          );
        }
      }
    }

    if (_titleController.text.trim().isEmpty) {
      _titleController.text = 'Routine pickup';
    }
    if (_rewardController.text.trim().isEmpty) {
      _rewardController.text = '0';
    }

    final start = DateTime.now().add(const Duration(hours: 1));
    _fromDate = DateTime(start.year, start.month, start.day, start.hour, 0);
    _toDate = _fromDate.add(const Duration(hours: 2));
  }

  void _applyInitialRequestValues(RecyclingRequest request) {
    _titleController.text = request.title;
    _descriptionController.text = request.description;
    _rewardController.text = _formatReward(request.reward ?? 0);
    _splitPercentage = request.splitPercentage;
    _locationController.text = request.location;
    if (request.locationLatitude != null && request.locationLongitude != null) {
      _selectedLocation = LocationSuggestion(
        displayName: request.location,
        title: request.location,
        subtitle: '',
        lat: request.locationLatitude!,
        lon: request.locationLongitude!,
      );
    }
  }

  Future<void> _submitRequest(PantaProvider provider) async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final success = await provider.createRequest(
      _titleController.text,
      _fromDate,
      _toDate,
      _locationController.text,
      locationLatitude: _selectedLocation?.lat,
      locationLongitude: _selectedLocation?.lon,
      description: _descriptionController.text,
      reward: double.tryParse(_rewardController.text) ?? 0.0,
      imageBytes: _selectedPhotoBytes,
      imageMimeType: _selectedPhotoMimeType,
      imageFileName: _selectedPhotoFileName,
      saveAddress: _saveAsAddress || _isQuickMode,
      saveTemplate: _saveAsTemplate,
      splitPercentage: _splitPercentage,
    );
    if (success && mounted) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.requestCreated)),
      );
    }
  }
}

class _QuickRequestSummaryCard extends StatelessWidget {
  const _QuickRequestSummaryCard({
    required this.title,
    required this.location,
    required this.fromDate,
    required this.toDate,
    required this.rewardText,
    required this.onEditPressed,
  });

  final String title;
  final String location;
  final DateTime fromDate;
  final DateTime toDate;
  final String rewardText;
  final VoidCallback onEditPressed;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final localeName = l10n.localeName;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppTheme.primaryGreen,
            AppTheme.primaryGreen.withValues(alpha: 0.85),
          ],
        ),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.flash_on_rounded, color: Colors.white),
              const SizedBox(width: 8),
              Text(
                'Book in 30 seconds',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const Spacer(),
              TextButton(
                onPressed: onEditPressed,
                child: const Text(
                  'Edit details',
                  style: TextStyle(color: Colors.white),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _QuickInfoRow(
            icon: Icons.inventory_2_outlined,
            label: title.isEmpty ? 'Routine pickup' : title,
          ),
          const SizedBox(height: 8),
          _QuickInfoRow(
            icon: Icons.location_on_outlined,
            label: location.isEmpty ? 'Choose a pickup address' : location,
          ),
          const SizedBox(height: 8),
          _QuickInfoRow(
            icon: Icons.schedule_outlined,
            label:
                '${DateFormat('d MMM, HH:mm', localeName).format(fromDate)} - ${DateFormat('HH:mm', localeName).format(toDate)}',
          ),
          const SizedBox(height: 8),
          _QuickInfoRow(
            icon: Icons.payments_outlined,
            label:
                '${AppConstants.currencySymbol}${rewardText.isEmpty ? '0' : rewardText} ${AppConstants.currencyCode}',
          ),
        ],
      ),
    );
  }
}

class _QuickInfoRow extends StatelessWidget {
  const _QuickInfoRow({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: Colors.white70, size: 18),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            label,
            style: const TextStyle(color: Colors.white),
          ),
        ),
      ],
    );
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
    final l10n = context.l10n;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey.withValues(alpha: 0.2)),
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
                Text(DateFormat('d MMM, HH:mm', l10n.localeName).format(date),
                    style: const TextStyle(fontWeight: FontWeight.bold)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
