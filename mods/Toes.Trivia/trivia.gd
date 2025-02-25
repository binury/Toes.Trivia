class Question:
	var text: String
	var correct_answer: String
	var incorrect_answers: Array
	var needs_choices: bool
	func _init(args: Dictionary):
		self.text = args.text
		self.correct_answer = args.correct_answer
		self.incorrect_answers = args.incorrect_answers
		self.needs_choices = args.needs_choices

class TriviaMetaEntry:
	var uid: String
	var path: String

class TriviaSet:
	var name: String
	var uid: String
	var description: String
	var config: Dictionary # TODO
	var content: Array

	func _init(args: Dictionary):
		self.name = args.name
		self.uid = args.uid
		self.description = args.description
		self.config = args.config
		self.content = args.content


class Mod:
	var description: String
	var active: bool
