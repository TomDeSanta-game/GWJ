extends Control

signal back_pressed

var prices = {
	"item1": 100,
	"item2": 150,
	"item3": 200
}

var store_items = []
var player_money = 0

func _ready():
	var game_controller = get_node("/root/Main")
	if game_controller:
		player_money = game_controller.money
	
	$StoreContainer/FooterMargin/Footer/BackButton.pressed.connect(_on_back_button_pressed)
	
	update_money_display()
	
	store_items = [
		$StoreContainer/ItemsMargin/ItemsPanel/PanelMargin/ItemGrid/StoreItem1,
		$StoreContainer/ItemsMargin/ItemsPanel/PanelMargin/ItemGrid/StoreItem2,
		$StoreContainer/ItemsMargin/ItemsPanel/PanelMargin/ItemGrid/StoreItem3
	]
	
	setup_price_displays()
	setup_item_interaction()
	setup_category_buttons()
	select_category(0)

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
		
		var game_controller = get_node("/root/Main")
		if game_controller:
			game_controller.money = player_money
			SignalBus.emit_money_changed(player_money)
		
		print("Successfully purchased " + item_key + " for " + str(price) + " coins")
	else:
		print("Not enough money to purchase " + item_key + " (need " + str(price) + " coins, have " + str(player_money) + ")")
		
		tween = create_tween()
		tween.tween_property(item, "modulate", Color(1.5, 0.5, 0.5), 0.1)
		tween.tween_property(item, "modulate", Color(1, 1, 1), 0.2)

func _on_back_button_pressed():
	var back_btn = $StoreContainer/FooterMargin/Footer/BackButton
	var tween = create_tween()
	tween.tween_property(back_btn, "modulate", Color(1.5, 1.5, 1.5), 0.1)
	tween.tween_property(back_btn, "modulate", Color(1, 1, 1), 0.1)
	
	emit_signal("back_pressed") 