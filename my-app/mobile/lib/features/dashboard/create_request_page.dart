import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/panta_provider.dart';
import '../../core/theme/app_theme.dart';
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
  DateTime _fromDate = DateTime.now();
  DateTime _toDate = DateTime.now().add(const Duration(hours: 2));

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
              TextFormField(
                controller: _locationController,
                decoration: const InputDecoration(
                  hintText: 'Enter pickup address',
                  prefixIcon: Icon(Icons.location_on_outlined),
                ),
                 validator: (v) => v!.isEmpty ? 'Please enter location' : null,
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
                         final d = await showDatePicker(context: context, firstDate: DateTime.now(), lastDate: DateTime(2025), initialDate: _fromDate);
                         if(d != null) setState(() => _fromDate = d);
                      },
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _DateSelector(
                      label: "To",
                      date: _toDate,
                      onTap: () async {
                         final d = await showDatePicker(context: context, firstDate: DateTime.now(), lastDate: DateTime(2025), initialDate: _toDate);
                         if(d != null) setState(() => _toDate = d);
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

  void _submit() {
    if (_formKey.currentState!.validate()) {
      context.read<PantaProvider>().createRequest(
        _titleController.text,
        _fromDate,
        _toDate,
        _locationController.text,
      );
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Request Created!")));
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
                const Icon(Icons.calendar_today, size: 16, color: AppTheme.primaryGreen),
                const SizedBox(width: 8),
                Text(DateFormat('MMM dd, HH:mm').format(date), style: const TextStyle(fontWeight: FontWeight.bold)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
