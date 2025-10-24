class_name ContentRegistryHub


static var _content_by_name: Dictionary[StringName, ContentRegistry]
static var _versions: Dictionary[StringName, int]
static var _resource_cache: Dictionary[String, Resource] = {}  # Cache for preloaded resources
static var _cache_enabled: bool = true


static func _static_init() -> void:
	if OS.has_feature("master-server") or OS.has_feature("gateway-server"):
		return
	const INDEXES_DIR: String = "res://source/common/registry/indexes/"
	for index_path: String in ResourceLoader.list_directory(INDEXES_DIR):
		var content_index: ContentIndex = ResourceLoader.load(INDEXES_DIR + index_path)
		register_registry(
			index_path.trim_suffix("_index.tres"),
			content_index
		)
		#print_debug(content_index.entries)
	#print("_content_by_name = ", _content_by_name)


static func register_registry(content_name: StringName, content_index: ContentIndex) -> void:
	#var content_registry: ContentRegistry = ContentRegistry.new(content_index)
	_content_by_name[content_name] = ContentRegistry.new(content_index)
	_versions[content_name] = content_index.version


static func registry_of(content_name: StringName) -> ContentRegistry:
	return _content_by_name.get(content_name, null)


static func version_of(content_name: StringName) -> int:
	return _versions.get(content_name, 0)


static func id_from_slug(content_name: StringName, slug: StringName) -> int:
	return registry_of(content_name).id_from_slug(slug)


static func load_by_id(
	content_name: StringName,
	id: int,
	cache_mode: ResourceLoader.CacheMode = ResourceLoader.CACHE_MODE_REUSE
) -> Resource:
	# Check cache first
	if _cache_enabled:
		var cache_key: String = "%s_%d" % [content_name, id]
		if _resource_cache.has(cache_key):
			return _resource_cache[cache_key]
	
	var path: StringName = registry_of(content_name).path_from_id(id)
	if path.is_empty():
		return null
	
	var resource: Resource = ResourceLoader.load(path, "", cache_mode)
	
	# Cache the result
	if _cache_enabled and resource != null:
		var cache_key: String = "%s_%d" % [content_name, id]
		_resource_cache[cache_key] = resource
	
	return resource


static func load_by_slug(
	content_name: StringName,
	slug: StringName,
	cache_mode: ResourceLoader.CacheMode = ResourceLoader.CACHE_MODE_REUSE
) -> Resource:
	# Check cache first
	if _cache_enabled:
		var cache_key: String = "%s_%s" % [content_name, slug]
		if _resource_cache.has(cache_key):
			return _resource_cache[cache_key]
	
	var path: StringName = registry_of(content_name).path_from_slug(slug)
	if path.is_empty():
		return null
	
	var resource: Resource = ResourceLoader.load(path, "", cache_mode)
	
	# Cache the result
	if _cache_enabled and resource != null:
		var cache_key: String = "%s_%s" % [content_name, slug]
		_resource_cache[cache_key] = resource
	
	return resource


static func preload_all_content(content_name: StringName) -> Dictionary:
	"""
	Pre-load all resources of a specific content type into memory cache.
	Returns statistics about the preload operation.
	"""
	var start_time := Time.get_ticks_msec()
	var start_memory := OS.get_static_memory_usage()
	var loaded_count := 0
	var failed_count := 0
	
	var registry := registry_of(content_name)
	if registry == null:
		push_error("[ContentRegistryHub] Cannot preload '%s': registry not found" % content_name)
		return {
			"success": false,
			"error": "Registry not found"
		}
	
	# Load the content index to get all entries
	var index_path := "res://source/common/registry/indexes/%s_index.tres" % content_name
	var content_index: ContentIndex = ResourceLoader.load(index_path)
	if content_index == null:
		push_error("[ContentRegistryHub] Cannot preload '%s': index file not found at %s" % [content_name, index_path])
		return {
			"success": false,
			"error": "Index file not found"
		}
	
	# Load all resources from the index
	for entry in content_index.entries:
		var id: int = entry.get(&"id", 0)
		if id == 0:
			continue
		
		# Use load_by_id which will cache it
		var resource := load_by_id(content_name, id)
		if resource != null:
			loaded_count += 1
		else:
			failed_count += 1
			var path := registry.path_from_id(id)
			push_warning("[ContentRegistryHub] Failed to preload %s ID %d at %s" % [content_name, id, path])
	
	var elapsed_ms := Time.get_ticks_msec() - start_time
	var memory_increase := OS.get_static_memory_usage() - start_memory
	
	var stats := {
		"success": true,
		"content_name": content_name,
		"loaded_count": loaded_count,
		"failed_count": failed_count,
		"elapsed_ms": elapsed_ms,
		"elapsed_sec": elapsed_ms / 1000.0,
		"memory_increase_bytes": memory_increase,
		"memory_increase_mb": memory_increase / 1024.0 / 1024.0
	}
	
	print("[ContentRegistryHub] Preloaded %d %s in %.2fs (+%.2f MB)" % [
		loaded_count, 
		content_name, 
		stats.elapsed_sec, 
		stats.memory_increase_mb
	])
	
	if failed_count > 0:
		push_warning("[ContentRegistryHub] %d items failed to load" % failed_count)
	
	return stats


static func get_cache_stats() -> Dictionary:
	"""Returns statistics about the current cache state"""
	var total_size := 0
	for resource in _resource_cache.values():
		if resource:
			# Rough estimate - doesn't include all internal Resource data
			total_size += 1000  # Base size estimate per resource
	
	return {
		"enabled": _cache_enabled,
		"cached_count": _resource_cache.size(),
		"estimated_size_bytes": total_size,
		"estimated_size_mb": total_size / 1024.0 / 1024.0
	}


static func clear_cache() -> void:
	"""Clears all cached resources. Useful for testing or low-memory situations."""
	_resource_cache.clear()
	print("[ContentRegistryHub] Cache cleared")


static func set_cache_enabled(enabled: bool) -> void:
	"""Enable or disable caching. When disabled, resources are always loaded from disk."""
	_cache_enabled = enabled
	if not enabled:
		print("[ContentRegistryHub] Cache disabled")
	else:
		print("[ContentRegistryHub] Cache enabled")


class CachedContent:
	pass
