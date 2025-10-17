# Shop Setup - Property Name Fix

**Date**: October 17, 2025  
**Status**: ✅ **FIXED** - Invalid property access resolved

---

## Error

```
Invalid access to property or key 'value' on a base object of type 'Resource (MaterialItem)'.
```

**Location**: `shop_setup_ui.gd` line 151

---

## Problem

The code was trying to access `item.value` which doesn't exist on the Item class:

```gdscript
var suggested_price = item.value if item.value > 0 else 10  # ❌ No 'value' property!
```

---

## Root Cause

Looking at the Item class (`source/common/gameplay/items/item.gd`), the property is called **`minimum_price`**, not `value`:

```gdscript
class_name Item
extends Resource

# Trading / Economy
@export var can_trade: bool = false
@export var can_sell: bool = false
@export var minimum_price: int = 0  # ✅ This is the correct property!
```

---

## Fix Applied ✅

**File**: `source/client/ui/shop/shop_setup_ui.gd` line 151

**Changed**:
```gdscript
# Suggest a price (could be based on minimum_price)
var suggested_price = item.minimum_price if item.minimum_price > 0 else 10
price_spinbox.value = suggested_price
```

---

## What This Does

When adding an item to the shop, the system now:
1. Checks if the item has a `minimum_price` set (> 0)
2. If yes, suggests that as the default price
3. If no minimum_price (or it's 0), suggests 10 gold as default
4. Player can still override this value

---

## Status

✅ **Error Fixed** - Shop Setup UI should now work without runtime errors!

---

## Test It

1. Open Shop Setup UI
2. Click on an item
3. Dialog should appear with suggested price (no errors)
4. Default price will be either the item's `minimum_price` or 10 gold
