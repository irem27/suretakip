import 'package:suretakip/core/database/app_database.dart';
import 'package:suretakip/features/customers/domain/entities/customer.dart';

/// Drift satırını domain [Customer]'a çevirir (UI bunu gösterir).
Customer mapLocalCustomerToDomain(LocalCustomerRow row) => Customer(
  id: row.id,
  businessId: row.businessId,
  name: row.name,
  phone: row.phone,
  email: row.email,
  notes: row.notes,
  isActive: row.isActive,
  archivedAt: row.isActive ? null : row.updatedAtLocal,
  createdAt: row.createdAtServer ?? row.createdAtLocal,
  updatedAt: row.updatedAtServer ?? row.updatedAtLocal,
);
