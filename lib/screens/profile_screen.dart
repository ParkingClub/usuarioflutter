// lib/screens/profile_screen.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:parkingusers/screens/map_screen.dart';
import 'package:parkingusers/services/auth_service.dart';
import 'package:flutter/cupertino.dart';

class ProfileScreen extends StatefulWidget {
  final bool isFirstTime;
  const ProfileScreen({super.key, this.isFirstTime = false});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final AuthService _authService = AuthService();
  bool _isLoading = true;
  bool _isSaving = false;

  int? _selectedPlateDigit;
  int? _selectedDay;
  int? _selectedMonth;
  int? _selectedYear;
  DateTime? _selectedBirthday;

  // --- NUEVA VARIABLE PARA EL MENSAJE DE ERROR ---
  String? _errorMessage;

  String _displayName = 'Usuario';
  String? _photoURL;
  bool _isBirthdayAlreadySet = false;

  static const Color brandColor = Color(0xFF920606);
  static const List<String> _months = [
    'Enero', 'Febrero', 'Marzo', 'Abril', 'Mayo', 'Junio',
    'Julio', 'Agosto', 'Septiembre', 'Octubre', 'Noviembre', 'Diciembre'
  ];

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    // ... (sin cambios en esta función)
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
        final birthday = (data['birthday'] as Timestamp).toDate();
        _selectedBirthday = birthday;
        _selectedDay = birthday.day;
        _selectedMonth = birthday.month;
        _selectedYear = birthday.year;
        _isBirthdayAlreadySet = true;
      }
    }
    if (mounted) setState(() => _isLoading = false);
  }

  void _validateAndConstructDate() {
    // ... (sin cambios en esta función)
    if (_selectedYear != null && _selectedMonth != null) {
      final lastDayOfMonth = DateTime(_selectedYear!, _selectedMonth! + 1, 0).day;
      if (_selectedDay != null && _selectedDay! > lastDayOfMonth) {
        setState(() => _selectedDay = lastDayOfMonth);
      }
    }
    if (_selectedDay != null && _selectedMonth != null && _selectedYear != null) {
      setState(() {
        _selectedBirthday = DateTime(_selectedYear!, _selectedMonth!, _selectedDay!);
      });
    }
  }

  // --- MÉTODO DE GUARDADO CON VALIDACIÓN MEJORADA ---
  Future<void> _saveChanges() async {
    // Limpiamos cualquier error anterior al intentar guardar
    setState(() => _errorMessage = null);

    if (_selectedPlateDigit == null) {
      setState(() => _errorMessage = 'Por favor, selecciona el último dígito de tu placa.');
      return;
    }
    if (!_isBirthdayAlreadySet && _selectedBirthday == null) {
      setState(() => _errorMessage = 'Por favor, selecciona tu fecha de nacimiento completa.');
      return;
    }

    if (!_isBirthdayAlreadySet) {
      final bool? confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Confirmar Datos'),
          content: const Text('¿Estás seguro de guardar estos datos?\n\nLa fecha de nacimiento no se podrá modificar después.'),
          actions: <Widget>[
            TextButton(child: const Text('Cancelar'), onPressed: () => Navigator.of(context).pop(false)),
            FilledButton(
                style: FilledButton.styleFrom(backgroundColor: brandColor),
                child: const Text('Guardar'),
                onPressed: () => Navigator.of(context).pop(true)),
          ],
        ),
      );
      if (confirmed != true) return;
    }

    setState(() => _isSaving = true);
    try {
      await _authService.updateUserData(
        plateLastDigit: _selectedPlateDigit.toString(),
        birthday: _isBirthdayAlreadySet ? null : _selectedBirthday,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('¡Perfil guardado con éxito!'), backgroundColor: Colors.green),
        );

        if (widget.isFirstTime) {
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(builder: (context) => const MapScreen()), (Route<dynamic> route) => false,
          );
        } else {
          Navigator.of(context).pop();
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Ocurrió un error al guardar. Inténtalo de nuevo.';
        });
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Widget _buildPlateDigitSelector() {
    // ... (sin cambios en este widget)
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

  Widget _buildBirthdayPicker() {
    // ... (sin cambios en este widget)
    void showPicker({required List<Widget> items, required int initialItem, required Function(int) onSelectedItemChanged, required String title}) {
      showModalBottomSheet(
        context: context,
        builder: (context) => SizedBox(
          height: 250,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ),
              Expanded(
                child: CupertinoPicker(
                  itemExtent: 32.0,
                  scrollController: FixedExtentScrollController(initialItem: initialItem),
                  onSelectedItemChanged: onSelectedItemChanged,
                  children: items,
                ),
              ),
            ],
          ),
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Fecha de Nacimiento', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500, color: Colors.black54)),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            border: Border.all(color: _isBirthdayAlreadySet ? Colors.transparent : Colors.grey.shade300),
            borderRadius: BorderRadius.circular(12),
            color: _isBirthdayAlreadySet ? Colors.grey.shade100 : Colors.transparent,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildPickerField(label: 'Año', value: _selectedYear, onTap: _isBirthdayAlreadySet ? null : () {
                final years = List.generate(100, (i) => DateTime.now().year - i);
                showPicker(
                  title: 'Selecciona el Año',
                  items: years.map((year) => Text(year.toString())).toList(),
                  initialItem: _selectedYear != null ? years.indexOf(_selectedYear!) : 18,
                  onSelectedItemChanged: (index) {
                    setState(() { _selectedYear = years[index]; _validateAndConstructDate(); });
                  },
                );
              }),
              _buildPickerField(label: 'Mes', value: _selectedMonth != null ? _months[_selectedMonth! - 1] : null, onTap: _isBirthdayAlreadySet || _selectedYear == null ? null : () {
                showPicker(
                  title: 'Selecciona el Mes',
                  items: _months.map((month) => Text(month)).toList(),
                  initialItem: (_selectedMonth ?? 1) - 1,
                  onSelectedItemChanged: (index) {
                    setState(() { _selectedMonth = index + 1; _validateAndConstructDate(); });
                  },
                );
              }),
              _buildPickerField(label: 'Día', value: _selectedDay, onTap: _isBirthdayAlreadySet || _selectedMonth == null ? null : () {
                final daysInMonth = DateTime(_selectedYear!, _selectedMonth! + 1, 0).day;
                final days = List.generate(daysInMonth, (i) => i + 1);
                showPicker(
                  title: 'Selecciona el Día',
                  items: days.map((day) => Text(day.toString())).toList(),
                  initialItem: (_selectedDay ?? 1) - 1,
                  onSelectedItemChanged: (index) {
                    setState(() { _selectedDay = days[index]; _validateAndConstructDate(); });
                  },
                );
              }),
            ],
          ),
        ),
        if (_isBirthdayAlreadySet)
          const Padding(
            padding: EdgeInsets.only(top: 8.0),
            child: Text('La fecha de nacimiento no se puede modificar.', style: TextStyle(color: Colors.grey, fontSize: 12)),
          ),
      ],
    );
  }

  Widget _buildPickerField({required String label, required dynamic value, required VoidCallback? onTap}) {
    // ... (sin cambios en este widget)
    final bool isEnabled = onTap != null;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
        child: Column(
          children: [
            Text(label, style: TextStyle(color: isEnabled ? Colors.grey.shade600 : Colors.grey.shade400, fontSize: 12)),
            const SizedBox(height: 4),
            Text(
              value?.toString() ?? '- -',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: isEnabled ? brandColor : Colors.grey.shade400),
            ),
          ],
        ),
      ),
    );
  }

  // --- NUEVO WIDGET PARA MOSTRAR ERRORES ---
  Widget _buildErrorWidget() {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 300),
      child: _errorMessage != null
          ? Container(
        key: const ValueKey('error'),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        margin: const EdgeInsets.only(bottom: 24),
        decoration: BoxDecoration(
          color: Colors.red.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.red.withOpacity(0.3)),
        ),
        child: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.red, size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                _errorMessage!,
                style: const TextStyle(color: Colors.red, fontWeight: FontWeight.w500),
              ),
            ),
          ],
        ),
      )
          : const SizedBox.shrink(key: ValueKey('no-error')),
    );
  }

  @override
  Widget build(BuildContext context) {
    // --- OBTENEMOS EL PADDING INFERIOR ---
    final double bottomPadding = MediaQuery.of(context).padding.bottom;

    return WillPopScope(
      onWillPop: () async => !widget.isFirstTime,
      child: Container(
        constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.9),
        decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(28.0))),
        child: _isLoading
            ? const Center(child: CircularProgressIndicator(color: brandColor))
            : Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              margin: const EdgeInsets.only(top: 12.0, bottom: 8.0),
              width: 40, height: 5,
              decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(10)),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8.0),
              child: Text(
                widget.isFirstTime ? 'Completa tu Perfil' : 'Mi Perfil',
                style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              ),
            ),
            const Divider(height: 1, indent: 20, endIndent: 20),
            Flexible(
              child: SingleChildScrollView(
                // --- APLICAMOS EL PADDING INFERIOR ---
                padding: EdgeInsets.fromLTRB(24.0, 24.0, 24.0, 24.0 + bottomPadding),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Center(
                      child: Column(
                        children: [
                          CircleAvatar(
                            radius: 45, backgroundColor: Colors.grey.shade200,
                            backgroundImage: _photoURL != null ? NetworkImage(_photoURL!) : null,
                            child: _photoURL == null ? Icon(Icons.person, size: 45, color: Colors.grey.shade400) : null,
                          ),
                          const SizedBox(height: 12),
                          Text(_displayName, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 4),
                          Text(_authService.currentUser?.email ?? '', style: TextStyle(fontSize: 15, color: Colors.grey.shade600)),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    if (widget.isFirstTime)
                      Container(
                        padding: const EdgeInsets.all(12),
                        margin: const EdgeInsets.only(bottom: 24.0),
                        decoration: BoxDecoration(
                            color: brandColor.withOpacity(0.05),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: brandColor.withOpacity(0.2))
                        ),
                        child: const Text(
                          '¡Bienvenido! Por favor, completa tus datos para continuar.',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 15, color: brandColor, fontWeight: FontWeight.w500),
                        ),
                      ),
                    _buildPlateDigitSelector(),
                    const SizedBox(height: 24),
                    _buildBirthdayPicker(),
                    const SizedBox(height: 24),
                    // --- WIDGET DE ERROR INTEGRADO ---
                    _buildErrorWidget(),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: _isSaving ? null : _saveChanges,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: brandColor, foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      child: _isSaving
                          ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : Text(widget.isFirstTime ? 'GUARDAR Y CONTINUAR' : 'GUARDAR CAMBIOS'),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}