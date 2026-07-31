# 📋 Patch Notes - @ox_inventoryv2

## Additions
- Added admin commands `/allitems` and `/searchitem` to manage items.

## Fixes
- Fixed the weapon preview in the accessories panel sticking around after closing the UI.
- Fixed the weapon rotation in the accessories panel (mouse wheel input).
- Fixed clothing saves with `rcore_clothing` by adding a synchronization delay.

## Improvements
- Improved weapon preview cleanup when closing the inventory.

## Prime Integration Updates (2026-02)
- Added `stretcher1` usable item integration for `ContextMenu` workflow.
- Item usage now triggers server-side stretcher spawn flow (model `stryker_fix`).
- Added recovery flow compatibility: stretcher can be retrieved and returned as inventory item via ContextMenu interactions.

---
