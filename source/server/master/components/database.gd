class_name MasterDatabase
extends Node


var account_collection: AccountResourceCollection
var account_collection_path: String = ""


func _ready() -> void:
	_configure_database_path()
	tree_exiting.connect(save_account_collection)
	load_account_collection()


func _configure_database_path() -> void:
	if OS.has_feature("editor"):
		account_collection_path = "res://source/server/master/account_collection.tres"
	else:
		# Use current directory for production builds where res:// is read-only
		account_collection_path = "./account_collection.tres"
	print("[MasterDatabase] Using database path: %s" % account_collection_path)


func load_account_collection() -> void:
	if ResourceLoader.exists(account_collection_path):
		account_collection = ResourceLoader.load(account_collection_path)
		print("[MasterDatabase] Loaded %d accounts" % account_collection.collection.size())
	else:
		account_collection = AccountResourceCollection.new()
		print("[MasterDatabase] No existing database found, created new collection")


func handle_exists(handle: String) -> bool:
	if account_collection.collection.has(handle):
		return true
	return false


func validate_credentials(handle: String, password: String) -> AccountResource:
	var account: AccountResource = null
	if account_collection.collection.has(handle):
		account = account_collection.collection[handle]
		if account.password == password:
			return account
	return null


func save_account_collection() -> void:
	var error := ResourceSaver.save(account_collection, account_collection_path)
	if error != OK:
		printerr("[MasterDatabase] ERROR: Failed to save account collection: %s" % error_string(error))
	else:
		print("[MasterDatabase] Saved %d accounts successfully" % account_collection.collection.size())
