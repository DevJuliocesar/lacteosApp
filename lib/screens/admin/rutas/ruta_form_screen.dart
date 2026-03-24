import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:lacteos_app/models/ruta.dart';
import 'package:lacteos_app/providers/rutas_provider.dart';
import 'package:lacteos_app/providers/users_provider.dart';

class RutaFormScreen extends StatefulWidget {
  final String? rutaId;
  const RutaFormScreen({super.key, this.rutaId});

  bool get isEditing => rutaId != null;

  @override
  State<RutaFormScreen> createState() => _RutaFormScreenState();
}

class _RutaFormScreenState extends State<RutaFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameFocus = FocusNode();
  final _nameCtrl = TextEditingController();
  bool _isActive = true;
  final Set<String> _selectedUserIds = {};
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<UsersProvider>().loadOperarios();
      if (widget.isEditing) {
        final route = context
            .read<RutasProvider>()
            .routes
            .where((r) => r.id == widget.rutaId)
            .firstOrNull;
        if (route != null) _populateForm(route);
      }
      _nameFocus.requestFocus();
    });
  }

  void _populateForm(DeliveryRoute route) {
    _nameCtrl.text = route.name;
    setState(() {
      _isActive = route.isActive;
      _selectedUserIds.addAll(route.userIds);
    });
  }

  @override
  void dispose() {
    _nameFocus.dispose();
    _nameCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);
    try {
      final provider = context.read<RutasProvider>();
      final route = DeliveryRoute(
        id: widget.rutaId ?? '',
        name: _nameCtrl.text.trim(),
        status: _isActive ? 'active' : 'inactive',
        userIds: _selectedUserIds.toList(),
      );
      if (widget.isEditing) {
        await provider.updateRoute(route);
      } else {
        await provider.createRoute(route);
      }
      if (mounted) context.pop();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.isEditing ? 'Editar ruta' : 'Nueva ruta'),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextFormField(
              controller: _nameCtrl,
              focusNode: _nameFocus,
              decoration: const InputDecoration(labelText: 'Nombre de la ruta'),
              validator: (v) => v!.isEmpty ? 'Campo requerido' : null,
            ),
            const SizedBox(height: 8),
            SwitchListTile(
              title: const Text('Ruta activa'),
              value: _isActive,
              onChanged: (v) => setState(() => _isActive = v),
              contentPadding: EdgeInsets.zero,
            ),
            const SizedBox(height: 16),
            Text('Operarios asignados',
                style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 8),
            Consumer<UsersProvider>(
              builder: (_, usersProvider, __) {
                if (usersProvider.isLoading) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (usersProvider.operarios.isEmpty) {
                  return const Text('No hay operarios disponibles',
                      style: TextStyle(color: Colors.grey));
                }
                return Column(
                  children: usersProvider.operarios.map((user) {
                    return CheckboxListTile(
                      title: Text(user.name),
                      subtitle: Text(user.email),
                      value: _selectedUserIds.contains(user.id),
                      onChanged: (checked) {
                        setState(() {
                          if (checked == true) {
                            _selectedUserIds.add(user.id);
                          } else {
                            _selectedUserIds.remove(user.id);
                          }
                        });
                      },
                      contentPadding: EdgeInsets.zero,
                    );
                  }).toList(),
                );
              },
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isSaving ? null : _submit,
                child: _isSaving
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                            color: Colors.white, strokeWidth: 2))
                    : Text(widget.isEditing ? 'Guardar cambios' : 'Crear ruta'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
