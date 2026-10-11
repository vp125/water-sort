class_name Palette
extends RefCounted
## Colour ids used by puzzle units. The first four (purple, orange, yellow, ice blue) are the
## signature colours used by the earliest levels; 12 hues in total, enough for level 50.

const COLORS: Array[Color] = [
	Color("#a855f7"),  # purple
	Color("#fb923c"),  # orange
	Color("#facc15"),  # yellow
	Color("#7dd3fc"),  # ice blue
	Color("#f43f5e"),  # rose red
	Color("#4ade80"),  # green
	Color("#f472b6"),  # pink
	Color("#3b82f6"),  # royal blue
	Color("#14b8a6"),  # teal
	Color("#a3e635"),  # lime
	Color("#b9825a"),  # sand
	Color("#e2e8f0"),  # pearl
]


static func color_of(id: int) -> Color:
	return COLORS[id % COLORS.size()]
