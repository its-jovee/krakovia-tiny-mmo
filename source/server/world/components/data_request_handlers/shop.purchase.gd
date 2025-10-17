extends DataRequestHandler

## Handler for purchasing an item from a shop

func data_request_handler(
	peer_id: int,
	instance: ServerInstance,
	args: Dictionary
) -> Dictionary:
	var seller_peer: int = args.get("seller_peer", -1)
	var item_id: int = args.get("item_id", -1)
	var quantity: int = args.get("quantity", 1)
	
	if seller_peer == -1:
		return {"error": "Invalid seller"}
	
	if item_id == -1:
		return {"error": "Invalid item_id"}
	
	if not instance.has_node("ShopManager"):
		return {"error": "Shop system not available"}
	
	var shop_mgr: ShopManager = instance.get_node("ShopManager")
	return shop_mgr.purchase_item(peer_id, seller_peer, item_id, quantity)
