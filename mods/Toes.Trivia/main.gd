extends Node

const Trivia = preload("res://mods/Toes.Trivia/trivia.gd")
onready var Players = get_node("/root/ToesSocks/Players")
onready var Chat = get_node("/root/ToesSocks/Chat")

const DEBUG_MODE = true

const TRIVIA_DIR_PATH := "user://trivia"
const META_PATH := TRIVIA_DIR_PATH + "/" + "meta.json"

const SURVIVAL_BASE_POINTS = 3
const SURVIVAL_DEATH_THRESHOLD = 0 - SURVIVAL_BASE_POINTS

const STEAL_TIME_WINDOW = 3500

const AFFIRMATIONS = ["Correct", "Bingo", "Nicely done", "Ayo", "Ace", "Nailed it"]

var http_request

## Cache of custom trivia sets
export var custom_trivias := {}

## Name of current set
export var active_custom_trivia := ""

## Custom qeustions
export var current_trivia_set := []

var trivia_is_running: bool = false
var current_question: String

## Don't do these again
var seen_trivia_questions: Array

## Correct answer to the current_question
var current_answers: Array

## Wrong answers to current question
var current_wrong_answers: Array

## A shuffled list of possible answers to a given question
## Only used if trivia_needs_multiple_choice is true
var current_options: Array

## if question is not answerable without referencing the possible answers.
## I.e., due to broad scope or specificity
## Disables H _ n t s  from being given (as it would reveal the answer, duh)
var current_trivia_needs_multiple_choice: bool

## Round ends at this time
var current_expiration: int

## Whether a final hint has been given
var final_hint_given: bool

## Winner of current round, if anyone guessed correctly
var current_round_winners := []

## Some rounds we will collect guesses and evaluate

## State returned to after unpausing
var saved_state := ""

var last_round_began_at := 0
var last_round_ended_at := 0
var rounds_completed := 0

## Defaults
var difficulty := "easy"
var mode := "passive"
const max_rounds = 10

export var mods := {
	"hints":
	{
		"description":
		"Only for the most hardcore or specific circumstances. The game is much less fun without the hints! I warned you...",
		"active": true
	},
	"freebies":
	{
		"description":
		"Like Wheel Of Fortune, some blanks will reveal their letters, depending on how looong the answer is. Hints must be active!",
		"active": true
	},
	#    "hangman":
	#    {
	#        "description":
	#        "[N/A in-development] Correct *letter* guesses - together intentional or not- will reveal. Points are awarded by letter.",
	#        "active": false
	#    },
	"lifeline":
	{
		"description":
		"A SUPER-HINT lifeline is provided if nobody has guessed by the time the countdown reaches 10-seconds remaining.",
		"active": true
	},
	"survival":
	{
		"description":
		"[BETA] Just make it to the end! Blind (incorrect) guesses will cost you 1 point! Before you try it- biding time will cost you too. Don't get TOO low... or you're OUT!!",
		"active": false
	},
	#    "teams": {"description": "[N/A in-development] Team up!", "active": false},
	"bucket_crab":
	{
		"description":
		"Permits a tiny time window following anyone's correct guess wherein others -who were maybe still typing it out- have a final chance to lock in and share partial points",
		"active": true
	}
}

export var current_round_guesses := {}

## Current game state
var state := ""


func _modifier_is_active(key: String) -> bool:
	return mods.get(key)["active"] == true


const BOT_NAME = "⁽ᵀᴿᴵⱽᴵᴬ⁾"
const BOT_COLOR = "#9234eb"

export var MODES := {
	"active":
	## After a round ends, this amount of time will be idle even if the new round is ready
	## A new round will never begin unless this amount of time has passed
	## Maximum time to chat in an answer to the trivia question
	{"COOLDOWN_TIME": 20000, "MIN_TIME_BETWEEN_ROUNDS": 35000, "TIMEOUT": 40000},
	"passive": {"COOLDOWN_TIME": 100000, "MIN_TIME_BETWEEN_ROUNDS": 60000, "TIMEOUT": 60000}
}

var _scores := {}


func _init() -> void:
	var metadata = _get_trivia_files_list()
	# TODO malformed json validate
	for trivia in metadata.get("trivias", []):
		custom_trivias[trivia.uid] = trivia.path
	var configured_default = metadata.get("default", "none")
	if configured_default != "none":
		if configured_default in custom_trivias.keys():
			active_custom_trivia = configured_default
			current_trivia_set = load_trivia_set(configured_default).content

	# var mpt := load_trivia_set("mpt")
	# if mpt == null:
	#     print("Attempted to load custom trivia file but there was some error...")
	#     breakpoint
	# else:
	#     print("Loaded custom trivia!")
	#     current_trivia_set = mpt.content


func _ready():
	randomize()

	Chat.connect("player_messaged", self, "_on_player_messaged")

	http_request = HTTPRequest.new()
	add_child(http_request)
	http_request.connect("request_completed", self, "_load_question")

	Players.connect("ingame", self, "_ingame")


func _exit_tree():
	if not Players.in_game:
		trivia_is_running = false
		_reset()


func _get_trivia_files_list(refresh = false) -> Dictionary:
	_log("getting trivia files list")
	var trivias := {}
	var existing_default_set = "none"

	var dir := Directory.new()
	if dir.open(TRIVIA_DIR_PATH) == OK:
		if refresh or File.new().file_exists(META_PATH) == false:
			_log("refreshing trivia files cache (metafile)")
			_log("existing meta.json? " + str(File.new().file_exists(META_PATH)))
			dir.list_dir_begin(true, true)
			var file_name = dir.get_next()
			while file_name != "":
				if dir.current_is_dir():
					file_name = dir.get_next()
					continue
				if file_name == "meta.json":
					_log("Found existing meta.json...")
					var old_metafile := File.new()
					old_metafile.open(META_PATH, File.READ)
					var old_metafile_text = old_metafile.get_as_text()
					_log(old_metafile_text)
					var old_config := JSON.parse(old_metafile_text)
					if old_config.error == OK:
						existing_default_set = old_config.result.get(
							"default", existing_default_set
						)
					old_metafile.close()
					file_name = dir.get_next()
					continue

				_log("Checking %s ..." % file_name)
				var path = TRIVIA_DIR_PATH + "/" + file_name
				var trivia_set = load_trivia_set(path)
				var uid = trivia_set.get("uid", file_name)
				_log("Cached custom trivia file " + file_name + "(%s)" % uid)
				trivias[uid] = path

				file_name = dir.get_next()

			var meta_content = {"default": existing_default_set, "trivias": []}
			var metafile := File.new()
			for uid in trivias.keys():
				meta_content.trivias.append({"uid": uid, "path": trivias[uid]})
			metafile.open(META_PATH, File.WRITE)
			metafile.store_string(JSON.print(meta_content))
			_log("Refreshed and wrote new meta.json")
			metafile.close()

	else:
		_log("Oh noes we are missing the trivia dir! Let's recreate it...")
		var err := dir.make_dir(TRIVIA_DIR_PATH)
		if err != OK:
			_log("Couldn't create Trivia directory. Giving up")

		var meta_content = {"default": "none", "trivias": []}
		var metafile := File.new()
		for uid in trivias.keys():
			meta_content.trivias.append({"uid": uid, "path": trivias[uid]})
		metafile.open(META_PATH, File.WRITE)
		metafile.store_string(JSON.print(meta_content))
		_log("Created new meta.json")
		metafile.close()

	var metafile := File.new()
	metafile.open(META_PATH, File.READ)
	_log(metafile.get_as_text())
	var metadata := JSON.parse(metafile.get_as_text())
	metafile.close()
	if metadata.error != OK:
		printerr("Malformed meta file?!")

	return metadata.result


func load_trivia_set(uid_or_file: String) -> Trivia.TriviaSet:
	_log("Loading custom trivia set")
	var file_name: String = (
		custom_trivias[uid_or_file]
		if custom_trivias.has(uid_or_file)
		else uid_or_file
	)
	var path := file_name
	var trivia_file := File.new()
	if !trivia_file.file_exists(path):
		Chat.write(
			(
				"Missing trivia files for %s! Did you recently rename them without updating the cache?"
				% path
			)
		)
#		breakpoint
		return null
	else:
		trivia_file.open(path, File.READ)
		var parsed_json: JSONParseResult = JSON.parse(trivia_file.get_as_text())
		trivia_file.close()
		if parsed_json.error != OK:
#			breakpoint
			printerr("Malformed trivia file!" + path)
			# TODO
		var trivia_set = parsed_json.result
		return trivia_set


func _process(dt):
	# breakpoint
	if not trivia_is_running or state == "paused":
		return

	if not Players.in_game:
		_reset()

	match state:
		## Loading new question
		## -> Loaded
		"loading":
			pass

		## Trivia is ready, pending timers
		## -> Listening
		"loaded":
			if (
				# Continue waiting...
				(last_round_began_at != 0)
				and (
					(last_round_began_at + MODES[mode].MIN_TIME_BETWEEN_ROUNDS)
					> Time.get_ticks_msec()
				)
			):
				return

			if rounds_completed + 1 == max_rounds:
				Chat.send_raw("=== ⒻⒾⓃⒶⓁ ⓇⓄⓊⓃⒹ ===")
			else:
				Chat.send_raw(
					"\n=== ⓡⓞⓤⓝⓓ " + _format_number_circled(rounds_completed + 1) + " ==="
				)
			_announce(current_question)
			if current_trivia_needs_multiple_choice:
				Chat.send_raw("(" + ",".join(current_options) + ")")
			else:
				if _modifier_is_active("hints"):
					Chat.send_raw("ₕᵢₙₜ: " + _format_answer_hint(current_answers[0]))

			current_expiration = Time.get_ticks_msec() + MODES[mode].TIMEOUT
			last_round_began_at = Time.get_ticks_msec()
			state = "listening"
			_log("TRIVIA: Mode -> Listening")

		## Waiting for players to guess
		## -> Finished
		"listening":
			# breakpoint
			var answer = current_answers[0]
			if Time.get_ticks_msec() >= current_expiration:
				if _modifier_is_active("bucket_crab") and not current_round_winners.empty():
					_announce(
						"{affirmation}! It was: {answer}.".format(
							{"affirmation": sample(AFFIRMATIONS), "answer": answer}
						)
					)
					_finish_round("answer")
				else:
					_announce("Oh well. The answer was: " + answer)
					_finish_round("timeout")

			elif (
				_modifier_is_active("lifeline")
				and answer.length() > 6
				and current_expiration - Time.get_ticks_msec() <= 10000
				and !final_hint_given
				and current_round_winners.empty()
			):
				final_hint_given = true
				Chat.send_raw(
					(
						"Times nearly up! Last chance... "
						+ _format_answer_hint(answer, int(floor(answer.length() / 2.0)))
					)
				)

		## No player guessed, completed with no winner
		## -> Loading
		"finished_by_timeout":
			if last_round_ended_at + MODES[mode].COOLDOWN_TIME > Time.get_ticks_msec():
				return
			_next_round()

		## Trivia round completed
		## -> Loading
		"finished_by_answer":
			if last_round_ended_at + MODES[mode].COOLDOWN_TIME > Time.get_ticks_msec():
				return
			_next_round()

		## Skipped question
		## -> Loading
		"finished_by_skip":
			_next_round()


func _ingame():
	trivia_is_running = false
	_reset_timers()


func _reset_timers():
	current_expiration = 0
	final_hint_given = false
	last_round_began_at = 0
	last_round_ended_at = 0
	current_round_winners.clear()


func _load_question(result, response_code, headers, body):
	_log("TRIVIA: Loading question")
	var trivia
	seen_trivia_questions.append(trivia.question)
	#    while trivia.question in seen_trivia_questions:
#        _log("Skipping question - already seen...")
#        _log(trivia.question)
#        trivia = sample(current_trivia_set)
#    seen_trivia_questions.append(trivia.question)

	var json = JSON.parse(body.get_string_from_utf8())

	if json.result.response_code == 5:
		# Throttled
		yield (get_tree().create_timer(5), "timeout")
		return _fetch_question()

	_log(json.result)
	trivia = json.result.results[0]

	current_question = _unescape(trivia["question"]).dedent()
	current_answers = [_unescape(trivia["correct_answer"]).dedent()]
	if "&" in current_answers[0]:
		current_answers.append(current_answers[0].replacen("&", "and"))
	var wrong_answers = []
	for wanswer in trivia["incorrect_answers"]:
		wrong_answers.append(_unescape(wanswer).dedent())
	current_wrong_answers = wrong_answers
	current_options = current_answers + current_wrong_answers
	current_options.shuffle()
	## This is a hack workaround for the game being multiple-choice
	current_trivia_needs_multiple_choice = (
		(trivia.has("needs_choices") and trivia.needs_choices)
		or "which of the" in current_question.to_lower()
		or "which one of" in current_question.to_lower()
	)

	state = "loaded"
	_log("Done loading trivia question")


func _load_offline_question():
	_log("Loading (custom) question")

	if current_trivia_set.empty():
		Chat.notify("Warning: There are 0 trivia questions left in the bank!")
		yield (get_tree().create_timer(1.5), "timeout")
		Chat.notify("Ending trivia match early, since there are no unused questions left")
		yield (get_tree().create_timer(1.5), "timeout")
		Chat.notify("To reload the questions again or switch to a new trivia set type `!use [uid]`")

		return _finish_trivia()

	current_trivia_set.shuffle()
	var trivia = current_trivia_set.pop_back()

	current_question = trivia["question"].dedent()
	current_answers = [trivia["correct_answer"].dedent()]

	var wrong_answers = []
	for wanswer in trivia["incorrect_answers"]:
		wrong_answers.append(wanswer.dedent())
	current_wrong_answers = wrong_answers
	current_options = current_answers + current_wrong_answers
	current_options.shuffle()
	current_trivia_needs_multiple_choice = trivia.get("needs_choices", false)

	# Do this last to exclude alt answers from choices
	var alt_answers = trivia.get("alt_answers", [])
	for aa in alt_answers:
		current_answers.append(aa)

	state = "loaded"
	_log("Done loading offline trivia question")


## Adjusts score and reurns new value
func _adjust_player_score(name: String, amt: int) -> int:
	if !_scores.has(name):
		_scores[name] = SURVIVAL_BASE_POINTS if _modifier_is_active("survival") else 0
	_scores[name] += amt
	return _scores[name]


func _punish_player(name: String, amt: int = 1) -> void:
	_log("Punishing player " + name)

	var new_score = _adjust_player_score(name, -abs(amt) as int)
	Chat.emote_as(
		name, "loses -{amt} points! ({score} left)".format({"amt": amt, "score": new_score})
	)
	if new_score <= SURVIVAL_DEATH_THRESHOLD:
		# _announce("%s has completely expended and run out of trivia points! But the survival showdown must go on...")
		_announce("Oh dear... %s has expended all of their trivia points" % name)
		_adjust_player_score(name, -INF as int)


func _finish_round(by: String) -> void:
	if not by == "skip":
		last_round_ended_at = Time.get_ticks_msec()
		rounds_completed += 1
	state = "finished_by_" + by
	if state == "finished_by_answer":
		var points_to_award = 4 if current_trivia_needs_multiple_choice else 12
		if _modifier_is_active("survival"):
			points_to_award = points_to_award / 4
		var SHOULD_DISTRIBUTE = not current_trivia_needs_multiple_choice
		if current_round_winners.size() < 2:
			_adjust_player_score(current_round_winners[0], points_to_award)
			_announce(str(points_to_award) + " points go to: " + current_round_winners[0])
		elif SHOULD_DISTRIBUTE:
			var winner_list = "Points to: "
			for player_idx in range(current_round_winners.size()):
				var playerName = current_round_winners[player_idx]
				var points_given = max((9 - (2 * player_idx)), 1) # 9, 7, 5, 3, 1
				_adjust_player_score(playerName, points_given)
				winner_list += (playerName + " +" + str(points_given) + ", ")
			_announce(winner_list.trim_suffix(", "))


func _next_round() -> void:
	# TODO TRIVIA TIE SHOWDOWN?!
	if rounds_completed + 1 > max_rounds:
		_finish_trivia()
		return
	state = "loading"
	current_round_winners.clear()

	if active_custom_trivia.empty():
		_fetch_question()
	else:
		_load_offline_question()


# the categories are: books, film, music, theater, TV, Vidya, Board games, Nature, Computers, Math, Mythology, Sports, Geog, History, Politica, Art, Celeb, Animals...
func _fetch_question() -> void:
	var URL = (
		"https://opentdb.com/api.php?amount=1&type=multiple"
		if difficulty == "any"
		else ("https://opentdb.com/api.php?amount=1&type=multiple&difficulty=" + difficulty)
	)
	# URL = URL + "&category=27"  # Animals
	# URL = URL + "&category=19" # Math
	var error = http_request.request(URL)
	if error:
		push_error("An error ocurred while fetching trivia from DB")


func _on_player_messaged(message: String, player_name: String, is_self: bool) -> void:
	if is_self:
		if message.begins_with("!status"):
			_announce("status is " + state if state else "offline")
	if is_self:
		if message.begins_with("!start") or message.begins_with("!trivia"):
			if trivia_is_running:
				return
			Chat.send_raw("ᵀʳⁱᵛⁱᵃ ⁱˢ ˢᵗᵃʳᵗⁱⁿᵍ")
			var format = {
				"active": "ᵃᶜᵗⁱᵛᵉ",
				"passive": "ᴾᵃˢˢⁱᵛᵉ",
				"any": "ᵃⁿʸ",
				"easy": "ᴱᴬˢʸ",
				"medium": "ᴹᴱᴰᴵᵁᴹ",
				"hard": "ʰᵃʳᵈ",
			}
			if active_custom_trivia.empty():
				Chat.write(
					(
						"ᴰᴵᶠᶠᴵᶜᵁᴸᵀʸ  ⁻ "
						+ format[difficulty]
						+" | ᴹᴼᴰᴱ ⁻ "
						+ format[mode]
						+" | ᶜᵃᵗᵉᵍᵒʳʸ ⁻ ᵃⁿʸ"
					)
				)
			else:
				Chat.write("[rainbow]Custom trivia: %s [/rainbow]" % active_custom_trivia)

			Chat.write("To stop: [rainbow]!stop[/rainbow]")
			Chat.write("To skip a question: [rainbow]!skip[/rainbow]")
			Chat.write("To pause: [rainbow]!pause[/rainbow] Or resume: [rainbow]!resume[/rainbow]")
			_reset_timers()
			_scores.clear() # TODO: This is redundant; remove
			rounds_completed = 0
			trivia_is_running = true
			_next_round()
			return

		if (
			message.begins_with("!end_trivia")
			or message.begins_with("!stop_trivia")
			or message.begins_with("!stop")
		):
			if not trivia_is_running:
				return
			Chat.send_raw("ᵀʳⁱᵛⁱᵃ ᵂᵃˢ ˢᵗᵒᵖᵖᵉᵈ")
			_finish_trivia()

		if message.begins_with("!use") or message.begins_with("!switch"):
			var args = Array(message.split(" ")).slice(1, -1)
			if args.empty():
				Chat.write("Command usage is !use (uid)")
			else:
				var target_set = args[0]

				if target_set == "none":
					active_custom_trivia = ""
					current_trivia_set.clear()
					_announce("OK! Using default trivia set")
					return

				if !custom_trivias.get(target_set, false):
					Chat.write(
						target_set + " not in cache..." + " Reloading custom Trivia files..."
					)
					_log(target_set + " not in cache..." + " Reloading custom Trivia files...")
					var metadata := _get_trivia_files_list(true)
					for trivia in metadata.get("trivias", []):
						custom_trivias[trivia.uid] = trivia.path

				var new_trivia_set = load_trivia_set(target_set)
				if new_trivia_set == null:
					new_trivia_set = {}
				current_trivia_set = new_trivia_set.get("content", [])
				if current_trivia_set.empty():
					Chat.write(
						(
							"Unable to find that Trivia set or it was empty when loaded... Available sets: "
							+" ".join(custom_trivias.keys())
						)
					)
				else:
					active_custom_trivia = target_set
					_announce("OK! Using custom trivia set " + target_set)

		if message.begins_with("!mode"):
			var args = Array(message.split(" ")).slice(1, -1)
			if args.empty():
				_announce("The current mode is " + mode)
				return
			var modes = ["active", "passive"]
			if args[0] in modes:
				mode = args[0]
				_announce("Changed mode to: " + args[0])
			else:
				_announce("Invalid mode setting")
			pass

		if message.begins_with("!mods") or message.begins_with("!mod "):
			var args = Array(message.split(" ")).slice(1, -1)
			if args.empty():
				var mod_status = ""
				for mod in mods.keys():
					mod_status += (mod + "=" + ("active" if mods[mod].active else "disabled") + " ")
				mod_status.trim_suffix(" ")
				_announce("Mod statuses: " + mod_status)
				return

			var mod_target = args[0]
			var valid_mods = mods.keys()
			if not mod_target in valid_mods:
				_announce("Unknown mod " + mod_target)
				return

			if args.size() == 1:
				_announce(
					(
						mod_target + "=" + "active"
						if mods[mod_target].active == true
						else "disabled" + "\n" + mods[mod_target].description
					)
				)
			else:
				if not (
					args[1]
					in [
						"on",
						"off",
						0,
						1,
						"false",
						"true",
						"enable",
						"enabled",
						"active",
						"disable",
						"disabled"
					]
				):
					Chat.notify("Command not understood. Sorry. Please try again")
					return
				var state_target = _parse_mod_state_arg(args[1])
				if mods[mod_target].active != state_target:
					_announce(
						(
							mod_target.capitalize() + " " + "activated"
							if state_target == true
							else "disabled"
						)
					)
				mods[mod_target].active = state_target

		if message.begins_with("!diff"):
			var args = Array(message.split(" ")).slice(1, -1)
			if args.empty():
				_announce("The difficulty is " + difficulty)
				return
			var difficulties = ["any", "easy", "medium", "hard"]
			if args[0] in difficulties:
				difficulty = args[0]
				_announce("Changed difficulty to: " + args[0])
			else:
				_announce("Invalid difficulty setting")

		if message.begins_with("!cat "):
			pass

	if (
		trivia_is_running
		and _modifier_is_active("survival")
		and _scores.get(player_name, 0) == -INF
	):
		Chat.notify("Ignored, loser!")
		# Ignored, loser!
		return

	if message.begins_with("!pause"):
		Chat.send_raw("ᵗʳⁱᵛⁱᵃ ᵖᵃʷˢᵉᵈ")
		Chat.notify("Trivia is paused")
		# TODO: skip handling?
		saved_state = state
		state = "paused"

	if message.begins_with("!resume") or message.begins_with("!unpause"):
		Chat.send_raw("ᵗʳⁱᵛⁱᵃ ᵘⁿᵖᵃʷˢᵉᵈ")
		Chat.notify("Trivia has resumed")
		state = saved_state

	if not trivia_is_running or state == "paused":
		return

	if state == "listening":
		if is_self or not is_self:
			if message.begins_with("!skip"):
				# Ignore skips for
				var time_left = current_expiration - Time.get_ticks_msec()
				if time_left <= 15 * 1000:
					_announce("Too late to skip!")
					return
				Chat.notify("Trivia question was skipped")
				_announce("ˢᵏⁱᵖᵖᵉᵈ")
				_finish_round("skip")
				_reset_timers()
				return

		###########
		# GUESSES #
		###########

		# No need to re-award points
		if player_name in current_round_winners:
			return

		var NEARBY_KEYS = {
			"q": "wa",
			"w": "sqe",
			"e": "wrd",
			"r": "efy",
			"t": "ryg",
			"y": "tuh",
			"u": "yij",
			"i": "oku",
			"o": "pli",
			"p": "ol",
			"a": "szq",
			"s": "awdx",
			"d": "fces",
			"f": "gvrd",
			"g": "ftyvhb",
			"h": "jnygub",
			"j": "nhuikm",
			"k": "loijm",
			"l": "kpo",
			"z": "axs",
			"x": "czds",
			"c": "xvfd",
			"v": "cbfg",
			"b": "vngh",
			"n": "bmhj",
			"m": "nkj",
		}

		var guess := message.to_lower()
		for answer in current_answers:
			var perfect_match: bool = answer.to_lower() in guess
			var imperfect_match := false
			if not perfect_match:
				var SIM_THRESH := 0.9
				var MAX_TYPOS := 2
				if guess.similarity(answer) >= SIM_THRESH:
					var typo_count := 0
					var unlikely_to_typo := false
					for i in range(guess.length()):
						var expected: String = answer[i]
						var given := guess[i]
						if given == expected: continue
						typo_count += 1
						if typo_count > 2: break
						var nearby = NEARBY_KEYS.get(given)
						if expected in nearby: continue
						unlikely_to_typo = true
					imperfect_match = typo_count <= 2 and not unlikely_to_typo

			if (perfect_match or imperfect_match):
				var was_first_guesser = current_round_winners.empty()
				current_round_winners.append(player_name)
				if _modifier_is_active("bucket_crab"):
					if !was_first_guesser:
						return
					var time_left = current_expiration - Time.get_ticks_msec()
					if time_left > STEAL_TIME_WINDOW:
						current_expiration = Time.get_ticks_msec() + STEAL_TIME_WINDOW
					# _announce("Answer found! Lock in your final guess, quickly.")
				else:
					_announce(
						"{msg} - answer was: {answer}".format(
							{"msg": sample(AFFIRMATIONS), "answer": answer}
						)
					)
					_finish_round("answer")
				return
		if _modifier_is_active("survival"):
			var guessed_mc_wrong = (
				current_trivia_needs_multiple_choice
				and guess in current_wrong_answers
			)
			var guessing_easy_wrong = guess.length() == current_answers[0].length()
			# guess.length() <= 2
			if guessed_mc_wrong or guessing_easy_wrong:
				_punish_player(player_name, 1)

	if is_self or not is_self:
		if message.begins_with("!scores") or message.begins_with("!score"):
			_announce_scores()


func _unescape(string: String) -> String:
	# breakpoint
	return string.http_unescape().xml_unescape()


func _format_answer_hint(answer: String, hint_count: int = -1) -> String:
	var hint := ""
	var characters := "abcdefghijklmnopqrstuvwxyz1234567890àâäáãåéèêëìíîïöôóòõùúûñÿ"
	var blanks := answer.length()

	var answer_ineligible := blanks <= 2 or !_modifier_is_active("freebies")

	var answer_regular := blanks > 2 and blanks < 15
	var reg_blanks := int(floor(blanks) * 0.20)

	var answer_huge := blanks >= 15
	var extra_blanks := int(floor(blanks) * 0.35)

	hint_count = (0 if answer_ineligible else reg_blanks if answer_regular else extra_blanks)  # Huge!

	var unrevealed_indices := range(blanks - 1)
	var blanks_to_reveal := []
	while hint_count > 0:
		unrevealed_indices.shuffle()
		blanks_to_reveal.append(unrevealed_indices.pop_back())
		hint_count -= 1
	var idx = 0
	for c in answer:
		var l = c.to_lower()
		if l == " ":
			pass
		elif l in "$-,/'\".!":
			hint += l
		elif l in characters:
			hint += (c if blanks_to_reveal.has(idx) else "_")
		else:
			_log(c + " not in char list...")
			hint += "?"
		hint += " "
		idx += 1
	return hint


func _format_number(num: int) -> String:
	var formatted := ""
	var numbers := "⁰¹²³⁴⁵⁶⁷⁸⁹"
	for digit in str(num):
		formatted += numbers[int(digit)]
	return formatted


func _format_number_circled(num: int) -> String:
	var formatted := ""
	var numbers := "0①②③④⑤⑥⑦⑧⑨"
	for digit in str(num):
		formatted += numbers[int(digit)]
	return formatted


func _get_scores() -> Array:
	var scores_list := []
	for player in _scores:
		scores_list.push_back([player, _scores[player]])
	scores_list.sort_custom(self, "_sort_scores")
	return scores_list


## (Sorts descending)
func _sort_scores(a, b) -> bool:
	return a[1] > b[1]


func _announce_scores(is_final_round = false) -> void:
	var scores = _get_scores()
	if scores.size() == 0:
		return  # No scores to announce

	_announce("=== " + ("ⓇⒺⓈⓊⓁⓉⓈ" if is_final_round else "ⓢⓒⓞⓡⓔⓢ") + " ===")
	for i in range(scores.size() if is_final_round else min(3, scores.size())):
		var ranking = scores[i]
		var player = ranking[0]
		var score = ranking[1]
		var ordinal = [
			"Winner♛" if is_final_round else "1st",
			"2nd",
			"3rd",
			"4th",
			"5th",
			"6th",
			"7th",
			"8th",
			"9th",
			"10th"
		]

		Chat.send_raw(ordinal[i] + "(" + str(score) + ") " + player)
		# TODO: Knocked out players don't place!
		# TODO: Tiebreakers??


func _finish_trivia() -> void:
	trivia_is_running = false
	state = ""
	_announce_scores(true)
	_announce(
		"ᵀʰᵃⁿᵏˢ ᶠᵒʳ ᵖˡᵃʸⁱⁿᵍ! ᵀʳⁱᵛⁱᵃ ⁱˢ ⁱⁿ ᴮᴱᵀᴬ. ᴾˡᵉᵃˢᵉ ʳᵉᵃᶜʰ ᵒᵘᵗ ᵗᵒ @ᵗᵒᵉˢ ᵗᵒ ʳᵉᵖᵒʳᵗ ⁱˢˢᵘᵉˢ ᵒʳ ˢʰᵃʳᵉ ᶠᵉᵉᵈᵇᵃᶜᵏ"
	)
	_scores.clear()


func _reset():
	trivia_is_running = false
	current_round_winners.clear()
	_reset_timers()
	_scores.clear()
	rounds_completed = 0
	state = ""


func sample(list):
	randomize()
	if !list or list.size() == 0:
		return null
	return list[randi() % list.size()]


func _parse_mod_state_arg(input) -> bool:
	match input:
		"on", 1, "true", "enabled", "enable", "active":
			return true
		"off", 0, "false", "disabled", "disable":
			return false
		_:
			push_error("wtf invalid")
			return false


func _log(msg: String) -> void:
	if !DEBUG_MODE:
		return
	print("TRIVIA: " + msg)


func _announce(msg: String) -> void:
	Chat.send_as(BOT_NAME, msg, BOT_COLOR)
