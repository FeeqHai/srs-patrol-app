import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/providers/settings_provider.dart';
import '../../../core/utils/account_validation.dart';
import '../../auth/models/user_model.dart';

class MemberProfileEditResult {
  const MemberProfileEditResult({
    required this.fullName,
    required this.icNumber,
    required this.phoneNumber,
    required this.email,
  });

  final String fullName;
  final String icNumber;
  final String phoneNumber;
  final String email;
}

class EditMemberProfileDialog extends StatefulWidget {
  const EditMemberProfileDialog({required this.member, super.key});

  final UserModel member;

  @override
  State<EditMemberProfileDialog> createState() =>
      _EditMemberProfileDialogState();
}

class _EditMemberProfileDialogState extends State<EditMemberProfileDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _ic;
  late final TextEditingController _phone;
  late final TextEditingController _email;

  @override
  void initState() {
    super.initState();
    _name = TextEditingController(text: widget.member.fullName);
    _ic = TextEditingController(text: widget.member.icNumber ?? '');
    _phone = TextEditingController(text: widget.member.phoneNumber ?? '');
    _email = TextEditingController(text: widget.member.email ?? '');
  }

  @override
  void dispose() {
    // The route result arrives before the exit animation finishes. Keep these
    // controllers alive until the dialog itself is removed from the tree.
    _name.dispose();
    _ic.dispose();
    _phone.dispose();
    _email.dispose();
    super.dispose();
  }

  void _save() {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final result = MemberProfileEditResult(
      fullName: _name.text.trim(),
      icNumber: AccountValidation.normalizeIc(_ic.text),
      phoneNumber: AccountValidation.normalizePhone(_phone.text),
      email: _email.text.trim(),
    );
    Navigator.pop(context, result);
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();
    String? translatedError(String? error) =>
        error == null ? null : settings.t(error);
    return AlertDialog(
      title: Text(settings.t('Edit Profil Ahli')),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _name,
                validator: (value) =>
                    translatedError(AccountValidation.required(value)),
                decoration: InputDecoration(
                  labelText: settings.t('Nama Penuh'),
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _ic,
                keyboardType: TextInputType.number,
                autovalidateMode: AutovalidateMode.onUserInteraction,
                validator: (value) =>
                    translatedError(AccountValidation.icNumber(value)),
                decoration: InputDecoration(
                  labelText: settings.t('No. Kad Pengenalan'),
                  errorMaxLines: 3,
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _phone,
                keyboardType: TextInputType.phone,
                autovalidateMode: AutovalidateMode.onUserInteraction,
                validator: (value) =>
                    translatedError(AccountValidation.phone(value)),
                decoration: InputDecoration(
                  labelText: settings.t('No. Telefon'),
                  errorMaxLines: 4,
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _email,
                keyboardType: TextInputType.emailAddress,
                validator: (value) =>
                    translatedError(AccountValidation.required(value)),
                decoration: InputDecoration(labelText: settings.t('E-mel')),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(settings.t('Batal')),
        ),
        FilledButton(onPressed: _save, child: Text(settings.t('Simpan'))),
      ],
    );
  }
}
