extends RefCounted
## Read-only content access. Stable IDs survive renaming characters.
const CharacterDefinition = preload("res://src/data/character_definition.gd")
const ALL: Array = preload("res://resources/characters.tres").characters


static func find(id_or_name: String) -> CharacterDefinition:
	for character: CharacterDefinition in ALL:
		if str(character.id) == id_or_name or character.display_name == id_or_name:
			return character
	return null


static func for_listing(listing: Dictionary) -> CharacterDefinition:
	var character := find(str(listing.get("character_id", listing.get("seller", ""))))
	return character if character != null else ALL[0]


static func pick(rng: RandomNumberGenerator) -> CharacterDefinition:
	return ALL[rng.randi_range(0, ALL.size() - 1)]


static func line(template: String, price: int = 0) -> String:
	return template.replace("{price}", str(price))
