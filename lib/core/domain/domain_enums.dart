enum MemberRole { owner, admin, staff }

enum SessionStatus { draft, active, paused, completed, cancelled }

enum TimeEntryType { active, paused }

enum InventoryMovementType {
  initial,
  sale,
  saleReversal,
  manualAdjustment,
  restock,
}
