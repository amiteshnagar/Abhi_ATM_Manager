import 'package:flutter/material.dart';

Future<String?> showReasonDialog({
  required BuildContext context,
  required String title,
  required String labelText,
  required String actionButtonText,
}) async {
  final TextEditingController controller = TextEditingController();
  final formKey = GlobalKey<FormState>();

  return showDialog<String>(
    context: context,
    barrierDismissible: false,
    builder: (context) {
      return AlertDialog(
        title: Text(title),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: controller,
                autofocus: true,
                maxLines: 2,
                decoration: InputDecoration(
                  labelText: labelText,
                  hintText: 'Enter a valid reason',
                ),
                validator: (val) {
                  if (val == null || val.trim().isEmpty) {
                    return 'Reason is mandatory.';
                  }
                  return null;
                },
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, null),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              if (formKey.currentState!.validate()) {
                Navigator.pop(context, controller.text.trim());
              }
            },
            child: Text(actionButtonText),
          ),
        ],
      );
    },
  );
}
