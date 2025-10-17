extends DataRequestHandler

## Handler for opening a player shop

func data_request_handler(
	peer_id: int,
	instance: ServerInstance,
	args: Dictionary
) -> Dictionary:
	var shop_name: String = args.get("shop_name", "")
	
	if not instance.has_node("ShopManager"):
		return {"error": "Shop system not available"}
	
	var shop_mgr: ShopManager = instance.get_node("ShopManager")
	return shop_mgr.open_shop(peer_id, shop_name, instance)
