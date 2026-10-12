import 'package:flutter/material.dart';

import '../data/construction_journal_models.dart';

class JournalRowContractPicker extends StatelessWidget {
  const JournalRowContractPicker({
    super.key,
    required this.contractId,
    required this.contracts,
    required this.onChanged,
    this.contractNumber,
    this.helperText,
    this.enabled = true,
  });

  final int? contractId;
  final String? contractNumber;
  final List<ConstructionJournalContractOption> contracts;
  final ValueChanged<int?> onChanged;
  final String? helperText;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final selectedPresent = contracts.any(
      (contract) => contract.id == contractId,
    );
    return DropdownButtonFormField<int>(
      key: ValueKey(contractId),
      initialValue: contractId ?? 0,
      isExpanded: true,
      decoration: InputDecoration(
        labelText: 'Договор строки',
        border: const OutlineInputBorder(),
        helperText:
            helperText ??
            (contractId == null ? 'Факт учитывается в проекте' : null),
        helperMaxLines: 3,
      ),
      items: [
        const DropdownMenuItem(value: 0, child: Text('Без договора')),
        if (contractId != null && !selectedPresent)
          DropdownMenuItem(
            value: contractId,
            child: Text('Договор ${contractNumber ?? contractId}'),
          ),
        ...contracts.map(
          (contract) => DropdownMenuItem(
            value: contract.id,
            child: Text(contract.label, overflow: TextOverflow.ellipsis),
          ),
        ),
      ],
      onChanged:
          enabled ? (value) => onChanged(value == 0 ? null : value) : null,
    );
  }
}
