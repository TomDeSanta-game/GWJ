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
	log_debug("STORE: _ready called")
	print("STORE: Store UI is being initialized")
	
	print_node_tree(self, 0)
	
	var gc = find_game_controller()
	log_debug("STORE: game_controller found: " + str(gc != null))
	if gc:
		game_controller = gc
		player_money = game_controller.money if "money" in game_controller else 0
		player_upgrades = game_controller.get_upgrades() if game_controller.has_method("get_upgrades") else {}
		print("STORE: Got money: ", player_money, " and upgrades: ", player_upgrades)
	
	anchor_right = 1.0
	anchor_bottom = 1.0
	
	upgrade_names = {
		"multi_shot": "Multi Shot",
		"launch_speed": "Launch Speed",
		"cooldown": "Fast Reload"
	}
	
	upgrade_descriptions = {
		"multi_shot": {
			"description": "Shoot multiple shapes at once",
			"base_price": 50,
			"price_scale": 100,
			"max_level": 5
		},
		"launch_speed": {
			"description": "Increase projectile velocity",
			"base_price": 30,
			"price_scale": 70,
			"max_level": 5
		},
		"cooldown": {
			"description": "Reduce reload time",
			"base_price": 40,
			"price_scale": 80,
			"max_level": 5
		}
	}
	
	var store_container = get_node_or_null("StoreContainer")
	if store_container:
		store_container.anchor_right = 1.0
		store_container.anchor_bottom = 1.0
		store_container.size_flags_horizontal = SIZE_EXPAND_FILL
		store_container.size_flags_vertical = SIZE_EXPAND_FILL
	
	store_items = []
	var item_grid = get_node_or_null("StoreContainer/ItemsMargin/ItemsPanel/PanelMargin/ItemGrid")
	if item_grid:
		for i in range(item_grid.get_child_count()):
			var item_name = "StoreItem" + str(i+1)
			var item = item_grid.get_node_or_null(item_name)
			if item is Panel:
				log_debug("STORE: Found store item: " + item_name)
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
		print("STORE: Back button connected to close function")
	
	update_money_display()
	setup_price_displays()
	setup_item_descriptions()
	select_category(0)

func print_node_tree(node, indent):
	var indent_str = ""
	for i in range(indent):
		indent_str += "  "
		
	print(indent_str + node.name + " (" + node.get_class() + ")")
	
	for child in node.get_children():
		print_node_tree(child, indent + 1)

func log_debug(message):
	if Log:
		Log.debug(message)
	else:
		print(message)
		
func log_error(message):
	if Log:
		Log.error(message)
	else:
		print("ERROR: " + message)

func find_game_controller():
	var possible_paths = [
		"/root/Main/GameController", 
		"/root/MainNew/GameController",
		"/root/Node/MainNew/GameController",
		"/root/Node2D/MainNew/GameController",
		"../../GameController"
	]
	
	for path in possible_paths:
		var node = get_node_or_null(path)
		if node and node.has_method("toggle_store_direct") and ("money" in node or node.has_method("get_money")):
			print("STORE: Found game controller at path: ", path)
			return node
	
	var root = get_tree().root
	for child in root.get_children():
		var node = find_controller_in_children(child)
		if node:
			print("STORE: Found game controller through search")
			return node
			
	print("STORE: Could not find game controller!")
	return null

func find_controller_in_children(node):
	if node.name == "GameController" and node.has_method("toggle_store_direct") and ("money" in node or node.has_method("get_money")):
		return node
		
	for child in node.get_children():
		var result = find_controller_in_children(child)
		if result:
			return result
			
	return null

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
			print("STORE: Updated money display to: ", player_money, " using path: ", path)
			found = true
			break
	
	if not found:
		print("STORE: WARNING - Could not find money display label with any of the known paths")

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
			print("STORE: Found item container at path: ", path)
			break
	
	if not item_container:
		print("STORE: ERROR - Could not find any item container!")
		return
		
	for i in range(item_container.get_child_count()):
		var item = item_container.get_child(i)
		
		var price_label = null
		var price_paths = ["PriceBackground/Price", "PriceContainer/PriceAmount", "Price", "PriceAmount"]
		
		for path in price_paths:
			price_label = item.get_node_or_null(path)
			if price_label:
				print("STORE: Found price label at path: ", path, " for item ", i)
				break
				
		if price_label:
			var upgrade_key = get_upgrade_key_for_item(i)
			if upgrade_key in upgrade_descriptions:
				var current_level = player_upgrades.get(upgrade_key, 0)
				print("STORE: Item ", i, " is upgrade: ", upgrade_key, " at level: ", current_level)
				
				if current_level >= upgrade_descriptions[upgrade_key].max_level:
					price_label.text = "MAX"
					prices[upgrade_key] = 999999
				else:
					var price = get_price_for_upgrade(upgrade_key)
					price_label.text = str(price)
					prices[upgrade_key] = price
					print("STORE: Set price for ", upgrade_key, " to ", price)
					
				var buy_button = null
				var button_paths = ["BuyButton", "Button"]
				
				for path in button_paths:
					buy_button = item.get_node_or_null(path)
					if buy_button:
						break
						
				if buy_button:
					buy_button.disabled = prices[upgrade_key] > player_money
					print("STORE: Button for ", upgrade_key, " enabled: ", not buy_button.disabled)
					
					if not buy_button.is_connected("pressed", Callable(self, "_on_item_pressed").bind(i)):
						buy_button.pressed.connect(_on_item_pressed.bind(i))
						print("STORE: Connected button for item ", i)

func setup_item_descriptions():
	for i in range(store_items.size()):
		var item = store_items[i]
		var desc_label = item.get_node_or_null("ItemDescription")
		
		if desc_label:
			var upgrade_key = get_upgrade_key_for_item(i)
			if upgrade_key in upgrade_descriptions:
				desc_label.text = upgrade_descriptions[upgrade_key].description

func _on_item_pressed(item_index):
	var upgrade_key = get_upgrade_key_for_item(item_index)
	if not upgrade_key:
		print("ERROR: Invalid upgrade key for item index: ", item_index)
		return
		
	if not upgrade_key in prices:
		print("ERROR: Upgrade key not found in prices: ", upgrade_key)
		return
		
	var price = prices[upgrade_key]
	print("STORE: Attempting to purchase ", upgrade_key, " for ", price, " money: ", player_money)
	
	if player_money >= price:
		var current_level = player_upgrades.get(upgrade_key, 0)
		if current_level >= upgrade_descriptions[upgrade_key].max_level:
			print("STORE: Cannot purchase - max level reached for ", upgrade_key)
			return
			
		player_money -= price
		player_upgrades[upgrade_key] = current_level + 1
		
		print("STORE: Purchase successful! New level for ", upgrade_key, ": ", player_upgrades[upgrade_key])
		
		update_money_display()
		setup_price_displays()
		
		print("STORE: DIRECTLY EMITTING UPGRADE SIGNAL: ", player_upgrades)
		SignalBus.emit_upgrades_changed(player_upgrades)
		
		var gc = find_game_controller()
		if gc:
			print("STORE: Updating game controller with new data")
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
		print("STORE: Cannot afford upgrade ", upgrade_key, " - costs ", price, " but only have ", player_money)

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
	print("STORE: Close button pressed, closing store")
	if game_controller and game_controller.has_method("toggle_store_direct"):
		game_controller.toggle_store_direct()
	else:
		visible = false
		get_tree().paused = false
		print("STORE: No game controller found, manually hiding store")

func update_with_player_data(money, upgrades):
	player_money = money
	player_upgrades = upgrades.duplicate()
	update_money_display()
	setup_price_displays()
