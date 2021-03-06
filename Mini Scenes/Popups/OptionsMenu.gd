extends 'res://Mini Scenes/Popups/popup.gd'

signal changed_language
signal changed_volume

export(PackedScene) var credits

func _ready():
	_speed = 2
	setup(258, 188)
	options_setup()


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	processing(delta)


func options_setup():
	# setup dropdowns
	$LanguageButton.add_item('English')
	$LanguageButton.add_item('Portugues')
	$LanguageButton.add_item('Deutsch')
	
	$MusicSlider.value = (Global.get_music_volume() -0.001) * 100
	$SoundsSlider.value = (Global.get_sounds_volume() -0.001) * 100
	
	$LanguageButton.select(Global.get_language())
	
	$CheatButton.pressed = Global.get_debug_enabled()
	language(Global.get_language())


func language(language):
	$Options.text = Global.options[language]['Options']
	$Volume.text = Global.options[language]['Volume']
	$Music.text = Global.options[language]['Music']
	$Sounds.text = Global.options[language]['Sounds']
	$Language.text = Global.options[language]['Language']


func _on_CloseButton_button_up():
	queue_free()


func _on_LanguageButton_item_selected(_ID):
	Audio.play_sound(Audio.small_press, 2)
	Global.set_language($LanguageButton.get_selected_id())
	emit_signal("changed_language", Global.get_language())


func _on_MusicSlider_value_changed(value):
	Global.set_music_volume(value)
	emit_signal("changed_volume")


func _on_SoundsSlider_value_changed(value):
	Global.set_sounds_volume(value)
	emit_signal("changed_volume")


func _on_CheckBox_toggled(_button_pressed):
	Global.set_debug_enabled(!Global.get_debug_enabled())


func _on_CreditsButton_button_up():
	var credits_panel = credits.instance()
	add_child(credits_panel)
	move_child(credits_panel, get_child_count()-1)
