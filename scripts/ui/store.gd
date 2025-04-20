extends Control

var Log = null
var player_money = 0
var player_upgrades = {}
var game_controller = null
var store_items = []
var prices = {}
var upgrade_names = {}
var upgrade_descriptions = {}

func _ready():
	Log = get_node_or_null("/root/Log")
	if Log:
		Log.debug("STORE: _ready called")
	
	# Initialize UI first
	anchor_right = 1.0
	anchor_bottom = 1.0
	
	upgrade_names = {
		"multi_shot": "Multi Shot",
		"launch_speed": "Launch Speed",
		"cooldown": "Fast Reload"
	}
	
	upgrade_descriptions = {
		"multi_shot": {
			"description": "Launch multiple shapes at once",
			"base_price": 40,
			"price_scale": 70,
			"max_level": 5
		},
		"launch_speed": {
			"description": "Increase projectile velocity by 50",
			"base_price": 25,
			"price_scale": 50,
			"max_level": 5
		},
		"cooldown": {
			"description": "Reduce reload time by 0.05s",
			"base_price": 30,
			"price_scale": 60,
			"max_level": 5
		}
	}
	
	var store_container = get_node_or_null("StoreContainer")
	if store_container:
		store_container.anchor_right = 1.0
		store_container.anchor_bottom = 1.0
		store_container.size_flags_horizontal = SIZE_EXPAND_FILL
		store_container.size_flags_vertical = SIZE_EXPAND_FILL
	
	setup_ui()
	update_money_display()
	setup_price_displays()
	setup_item_descriptions()
	select_category(0)
	
	# Use call_deferred for controller finding to happen after initialization
	call_deferred("_init_controller_search")

func _init_controller_search():
	# Queue a timer to delay controller search
	if is_inside_tree():
		var timer = get_tree().create_timer(0.1)
		if timer:
			timer.timeout.connect(_on_controller_search_timeout)
	else:
		# We can't safely proceed
		if Log:
			Log.error("STORE: Cannot initialize controller search, not in tree")

func _on_controller_search_timeout():
	# Use call_deferred to avoid potential frame issues
	call_deferred("_begin_controller_update")

func _begin_controller_update():
	# Safety check - must be in tree
	if not is_inside_tree():
		return
		
	# Use call_deferred to start an async process without blocking this function
	call_deferred("_start_controller_task")

# Starts the async controller search process
func _start_controller_task():
	# Safety checks - must be in tree 
	if not is_inside_tree():
		return
		
	# Try fast path first (direct lookup)
	var gc = _find_direct_controller()
	if gc:
		_update_store_with_controller(gc)
		return
		
	# Try tree search if root is ready
	var tree = get_tree()
	if tree and tree.root:
		gc = _find_controller_in_tree_search()
		if gc:
			_update_store_with_controller(gc)
			return
		
	# Directly schedule the search via call_deferred
	call_deferred("_schedule_delayed_search")

# Updates the store with controller data (no awaits)
func _update_store_with_controller(gc):
	# Skip if we didn't find a valid controller
	if not gc or not is_instance_valid(gc):
		return
		
	# Store controller reference
	game_controller = gc
	
	# Cache data immediately
	var money_value = 0
	var upgrades_dict = {}
	
	# Safe access to money
	if is_instance_valid(gc):
		if gc.get("money") != null:
			money_value = gc.money
		elif gc.has_method("get_money"):
			money_value = gc.get_money()
	
	# Safe access to upgrades
	if is_instance_valid(gc) and gc.has_method("get_upgrades"):
		var upgrades = gc.get_upgrades()
		if upgrades != null:
			upgrades_dict = upgrades.duplicate()
	
	# Update store data
	if is_instance_valid(self):
		player_money = money_value
		player_upgrades = upgrades_dict
		
		# Log if available
		if is_instance_valid(Log):
			Log.debug("STORE: Got money: " + str(player_money) + " and upgrades: " + str(player_upgrades))
	
	# Update UI components
	if is_instance_valid(self) and is_inside_tree():
		call_deferred("_update_ui_safely")

func deferred_find_controller():
	# This function is kept for compatibility, but uses the new pattern
	_init_controller_search()

# Simple controller finder that returns a Promise-like object
func _find_controller_safely():
	# Only proceed if we're in the tree
	if not is_inside_tree():
		var promise = _FindControllerPromise.new(self)
		promise.start_search()
		return promise
		
	# Try direct path first (most efficient)
	var controller = _find_direct_controller()
	if controller:
		return _create_fulfilled_promise(controller)
	
	# Try tree search next
	var tree = get_tree()
	if tree and tree.root:
		controller = _find_controller_in_tree_search()
		if controller:
			return _create_fulfilled_promise(controller)
	
	# No controller found with fast paths, use delayed search
	var promise = _FindControllerPromise.new(self)
	promise.start_search()
	return promise

# Helper class to avoid direct await in our function
class _FindControllerPromise:
	signal completed(result)
	var store_ref: WeakRef
	
	func _init(store):
		store_ref = weakref(store)
		
	func start_search():
		# This will be called with call_deferred
		_search_after_frame()
		
	func _search_after_frame():
		var store = store_ref.get_ref()
		if not store or not store.is_inside_tree():
			completed.emit(null)
			return
			
		# Get tree reference
		var tree = store.get_tree()
		if not tree:
			completed.emit(null)
			return
			
		# Wait a frame
		await tree.process_frame
		
		# Check store is still valid
		store = store_ref.get_ref()
		if not store or not store.is_inside_tree():
			completed.emit(null)
			return
			
		# Try direct path again
		var controller = store._find_direct_controller()
		
		# If that fails, try tree search
		if not controller:
			controller = store._find_controller_in_tree_search()
			
		# Emit result
		completed.emit(controller)
		
	# Make this awaitable (like a Promise)
	func _to_string():
		return "FindControllerPromise"

# Create a simple promise-like object that's already fulfilled
func _create_fulfilled_promise(value):
	var promise = _FulfilledPromise.new()
	promise.value = value
	return promise
	
class _FulfilledPromise:
	var value = null
	signal completed(result)
	
	func _init():
		# Immediately emit the completed signal in the next frame
		call_deferred("_emit_completed")
	
	func _emit_completed():
		completed.emit(value)
		
	# Make this awaitable (like a Promise)
	func _to_string():
		return "FulfilledPromise"

# Direct path finder - no await, just checks common paths
func _find_direct_controller():
	if not is_inside_tree():
		return null
		
	var paths = [
		"/root/Main/GameController", 
		"/root/MainNew/GameController",
		"/root/Node/MainNew/GameController",
		"/root/Node2D/MainNew/GameController",
		"../../GameController"
	]
	
	for p in paths:
		var node = get_node_or_null(p)
		if node and _is_game_controller(node):
			return node
			
	return null

# Determines if we should retry after a frame
func _should_retry_after_frame():
	if not is_inside_tree():
		return false
		
	var scene_tree = get_tree()
	if not scene_tree:
		return false
		
	var root = scene_tree.root
	if not root:
		return false
	
	# Check if we're in a partially loaded state where waiting a frame might help
	return scene_tree.current_scene == null or not scene_tree.paused_before_exit

# Retry function that handles the await
func _retry_find_controller_after_frame():
	return null

# Tree search without awaits
func _find_controller_in_tree_search():
	if not is_inside_tree():
		return null
		
	var tree = get_tree()
	if not tree or not tree.root:
		return null
		
	return _find_controller_in_tree(tree.root)

func _find_controller_in_tree(root_node):
	# Early return if root is null
	if root_node == null:
		return null
	
	var found_controller = null
	
	# Fixed child count to avoid any potential race conditions
	var child_count = root_node.get_child_count()
	
	# First level search with safety bounds
	var i = 0
	while i < child_count and i < root_node.get_child_count() and found_controller == null:
		var child = root_node.get_child(i)
		if child != null and child.name == "GameController":
			# Direct check without calling methods
			if child.has_method("toggle_store_direct"):
				if "money" in child or child.has_method("get_money"):
					found_controller = child
		i += 1
	
	# If not found in first level, check second level without recursion
	if found_controller == null:
		i = 0
		while i < child_count and i < root_node.get_child_count() and found_controller == null:
			var first_level = root_node.get_child(i)
			if first_level != null:
				var gc_count = first_level.get_child_count()
				var j = 0
				while j < gc_count and j < first_level.get_child_count() and found_controller == null:
					var second_level = first_level.get_child(j)
					if second_level != null and second_level.name == "GameController":
						if second_level.has_method("toggle_store_direct"):
							if "money" in second_level or second_level.has_method("get_money"):
								found_controller = second_level
					j += 1
			i += 1
	
	# Only log if we have a valid logger
	if is_instance_valid(Log) and found_controller != null:
		Log.debug("STORE: Found controller in tree")
			
	return found_controller

# Helper method to check if a node is the game controller
func _is_game_controller(node):
	if node == null:
		return false
		
	return node.name == "GameController" and node.has_method("toggle_store_direct") and ("money" in node or node.has_method("get_money"))

func setup_ui():
	store_items = []
	var item_grid = get_node_or_null("StoreContainer/ItemsMargin/ItemsPanel/PanelMargin/ItemGrid")
	if item_grid:
		for i in range(item_grid.get_child_count()):
			var item_name = "StoreItem" + str(i+1)
			var item = item_grid.get_node_or_null(item_name)
			if item is Panel:
				if Log:
					Log.debug("STORE: Found store item: " + item_name)
				store_items.append(item)
				
				var existing_button = item.get_node_or_null("BuyButton")
				if existing_button:
					existing_button.visible = true
					existing_button.text = "BUY"
					existing_button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
					
					if existing_button.is_connected("pressed", Callable(self, "_on_item_pressed").bind(i)):
						existing_button.disconnect("pressed", Callable(self, "_on_item_pressed").bind(i))
					existing_button.pressed.connect(_on_item_pressed.bind(i))
				else:
					var buy_button = Button.new()
					buy_button.name = "BuyButton"
					buy_button.text = "BUY"
					buy_button.flat = false
					buy_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
					buy_button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
					buy_button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
					buy_button.position = Vector2(item.size.x/2 - 50, item.size.y/2)
					buy_button.size = Vector2(100, 40)
					buy_button.pressed.connect(_on_item_pressed.bind(i))
					item.add_child(buy_button)
				
				var level_label = Label.new()
				level_label.name = "LevelLabel"
				level_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
				level_label.position = Vector2(item.size.x/2 - 40, item.size.y - 30)
				level_label.size = Vector2(80, 20)
				level_label.theme_type_variation = "HeaderSmall"
				item.add_child(level_label)
				
				var panel_button = Button.new()
				panel_button.flat = true
				panel_button.size_flags_horizontal = SIZE_EXPAND_FILL
				panel_button.size_flags_vertical = SIZE_EXPAND_FILL
				panel_button.mouse_filter = Control.MOUSE_FILTER_PASS
				panel_button.name = "PanelButton"
				item.add_child(panel_button)
	
	var category_tabs = get_node_or_null("StoreContainer/CategoryMargin/CategoriesPanel/Categories")
	if category_tabs:
		for i in range(category_tabs.get_child_count()):
			var tab = category_tabs.get_child(i)
			if tab is Button:
				tab.pressed.connect(_on_category_selected.bind(i))
	
	var back_button = get_node_or_null("StoreContainer/FooterMargin/Footer/BackButton")
	if back_button:
		if back_button.is_connected("pressed", _on_close_button_pressed):
			back_button.disconnect("pressed", _on_close_button_pressed)
		back_button.pressed.connect(_on_close_button_pressed)
		back_button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		if Log:
			Log.debug("STORE: Back button connected to close function")

func get_upgrade_key_for_item(item_index):
	match item_index:
		0: return "multi_shot"
		1: return "launch_speed"
		2: return "cooldown"
		_: return ""

func get_price_for_upgrade(upgrade_key):
	var base_price = upgrade_descriptions[upgrade_key].base_price
	var level = player_upgrades.get(upgrade_key, 0)
	var price_scale = upgrade_descriptions[upgrade_key].price_scale
	
	return base_price + (level * price_scale)

func update_money_display():
	var paths = [
		"MoneyDisplay/MoneyAmount",
		"StoreContainer/HeaderMargin/Header/CoinDisplay/CoinAmount",
		"HeaderMargin/Header/CoinDisplay/CoinAmount",
		"Header/CoinDisplay/CoinAmount",
		"CoinDisplay/CoinAmount"
	]
	
	var found = false
	for path in paths:
		var label = get_node_or_null(path)
		if label:
			label.text = str(player_money)
			if Log:
				Log.debug("STORE: Updated money display to: " + str(player_money) + " using path: " + path)
			found = true
			break
	
	if not found and Log:
		Log.warning("STORE: Could not find money display label with any of the known paths")

func setup_price_displays():
	prices.clear()
	
	var possible_containers = [
		"ItemContainer",
		"StoreContainer/ItemsMargin/ItemsPanel/PanelMargin/ItemGrid", 
		"ItemsMargin/ItemsPanel/PanelMargin/ItemGrid",
		"ItemsPanel/PanelMargin/ItemGrid",
		"PanelMargin/ItemGrid",
		"ItemGrid"
	]
	
	var item_container = null
	for path in possible_containers:
		var container = get_node_or_null(path)
		if container:
			item_container = container
			if Log:
				Log.debug("STORE: Found item container at path: " + path)
			break
	
	if not item_container:
		if Log:
			Log.error("STORE: Could not find any item container!")
		return
		
	for i in range(item_container.get_child_count()):
		var item = item_container.get_child(i)
		
		var price_label = null
		var price_paths = ["PriceBackground/Price", "PriceContainer/PriceAmount", "Price", "PriceAmount"]
		
		for path in price_paths:
			price_label = item.get_node_or_null(path)
			if price_label:
				if Log:
					Log.debug("STORE: Found price label at path: " + path + " for item " + str(i))
				break
				
		if price_label:
			var upgrade_key = get_upgrade_key_for_item(i)
			if upgrade_key in upgrade_descriptions:
				var current_level = player_upgrades.get(upgrade_key, 0)
				if Log:
					Log.debug("STORE: Item " + str(i) + " is upgrade: " + upgrade_key + " at level: " + str(current_level))
				
				if current_level >= upgrade_descriptions[upgrade_key].max_level:
					price_label.text = "MAX"
					prices[upgrade_key] = 999999
				else:
					var price = get_price_for_upgrade(upgrade_key)
					price_label.text = str(price)
					prices[upgrade_key] = price
					if Log:
						Log.debug("STORE: Set price for " + upgrade_key + " to " + str(price))
				
				var level_label = item.get_node_or_null("LevelLabel")
				if level_label:
					level_label.text = "Level: " + str(current_level)
					
				var buy_button = null
				var button_paths = ["BuyButton", "Button"]
				
				for path in button_paths:
					buy_button = item.get_node_or_null(path)
					if buy_button:
						break
						
				if buy_button:
					buy_button.disabled = prices[upgrade_key] > player_money
					if Log:
						Log.debug("STORE: Button for " + upgrade_key + " enabled: " + str(not buy_button.disabled))
					
					if not buy_button.is_connected("pressed", Callable(self, "_on_item_pressed").bind(i)):
						buy_button.pressed.connect(_on_item_pressed.bind(i))
						if Log:
							Log.debug("STORE: Connected button for item " + str(i))

func setup_item_descriptions():
	for i in range(store_items.size()):
		var item = store_items[i]
		var desc_label = item.get_node_or_null("ItemDescription")
		
		if desc_label:
			var upgrade_key = get_upgrade_key_for_item(i)
			if upgrade_key in upgrade_descriptions:
				desc_label.text = upgrade_descriptions[upgrade_key].description

func _on_item_pressed(index):
	if Log:
		Log.debug("STORE: Item pressed: " + str(index))
	
	if not game_controller:
		var controller_promise = _find_controller_safely()
		var gc = await controller_promise.completed
		if gc:
			game_controller = gc
		else:
			if Log:
				Log.error("STORE: No game controller available for purchase!")
			return
	
	var upgrade_key = get_upgrade_key_for_item(index)
	if not upgrade_key:
		if Log:
			Log.error("STORE: Invalid upgrade key for item index: " + str(index))
		return
		
	if not upgrade_key in prices:
		if Log:
			Log.error("STORE: Upgrade key not found in prices: " + upgrade_key)
		return
		
	var price = prices[upgrade_key]
	if Log:
		Log.debug("STORE: Attempting to purchase " + upgrade_key + " for " + str(price) + " money: " + str(player_money))
	
	if player_money >= price:
		var current_level = player_upgrades.get(upgrade_key, 0)
		if current_level >= upgrade_descriptions[upgrade_key].max_level:
			if Log:
				Log.debug("STORE: Cannot purchase - max level reached for " + upgrade_key)
			return
			
		player_money -= price
		player_upgrades[upgrade_key] = current_level + 1
		
		if Log:
			Log.debug("STORE: Purchase successful! New level for " + upgrade_key + ": " + str(player_upgrades[upgrade_key]))
		
		update_money_display()
		setup_price_displays()
		
		if Log:
			Log.debug("STORE: Emitting upgrade signal with upgrades: " + str(player_upgrades))
		SignalBus.emit_upgrades_changed(player_upgrades)
		
		var controller_promise = _find_controller_safely()
		var gc = await controller_promise.completed
		if gc:
			if Log:
				Log.debug("STORE: Updating game controller with new data")
			if gc.has_method("set_money"):
				gc.set_money(player_money)
			else:
				gc.money = player_money
				
			if gc.has_method("set_upgrades"):
				gc.set_upgrades(player_upgrades)
			else:
				gc.upgrades = player_upgrades.duplicate()
				gc.update_launcher_with_upgrades()
	else:
		if Log:
			Log.debug("STORE: Cannot afford upgrade " + upgrade_key + " - costs " + str(price) + " but only have " + str(player_money))

func select_category(category_index):
	var category_tabs = get_node_or_null("StoreContainer/CategoryMargin/CategoriesPanel/Categories")
	if category_tabs:
		for i in range(category_tabs.get_child_count()):
			var tab = category_tabs.get_child(i)
			if tab is Button:
				tab.disabled = i == category_index

func _on_category_selected(category_index):
	select_category(category_index)

func _on_close_button_pressed():
	if Log:
		Log.debug("STORE: Close button pressed, closing store")
	if game_controller and game_controller.has_method("toggle_store_direct"):
		game_controller.toggle_store_direct()
	else:
		visible = false
		var tree = get_tree()
		if tree:
			tree.paused = false
		if Log:
			Log.debug("STORE: No game controller found, manually hiding store")

func update_with_player_data(controller):
	if controller:
		game_controller = controller
		var local_gc = game_controller  # Cache to prevent async issues
		player_money = local_gc.money if "money" in local_gc else 0
		player_upgrades = local_gc.get_upgrades() if local_gc.has_method("get_upgrades") else {}
		
		update_money_display()
		setup_price_displays()
	else:
		var controller_promise = _find_controller_safely()
		var gc = await controller_promise.completed
		if gc:
			game_controller = gc
			var local_gc = game_controller  # Cache to prevent async issues
			player_money = local_gc.money if "money" in local_gc else 0
			player_upgrades = local_gc.get_upgrades() if local_gc.has_method("get_upgrades") else {}
			
			update_money_display()
			setup_price_displays()

func _update_ui_safely():
	# Final validity check before UI updates
	if is_instance_valid(self) and is_inside_tree():
		update_money_display()
		setup_price_displays()

# This function contains the single await to isolate it completely
func _start_delayed_search():
	if not is_instance_valid(self) or not is_inside_tree():
		return
		
	var tree = get_tree()
	if not tree:
		return
		
	await tree.process_frame
	
	# After await, check validity again
	if not is_instance_valid(self) or not is_inside_tree():
		return
		
	# Try direct paths first after the wait
	var gc = _find_direct_controller()
	if not gc:
		# Try tree search as last resort
		gc = _find_controller_in_tree_search()
		
	if gc and is_instance_valid(self) and is_inside_tree():
		_update_store_with_controller(gc)

# This queues the delayed search without directly using await
func _schedule_delayed_search():
	# This function has no await, making it safe to call with call_deferred
	if is_instance_valid(self) and is_inside_tree():
		# Create a FindControllerPromise which handles the await internally
		var promise = _FindControllerPromise.new(self)
		promise.completed.connect(_on_delayed_search_completed)
		promise.start_search()

# Callback for when the delayed search completes
func _on_delayed_search_completed(controller):
	if controller and is_instance_valid(self) and is_inside_tree():
		_update_store_with_controller(controller)
