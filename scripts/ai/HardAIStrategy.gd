extends MediumAIStrategy
class_name HardAIStrategy

# Hard look-ahead is bounded by the server's simulation budget. It samples only
# from unseen card identities in the observation, never the authoritative Deck.
func choose_pickup(observation: Dictionary, random: RandomNumberGenerator) -> Dictionary:
	return super.choose_pickup(observation, random)
