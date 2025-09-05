// lib/screens/view_profile_bottom_sheet.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:parkingusers/services/auth_service.dart';

class ViewProfileBottomSheet extends StatefulWidget {
  const ViewProfileBottomSheet({super.key});

  @override
  State<ViewProfileBottomSheet> createState() => _ViewProfileBottomSheetState();
}

class _ViewProfileBottomSheetState extends State<ViewProfileBottomSheet> {
  final AuthService _authService = AuthService();
  bool _isLoading = true;
  bool _isSaving = false;

  // Nueva variable para controlar si estamos en modo de edición o vista
  bool _isEditing = false;

  int? _selectedPlateDigit;
  DateTime? _selectedBirthday;
  String _displayName = 'Usuario';
  String? _photoURL;

  static const Color brandColor = Color(0xFF920606);

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    final user = _authService.currentUser;
    if (user == null) {
      if (mounted) setState(() => _isLoading = false);
      return;
    }

    final userDoc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();

    if (userDoc.exists) {
      final data = userDoc.data()!;
      _displayName = data['displayName'] ?? 'Usuario';
      _photoURL = data['photoURL'];
      if (data['plateLastDigit'] != null) {
        _selectedPlateDigit = int.tryParse(data['plateLastDigit']);
      }
      if (data['birthday'] != null) {
        _selectedBirthday = (data['birthday'] as Timestamp).toDate();
      }
    }
    if (mounted) setState(() => _isLoading = false);
  }

  Future<void> _saveChanges() async {
    if (_selectedPlateDigit == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Por favor, selecciona un dígito para la placa.'), backgroundColor: Colors.orange),
      );
      return;
    }

    setState(() => _isSaving = true);
    try {
      await _authService.updateUserData(plateLastDigit: _selectedPlateDigit.toString());

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('¡Placa actualizada con éxito!'), backgroundColor: Colors.green),
        );
        // Volvemos al modo de solo lectura
        setState(() => _isEditing = false);
      }
    } catch (e) {
      // Manejo de errores
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Widget _buildPlateDigitSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Último dígito de tu placa', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500, color: Colors.black54)),
        const SizedBox(height: 12),
        SizedBox(
          height: 50,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: 10,
            separatorBuilder: (context, index) => const SizedBox(width: 8),
            itemBuilder: (context, index) {
              final digit = index;
              final isSelected = _selectedPlateDigit == digit;
              return GestureDetector(
                onTap: () => setState(() => _selectedPlateDigit = digit),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: 50,
                  decoration: BoxDecoration(
                    color: isSelected ? brandColor : Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: isSelected ? brandColor : Colors.grey.shade300),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    digit.toString(),
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: isSelected ? Colors.white : Colors.black87),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  // Widget para mostrar una fila de información en modo de solo lectura
  Widget _buildInfoRow({required IconData icon, required String label, required String? value}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        children: [
          Icon(icon, color: brandColor, size: 22),
          const SizedBox(width: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
              const SizedBox(height: 2),
              Text(value ?? 'No establecido', style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
            ],
          )
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final double bottomPadding = MediaQuery.of(context).padding.bottom;
    return Wrap(
      children: [
        Container(
          padding: EdgeInsets.fromLTRB(24, 24, 24, 24 + bottomPadding),
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(25)),
          ),
          child: _isLoading
              ? const Center(heightFactor: 5, child: CircularProgressIndicator(color: brandColor))
              : Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // --- CABECERA ---
              Row(
                children: [
                  CircleAvatar(
                    radius: 30,
                    backgroundColor: Colors.grey.shade200,
                    backgroundImage: _photoURL != null ? NetworkImage(_photoURL!) : null,
                    child: _photoURL == null ? const Icon(Icons.person, size: 30, color: Colors.grey) : null,
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(_displayName, style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontSize: 20)),
                        Text(_authService.currentUser?.email ?? '', style: Theme.of(context).textTheme.bodyMedium),
                      ],
                    ),
                  ),
                  IconButton(onPressed: () => Navigator.of(context).pop(), icon: const Icon(Icons.close)),
                ],
              ),
              const Divider(height: 32),

              // --- VISTA CONDICIONAL: LECTURA O EDICIÓN ---
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                child: _isEditing
                // --- MODO EDICIÓN ---
                    ? Column(
                  key: const ValueKey('editing'),
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildPlateDigitSelector(),
                    const SizedBox(height: 24),
                    Text('La fecha de nacimiento no se puede modificar.', style: TextStyle(color: Colors.grey.shade600, fontSize: 13, fontStyle: FontStyle.italic)),
                    const SizedBox(height: 24),
                    Row(
                      children: [
                        Expanded(
                          child: TextButton(
                            onPressed: () => setState(() => _isEditing = false),
                            child: const Text('Cancelar'),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          flex: 2,
                          child: ElevatedButton(
                            onPressed: _isSaving ? null : _saveChanges,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: brandColor, foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            child: _isSaving
                                ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                                : const Text('Guardar Cambios'),
                          ),
                        ),
                      ],
                    )
                  ],
                )
                // --- MODO SOLO LECTURA ---
                    : Column(
                  key: const ValueKey('reading'),
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildInfoRow(icon: Icons.pin_outlined, label: 'Último dígito de placa', value: _selectedPlateDigit?.toString()),
                    _buildInfoRow(icon: Icons.cake_outlined, label: 'Fecha de Nacimiento', value: _selectedBirthday != null ? DateFormat('dd / MMMM / yyyy', 'es_ES').format(_selectedBirthday!) : null),
                    const SizedBox(height: 24),
                    ElevatedButton.icon(
                      icon: const Icon(Icons.edit_outlined, size: 18),
                      label: const Text('Editar Placa'),
                      onPressed: () => setState(() => _isEditing = true),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: brandColor, foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}