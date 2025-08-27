# Changelog

## 0.10.0

- You can no longer win a round twice by guessing the answer twice.
- Typo tolerance has been loosened again, but still not as loose as earlier versions.

## 0.9.6

- **Change**: multi-winner point distribution allocation and eligibility
  - This is no longer equal distribution and more points are now given to the first guessers
  - Multi-choice questions, which are always low-point (4) rounds, are only given to the first
- **Change**: In crab bucket mode, the answer is no longer acknowledged by the bot

## 0.9.5

- **New** Added typo tolerance for guess validation (experimental; feedback welcome!)
- **Fixed** Issues caused by special characters^[àâäáãåéèêëìíîïöôóòõùúûñÿ] in answers/questions
  - These should no longer break questions
  - You will still need to provide alt-answers _without_ special characters, if you want to show them to players and have them answer with regular characters
- **Change**d `alt answers` to no longer appear when trivia has multiple-choice enabled through `shown_choices`

## 0.9.4

- Fixed default trivia category being locked to animals. Sorry!
- **Fixed (custom trivia) questions being repeated in subsequent rounds**
- Improved handling of custom trivia file loading edge cases
- **Alt-answers are now working!**
- **Specifying a default custom trivia set in meta.json will now activate it upon entering the game, as expected**
- Various improvements and clean up

## 0.9.0

- Added custom trivia sets!
- Add new game modifiers!

## 0.1.0

- (No significant changes) Updated dependencies

## 0.0.8

- Skipping a question quickly after it is asked should no longer crash the game...
  This was caused due to rate limiting by the Trivia API provider providing unexpected results to the parser.
  So, skipping is now somewhat throttled to prevent this from happening.

## 0.0.5

- Hotfixed trivia not loading
- `.` In questions are now shown in hints rather than `?`

## 0.0.3

- Points for guessing correctly should now be awarded expediently
- At the end of the game all players' scores are now reported instead of just the top 3
- Added commands for changing mode/timers as well as the trivia difficulty
- Fixed rounds ending at 9 instead of 10

## 0.0.2

- Remove ability for any player to control until potential issues with multiple
  players having Trivia mod in same lobby can be handled
- Any player can pause or resume trivia now
