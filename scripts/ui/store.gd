extends Control

signal back_pressed

# Configuration
var prices = {
	"item1": 100,
	"item2": 150,
	"item3": 200
}

# Item references
var store_items = []

func _ready():
	# Setup button connections
	$StoreContainer/FooterMargin/Footer/BackButton.pressed.connect(_on_back_button_pressed)
	
	# Store all item references
	store_items = [
		$StoreContainer/ItemsMargin/ItemGrid/StoreItem1,
		$StoreContainer/ItemsMargin/ItemGrid/StoreItem2,
		$StoreContainer/ItemsMargin/ItemGrid/StoreItem3
	]
	
	# Setup price displays
	setup_price_displays()
	
	# Make items interactive
	setup_item_interaction()
	
	# Setup category buttons
	setup_category_buttons()
	
	# Select first category by default
	select_category(0)

func setup_price_displays():
	for i in range(store_items.size()):
		var item = store_items[i]
		var item_key = "item" + str(i + 1)
		var _price = prices[item_key]  # Using underscore prefix for now
		
		# Set the visual price indicator - placeholder for future price display
		var price_container = item.get_node("PriceContainer")
		var _price_display = price_container.get_node("Price")  # Using underscore prefix
		
		# Setup hover effect
		item.mouse_entered.connect(_on_item_mouse_entered.bind(item))
		item.mouse_exited.connect(_on_item_mouse_exited.bind(item))

func setup_item_interaction():
	for i in range(store_items.size()):
		var item = store_items[i] 
		
		# Add click detector
		if not item.has_node("ClickDetector"):
			var click_detector = Button.new()
			click_detector.name = "ClickDetector"
			click_detector.flat = true
			click_detector.layout_mode = 1
			click_detector.anchors_preset = Control.PRESET_FULL_RECT
			click_detector.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
			item.add_child(click_detector)
			
			# Connect the pressed signal
			click_detector.pressed.connect(_on_item_clicked.bind(i))

func setup_category_buttons():
	# Setup category buttons
	var categories = $StoreContainer/CategoryMargin/Categories.get_children()
	for i in range(categories.size()):
		categories[i].pressed.connect(_on_category_selected.bind(i))

func select_category(index):
	# Visual feedback for selected category
	var categories = $StoreContainer/CategoryMargin/Categories.get_children()
	for i in range(categories.size()):
		var category = categories[i]
		var icon = category.get_child(0)
		
		if i == index:
			# Selected state
			icon.modulate = Color(1, 1, 1, 1)
			category.modulate = Color(1, 1, 1, 1)
		else:
			# Unselected state
			icon.modulate = Color(1, 1, 1, 0.5)
			category.modulate = Color(1, 1, 1, 0.7)
	
	# Update visible items based on category
	for i in range(store_items.size()):
		store_items[i].visible = (i % categories.size() == index)

func _on_category_selected(category_index):
	select_category(category_index)

func _on_item_mouse_entered(item):
	# Highlight effect
	item.modulate = Color(1.1, 1.1, 1.1)
	
	# Scale effect
	var tween = create_tween()
	tween.tween_property(item, "scale", Vector2(1.05, 1.05), 0.1).set_ease(Tween.EASE_OUT)

func _on_item_mouse_exited(item):
	# Remove highlight
	item.modulate = Color(1, 1, 1)
	
	# Reset scale
	var tween = create_tween()
	tween.tween_property(item, "scale", Vector2(1, 1), 0.1).set_ease(Tween.EASE_IN)

func _on_item_clicked(item_index):
	# Get the item and price
	var item = store_items[item_index]
	var item_key = "item" + str(item_index + 1)
	var price = prices[item_key]
	
	# Flash effect to acknowledge click
	var tween = create_tween()
	tween.tween_property(item, "modulate", Color(1.5, 1.5, 1.5), 0.1)
	tween.tween_property(item, "modulate", Color(1, 1, 1), 0.1)
	
	# Here you would check if player has enough coins
	# For now just print the purchase attempt
	print("Attempting to purchase " + item_key + " for " + str(price) + " coins")
	
	# TODO: Implement actual purchase logic
	# GameState.purchase_item(item_key, price)

func _on_back_button_pressed():
	# Flash effect
	var back_btn = $StoreContainer/FooterMargin/Footer/BackButton
	var tween = create_tween()
	tween.tween_property(back_btn, "modulate", Color(1.5, 1.5, 1.5), 0.1)
	tween.tween_property(back_btn, "modulate", Color(1, 1, 1), 0.1)
	
	# Emit signal to go back
	emit_signal("back_pressed") 