import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:lacteos_app/models/user.dart';
import 'package:lacteos_app/providers/users_provider.dart';
import 'package:lacteos_app/services/users_service.dart';

class UsersScreen extends StatefulWidget {
  const UsersScreen({super.key});

  @override
  State<UsersScreen> createState() => _UsersScreenState();
}

class _UsersScreenState extends State<UsersScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<UsersProvider>().loadOperarios();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Operarios')),
      floatingActionButton: FloatingActionButton.extended(
        icon: const Icon(Icons.person_add_outlined),
        label: const Text('Invitar operario'),
        onPressed: () => _showInviteDialog(context),
      ),
      body: Consumer<UsersProvider>(
        builder: (_, provider, __) {
          if (provider.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }
          if (provider.error != null) {
            return Center(child: Text(provider.error!));
          }
          if (provider.operarios.isEmpty) {
            return const Center(child: Text('No hay operarios registrados'));
          }
          return ListView.separated(
            padding: const EdgeInsets.only(bottom: 80),
            itemCount: provider.operarios.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (_, index) {
              final user = provider.operarios[index];
              return _OperarioTile(user: user);
            },
          );
        },
      ),
    );
  }

  void _showInviteDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => const _InviteDialog(),
    );
  }
}

class _OperarioTile extends StatelessWidget {
  final User user;

  const _OperarioTile({required this.user});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: CircleAvatar(
        backgroundColor: user.isPending ? Colors.orange.shade50 : Colors.blue.shade50,
        child: Text(
          user.name.isNotEmpty ? user.name[0].toUpperCase() : '?',
          style: TextStyle(
            color: user.isPending ? Colors.orange : Colors.blue,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      title: Text(user.name),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(user.email),
          const SizedBox(height: 2),
          _StatusChip(isPending: user.isPending),
        ],
      ),
      isThreeLine: true,
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (user.isPending)
            _ResendButton(user: user)
          else
            IconButton(
              icon: const Icon(Icons.edit_outlined),
              onPressed: () => _showEditDialog(context, user),
            ),
          _DeleteButton(user: user),
        ],
      ),
    );
  }

  void _showEditDialog(BuildContext context, User user) {
    showDialog(
      context: context,
      builder: (_) => _EditDialog(user: user),
    );
  }
}

class _StatusChip extends StatelessWidget {
  final bool isPending;

  const _StatusChip({required this.isPending});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: isPending ? Colors.orange.shade100 : Colors.green.shade100,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        isPending ? 'Invitación pendiente' : 'Activo',
        style: TextStyle(
          fontSize: 11,
          color: isPending ? Colors.orange.shade800 : Colors.green.shade800,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}

class _ResendButton extends StatefulWidget {
  final User user;

  const _ResendButton({required this.user});

  @override
  State<_ResendButton> createState() => _ResendButtonState();
}

class _ResendButtonState extends State<_ResendButton> {
  bool _loading = false;

  Future<void> _resend() async {
    setState(() => _loading = true);
    try {
      await UsersService().resendInvitation(
        email: widget.user.email,
        name: widget.user.name,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Invitación reenviada a ${widget.user.email}'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return _loading
        ? const SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(strokeWidth: 2),
          )
        : IconButton(
            icon: const Icon(Icons.send_outlined, color: Colors.orange),
            tooltip: 'Reenviar invitación',
            onPressed: _resend,
          );
  }
}

class _EditDialog extends StatefulWidget {
  final User user;

  const _EditDialog({required this.user});

  @override
  State<_EditDialog> createState() => _EditDialogState();
}

class _EditDialogState extends State<_EditDialog> {
  final _formKey = GlobalKey<FormState>();
  late final _nameCtrl = TextEditingController(text: widget.user.name);
  bool _loading = false;

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    try {
      final updated = User(
        id: widget.user.id,
        name: _nameCtrl.text.trim(),
        email: widget.user.email,
        role: widget.user.role,
      );
      await context.read<UsersProvider>().updateOperario(updated);
      if (!mounted) return;
      Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Editar operario'),
      content: Form(
        key: _formKey,
        child: TextFormField(
          controller: _nameCtrl,
          decoration: const InputDecoration(
            labelText: 'Nombre',
            prefixIcon: Icon(Icons.person_outline),
          ),
          textCapitalization: TextCapitalization.words,
          autofocus: true,
          validator: (v) =>
              (v == null || v.trim().isEmpty) ? 'Ingresa el nombre' : null,
        ),
      ),
      actions: [
        TextButton(
          onPressed: _loading ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: _loading ? null : _submit,
          child: _loading
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                )
              : const Text('Guardar'),
        ),
      ],
    );
  }
}

class _DeleteButton extends StatelessWidget {
  final User user;

  const _DeleteButton({required this.user});

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.delete_outline, color: Colors.red),
      onPressed: () async {
        final confirm = await showDialog<bool>(
          context: context,
          builder: (_) => AlertDialog(
            title: const Text('Eliminar operario'),
            content: Text(
                '¿Eliminar a "${user.name}"? Esta acción no se puede deshacer.'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancelar'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Eliminar',
                    style: TextStyle(color: Colors.red)),
              ),
            ],
          ),
        );
        if (confirm == true && context.mounted) {
          try {
            await context.read<UsersProvider>().deleteOperario(user.id);
          } catch (e) {
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
              );
            }
          }
        }
      },
    );
  }
}

class _InviteDialog extends StatefulWidget {
  const _InviteDialog();

  @override
  State<_InviteDialog> createState() => _InviteDialogState();
}

class _InviteDialogState extends State<_InviteDialog> {
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _nameCtrl = TextEditingController();
  final _service = UsersService();
  bool _loading = false;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _nameCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    try {
      await _service.inviteOperario(
        email: _emailCtrl.text.trim(),
        name: _nameCtrl.text.trim(),
      );
      if (!mounted) return;
      Navigator.of(context).pop();
      // Recarga la lista para que aparezca el nuevo operario
      context.read<UsersProvider>().loadOperarios();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Invitación enviada a ${_emailCtrl.text.trim()}'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString().replaceFirst('Exception: ', '')),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Invitar operario'),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              controller: _nameCtrl,
              decoration: const InputDecoration(
                labelText: 'Nombre',
                prefixIcon: Icon(Icons.person_outline),
              ),
              textCapitalization: TextCapitalization.words,
              autofocus: true,
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Ingresa el nombre' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _emailCtrl,
              decoration: const InputDecoration(
                labelText: 'Correo electrónico',
                prefixIcon: Icon(Icons.email_outlined),
              ),
              keyboardType: TextInputType.emailAddress,
              validator: (v) {
                if (v == null || v.trim().isEmpty) return 'Ingresa el correo';
                if (!v.contains('@')) return 'Correo inválido';
                return null;
              },
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _loading ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: _loading ? null : _submit,
          child: _loading
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                )
              : const Text('Enviar invitación'),
        ),
      ],
    );
  }
}
