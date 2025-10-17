extends DataRequestHandler

## Handler for closing a player shop

func data_request_handler(
	peer_id: int,
	instance: ServerInstance,
	args: Dictionary
) -> Dictionary:
	if not instance.has_node("ShopManager"):
		return {"error": "Shop system not available"}
	
	var shop_mgr: ShopManager = instance.get_node("ShopManager")
	return shop_mgr.close_shop(peer_id)
