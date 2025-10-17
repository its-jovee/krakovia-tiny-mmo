extends DataRequestHandler

## Handler for removing an item from a shop

func data_request_handler(
	peer_id: int,
	instance: ServerInstance,
	args: Dictionary
) -> Dictionary:
	var item_id: int = args.get("item_id", -1)
	
	if item_id == -1:
		return {"error": "Invalid item_id"}
	
	if not instance.has_node("ShopManager"):
		return {"error": "Shop system not available"}
	
	var shop_mgr: ShopManager = instance.get_node("ShopManager")
	return shop_mgr.remove_item_from_shop(peer_id, item_id)
