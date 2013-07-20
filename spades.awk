# For saving
@include "json.awk"

# Functions
function sp_init(cards, tmp0, tmp1)
{
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
	# Per message
	if (type <  0) {
		sp_from     = ""    #    The speakers player name
		sp_valid    = ""    #    It is the speaker turn
	}

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
		sp_turn     = 0     #     Index of who's turn it is
		sp_player   = ""    #     Who's turn it is
		sp_limit    = 10    #     Bag out limit
		delete sp_hands     # [p] Each players cards
		delete sp_players   # [p] Player names players["name"] -> i
		delete sp_auths     # [c] Player auth names auths["auth"] -> "name"
		delete sp_order     # [i] Player order order[i] -> "name"
		delete sp_scores    # [i] Teams score
	}
}

function sp_acopy(dst, src,	key)
{
	if (isarray(src))
		for (key in src)
			json_copy(dst, key, src[key])
}

function sp_save(file,	game)
{
	# Per hand
	game["suit"]    = sp_suit;
	game["piles"]   = sp_piles;
	json_copy(game, "pile",    sp_pile);

	# Per round
	game["state"]   = sp_state;
	game["broken"]  = sp_broken;
	json_copy(game, "looked",  sp_looked);
	json_copy(game, "bids",    sp_bids);
	json_copy(game, "nil",     sp_nil);
	json_copy(game, "pass",    sp_pass);
	json_copy(game, "tricks",  sp_tricks);

	# Per game
	game["channel"] = sp_channel;
	game["owner"]   = sp_owner;
	game["playto"]  = sp_playto;
	game["dealer"]  = sp_dealer;
	game["turn"]    = sp_turn;
	game["player"]  = sp_player;
	game["limit"]   = sp_limit;
	json_copy(game, "hands",   sp_hands);
	json_copy(game, "players", sp_players);
	json_copy(game, "auths",   sp_auths);
	json_copy(game, "order",   sp_order);
	json_copy(game, "scores",  sp_scores);

	# Save
	json_save(file, game);
}

function sp_load(file,	game)
{
	# Load
	if (!json_load(file, game))
		return

	# Per hand
	sp_suit    = game["suit"];
	sp_piles   = game["piles"];
	sp_acopy(sp_pile,    game["pile"]);

	# Per round
	sp_state   = game["state"];
	sp_broken  = game["broken"];
	sp_acopy(sp_looked,  game["looked"]);
	sp_acopy(sp_bids,    game["bids"]);
	sp_acopy(sp_nil,     game["nil"]);
	sp_acopy(sp_pass,    game["pass"]);
	sp_acopy(sp_tricks,  game["tricks"]);

	# Per game
	sp_channel = game["channel"];
	sp_owner   = game["owner"];
	sp_playto  = game["playto"];
	sp_dealer  = game["dealer"];
	sp_turn    = game["turn"];
	sp_player  = game["player"];
	sp_limit   = game["limit"];
	sp_acopy(sp_hands,   game["hands"]);
	sp_acopy(sp_players, game["players"]);
	sp_acopy(sp_auths,   game["auths"]);
	sp_acopy(sp_order,   game["order"]);
	sp_acopy(sp_scores,  game["scores"]);
}

function sp_pretty(cards, who)
{
	if (!nocolor[who]) {
		gsub(/[0-9JQKA]*[sc]/, "\0031,00\002&\017", cards) # black
		gsub(/[0-9JQKA]*[hd]/, "\0034,00\002&\017", cards) # red
	}
	if (!nounicode[who]) {
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
	if (length(sp_order) == 4)
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

function sp_hand(to, who,	sort, str)
{
	asorti(sp_hands[who], sort, "sp_csort")
	for (i=0; i<length(sort); i++)
		str = str "" sprintf("%4s", sort[i])
	gsub(/^ +| +$/, "", str)
	return sp_pretty(str, to)
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
	bags = sp_scores[i] % sp_limit
	if (bags < 0)
		bags += sp_limit
	return bags
}

function sp_bidders(	i, turn, bid, bids)
{
	for (i = 0; i < 4; i++) {
		turn = (sp_dealer + i) % 4
		if (sp_bids[turn] && !sp_nil[turn])
			bid  = sp_order[turn] ":" sp_bids[turn]
		else if (sp_nil[turn] == 1)
			bid  = sp_order[turn] ":" "nil"
		else if (sp_nil[turn] == 2)
			bid  = sp_order[turn] ":" "blind"
		else
			continue
		bids = bids " " bid
	}
	gsub(/^ +| +$/, "", bids)
	return bids
}

function sp_score(	bids, times, tricks)
{
	for (i=0; i<2; i++) {
		bids   = sp_bids[i]   + sp_bids[i+2]
		tricks = sp_tricks[i] + sp_tricks[i+2]
		bags   = tricks - bids
		times  = int((sp_bags(i) + bags) / sp_limit)
		if (times > 0) {
			say(sp_team(i) " bag" (times>1?" way ":" ") "out")
			sp_scores[i] -= sp_limit * 10 * times;
		}
		if (tricks >= bids) {
			say(sp_team(i) " make their bid: " tricks "/" bids)
			sp_scores[i] += bids*10 + bags;
		} else {
			say(sp_team(i) " go bust: " tricks "/" bids)
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
	delete sp_hands[sp_from][card]
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
	sp_load("var/sp_cur.json");
	#if (sp_channel)
	#	say(sp_channel, "Game restored.")
}

// {
	sp_from  = AUTH in sp_auths ? sp_auths[AUTH] : FROM
	sp_valid = sp_from && sp_from == sp_player
}

CMD == "PRIVMSG" &&
! /help/ &&
/[Ss]pades/ {
	say("Spades! " sp_pretty("As,Ah,Ad,Ac", FROM))
}

AUTH == OWNER &&
/^\.savegame/ {
	sp_save("var/sp_save.json");
	say("Game saved.")
}

AUTH == OWNER &&
/^\.loadgame/ {
	sp_load("var/sp_save.json");
	say("Game loaded.")
}

# Help
/^\.help [Ss]pades$/ {
	say("Spades -- play a game of spades")
	say("Examples:")
	say(".newgame [score] -- start a game to <score> points, default 500")
	say(".endgame -- abort the current game")
	say(".savegame -- save the current game to disk")
	say(".loadgame -- load the previously saved game")
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
AUTH == OWNER &&
/^\.deal (\w+) (.*)/ {
	say(sp_channel, FROM " is cheating for " $2)
	delete sp_hands[$2]
	for (i=3; i<=NF; i++)
		sp_hands[$2][$i] = 1
	next
}

AUTH == OWNER &&
sp_state == "play" &&
/^\.play (\w+) (\S+)$/ {
	say(sp_channel, FROM " is cheating for " $2)
	sp_from = $2
	sp_play($3)
	next
}


# Setup
/^\.newgame ?([0-9]+)?/ {
	if (sp_state != "new") {
		reply("There is already a game in progress.")
	} else {
		$1         = ".join"
		sp_owner   = FROM
		sp_playto  = $2 ? $2 : 200
		sp_limit   = sp_playto > 200 ? 10 : 5;
		sp_state   = "join"
		sp_channel = DST
		say(sp_owner " starts a game of Spades to " sp_playto " with " sp_limit " bags!")
	}
}

(sp_from == sp_owner || AUTH == OWNER) &&
/^\.endgame$/ {
	if (sp_state == "new") {
		reply("There is no game in progress.")
	} else {
		say(FROM " ends the game")
		sp_reset(2)
	}
}

/^\.join$/ {
	if (sp_state == "new") {
		reply("There is no game in progress")
	}
	else if (sp_state == "play") {
		reply("The game has already started")
	}
	else if (sp_state == "join" && sp_from in sp_players) {
		reply("You are already playing")
	}
	else if (sp_state == "join") {
		i = sp_next()
		sp_players[FROM] = i
		if (AUTH)
			sp_auths[AUTH] = FROM
		sp_order[i] = FROM
		say(FROM " joins the game!")
	}
	if (sp_state == "join" && sp_turn == 0)
		sp_deal()
}

!sp_valid &&
(sp_state "bid" || sp_state == "play") &&
/^\.(bid|play)\>/ {
	if (sp_from in sp_players)
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
		} else {
			sp_nil[i] = 0
		}
		if (sp_turn != sp_dealer) {
			say("Bidding goes to " sp_player "!")
		} else {
			for (p in sp_players)
				say(p, "You have: " sp_hand(p, p))
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
	_card = $2
	_team = sp_from in sp_players ? sp_players[sp_from] % 2 : 0

	# check validity and pass
	if (!(sp_from in sp_players)) {
		say(".slap " FROM ", you are not playing.")
	}
	else if (sp_nil[_team] != 2 && sp_nil[_team+2] != 2) {
		reply("Your team did not go blind")
	}
	else if (sp_pass[sp_players[sp_from]]) {
		reply("You have already passed a card")
	}
	else if (!(_card in sp_deck)) {
		reply("Invalid card")
	}
	else if (!(_card in sp_hands[sp_from])) {
		reply("You do not have that card")
	}
	else {
		sp_pass[sp_players[sp_from]] = $2
		say(sp_channel, FROM " passes a card")
	}

	# check for end of passing
	if (((sp_nil[0] != 2 && sp_nil[2] != 2) || (sp_pass[0] && sp_pass[2])) &&
	    ((sp_nil[1] != 2 && sp_nil[3] != 2) || (sp_pass[1] && sp_pass[3]))) {
		for (i in sp_pass) {
			_partner = (i+2)%4
			_card    = sp_pass[i]
			delete sp_hands[sp_order[i]][_card]
			sp_hands[sp_order[_partner]][_card] = 1
		}
		say(sp_channel, "Cards have been passed, play starts with " sp_player "!")
		for (p in sp_players)
			say(p, "You have: " sp_hand(p, p))
		sp_state = "play"
	}
}

sp_state ~ "(bid|pass|play)" &&
/^\.look$/ {
	if (!(sp_from in sp_players)) {
		say(".slap " FROM ", you are not playing.")
	} else {
		sp_looked[sp_players[sp_from]] = 1
		say(FROM, "You have: " sp_hand(FROM, sp_from))
	}
}

sp_valid &&
sp_state == "play" &&
/^\.play (\S+)$/ {
	_card = $2
	if (!(_card in sp_deck)) {
		reply("Invalid card")
	}
	else if (!(_card in sp_hands[sp_from])) {
		reply("You do not have that card")
	}
	else if (sp_suit && _card !~ sp_suit && sp_hasa(sp_from, sp_suit)) {
		reply("You must follow suit (" sp_suit ")")
	}
	else if (_card ~ /s/ && length(sp_hands[sp_from]) == 13 && sp_hasa(sp_from, "[^s]$")) {
		reply("You cannot trump on the first hand")
	}
	else if (_card ~ /s/ && length(sp_pile) == 0 && sp_hasa(sp_from, "[^s]$") && !sp_broken) {
		reply("Spades have not been broken")
	}
	else {
		sp_play(_card)
		if (sp_state == "play") {
			if (length(sp_hands[sp_from]))
				say(FROM, "You have: " sp_hand(FROM, sp_from))
			if (sp_piles)
				say(sp_player ": it is your turn! " \
				    "(" sp_pretty(sp_piles, sp_player) ")")
			else
				say(sp_player ": it is your turn!")
		}
	}
}

/^\.bids$/ && sp_state ~ "(pass|play)" {
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

/^\.turn/ && sp_state ~ "(bid|pass|play)" {
	_bids = sp_bidders()
	_pile = sp_pretty(sp_piles, FROM)
	if (sp_state == "bid" && !_bids)
		say("It is " sp_player "'s bid!")
	if (sp_state == "bid" && _bids)
		say("It is " sp_player "'s bid! (" _bids ")")
	if (sp_state == "play" && !_pile)
		say("It is " sp_player "'s turn!")
	if (sp_state == "play" && _pile)
		say("It is " sp_player "'s turn! (" _pile ")")
	for (_i=0; sp_state == "pass" && _i<4; _i++)
		if ((sp_nil[_i%2+0]==2 || sp_nil[_i%2+2]==2) && !sp_pass[_i])
			say("Waiting for " sp_order[_i] " to pass a card!")
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
	if (sp_state ~ "bid|pass|play") {
		say("Playing to: " \
		    sp_playto " points, " \
		    sp_limit  " bags")
		say(sp_team(0) ": " \
		    int(sp_scores[0]) " points, " \
		    int(sp_bags(0))   " bags")
		say(sp_team(1) ": " \
		    int(sp_scores[1]) " points, " \
		    int(sp_bags(1))   " bags")
	}
}

/^\.((new|end|load)game|join|look|bid|play)/ {
	sp_save("var/sp_cur.json");
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
