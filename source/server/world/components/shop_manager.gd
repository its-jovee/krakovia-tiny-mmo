class_name ShopManager
extends Node

## Manages all active player shops on the server
## Handles shop creation, item listing, purchases, and cleanup

# Active shops: {session_id: ShopSession}
var active_shops: Dictionary = {}
# Quick lookup: {peer_id: session_id}
var shops_by_peer: Dictionary = {}
var next_session_id: int = 1

# Shop session data structure
class ShopSession:
	var session_id: int
	var seller_peer_id: int
	var seller_name: String
	var shop_name: String
	## Dictionary of items for sale: {item_id: {quantity: int, price: int}}
	var items_for_sale: Dictionary = {}
	var shop_position: Vector2
	var instance: ServerInstance
	
	func get_data() -> Dictionary:
		return {
			"session_id": session_id,
			"seller_peer_id": seller_peer_id,
			"seller_name": seller_name,
			"shop_name": shop_name,
			"items": items_for_sale,
			"position": shop_position
		}


## Check if a player currently has a shop open
func has_shop(peer_id: int) -> bool:
	return shops_by_peer.has(peer_id)


## Get a shop session by seller peer id
func get_shop_by_peer(peer_id: int) -> ShopSession:
	var session_id = shops_by_peer.get(peer_id, -1)
	if session_id == -1:
		return null
	return active_shops.get(session_id, null)


## Open a new shop for a player
func open_shop(peer_id: int, shop_name: String, instance: ServerInstance) -> Dictionary:
	print("ShopManager: Opening shop for peer ", peer_id, " with name '", shop_name, "'")
	
	# Check if player already has a shop
	if has_shop(peer_id):
		return {"error": "You already have a shop open"}
	
	var player = instance.get_player(peer_id)
	if not player:
		return {"error": "Player not found"}
	
	# Check if player is in a trade
	if instance.has_node("TradeManager"):
		var trade_mgr: TradeManager = instance.get_node("TradeManager")
		if trade_mgr.is_player_in_trade(peer_id):
			return {"error": "Cannot open shop while trading"}
	
	# Validate shop name
	if shop_name.strip_edges().is_empty():
		shop_name = "%s's Shop" % player.player_resource.display_name
	
	# Create new shop session
	var session = ShopSession.new()
	session.session_id = next_session_id
	session.seller_peer_id = peer_id
	session.seller_name = player.player_resource.display_name
	session.shop_name = shop_name
	session.shop_position = player.global_position
	session.instance = instance
	
	active_shops[next_session_id] = session
	shops_by_peer[peer_id] = next_session_id
	next_session_id += 1
	
	# Notify the seller
	instance.data_push.rpc_id(peer_id, &"shop.opened", {
		"session_id": session.session_id,
		"shop_name": session.shop_name
	})
	
	# Broadcast shop status to nearby players
	_broadcast_shop_status(session, "opened")
	
	print("ShopManager: Shop opened successfully with session_id ", session.session_id)
	return {"success": true, "session_id": session.session_id}


## Close a player's shop
func close_shop(peer_id: int) -> Dictionary:
	if not has_shop(peer_id):
		return {"error": "You don't have a shop open"}
	
	var session_id = shops_by_peer[peer_id]
	var session: ShopSession = active_shops[session_id]
	
	print("ShopManager: Closing shop for peer ", peer_id)
	
	# Broadcast shop closed
	_broadcast_shop_status(session, "closed")
	
	# Notify seller
	session.instance.data_push.rpc_id(peer_id, &"shop.closed", {})
	
	# Clean up
	active_shops.erase(session_id)
	shops_by_peer.erase(peer_id)
	
	return {"success": true}


## Add an item to the shop listing
func add_item_to_shop(peer_id: int, item_id: int, quantity: int, price: int) -> Dictionary:
	if not has_shop(peer_id):
		return {"error": "You don't have a shop open"}
	
	if quantity <= 0:
		return {"error": "Quantity must be positive"}
	
	if price < 0:
		return {"error": "Price cannot be negative"}
	
	var session: ShopSession = get_shop_by_peer(peer_id)
	var player = session.instance.get_player(peer_id)
	
	# Verify player owns the item
	var player_resource = player.player_resource
	if not player_resource.inventory.has(item_id):
		return {"error": "Item not in inventory"}
	
	var item_entry = player_resource.inventory[item_id]
	if item_entry.stack < quantity:
		return {"error": "Not enough items"}
	
	# Load item to check if it can be sold
	var item: Item = ContentRegistryHub.load_by_id(&"items", item_id)
	if not item:
		return {"error": "Item not found"}
	
	if not item.can_sell:
		return {"error": "This item cannot be sold"}
	
	# Check shop item limit (20 unique items)
	if session.items_for_sale.size() >= 20 and not session.items_for_sale.has(item_id):
		return {"error": "Shop is full (max 20 item types)"}
	
	# Add or update item in shop
	if session.items_for_sale.has(item_id):
		# Update existing listing
		session.items_for_sale[item_id].quantity += quantity
		session.items_for_sale[item_id].price = price  # Update price
	else:
		# New listing
		session.items_for_sale[item_id] = {
			"quantity": quantity,
			"price": price,
			"name": item.item_name
		}
	
	# Items are still in player's inventory (not locked)
	# They will be transferred on purchase
	
	# Broadcast shop update
	_broadcast_shop_update(session)
	
	print("ShopManager: Added ", quantity, "x ", item.item_name, " at ", price, " gold to shop")
	return {
		"success": true,
		"item_id": item_id,
		"quantity": session.items_for_sale[item_id].quantity,
		"price": price
	}


## Remove an item from the shop listing
func remove_item_from_shop(peer_id: int, item_id: int) -> Dictionary:
	if not has_shop(peer_id):
		return {"error": "You don't have a shop open"}
	
	var session: ShopSession = get_shop_by_peer(peer_id)
	
	if not session.items_for_sale.has(item_id):
		return {"error": "Item not in shop"}
	
	# Remove item from shop
	session.items_for_sale.erase(item_id)
	
	# Broadcast shop update
	_broadcast_shop_update(session)
	
	return {"success": true, "item_id": item_id}


## Purchase an item from a shop
func purchase_item(buyer_peer: int, seller_peer: int, item_id: int, quantity: int) -> Dictionary:
	print("ShopManager: Purchase request - Buyer: ", buyer_peer, " Seller: ", seller_peer, " Item: ", item_id, " Qty: ", quantity)
	
	# Validate inputs
	if quantity <= 0:
		return {"error": "Quantity must be positive"}
	
	if buyer_peer == seller_peer:
		return {"error": "Cannot buy from your own shop"}
	
	# Check if seller has a shop
	if not has_shop(seller_peer):
		return {"error": "Shop no longer exists"}
	
	var session: ShopSession = get_shop_by_peer(seller_peer)
	var buyer = session.instance.get_player(buyer_peer)
	var seller = session.instance.get_player(seller_peer)
	
	if not buyer or not seller:
		return {"error": "Player not found"}
	
	# Check if buyer is in trade
	if session.instance.has_node("TradeManager"):
		var trade_mgr: TradeManager = session.instance.get_node("TradeManager")
		if trade_mgr.is_player_in_trade(buyer_peer):
			return {"error": "Cannot purchase while trading"}
	
	# Check if item is in shop
	if not session.items_for_sale.has(item_id):
		return {"error": "Item not in shop"}
	
	var shop_item = session.items_for_sale[item_id]
	
	if shop_item.quantity < quantity:
		return {"error": "Not enough items in shop"}
	
	# Calculate total price
	var total_price = shop_item.price * quantity
	
	# Check if buyer has enough gold
	if buyer.player_resource.golds < total_price:
		return {"error": "Not enough gold"}
	
	# Verify seller still has the items in inventory
	var seller_resource = seller.player_resource
	if not seller_resource.inventory.has(item_id):
		return {"error": "Seller no longer has this item"}
	
	var seller_item = seller_resource.inventory[item_id]
	if seller_item.stack < quantity:
		return {"error": "Seller doesn't have enough items"}
	
	# Execute transaction
	# 1. Remove gold from buyer
	buyer.player_resource.golds -= total_price
	
	# 2. Add gold to seller
	seller.player_resource.golds += total_price
	
	# 3. Remove items from seller
	seller_item.stack -= quantity
	if seller_item.stack <= 0:
		seller_resource.inventory.erase(item_id)
	
	# 4. Add items to buyer
	if buyer.player_resource.inventory.has(item_id):
		buyer.player_resource.inventory[item_id].stack += quantity
	else:
		buyer.player_resource.inventory[item_id] = {
			"stack": quantity
		}
	
	# 5. Update shop listing
	shop_item.quantity -= quantity
	if shop_item.quantity <= 0:
		session.items_for_sale.erase(item_id)
	
	# Load item for logging
	var item: Item = ContentRegistryHub.load_by_id(&"items", item_id)
	var item_name = item.item_name if item else "Unknown"
	
	# Log transaction
	_log_transaction(session, buyer_peer, buyer.player_resource.display_name, item_id, item_name, quantity, total_price)
	
	# Notify both parties
	session.instance.data_push.rpc_id(buyer_peer, &"shop.purchase_complete", {
		"item_id": item_id,
		"item_name": item_name,
		"quantity": quantity,
		"total_price": total_price,
		"seller_name": session.seller_name
	})
	
	session.instance.data_push.rpc_id(seller_peer, &"shop.item_sold", {
		"item_id": item_id,
		"item_name": item_name,
		"quantity": quantity,
		"total_price": total_price,
		"buyer_name": buyer.player_resource.display_name
	})
	
	# Update inventories and gold for both players
	session.instance.data_push.rpc_id(buyer_peer, &"inventory.update", buyer.player_resource.inventory)
	session.instance.data_push.rpc_id(buyer_peer, &"gold.update", {"gold": buyer.player_resource.golds})
	
	session.instance.data_push.rpc_id(seller_peer, &"inventory.update", seller.player_resource.inventory)
	session.instance.data_push.rpc_id(seller_peer, &"gold.update", {"gold": seller.player_resource.golds})
	
	# Broadcast shop update to other players
	_broadcast_shop_update(session)
	
	print("ShopManager: Purchase complete - ", quantity, "x ", item_name, " for ", total_price, " gold")
	return {
		"success": true,
		"item_name": item_name,
		"quantity": quantity,
		"total_price": total_price
	}


## Get shop data for browsing
func get_shop_data(seller_peer: int) -> Dictionary:
	if not has_shop(seller_peer):
		return {"error": "Shop not found"}
	
	var session: ShopSession = get_shop_by_peer(seller_peer)
	return {
		"success": true,
		"shop_data": session.get_data()
	}


## Get list of nearby shops (for future implementation)
func get_nearby_shops(peer_id: int, instance: ServerInstance, max_distance: float = 500.0) -> Array:
	var player = instance.get_player(peer_id)
	if not player:
		return []
	
	var nearby_shops = []
	var player_pos = player.global_position
	
	for session in active_shops.values():
		var distance = player_pos.distance_to(session.shop_position)
		if distance <= max_distance:
			nearby_shops.append({
				"seller_peer_id": session.seller_peer_id,
				"seller_name": session.seller_name,
				"shop_name": session.shop_name,
				"distance": distance,
				"item_count": session.items_for_sale.size()
			})
	
	return nearby_shops


## Broadcast shop status change to all players in instance
func _broadcast_shop_status(session: ShopSession, status: String) -> void:
	var data = {
		"status": status,
		"seller_peer_id": session.seller_peer_id,
		"seller_name": session.seller_name,
		"shop_name": session.shop_name,
		"position": session.shop_position
	}
	
	# Broadcast to all connected peers
	for peer_id in session.instance.connected_peers:
		session.instance.data_push.rpc_id(peer_id, &"shop.status", data)


## Broadcast shop listing update
func _broadcast_shop_update(session: ShopSession) -> void:
	var data = {
		"seller_peer_id": session.seller_peer_id,
		"items": session.items_for_sale
	}
	
	# Broadcast to all connected peers
	for peer_id in session.instance.connected_peers:
		session.instance.data_push.rpc_id(peer_id, &"shop.update", data)


## Log transaction for debugging/analytics
func _log_transaction(session: ShopSession, buyer_peer: int, buyer_name: String, item_id: int, item_name: String, quantity: int, price: int) -> void:
	print("[SHOP TRANSACTION] Buyer: ", buyer_name, " (", buyer_peer, ") | Seller: ", session.seller_name, 
		" (", session.seller_peer_id, ") | Item: ", item_name, " (", item_id, ") | Qty: ", quantity, " | Price: ", price, " gold")
