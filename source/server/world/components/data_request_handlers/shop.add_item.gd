extends DataRequestHandler

## Handler for adding an item to a shop

func data_request_handler(
	peer_id: int,
	instance: ServerInstance,
	args: Dictionary
) -> Dictionary:
	var item_id: int = args.get("item_id", -1)
	var quantity: int = args.get("quantity", 1)
	var price: int = args.get("price", 0)
	
	if item_id == -1:
		return {"error": "Invalid item_id"}
	
	if not instance.has_node("ShopManager"):
		return {"error": "Shop system not available"}
	
	var shop_mgr: ShopManager = instance.get_node("ShopManager")
	return shop_mgr.add_item_to_shop(peer_id, item_id, quantity, price)
