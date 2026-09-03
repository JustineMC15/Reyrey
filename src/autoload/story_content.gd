extends Node
# story_content.gd — autoload singleton "StoryContent"
#
# Plain data only. Each line: {"speaker": String, "text": String,
# "image": Texture2D (optional)}.
const OPENING_LINES := [
	{"text": "A millennium..."},
	{"text": "A millennium has passed since the stars halted their celestial pilgrimage.."},
	{"text": "The world shall soon follow."},
	{"text": "..."},
	{"text": "A star in the shape of a hollow rhombus will soon descend upon the icy ends of the earth."},
	{"text": "Alongside — rather, in search of his herald."},
	{"text": "Bearing the crest upon his tabard."},
]

#const ENDING_BASE_LINES := [
	#{"speaker": "Tin", "text": "There you are."},
	#{"speaker": "Tin", "text": "My name is Correntin, a wanderer. I've watched the rise and fall of civilizations more times than I care to count — the rhythm hidden in the birth and death of stars. I like spending my time alone, quietly. But I did want, once, to find someone to share eternity with."},
	#{"speaker": "Correntin", "text": "Now, Sir Knight,"},
	#{"speaker": "Correntin", "text": "Take my hand,"},
	#{"speaker": "Correntin", "text": "Let's go,"},
	#{"speaker": "Correntin", "text": "You'll walk with me, won't you?"},
#]
#
#const ENDING_TRUE_LINES := [
	#{"speaker": "Tin", "text": "There you are."},
	#{"speaker": "Tin", "text": "My name is Correntin, a wanderer. I've watched the rise and fall of civilizations more times than I care to count — the rhythm hidden in the birth and death of stars. I like spending my time alone, quietly. But I did want, once, to find someone to share eternity with."},
	#{"speaker": "Correntin", "text": "...A—all of them? You actually went and collected all of it?"},
	#{"speaker": "Correntin", "text": "..."},
	#{"speaker": "Correntin", "text": "I can't accept this, I don't deserve it."},
	#{"speaker": "Correntin", "text": "Tell you what — why don't you keep it for now."},
	#{"speaker": "Correntin", "text": "This attempt is a fluke. That which you collected is wasted on me. If you find Tin — lifeless eyes, fake smile — give it to him instead."},
	#{"speaker": "Correntin", "text": "He won't know what it means yet. That's fine. Neither did I, the first time."},
	#{"speaker": "Correntin", "text": "Go on, then. I've got a world to put back to sleep."},
#]

#const ENDING_BAD_LINES := [
	#{"speaker": "???", "text": "It's so unfair…"},
	#{"speaker": "???", "text": "The world turns regardless."},
	#{"speaker": "???", "text": "Spurning all that dare cling to hope."},
	#{"speaker": "???", "text": "We are all but flakes of empty dust"},
	#{"speaker": "???", "text": "Spinning on a ball of rust"},
	#{"speaker": "???", "text": "…"},
	#{"speaker": "???", "text": "Have you come to look at the stars?"},
	#{"speaker": "???", "text": "…"},
	#{"speaker": "???", "text": "I heard a voice once."},
	#{"speaker": "???", "text": "They promised me that when the afterglow of the stars fell, they would catch that light for me."},
	#{"speaker": "???", "text": "I waited."},
	#{"speaker": "???", "text": "I have been waiting for so long."},
	#{"speaker": "???", "text": "I no longer remember their face."},
	#{"speaker": "???", "text": "I no longer remember their voice."},
	#{"speaker": "???", "text": "But I remember the promise."},
	#{"speaker": "???", "text": "Don't you?"},
	#{"speaker": "???", "text": "…"},
	#{"speaker": "???", "text": "Let's take in the view."},
	#{"speaker": "???", "text": "Before the world halts its eternal dance."},
#]

const ENDING_BASE_LINES := [
{"speaker": "Justine Taroy", "text": "Thank you for playing Reyrey's demo!"},
{"speaker": "Justine Taroy", "text": "Unfortunately, this is as far as I was able to get for this demo."},
{"speaker": "Justine Taroy", "text": "Thank you for taking the time to play it."},
{"speaker": "Justine Taroy", "text": "I'd love to hear what you think, and I'm happy to answer any questions."},
{"speaker": "Justine Taroy", "text": "Oh, and feel free to try out testworld.tscn - It has a bunnch of features"},
{"speaker": "Justine Taroy", "text": "That I haven't implemented yet but is fully working"},
]

const ENDING_TRUE_LINES := [
{"speaker": "Justine Taroy", "text": "Thank you for playing Reyrey's demo!"},
{"speaker": "Justine Taroy", "text": "Unfortunately, this is as far as I was able to get for this demo."},
{"speaker": "Justine Taroy", "text": "Thank you for taking the time to play it."},
{"speaker": "Justine Taroy", "text": "I'd love to hear what you think, and I'm happy to answer any questions."},
{"speaker": "Justine Taroy", "text": "Oh, and feel free to try out testworld.tscn - It has a bunnch of features"},
{"speaker": "Justine Taroy", "text": "That I haven't implemented yet but is fully working"},
]

const ENDING_BAD_LINES := [
{"speaker": "Justine Taroy", "text": "Thank you for playing Reyrey's demo!"},
{"speaker": "Justine Taroy", "text": "Unfortunately, this is as far as I was able to get for this demo."},
{"speaker": "Justine Taroy", "text": "Thank you for taking the time to play it."},
{"speaker": "Justine Taroy", "text": "I'd love to hear what you think, and I'm happy to answer any questions."},
{"speaker": "Justine Taroy", "text": "Oh, and feel free to try out testworld.tscn - It has a bunnch of features"},
{"speaker": "Justine Taroy", "text": "That I haven't implemented yet but is fully working"},
]
