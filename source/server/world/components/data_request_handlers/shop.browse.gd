extends DataRequestHandler

## Handler for browsing a shop's inventory

func data_request_handler(
	peer_id: int,
	instance: ServerInstance,
	args: Dictionary
) -> Dictionary:
	var seller_peer: int = args.get("seller_peer", -1)
	
	if seller_peer == -1:
		return {"error": "Invalid seller"}
	
	if not instance.has_node("ShopManager"):
		return {"error": "Shop system not available"}
	
	var shop_mgr: ShopManager = instance.get_node("ShopManager")
	return shop_mgr.get_shop_data(seller_peer)
