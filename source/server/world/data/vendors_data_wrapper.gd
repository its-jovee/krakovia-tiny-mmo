class_name VendorsDataWrapper
extends Resource
## Wrapper resource to persist all vendor data to disk.
## Godot requires a Resource to save to .tres files.

## Dictionary of vendor_id -> VendorData
@export var vendors: Dictionary = {}

