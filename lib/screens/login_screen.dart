// lib/screens/profile_screen.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:parkingusers/services/auth_service.dart';

class ProfileScreen extends StatefulWidget {
  final bool isFirstTime;
  const ProfileScreen({super.key, this.isFirstTime = false});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final AuthService _authService = AuthService();
  final _plateController = TextEditingController();
  DateTime? _selectedBirthday;
  bool _isLoading = true;
  String _userEmail = '';
  bool _isBirthdayAlreadySet = false;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    final user = _authService.currentUser;
    if (user == null) {
      setState(() => _isLoading = false);
      return;
    }

    _userEmail = user.email ?? 'No se encontró el correo';
    final userDoc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();

    if (userDoc.exists) {
      final data = userDoc.data()!;
      _plateController.text = data['plateLastDigit'] ?? '';
      if (data['birthday'] != null) {
        _selectedBirthday = (data['birthday'] as Timestamp).toDate();
        _isBirthdayAlreadySet = true;
      }
    }
    setState(() => _isLoading = false);
  }

  Future<bool?> _showConfirmationDialog() {
    return showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Confirmar Cambios'),
          content: const Text('¿Estás seguro de guardar estos datos?\n\nLa fecha de nacimiento no se podrá modificar después.'),
          actions: <Widget>[
            TextButton(child: const Text('Cancelar'), onPressed: () => Navigator.of(context).pop(false)),
            FilledButton(child: const Text('Guardar'), onPressed: () => Navigator.of(context).pop(true)),
          ],
        );
      },
    );
  }

  Future<void> _saveChanges() async {
    final bool? confirmed = await _showConfirmationDialog();
    if (confirmed != true) return;

    setState(() => _isLoading = true);
    try {
      await _authService.updateUserData(
        plateLastDigit: _plateController.text.trim(),
        birthday: _isBirthdayAlreadySet ? null : _selectedBirthday,
      );

      if (_selectedBirthday != null) {
        setState(() => _isBirthdayAlreadySet = true);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('¡Perfil guardado con éxito!'), backgroundColor: Colors.green),
        );
        // Si es la primera vez, cierra la pantalla de perfil.
        // Como usamos pushReplacement, al hacer pop() volverá a la pantalla del mapa.
        if (widget.isFirstTime) {
          Navigator.of(context).pop();
        }
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al guardar: $e'), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context, initialDate: _selectedBirthday ?? DateTime.now(),
      firstDate: DateTime(1920), lastDate: DateTime.now(),
    );
    if (picked != null && picked != _selectedBirthday) {
      setState(() => _selectedBirthday = picked);
    }
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async => !widget.isFirstTime,
      child: Scaffold(
        appBar: AppBar(
          title: Text(widget.isFirstTime ? 'Completa tu Perfil' : 'Mi Perfil'),
          backgroundColor: Colors.black,
          automaticallyImplyLeading: !widget.isFirstTime,
        ),
        body: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (widget.isFirstTime)
                Padding(
                  padding: const EdgeInsets.only(bottom: 24.0),
                  child: Text(
                    '¡Bienvenido a Parking Club! Por favor, completa tus datos para continuar.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Theme.of(context).textTheme.bodyLarge?.color),
                  ),
                ),

              Text('Correo Electrónico', style: Theme.of(context).textTheme.titleSmall),
              const SizedBox(height: 8),
              Text(_userEmail, style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 32),
              TextField(
                controller: _plateController,
                decoration: const InputDecoration(labelText: 'Último dígito de tu placa', hintText: 'Ej: 7', border: OutlineInputBorder()),
                keyboardType: TextInputType.number, maxLength: 1,
              ),
              const SizedBox(height: 16),
              const Text('Fecha de Nacimiento', style: TextStyle(fontSize: 16)),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      _selectedBirthday == null ? 'No seleccionada' : DateFormat('dd / MMMM / yyyy', 'es_ES').format(_selectedBirthday!),
                      style: TextStyle(fontSize: 18, color: _isBirthdayAlreadySet ? Colors.grey : null),
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.calendar_today, color: _isBirthdayAlreadySet ? Colors.grey : const Color(0xFF920606)),
                    onPressed: _isBirthdayAlreadySet ? null : () => _selectDate(context),
                  ),
                ],
              ),
              if (_isBirthdayAlreadySet)
                const Padding(
                  padding: EdgeInsets.only(top: 8.0),
                  child: Text('La fecha de nacimiento ya ha sido guardada y no se puede modificar.', style: TextStyle(color: Colors.grey, fontSize: 12)),
                ),
              const SizedBox(height: 40),
              ElevatedButton(
                onPressed: _saveChanges,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF920606), padding: const EdgeInsets.symmetric(vertical: 16),
                  foregroundColor: Colors.white,
                ),
                child: const Text('GUARDAR CAMBIOS'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}