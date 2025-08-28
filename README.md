# (Webfishing) Trivia

_Play trivia in chat while you fish!_

## Instructions

To begin a Trivia session, type `!start` into the chat.

### Commands

- `!pause`
- `!resume`
- `!skip`
- `!stop`
- `!scores`
- `!status`
- `!diff {easy,medium,hard,any}` - Change difficulty. I suggest `easy` the default, for most lobbies...
- `!mode {passive, active}` - Passive mode has longer time limit and cooldown period between questions - to fill the silence in an otherwise quiet fishing lobby - whereas active is intended for use when the entire lobby is just focused on trivia
- `(!mod|!mods) [label] [(on|off)]` - Game modifiers. **See below for info** about modifiers and their usage
- `(!use|!switch) [uid|"none"] ` - Switch Trivia to a custom set. The uid here corresponds to whatever you choose in the Trivia file you created. (And if you did omit it, uid will be the file's name) Switch to "`none`" to reset _back_ to the default Trivia API

### Modifiers

There are an assortment of modifiers for you to play in very different and exciting ways. Here are the modifiers you can enable or disable according to your own proclivities:

```
{
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

    "lifeline":
    {
        "description":
        "A 'SUPER-HINT' lifeline is provided if nobody has guessed by the time the countdown reaches 10-seconds remaining.",
        "active": true
    },

    "survival":
    {
        "description":
        "Just make it to the end! Blind (incorrect) guesses will cost you 1 point! Before you try it- biding time will cost you too. Don't get TOO low... or you're OUT!!",
        "active": false
    },

    "bucket_crab":
    {
        "description":
        "Permits a tiny time window following anyone's correct guess wherein others -who may have been still typing- now have a final chance (very brief!) to lock in to take a 'share' of the round's points",
        "active": true
    }
}
```

Many modifiers are enabled by default but can be turned off to suit your players particular dynamics and skill-level or game preferences.

### Custom Trivia Sets

You may feel inclined to play some Trivia of your own creation or particular fondness on occasion. So, by popular request, I have
included a simple system for loading your own trivia files!

Custom trivia files should be placed in a folder by themselves: `%appData%\godot\app_userdata\webfishing_2_newver\trivia`

You must create the folder if it does not already exist. You will place one (`.json`) file for each of your Trivia sets. I have included an example/template file `tempate.json` in this repository, for your reference. It looks like this:

```json
{
  "name": "Trivia Template",
  "authors": ["Toes"],
  "uid": "my_code",
  "description": "This description should express to ohers the unique traits of your custom trivia set. You can delete me safely.",
  "content": [
    {
      "question": "What is the usefulness of a custom Trivia set's UID?",
      "correct_answer": "You can use it to reference/select the trivia set in-game",
      "alt_answers": [
        "Typing convenience",
        "Alt answers are optional for your trivia questions ",
        "If a player guesses any of these, they will earn points and end the round"
      ],
      "incorrect_answers": ["Mike Myers", "Who cares!", "I can't read"]
    },
    {
      "question": "Which of these is a _true_ statement?",
      "correct_answer": "`needs_choices` should always be used for questions that have too much ambiguity",
      "incorrect_answers": [
        "Mysterious and opaque questions are fun to try and guess",
        "Stamps/Stamp-Mod is safe to download and will NOT infect your computer with any viruses",
        "Trivia questions and answers can be written to unlimited character length",
        "Hardcore players like questions that are unfair and hard"
      ],
      "needs_choices": true
    }
  ]
}
```

## Project

### [Contributing - pull requests welcomed](https://github.com/binury/Toes.Trivia/pulls)

### [Known Issues](https://github.com/binury/Toes.Trivia/issues?q=sort%3Aupdated-desc+is%3Aissue+is%3Aopen)

### [Report an issue / Feedback](https://discord.gg/kjf3FCAMDb)

### [Roadmap and feature requests](https://github.com/binury/Toes.Trivia/issues?q=sort%3Aupdated-desc%20is%3Aissue%20is%3Aopen%20label%3Aenhancement)


## License

This project is licensed under the [Apache License 2.0](./LICENSE.txt).

That means you’re free to use, fork, modify, and even commercialize this project, as long as you:

- Keep the copyright notice and license text with the code  
- Give credit where it’s due  
- State any significant changes you’ve made  
- Accept that the software is provided “as-is” with no warranty  

For the full details, see the [LICENSE](./LICENSE.txt) file.
