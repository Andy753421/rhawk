# Functions
function sp_init(cards, tmp0, tmp1)
{
	sp_valid    = 0     #     Message sent from sp_player
	sp_player   = ""    #     Who's turn it is
	sp_turn     = 0     #     Index of who's turn it is
	delete sp_hands     # [p] Each players cards

	# Init deck
	cards ="As Ks Qs Js 10s 9s 8s 7s 6s 5s 4s 3s 2s "\
	       "Ah Kh Qh Jh 10h 9h 8h 7h 6h 5h 4h 3h 2h "\
	       "Ac Kc Qc Jc 10c 9c 8c 7c 6c 5c 4c 3c 2c "\
	       "Ad Kd Qd Jd 10d 9d 8d 7d 6d 5d 4d 3d 2d"
	split(cards, tmp0)
	for (i=1; i<=length(tmp0); i++)
		sp_deck[tmp0[i]] = i
}

function sp_reset(type)
{
	# Per hand
	if (type >= 0) {
		sp_suit     = ""    #     The lead suit {s,h,d,c}
		sp_piles    = ""    # [x] Played cards this turn
		delete sp_pile      # [x] Played cards this turn
	}

	# Per round
	if (type >= 1) {
		sp_state    = "bid" #     {new,join,bid,pass,play}
		sp_broken   = 0     #     Whether spades are broken
		delete sp_looked    # [i] Whether a player has looked a their cards
		delete sp_bids      # [i] Each players bid
		delete sp_nil       # [i] Nil multiplier 0=regular, 1=nil, 2=blind
		delete sp_pass      # [i] Cards to pass
		delete sp_tricks    # [i] Tricks this round
	}

	# Per game
	if (type >= 2) {
		sp_channel  = ""    #     channel to play in
		sp_state    = "new" #     {new,join,bid,play}
		sp_owner    = ""    #     Who started the game
		sp_playto   = 0     #     Score the game will go to
		sp_dealer   =-1     #     Who is dealing this round
		delete sp_players   # [p] Player names players["name"] -> i
		delete sp_order     # [i] Player order order[i] -> "name"
		delete sp_scores    # [i] Teams score
	}
}

function sp_pretty(cards, who)
{
	if (!plain[who]) {
		gsub(/[0-9JQKA]*[sc]/, "\0031,00\002&\017", cards) # black
		gsub(/[0-9JQKA]*[hd]/, "\0034,00\002&\017", cards) # red
		gsub(/s/, "\002♠", cards)
		gsub(/h/, "\002♥", cards)
		gsub(/d/, "\002♦", cards)
		gsub(/c/, "\002♣", cards)
	}
	return cards
}

function sp_next(who, prev)
{
	prev      = sp_turn
	sp_turn   = who ? sp_players[who] : (sp_turn + 1) % 4
	sp_player = sp_order[sp_turn]
	return prev
}

function sp_deal(	shuf)
{
	say("/me deals the cards")
	asorti(sp_deck, shuf, "sp_usort")
	for (i=1; i<=52; i++)
		sp_hands[sp_order[i%4]][shuf[i]] = 1
	sp_state  = "bid"
	sp_dealer = (sp_dealer+1)%4
	sp_turn   =  sp_dealer
	sp_player =  sp_order[sp_turn]
	say("Bidding starts with " sp_player "!")
}

function sp_hand(who,	sort, str)
{
	asorti(sp_hands[who], sort, "sp_csort")
	for (i=0; i<length(sort); i++)
		str = str "" sprintf("%4s", sort[i])
	gsub(/^ +| +$/, "", str)
	return sp_pretty(str, who)
}

function sp_hasa(who, expr)
{
	for (c in sp_hands[who]) {
		if (c ~ expr)
			return 1
	}
	return 0
}

function sp_type(card)
{
	return substr(card, length(card))
}

function sp_usort(a,b,c,d) {
	return rand() - 0.5
}

function sp_csort(i1,v1,i2,v2) {
	return sp_deck[i1] > sp_deck[i2] ? +1 :
	       sp_deck[i1] < sp_deck[i2] ? -1 : 0;
}

function sp_winner(	card, tmp)
{
	for (card in sp_pile)
		if (card !~ sp_suit && card !~ /s/)
			delete sp_pile[card]
	asorti(sp_pile, tmp, "sp_csort")
	#print "pile: " tmp[1] ">" tmp[2] ">" tmp[3] ">" tmp[4]
	return tmp[1]
}

function sp_team(i)
{
	#return "{" sp_order[i+0] "," sp_order[i+2] "}"
	return sp_order[i+0] "/" sp_order[i+2]
}

function sp_bags(i,	bags)
{
	bags = sp_scores[i] % 10
	if (bags < 0)
		bags += 10
	return bags
}

function sp_score(	bids, tricks)
{
	for (i=0; i<2; i++) {
		bids   = sp_bids[i]   + sp_bids[i+2]
		tricks = sp_tricks[i] + sp_tricks[i+2]
		bags   = tricks - bids
		if (sp_bags(i) + bags >= 10) {
			say(sp_team(i) " bag out")
			sp_scores[i] -= 100
		}
		if (tricks >= bids) {
			say(sp_team(i) " make their bid")
			sp_scores[i] += bids*10 + bags;
		} else {
			say(sp_team(i) " go bust")
			sp_scores[i] -= bids*10;
		}
	}
	for (i=0; i<4; i++) {
		if (!sp_nil[i])
			continue
		say(sp_order[i] " " \
		    (sp_nil[i] == 1 && !sp_tricks[i] ? "makes nil!"       :
		     sp_nil[i] == 1 &&  sp_tricks[i] ? "fails at nil!"    :
		     sp_nil[i] == 2 && !sp_tricks[i] ? "makes blind nil!" :
		     sp_nil[i] == 2 &&  sp_tricks[i] ? "fails miserably at blind nil!" :
		                                       "unknown"))
		sp_scores[i%2] += 100 * sp_nil[i] * \
			(sp_tricks[i] == 0 ? 1 : -1)
	}
}

function sp_play(card,	winner, pi)
{
	delete sp_hands[FROM][card]
	sp_pile[card] = sp_player
	sp_piles      = sp_piles (sp_piles?",":"") card
	sp_next()

	if (card ~ /s/)
		sp_broken = 1

	# Start hand
	if (length(sp_pile) == 1)
		sp_suit = sp_type(card)

	# Finish hand
	if (length(sp_pile) == 4) {
		winner = sp_winner()
		pi     = sp_players[sp_pile[winner]]
		sp_tricks[pi]++
		say(sp_pile[winner] " wins with " sp_pretty(winner, FROM) \
		    " (" sp_pretty(sp_piles, FROM) ")")
		sp_next(sp_pile[winner])
		sp_reset(0)
	}

	# Finish round
	if (sp_tricks[0] + sp_tricks[1] + \
	    sp_tricks[2] + sp_tricks[3] == 13) {
		say("Round over!")
		sp_score()
		if (sp_scores[0] >= sp_playto || sp_scores[1] >= sp_playto &&
		    sp_scores[0]              != sp_scores[1]) {
			say("Game over!")
			winner = sp_scores[0] > sp_scores[1] ? 0 : 1
			looser = !winner
			say(sp_team(winner) " wins the game " \
			    sp_scores[winner] " to " sp_scores[looser])
			say(sp_order[winner+0] "++")
			say(sp_order[winner+2] "++")
			say(sp_order[looser+0] "--")
			say(sp_order[looser+2] "--")
			sp_reset(2)

		} else {
			if (sp_scores[0] == sp_scores[1] && 
			    sp_scores[0] >= sp_playto)
				say("It's tie! Playing an extra round!");
			sp_reset(1)
			sp_deal()
		}
	}
}

# Misc
BEGIN {
	cmd = "od -An -N4 -td4 /dev/random"
	cmd | getline seed
	close(cmd)
	srand(seed)
	sp_init()
	sp_reset(2)
}

// {
	sp_valid = (FROM && FROM == sp_player)
}

! /help/ &&
/[Ss]pades/ {
	say("Spades! " sp_pretty("As,Ah,Ad,Ac", FROM))
}

# Help
/^\.help [Ss]pades$/ {
	say("Spades -- play a game of spades")
	say("Examples:")
	say(".newgame [score] -- start a game to <score> points, default 500")
	say(".endgame -- abort the current game")
	say(".join -- join the current game")
	say(".look -- look at your cards")
	say(".bid n -- bid for <n> tricks")
	say(".play [card] -- play a card")
	say(".score -- check the score")
	say(".tricks -- check how many trick have been taken")
	say(".bids -- check what everyone bid")
	next
}

# Debugging
FROM == OWNER &&
/^\.deal (\w+) (.*)/ {
	delete sp_hands[$2]
	for (i=3; i<=NF; i++)
		sp_hands[$2][$i] = 1
	privmsg(sp_channel, FROM " is cheating for " $2)
}


# Setup
/^\.newgame ?([0-9]+)?$/ {
	if (sp_state != "new") {
		reply("There is already a game in progress.")
	} else {
		sp_owner   = FROM
		sp_playto  = $2 ? $2 : 200
		sp_state   = "join"
		sp_channel = DST
		say(sp_owner " starts a game of Spades to " sp_playto "!")
		#privmsg("#rhnoise", sp_owner " starts a game of Spades in " DST "!")
	}
}

(FROM == sp_owner || FROM == OWNER) &&
/^\.endgame$/ {
	if (sp_state == "new") {
		reply("There is no game in progress.")
	} else {
		say(FROM " ends the game")
		sp_reset(5)
	}
}

/^\.join$/ {
	if (sp_state == "new") {
		reply("There is no game in progress")
	}
	else if (sp_state == "play") {
		reply("The game has already started")
	}
	else if (sp_state == "join" && FROM in sp_players) {
		reply("You are already playing")
	}
	else if (sp_state == "join") {
		i = sp_next()
		sp_order[i] = FROM
		sp_players[FROM] = i
		say(FROM " joins the game!")
	}
	if (sp_state == "join" && sp_turn == 0)
		sp_deal()
}

!sp_valid &&
(sp_state "bid" || sp_state == "play") &&
/^\.(bid|play)\>/ {
	if (FROM in sp_players)
		say(".slap " FROM ", it is not your turn.")
	else
		say(".slap " FROM ", you are not playing.")
}

sp_valid &&
sp_state == "bid" &&
/^\.bid [0-9]+$/ {
	if ($2 < 0 || $2 > 13) {
		say("You can only bid from 0 to 13")
	} else {
		i = sp_next()
		sp_bids[i] = $2
		if ($2 == 0 && !sp_looked[i]) {
			say(FROM " goes blind nil!")
			sp_nil[i] = 2
		} else if ($2 == 0) {
			say(FROM " goes nil!")
			sp_nil[i] = 1
		}
		if (sp_turn != sp_dealer) {
			say("Bidding goes to " sp_player "!")
		} else {
			for (p in sp_players)
				privmsg(p, "You have: " sp_hand(p))
			sp_state = "play"
			for (i=0; i<2; i++) {
				if (sp_nil[i] == 2 || sp_nil[i+2] == 2) {
					say(sp_team(i) ": select a card to pass " \
					    "(/msg " NICK " .pass <card>)")
					sp_state = "pass"
				}
			}
			if (sp_state == "play")
				say("Play starts with " sp_player "!")
		}
	}
}

sp_state == "pass" &&
/^\.pass (\S+)$/ {
	card = $2
	team = sp_players[FROM] % 2
	if (!(FROM in sp_players)) {
		say(".slap " FROM ", you are not playing.")
	}
	else if (sp_nil[team] != 2 && sp_nil[team+2] != 2) {
		reply("Your team did not go blind")
	}
	else if (sp_pass[sp_players[FROM]]) {
		reply("You have already passed a card")
	}
	else if (!(card in sp_deck)) {
		reply("Invalid card")
	}
	else if (!(card in sp_hands[FROM])) {
		reply("You do not have that card")
	}
	else {
		sp_pass[sp_players[FROM]] = $2
		privmsg(sp_channel, FROM " passes a card")
	}
	if (((sp_nil[0] != 2 && sp_nil[2] != 2) || (sp_pass[0] && sp_pass[2])) &&
	    ((sp_nil[1] != 2 && sp_nil[3] != 2) || (sp_pass[1] && sp_pass[3]))) {
		for (i in sp_pass) {
			partner = (i+2)%4
			card    = sp_pass[i]
			delete sp_hands[sp_order[i]][card]
			sp_hands[sp_order[partner]][card] = 1
		}
		privmsg(sp_channel, "Cards have been passed, play starts with " sp_player "!")
		for (p in sp_players)
			privmsg(p, "You have: " sp_hand(p))
		sp_state = "play"
	}
}

sp_state ~ "(play|bid)" &&
/^\.look$/ {
	if (!(FROM in sp_players)) {
		say(".slap " FROM ", you are not playing.")
	} else {
		sp_looked[sp_players[FROM]] = 1
		privmsg(FROM, "You have: " sp_hand(FROM))
	}
}

sp_valid &&
sp_state == "play" &&
/^\.play (\S+)$/ {
	card = $2
	if (!(card in sp_deck)) {
		reply("Invalid card")
	}
	else if (!(card in sp_hands[FROM])) {
		reply("You do not have that card")
	}
	else if (sp_suit && card !~ sp_suit && sp_hasa(FROM, sp_suit)) {
		reply("You must follow suit (" sp_suit ")")
	}
	else if (card ~ /s/ && length(sp_hands[FROM]) == 13 && sp_hasa(FROM, "[^s]$")) {
		reply("You cannot trump on the first hand")
	}
	else if (card ~ /s/ && length(sp_pile) == 0 && sp_hasa(FROM, "[^s]$") && !sp_broken) {
		reply("Spades have not been broken")
	}
	else {
		sp_play(card)
		privmsg(FROM, "You have: " sp_hand(FROM))
		if (sp_state == "play") {
			if (sp_piles)
				say(sp_player ": it is your turn! " \
				    "(" sp_pretty(sp_piles, sp_player) ")")
			else
				say(sp_player ": it is your turn!")
		}
	}
}

/^\.bids$/ && sp_state == "play" {
	say(sp_order[0] " bid " sp_bids[0] ", " \
	    sp_order[2] " bid " sp_bids[2] ", " \
	    "total: " sp_bids[0] + sp_bids[2])
	say(sp_order[1] " bid " sp_bids[1] ", " \
	    sp_order[3] " bid " sp_bids[3] ", " \
	    "total: " sp_bids[1] + sp_bids[3])
}

/^\.tricks$/ && sp_state == "play" {
	say(sp_order[0] " took " int(sp_tricks[0]) "/" int(sp_bids[0]) ", " \
	    sp_order[2] " took " int(sp_tricks[2]) "/" int(sp_bids[2]))
	say(sp_order[1] " took " int(sp_tricks[1]) "/" int(sp_bids[1]) ", " \
	    sp_order[3] " took " int(sp_tricks[3]) "/" int(sp_bids[3]))
}

(TO == NICK || DST == sp_channel) &&
/^\.(score|status)$/ {
	if (sp_state == "new") {
		say("There is no game in progress")
	}
	if (sp_state == "join") {
		say("Waiting for players: " \
		    sp_order[0] " " sp_order[1] " " \
		    sp_order[2] " " sp_order[3])
	}
	if (sp_state == "bid" || sp_state == "play") {
		say(sp_team(0) ": " \
		    int(sp_scores[0]) " points, " \
		    int(sp_bags(0))   " bags")
		say(sp_team(1) ": " \
		    int(sp_scores[1]) " points, " \
		    int(sp_bags(1))   " bags")
	}
}

# Standin
#/^\.playfor [^ ]*$/ {
#}
#
#/^\.standin [^ ]*$/ {
#	if (p in sp_players) {
#	}
#	for (p in sp_standin) {
#		if ($2 in sp_standin) 
#		say(here " is already playing for " sp_standin[p]);
#	}
#	sp_standin[away] = here
#}
#
