/// Yeni müşteri oluşturma girdisi. id, timestamp ve is_active DB tarafından
/// üretilir.
final class CustomerInput {
  const CustomerInput({
    required this.businessId,
    required this.name,
    this.phone,
    this.email,
    this.notes,
  });

  final String businessId;
  final String name;
  final String? phone;
  final String? email;
  final String? notes;
}
