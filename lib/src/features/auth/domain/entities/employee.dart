import '../../../orders/domain/entities/branch.dart';

/// Role zaměstnance servisu. Do budoucna se namapuje na skupiny v Entra ID
/// a bude řídit, co smí uživatel v appce měnit.
enum EmployeeRole {
  mechanic('Mechanik'),
  serviceAdvisor('Servisní poradce'),
  shiftLead('Vedoucí směny');

  const EmployeeRole(this.label);

  final String label;
}

/// Přihlášený zaměstnanec RENOCAR. Appka nezná koncové zákazníky -
/// uživatel je vždy zaměstnanec servisu.
class Employee {
  const Employee({
    required this.id,
    required this.displayName,
    required this.email,
    required this.role,
    required this.homeBranch,
  });

  /// Object ID z Entra ID (dnes mock hodnota).
  final String id;
  final String displayName;
  final String email;
  final EmployeeRole role;

  /// Kmenová pobočka - předvyplní filtr v seznamu zakázek.
  final Branch homeBranch;

  String get initials {
    final parts = displayName
        .trim()
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty)
        .toList();
    if (parts.isEmpty) return '?';
    return parts.map((part) => part[0].toUpperCase()).take(2).join();
  }
}
