extends Control

signal back_pressed

@onready var scene_manager = get_node("/root/SceneManager")

var prices = {
	"item1": 100,
	"item2": 150,
	"item3": 200,
	"multi_shot": 500  # Price for multi-shot upgrade
}

var store_items = []
var player_money = 0
var player_upgrades = {}  # Track player upgrades

# Find the game controller node using multiple approaches
func find_game_controller():
	# Try various possible paths
	var possible_paths = [
		"/root/MainNew",       # Most likely correct path based on project.godot
		"/root/Main", 
		"/root/Game",
		get_tree().current_scene.get_path() # Current scene path
	]
	
	for path in possible_paths:
		var node = get_node_or_null(path)
		if node and (node.has_method("get_upgrades") or has_property(node, "money") or has_property(node, "upgrades")):
			print("Found game controller at: ", path)
			return node
	
	# If not found by path, try to find by searching current scene
	var current_scene = get_tree().current_scene
	if current_scene:
		print("Current scene is: ", current_scene.name)
		# If the current scene itself has the required methods
		if current_scene.has_method("get_upgrades") or has_property(current_scene, "money"):
			return current_scene
	
	print("Could not find game controller by any method")
	return null

# Helper function to check if a node has a property
func has_property(node: Node, property_name: String) -> bool:
	# Use property existence check
	return property_name in node

func _ready():
	var game_controller = find_game_controller()
	if game_controller:
		player_money = game_controller.money
		# Load existing upgrades if available
		if game_controller.has_method("get_upgrades"):
			player_upgrades = game_controller.get_upgrades()
		else:
			player_upgrades = {"multi_shot": 1}  # Default to 1 shot
	
	var back_button = get_node_or_null("StoreContainer/FooterMargin/Footer/BackButton")
	if back_button:
		back_button.pressed.connect(_on_back_button_pressed)
	else:
		pass
	
	update_money_display()
	
	var item_grid = get_node_or_null("StoreContainer/ItemsMargin/ItemsPanel/PanelMargin/ItemGrid")
	if item_grid:
		store_items = [
			item_grid.get_node_or_null("StoreItem1"),
			item_grid.get_node_or_null("StoreItem2"),
			item_grid.get_node_or_null("StoreItem3")
		]
		
		store_items = store_items.filter(func(item): return item != null)
		
		setup_price_displays()
		setup_item_interaction()
	
	setup_category_buttons()
	select_category(0)
	
	# Update item descriptions based on owned upgrades
	update_item_descriptions()

func update_money_display():
	var coin_amount = $StoreContainer/HeaderMargin/Header/CoinDisplay/CoinAmount
	if coin_amount:
		coin_amount.text = str(player_money)

func setup_price_displays():
	for i in range(store_items.size()):
		var item = store_items[i]
		var item_key = "item" + str(i + 1)
		var price = prices[item_key]
		
		var price_container = item.get_node("PriceContainer")
		var price_amount = price_container.get_node("PriceAmount")
		price_amount.text = str(price)
		
		item.mouse_entered.connect(_on_item_mouse_entered.bind(item))
		item.mouse_exited.connect(_on_item_mouse_exited.bind(item))

func setup_item_interaction():
	for i in range(store_items.size()):
		var item = store_items[i] 
		
		if not item.has_node("ClickDetector"):
			var click_detector = Button.new()
			click_detector.name = "ClickDetector"
			click_detector.flat = true
			click_detector.layout_mode = 1
			click_detector.anchors_preset = Control.PRESET_FULL_RECT
			click_detector.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
			item.add_child(click_detector)
			
			click_detector.pressed.connect(_on_item_clicked.bind(i))

func setup_category_buttons():
	var categories = $StoreContainer/CategoryMargin/CategoriesPanel/Categories.get_children()
	for i in range(categories.size()):
		categories[i].pressed.connect(_on_category_selected.bind(i))

func select_category(index):
	var categories = $StoreContainer/CategoryMargin/CategoriesPanel/Categories.get_children()
	for i in range(categories.size()):
		var category = categories[i]
		var label = category.get_node("CategoryLabel" + str(i + 1))
		
		if i == index:
			label.modulate = Color(1, 1, 1, 1)
			category.modulate = Color(1, 1, 1, 1)
		else:
			label.modulate = Color(1, 1, 1, 0.5)
			category.modulate = Color(1, 1, 1, 0.7)
	
	for i in range(store_items.size()):
		store_items[i].visible = (i % categories.size() == index)

func _on_category_selected(category_index):
	select_category(category_index)

func _on_item_mouse_entered(item):
	item.modulate = Color(1.1, 1.1, 1.1)
	
	var tween = create_tween()
	tween.tween_property(item, "scale", Vector2(1.05, 1.05), 0.1).set_ease(Tween.EASE_OUT)

func _on_item_mouse_exited(item):
	item.modulate = Color(1, 1, 1)
	
	var tween = create_tween()
	tween.tween_property(item, "scale", Vector2(1, 1), 0.1).set_ease(Tween.EASE_IN)

func _on_item_clicked(item_index):
	var item = store_items[item_index]
	var item_key = "item" + str(item_index + 1)
	var price = prices[item_key]
	
	var tween = create_tween()
	tween.tween_property(item, "modulate", Color(1.5, 1.5, 1.5), 0.1)
	tween.tween_property(item, "modulate", Color(1, 1, 1), 0.1)
	
	if player_money >= price:
		player_money -= price
		update_money_display()
		
		var game_controller = find_game_controller()
		if game_controller:
			game_controller.money = player_money
			SignalBus.emit_money_changed(player_money)
			
			# Handle special upgrades based on item index
			if item_index == 0:  # First item is multi-shot upgrade
				if not player_upgrades.has("multi_shot"):
					player_upgrades["multi_shot"] = 1
				
				# Increase multi_shot count
				player_upgrades["multi_shot"] += 1
				print("Multi-shot upgraded to: ", player_upgrades["multi_shot"])
				
				# Update game controller with new upgrades
				if game_controller.has_method("set_upgrades"):
					game_controller.set_upgrades(player_upgrades)
				else:
					game_controller.upgrades = player_upgrades
					SignalBus.emit_upgrades_changed(player_upgrades)
				
				# Update item description
				update_item_descriptions()
	else:
		tween = create_tween()
		tween.tween_property(item, "modulate", Color(1.5, 0.5, 0.5), 0.1)
		tween.tween_property(item, "modulate", Color(1, 1, 1), 0.2)

func update_item_descriptions():
	# Update multi-shot description if available
	if store_items.size() > 0:
		var multi_shot_item = store_items[0]
		var description = multi_shot_item.get_node_or_null("ItemDescription")
		if description:
			var shot_count = player_upgrades.get("multi_shot", 1)
			description.text = "Multi-Shot: " + str(shot_count) + " → " + str(shot_count + 1)

func _on_back_button_pressed():
	var back_btn = get_node_or_null("StoreContainer/FooterMargin/Footer/BackButton")
	if back_btn:
		var tween = create_tween()
		tween.tween_property(back_btn, "modulate", Color(1.5, 1.5, 1.5), 0.1)
		tween.tween_property(back_btn, "modulate", Color(1, 1, 1), 0.1)
	
	scene_manager.change_scene("res://scenes/MainNew.tscn", { "pattern": "curtains" })

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("open") or event.is_action_pressed("ui_cancel"):
		scene_manager.change_scene("res://scenes/MainNew.tscn", { "pattern": "curtains" })
