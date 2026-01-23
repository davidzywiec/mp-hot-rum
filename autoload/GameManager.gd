extends Node

var host_flag : bool = false
var deck


#Server/Game Manager Actions

#Create deck for the players based on player count
func create_deck(players: int) -> void:
	deck = Deck.new(players)

#Create hand for each player based on the hand count for that round
func deal_hand(round: int) -> void:
	pass
