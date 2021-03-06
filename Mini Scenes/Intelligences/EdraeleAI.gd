extends "res://Mini Scenes/Intelligences/Competitor.gd"

var agenda = 0

var target = ''
var target_inform = ''
var just_invest = ''
var letter_to_send = []

# {[info]:[round, sender]}
# lists all pieces of info (messages) competitor wants to investigate
var tactical_list = {}

# Called when the node enters the scene tree for the first time.
func _ready():
	character_name = 'Edraele'
	memory_time = 4
	base_influence = 4
	traits_list = ["Agenda", "Treachery", "Justice", "Reactive", "Jealousy", "Deduction",
					"Allegiances", "Queen", "Facade", "Intrigue", "Diplomatic",]
	
	relations = {'Grolk':0,'Zardri':0, 'Kallysta':0, 'Horlin':-1,'Obrulena':0,
	'Thoren':-1,'Salem':0,'Edraele':-2, 'Drakoth':0}

#-------------- REACTIONS AND SETUP --------------------

# start turn
func start_turn():
	print_turn()
	
	# Agenda
	if relations[get_player_character()] < 0:
		agenda = 0
	elif relations[get_player_character()] == 0:
		agenda = 1
	else:
		agenda = 2
	
	target = ''
	target_inform = ''
	
	.start_turn()


# process report info
func receive_report_info(reports): #report = {'player':[stance1, stance2, points]}
	for player_name in reports.keys():
		var report = reports[player_name]
		
		# Justice
		var just = trait_justice(report, player_name)
		
		# Treachery
		if !just and report[0] == 1 and report[1] == 0:
			emit_signal('set_relations', player_name, 1)
		
		receive_fact(get_current_round(), [player_name, report[1], character_name])
		
	forget_info()


# process voting info
func receive_proposal(leader, action, object, vote = 0):
	if (object == character_name or get_relation(object) == -2) and action == 1:
		vote = -1
	elif (get_relation(object) > 0 and action == 1) or get_relation(leader) < 0:
		vote = 1
	elif get_relation(leader) > 0:
		vote = -1
	
	.receive_proposal(leader,action, object, vote)
	trait_ignorant_diplomatic(leader)

# Insight
func receive_decree(action, object, voters, _vote_count):
	for voter in voters.keys():
		if voter != character_name:
			trait_insight(action, object, voter, voters[voter])

# Diplomatic
func receive_vote(voter, vote):
	trait_ignorant_diplomatic(voter, vote)


func choose_proposal():
	for player in turn_order:
		if get_relation(player) == 2:
			return [1, player]
	
	for player in turn_order:
		if get_relation(player) == 1:
			return [1, player]
	
	return [0, character_name]


func receive_influence_changes(_influence_list, _influence_changes):
	trait_attentive(_influence_changes)
	trait_ambitious(_influence_changes)

# process investigation -------------

func receive_points_info(info):
	# Jealousy
	if info > get_points():
		relations[just_invest] = 2
	elif relations[just_invest] == 2:
		relations[just_invest] = 1


func receive_matchtable_info(en_stances, op_stances, enemy_requested_name, opponent_requested_name):
		.receive_matchtable_info(en_stances, op_stances, enemy_requested_name, opponent_requested_name)


func receive_relation_info(relation, enemy_requested_name, opponent_requested_name):
	.receive_relation_info(relation, enemy_requested_name, opponent_requested_name)
# --------------------------------------

# process message
func receive_message(sender, roun, message):
	.receive_message(sender, roun, message)
	
	# add info to a list in ann_dict and to memory_list
	ann_dict[[message[0], message[1]]].append(sender)
	
	if sender != character_name:
		memory_list[message] = [roun, sender]
	
	# Intrigue - wait, is this message true? --------
	if (!trait_intrigue_check(sender, roun, message, self)):
		return
	
	# -----------------
	# Info processing
	
	# Intrigue - Well, thanks for the info
	if message[0] != sender and message[2] != sender:
		emit_signal('improve_relations', sender)
	
	trait_allegiances(message, relations)
	trait_reactive(message, relations)

	if message[1] == 1: # negative interaction
		# Snitching
		snitch_list.append(message)
		# (if someone attacks you, logically you would fight back)
		snitch_list.append([message[2], message[1], message[0]])
		
	receive_information(roun, message)


# process fact
func receive_fact(roun, fact):
	# Intrigue - Well, thanks for the info
	for tactical in tactical_list.keys():
		#[info]:[round, sender]
		if tactical == fact and roun == tactical_list[tactical][0]-1:
			emit_signal('improve_relations', tactical_list[tactical][1])
			tactical_list.erase(tactical)
	
	# Intrigue - wait, this memory is false
	for memory in memory_list.keys(): 
		if fact[0] == memory[0] and fact[1] != memory[1] and fact[2] == memory[2] and roun == memory_list[memory][0] and relations[memory_list[memory][1]] < 2:
			emit_signal('set_relations', memory_list[memory][1], 2)
			memory_list.erase(memory)
	
	.receive_fact(roun, fact)


# process information
func receive_information(roun, info):
	.receive_information(roun, info)


# process relation
func receive_relation(relation, enemy_name, opponent_name):
	.receive_relation(relation, enemy_name, opponent_name)
	
	# Reactive
	trait_reactive_relations(enemy_name, relation, opponent_name)
	
	# Deduction
	if opponent_name == get_player_character():
		receive_relation(relation, opponent_name, enemy_name)
	
	# Facade
	if relations[enemy_name] != 2 and opponent_name == get_character_name():
		relations[enemy_name] = relation

	if relation > 0 and relations[enemy_name] != -2 and relations[opponent_name] == 2:
		# Snitching
		snitch_list.append([enemy_name, 1, opponent_name])
		snitch_list.append([opponent_name, 1, enemy_name])
	
	trait_allegiances_relation(relation, enemy_name, opponent_name)


# ----------------- ACTIONS -----------------

func execute_action():
	if agenda == 0:
		trust_action()
	elif agenda == 1:
		susp_action()
	else:
		host_action()


func trust_action():
	match (priority_lister):
		1: # murder if turn 6
			if get_current_round() == 6:
				_murder()

		2: # invest warlord
			for enemy_name in turn_order:
				if (relations[enemy_name] == 1 or relations[enemy_name] == 0) and opponent_trait_list[enemy_name].has("Warlord"):
					_investigate(enemy_name)

		3: # attack enraged
			var attacked_list = attack(2)
			for victim_name in attacked_list:
				snitch_list.append([character_name, 1, victim_name])

		4: # attack hostile
			var attacked_list = attack(1)
			for victim_name in attacked_list:
				snitch_list.append([character_name, 1, victim_name])

		5: # attack warlord
			var attacked = _warlord_attack(0)
			if attacked != null:
				snitch_list.append([character_name, 1, attacked])

		6: # Snitching - snitch stuff to warlord
			if !snitch_list.empty():
				_warlord_snitch(snitch_list, [0, 1])

		7: # investigate suspicious info
			for tactical in tactical_list:
				_investigate(tactical[0])
				tactical_list.erase(tactical)

		8: # change turn order
			if get_influence() > 1:
				change_influence(1)

		9: # tell friends about enemies
			say_to_list([2, 1], 1, [-2, -1], 'warn', false, 'Brotherhood')

		10: # modify letter
			for player_x in turn_order:
				for player_y in turn_order:
					if search_and_forge([player_x, character_name, 0, player_y], player_x, player_y):
						break

		11: # resend letter
			if len(letter_to_send) != 0:
				send_letter(letter_to_send[0], letter_to_send[1], letter_to_send[2], letter_to_send[3], letter_to_send[3])
				letter_to_send = []

		12: # investigate enemy/suspected
			for enemy_name in turn_order:
				_investigate(enemy_name)

		13: # do nothing
			spend_action()
			return
	priority_lister += 1


func susp_action():
	match (priority_lister):
		1: # murder if turn 5
			if get_current_round() == 6:
				_murder()

		2: # invest warlord
			for enemy_name in turn_order:
				if (relations[enemy_name] == 1 or relations[enemy_name] == 0) and opponent_trait_list[enemy_name].has("Warlord"):
					_investigate(enemy_name)

		3: # attack enraged
			var attacked_list = attack(2)
			for victim_name in attacked_list:
				snitch_list.append([character_name, 1, victim_name])

		4: # attack hostile
			var attacked_list = attack(1)
			for victim_name in attacked_list:
				snitch_list.append([character_name, 1, victim_name])

		5: # attack warlord
			var attacked = _warlord_attack(0)
			if attacked != null:
				snitch_list.append([character_name, 1, attacked])

		6: # Snitching - snitch stuff to warlord
			if !snitch_list.empty():
				_warlord_snitch(snitch_list, [0, 1])

		7: # investigate suspicious info
			for tactical in tactical_list:
				_investigate(tactical[0])
				tactical_list.erase(tactical)

		8: # invest suspicious
			for target in turn_order:
				if relations[target] == 0:
					_investigate(target)

		9: # tell friends about suspect
			say_to_list([0], 1, [-2, -1], 'tell', false, 'Brotherhood')

		10: # modify letter
			for player_x in turn_order:
				for player_y in turn_order:
					if search_and_forge([player_x, player_x, 1, player_y], player_x, player_y):
						break

		11: # resend letter
			if len(letter_to_send) != 0:
				send_letter(letter_to_send[0], letter_to_send[1], letter_to_send[2], letter_to_send[3], letter_to_send[3])
				letter_to_send = []

		12: # change turn order
			if get_influence() > 1:
				change_influence(1)

		13:  # attack suspect
			attack(0)

		14: # do nothing
			spend_action()
			return
	priority_lister += 1

func host_action():
	match (priority_lister):
		1: # attack enraged
			var targett = attack(2)
			if targett.size() > 0:
				_set_target(targett[0])

		2: # tell brotherhood friends about enraged
			if target != '':
				_set_target_inform(_targeted_tell(target, 1, -2))
				if target_inform == '':
					_set_target_inform(_targeted_tell(target, 1, -1))

		3: # make target look bad
			if target != '':
				for player_y in turn_order:
					if relation_list.has([player_y, 0, target]):
						for letter in letter_list:
							for info in info_list.keys(): #info_list[info] >= get_current_round()-1 and 
								if letter[0] == target and letter[1] == info[0] and letter[2] != info[1] and letter[3] == info[2]:
									send_letter(letter[0], letter[1], letter[2], letter[3], player_y)
									print("Edraele making target look bad")
		4: # attack hostile
			attack(1)
		
		5: # tell brotherhood friends about hostile
			say_to_list([1], 1, [-2, -1], 'tell', false, 'Brotherhood')

		6: # change turn order
			for player in turn_order:
				if get_relation(player) >= 2:
					change_influence(-1, player)

		7: # change turn order
			if get_influence() > 1:
				change_influence(1)

		8: # do nothing
			spend_action()
			return
			
	priority_lister += 1
	
# ----------------- HELPER ACTIONS --------------------

func _murder():
	for target_name in relations.keys():
		change_stance(target_name, get_current_round(), 1)

func _warlord_attack(_target_relation):
	for player in turn_order:
		if relations[player] == _target_relation and opponent_trait_list[player].has("Warlord"):
			for relation in relation_list:
				if relation[0] == player and relation[1] == 0 and relation[2] != character_name:
					change_stance(player, get_current_round(), 1)
					return player

func _warlord_snitch(snitch_list, recipient_relation_list):
	var already_snitched = []
	# Snitching
	for info in snitch_list:
		if (recipient_relation_list.has(relations[info[2]]) and opponent_trait_list[info[2]].has("Warlord") 
		and !already_snitched.has(info[2])):
			warn(info[0], info[1], info[2])
			already_snitched.append(info[2])
			snitch_list.erase(info)

func _targeted_tell(_target, _order, _informed_relation):
	# look for players that don't know about my relation with this person
	for sally in turn_order:
		if relations[sally] == _informed_relation and sally != character_name:
			tell(_target, _order, sally)
			return target_inform

func _investigate(_target):
	if get_actions() <= 0 || _target == character_name:
		return false
		
	spend_action()
	set_info_til_round(_target, get_current_round())
	print_invest(_target)
	# look for their relation/historic with all others
	
	just_invest = _target
	emit_signal('point_info_request', self, _target)
	
	for opponent in turn_order:
		if opponent != _target:
			if _target != get_player_character():
				emit_signal('relation_info_request', self, _target, opponent)
			emit_signal('matchtable_info_request', self, _target, opponent)
	return true

func search_and_forge(target_letter, player_x, player_y):
	if player_y != character_name and relation_list.has([player_y, -1, player_x]) or relation_list.has([player_y, -2, player_x]):
		var package = search_letter(target_letter)
		if package[0] != -1 and forge_letter(target_letter, package[0], 3-package[1]):
			letter_to_send = letter_list[package[0]]
			return true
	return false

func _set_target(_new):
	if _new == null:
		target = ''
	else:
		target = _new

func _set_target_inform(_new):
	if _new == null:
		target_inform = ''
	else:
		target_inform = _new



