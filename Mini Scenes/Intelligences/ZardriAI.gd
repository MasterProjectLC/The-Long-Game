extends "res://Mini Scenes/Intelligences/Competitor.gd"

# lists enemies
var war_list = {}

func _ready():
	character_name = 'Zardri'
	memory_time = 1
	base_influence = 1
	traits_list = ["Ambusher", "Hatred", "Paranoid", "Treachery", "Intuition", "Dim-Witted", "Ignorant",]
	
	relations = {'Grolk':-1,'Zardri':-2, 'Kallysta':0, 'Horlin':0, 'Obrulena':0,
	'Thoren':1, 'Salem':0, 'Edraele':0, 'Drakoth':1, 'Daint': 0}
	
	for player_name in relations.keys():
		war_list[player_name] = []

# -------------- REACTIONS AND SETUP --------------------

# start turn
func start_turn():
	print_turn()
	
	.start_turn()


# process report info
func receive_report_info(reports): #report = {'player':[stance1, stance2, points]}
	for player_name in reports.keys():
		var report = reports[player_name]
		
		info_list[[player_name, report[1], character_name]] = get_current_round()
		trait_hatred(report, player_name)
		
	forget_info()

# process investigation -------------
func receive_matchtable_info(en_stances, op_stances, enemy_requested_name, opponent_requested_name):
	# Intuition
	trait_intuition(en_stances, op_stances, enemy_requested_name, opponent_requested_name)

	.receive_matchtable_info(en_stances, op_stances, enemy_requested_name, opponent_requested_name)


func receive_relation_info(relation, enemy_requested_name, opponent_requested_name):
	.receive_relation_info(relation, enemy_requested_name, opponent_requested_name)

# receive message
func receive_message(sender, roun, message):
	.receive_message(sender, roun, message)
	
	# add info to a list in ann_dict and to memory_list
	ann_dict[[message[0], message[1]]].append(sender)
	memory_list[message] = [roun, sender]
	
	# Dim-Witted
	message = [message[0], stance_inverse(message[1]), message[2]]
	emit_signal("worsen_relations", sender)
	
	# Paranoid
	trait_paranoid(message)
	
	.receive_information(roun, message)


func receive_proposal(leader, action, object, vote = 0):
	if action == 1 and object == character_name:
		vote = -1
	if (action == 1 and object != character_name) or (action == 0 and object == character_name):
		vote = 1
	
	.receive_proposal(leader,action, object, vote)
	trait_ignorant_diplomatic(leader)


# process relation
func receive_relation(relation, enemy_name, opponent_name):
	.receive_relation(relation, enemy_name, opponent_name)
	
	# Deduction
	if opponent_name == get_player_character():
		receive_relation(relation, opponent_name, enemy_name)
		
	# Paranoid pt. 2
	trait_paranoid_relation(relation, enemy_name, opponent_name)
	
	# Ambusher
	if relation > 0 and !war_list[opponent_name].has(enemy_name) and enemy_name != character_name:
		war_list[opponent_name].append(enemy_name)
		if war_list[opponent_name].size() >= 2 and opponent_name != character_name:
			relations[opponent_name] = 1


func choose_proposal():
	for player in turn_order:
		if get_relation(player) == 2:
			return [1, player]
	
	for player in turn_order:
		if get_relation(player) == 1:
			return [1, player]
	
	return [0, character_name]

# ----------------- HELPER REACTIONS -----------------



# ----------------- ACTIONS -----------------

func execute_action():
	match (priority_lister):
		1: # attack furious
			attack(2)
		
		2: # attack hostile
			attack(1)
		
		3: # reduce hostile influence
			for player in turn_order:
				if get_relation(player) >= 1:
					change_influence(-1, player)
		
		4: # investigate suspect
			for enemy_name in turn_order:
				if relations[enemy_name] == 0:
					_investigate(enemy_name)
		
		5: # do nothing
			spend_action()
			return
	
	priority_lister += 1

func _send_message(name1, message, name2, recipient):
	send_message(name1, message, name2, recipient)
	
