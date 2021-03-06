extends "res://Mini Scenes/Intelligences/Competitor.gd"

signal changed_stance
signal pressed_info
signal closed_manual
signal pressed_opponent
signal closed_report
signal opened_forgery
signal forged_letter
signal pressed_letters
signal pressed_influence

export var intelligences = []

export(PackedScene) var profile
export(PackedScene) var panel
export(PackedScene) var manual
export(PackedScene) var letters_panel
export(PackedScene) var forgery_panel
export(PackedScene) var council_panel
export(PackedScene) var influence_panel
var current_panel

export(PackedScene) var mail_viewer
export(PackedScene) var report_viewer

var turn_order_text = 'Turn Order'
var points_text = 'Points'
var round_text = 'Round'
var message_text = 'Message from'

var _old_turn_order = []
var has_voted = false
var influence_list = []

# ------------------ SETUP --------------------------

func _ready():
	character_name = 'Salem'
	base_influence = 3
	traits_list = ["Player Character", "Seer", "Charismatic"]
	
	relations = {'Grolk':0,'Zardri':0 ,'Kallysta':0,'Obrulena':0, 'Horlin':0,
	'Thoren':0,'Edraele':0,'Salem':-2, 'Drakoth':0, 'Daint': 0}


# other players-dependant setup
func setup(_player_character, _players, _turn_order, _dip_phrases, _opponent_trait_list):
	.setup(_player_character, _players, _turn_order, _dip_phrases, _opponent_trait_list)
	
	for i in range(len(players)):
		var player = players[i]
		
		if player[0] != character_name:
			
			# profile creation
			var _new = profile.instance()
			add_child(_new)
			move_child(_new, get_child_count()-1)
			
			# profile setup
			_new.rect_position = Vector2(45+(244*i),100)
			_new.anchor_left = 0.5
			_new.anchor_right = 0.5
			_new.anchor_top = 0.5
			_new.anchor_bottom = 0.5
			_new.margin_top = -195
			_new.margin_left = -460 + 244*i
			
			_new.connect("portrait_click", self, "_portrait_pressed")
			_new.connect("stance_change", self, "_stance_pressed")
			_new.name = player[0]
			_new.add_to_group("Profiles")
			_new.setup(player)
		
	for player in relations.keys():
		_info_til_round[player] = 0
	
	language(Global.get_language())


func language(language):
	turn_order_text = Global.mains[language]['Turn Order']
	$AdvanceTurn.text = Global.mains[language]['Advance']
	points_text = Global.mains[language]['Points']
	$PointSpace/Points.text = Global.mains[language]['Points'] + ': 0'
	round_text = Global.mains[language]['Round']
	message_text = Global.mains[language]['Message']
	$Forgery/Forgery.text = Global.mains[language]['Forgery']
	$Influence/Influence.text = Global.mains[language]['Influence']
	
	# Each Passive/Agressive Button
	for profile in get_tree().get_nodes_in_group("Profiles"):
		if profile.name != character_name:
			profile.language(language)


# -------------------- SIGNAL HANDLING -----------------

func start_turn():
	.start_turn()
	
	# change PassiveAgressive button
	if council_target[1] == 1 and council_target[0] != character_name and council_target[0] in turn_order:
		get_node(council_target[0]).new_stance(1)


# process turn order info
func receive_turn_order_info(turn_message):
	var _new = turn_order_text + ':\n'
	for i in range(turn_message.size()-1):
		_new = _new + turn_message[i]  + '-'
		if i == 2:
			_new = _new + '\n'
		
	_new = _new + turn_message[turn_message.size()-1]
	
	$TurnSpace/TurnOrder.text = _new
	.receive_turn_order_info(turn_message)


# process report info
func receive_report_info(report):
	var viewer = report_viewer.instance()
	viewer.report_setup(character_name, get_players(), report)
	add_child(viewer)
	move_child(viewer, get_child_count()-1)
	viewer.connect("tree_exited", self, "closed_report")
	
	for reporting in report.values():
		if reporting[0] == 0 and reporting[1] == 1:
			Audio.play_sound(Audio.backstab, 2)
			return

# DIPLOMACY STUFF ----------

var decree = [0, '', [], [0,0,0]]
var proposal = []

func receive_decree(action, object, voters, vote_count):
	decree = [action, object, voters, vote_count]
	.receive_decree(action, object, voters, vote_count)


func receive_proposal(_leader, action, object, _vote = 0):
	proposal = [action, object]
	
	var instance = council_panel.instance()
	add_child(instance)
	move_child(instance, get_child_count()-1)
	instance.connect("vote", self, "vote")
	instance.connect("toggle_council", self, "toggle_council")
	instance.setup_panel(decree[0], decree[1], decree[2], decree[3], 
	_old_turn_order, turn_order, get_players(), proposal)

func vote(vote):
	has_voted = true
	emit_signal("send_vote", character_name, vote)
	proposal = []


func choose_proposal():
	has_voted = true
	var instance = council_panel.instance()
	add_child(instance)
	move_child(instance, get_child_count()-1)
	instance.connect("propose", self, "propose")
	instance.connect("toggle_council", self, "toggle_council")
	instance.setup_panel(decree[0], decree[1], decree[2], decree[3], 
	_old_turn_order, turn_order, get_players())
	
	return null


func propose(_proposal):
	emit_signal("send_proposal", character_name, _proposal[0], _proposal[1])

func toggle_council(active):
	$Council.visible = active


func receive_influence_changes(_influence_list, _influence_changes):
	influence_list = _influence_list

# INVESTIGATION STUFF ------------
# request points info
func reveal_points():
	emit_signal('point_info_request', self, current_panel.get_enemy_name())

# process points info
func receive_points_info(info):
	current_panel.reveal_points(info)

# request matchtable info
func update_matchtable():
	emit_signal('matchtable_info_request', self, current_panel.get_enemy_name(), current_panel.get_opponent()[0])

# process matchtable info
func receive_matchtable_info(en_stances, op_stances, _enemy_requested_name, _opponent_requested_name):
	current_panel.update_matchtable(en_stances, op_stances)

# request relation info
func update_relation():
	emit_signal('relation_info_request', self, current_panel.get_enemy_name(), current_panel.get_opponent()[0])

# process relation info
func receive_relation_info(relation, _enemy_requested_name, _opponent_requested_name):
	current_panel.update_relation(relation)


# receive message
func receive_message(sender, roun, message):
	.receive_message(sender, roun, message)
	
	var mail_v = mail_viewer.instance()
	add_child(mail_v)
	move_child(mail_v, get_child_count()-1)
	mail_v.set_text(message_text + ': ' + sender + '\n\n' + message[0] + 
			' ' + get_dip_phrase(message[1]) + ' ' + message[2])


func set_profile_visible(_name, _new):
	Global.find_in_group(self, "Profiles", _name).visible = _new

# ------------------ PRESSING STUFF ---------------------

# request to open panel
func _portrait_pressed(enemy):
	current_panel = panel.instance()
	add_child(current_panel)
	move_child(current_panel, get_child_count()-1)
	current_panel.connect('info_pressed', self, '_info_pressed')
	current_panel.connect('letters_pressed', self, '_letters_pressed')
	current_panel.connect('opponent_pressed', self, '_opponent_pressed')
	current_panel.connect('update_matchtable', self, 'update_matchtable')
	current_panel.connect('send_message', self, '_send_message')
	
	current_panel.setup_panel(enemy, manual, get_info_til_round(enemy[0]), 
					get_players(), get_dip_phrases())
	
	if enemy[0] == 'Grolk':
		current_panel.connect("closed_manual", self, "closed_manual")
	
	update_matchtable()
	update_relation()
	reveal_points()


func closed_manual():
	emit_signal("closed_manual")


# pressed info button
func _info_pressed():
	if get_actions() > 0 and get_info_til_round(current_panel.get_enemy_name()) != get_current_round():
		print('info_pressed')
		spend_action()
		set_info_til_round(current_panel.get_enemy_name(), get_current_round())
		
		update_matchtable()
		update_relation()
		reveal_points()
		emit_signal("pressed_info", current_panel.get_enemy_name())


# pressed letters button
func _letters_pressed(enemy_name):
	var _new = letters_panel.instance()
	add_child(_new)
	move_child(_new, get_child_count()-1)
	
	_new.setup_panel(letter_list, enemy_name, get_dip_phrases())
	_new.connect("send_letter", self, "send_letter")
	emit_signal('pressed_letters', enemy_name)


# pressed change other opponent button
func _opponent_pressed():
	update_matchtable()
	update_relation()
	emit_signal("pressed_opponent")


# pressed send button
func _send_message(name1, message_id, name2):
	send_message(name1, message_id, name2, current_panel.get_enemy_name())


# pressed stance button
func _stance_pressed(_target, _stance):
	if get_actions() > 0 || get_stance(_target[0], get_current_round()) == 1:
		if change_stance(_target[0], get_current_round(), _stance):
			Global.find_in_group(self, "Profiles", _target[0]).new_stance(_stance)
			emit_signal('changed_stance')


func closed_report():
	emit_signal('closed_report')


# pressed advance button
func _on_AdvanceTurn_button_up():
	if !has_voted and Global.advanced_enabled:
		vote(0)
	has_voted = false
	
	_old_turn_order = turn_order.duplicate()
	council_target[0] = ''
	emit_signal('advance_turn', character_name)


func _on_Forgery_button_up():
	var _new = forgery_panel.instance()
	add_child(_new)
	move_child(_new, get_child_count()-1)
	
	_new.setup_panel(letter_list, players, get_dip_phrases())
	_new.connect("forged_letter", self, "forge_letter")
	emit_signal("opened_forgery")


# pressed restart button
func _on_Restart_button_up():
	get_tree().change_scene(get_parent().get_address())

# pressed back button
func _on_Back_button_up():
	get_tree().change_scene("res://Mini Scenes/Scenes/MainMenu.tscn")

# pressed any button
func button_down():
	Audio.play_sound(Audio.button_press, 1)

# pressed info button
func _on_Info_button_up():
	var manual_panel = manual.instance()
	manual_panel.manual_setup(0)
	add_child(manual_panel)
	move_child(manual_panel, get_child_count()-1)


# pressed council button
func _on_Council_button_up():
	if proposal == []:
		choose_proposal()
	else:
		receive_proposal('', proposal[0], proposal[1])


# pressed influence button
func _on_Influence_button_up():
	var new = influence_panel.instance()
	add_child(new)
	move_child(new, get_child_count()-1)
	
	new.connect("change_influence", self, "change_influence")
	new.setup_panel(turn_order, influence_list, players, character_name)
	emit_signal("pressed_influence")

# ----------------- ALTER TEXT -----------------------------

# alter action UI when action count changes
func _on_SalemAI_alter_actions(_new):
	$CrownSpace/Actions.text = str(_new)


# alter points UI when point count changes
func _on_SalemAI_alter_points(_new):
	$PointSpace/Points.text = str(points_text + ": " + str(_new))


func _on_SalemAI_alter_round(_round):
	$CurrentRound.text = round_text + ":" + str(_round)


# ------------- MISC ---------------------------

func forge_letter(letter, index, change_count):
	.forge_letter(letter, index, change_count)
	emit_signal('forged_letter', letter)


func set_portrait_visibility(_name, _visibility):
	var _node = get_node(_name)
	if _node:
		_node.visible = _visibility
