class_name AccountResource
extends Resource


@export var id: int
@export var handle: String
@export var password: String

# peer_id = 0 if not connected
var peer_id: int = 0


func init(_id: int, _handle: String, _password: String) -> void:
	id = _id
	handle = _handle
	password = _password
