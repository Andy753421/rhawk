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
		delete sp_last      # [x] The result of the last hand
		delete sp_hands     # [p] Each players cards
		delete sp_looked    # [i] Whether a player has looked a their cards
		delete sp_bids      # [i] Each players bid
		delete sp_nil       # [i] Nil multiplier 0=regular, 1=nil, 2=blind
		delete sp_pass      # [i] Cards to pass
		delete sp_tricks    # [i] Tricks this round
	}

	# Per game
	if (type >= 2) {
		sp_state    = "new" #     {new,join,bid,pass,play}
		sp_owner    = ""    #     Who started the game
		sp_playto   = 0     #     Score the game will go to
		sp_dealer   =-1     #     Who is dealing this round
		sp_turn     = 0     #     Index of who's turn it is
		sp_player   = ""    #     Who's turn it is
		sp_limit    = 10    #     Bag out limit / nil bonus
		delete sp_players   # [p] Player names players["name"] -> i
		delete sp_auths     # [c] Player auth names auths["auth"] -> "name"
		delete sp_share     # [c] Player teammates share["friend"] -> "name"
		delete sp_order     # [i] Player order order[i] -> "name"
		delete sp_scores    # [i] Teams score
		delete sp_teams     # [i] Teams names
	}

	# Persistent
	if (type >= 3) {
		sp_channel  = ""    #     channel to play in
		sp_log      = ""    #     Log file name
		sp_sock     = ""    #     UDP log socket
		delete sp_notify    # [p] E-mail notification address
	}
}

function sp_acopy(dst, src,	key)
{
	if (isarray(src)) {
		delete(dst)
		for (key in src)
			json_copy(dst, key, src[key])
	}
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
	json_copy(game, "last",    sp_last);
	json_copy(game, "looked",  sp_looked);
	json_copy(game, "bids",    sp_bids);
	json_copy(game, "nil",     sp_nil);
	json_copy(game, "pass",    sp_pass);
	json_copy(game, "tricks",  sp_tricks);

	# Per game
	game["owner"]   = sp_owner;
	game["playto"]  = sp_playto;
	game["dealer"]  = sp_dealer;
	game["turn"]    = sp_turn;
	game["player"]  = sp_player;
	game["limit"]   = sp_limit;
	json_copy(game, "hands",   sp_hands);
	json_copy(game, "players", sp_players);
	json_copy(game, "auths",   sp_auths);
	json_copy(game, "share",   sp_share);
	json_copy(game, "order",   sp_order);
	json_copy(game, "scores",  sp_scores);
	json_copy(game, "teams",   sp_teams);

	# Persistent
	game["channel"] = sp_channel;
	game["log"]     = sp_log;
	json_copy(game, "notify",  sp_notify);

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
	sp_acopy(sp_last,    game["last"]);
	sp_acopy(sp_looked,  game["looked"]);
	sp_acopy(sp_bids,    game["bids"]);
	sp_acopy(sp_nil,     game["nil"]);
	sp_acopy(sp_pass,    game["pass"]);
	sp_acopy(sp_tricks,  game["tricks"]);

	# Per game
	sp_owner   = game["owner"];
	sp_playto  = game["playto"];
	sp_dealer  = game["dealer"];
	sp_turn    = game["turn"];
	sp_player  = game["player"];
	sp_limit   = game["limit"];
	sp_acopy(sp_hands,   game["hands"]);
	sp_acopy(sp_players, game["players"]);
	sp_acopy(sp_auths,   game["auths"]);
	sp_acopy(sp_share,   game["share"]);
	sp_acopy(sp_order,   game["order"]);
	sp_acopy(sp_scores,  game["scores"]);
	sp_acopy(sp_teams,   game["teams"]);

	# Persistent
	sp_channel = game["channel"];
	sp_log     = game["log"];
	sp_acopy(sp_notify,  game["notify"]);
}

function sp_say(msg)
{
	say(sp_channel, msg)
	print msg |& sp_sock
	print strftime("%Y-%m-%d %H:%M:%S | ") sp_ugly(msg) >> "logs/" sp_log
	fflush("logs/" sp_log)
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

function sp_ugly(cards, who)
{
	gsub(/[\2\17]|\3[14],00|/, "", cards)
	gsub(/♠/, "s", cards)
	gsub(/♥/, "h", cards)
	gsub(/♦/, "d", cards)
	gsub(/♣/, "c", cards)
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

function sp_shuf(i, mixed)
{
	sp_usort(sp_players, mixed)
	for (i in mixed) {
		sp_order[i-1] = mixed[i]
		sp_players[mixed[i]] = i-1
	}
}

function sp_deal(	shuf)
{
	sp_say("/me deals the cards")
	sp_usort(sp_deck, shuf)
	for (i=1; i<=52; i++)
		sp_hands[sp_order[i%4]][shuf[i]] = 1
	sp_state  = "bid"
	sp_dealer = (sp_dealer+1)%4
	sp_turn   =  sp_dealer
	sp_player =  sp_order[sp_turn]
	sp_say(sp_player ": you bid first!")
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

function sp_usort(list, out) {
	for (i in list)
		out[i] = rand()
	asorti(out, out, "@val_num_asc")
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

function sp_team(i, players)
{
	#return "{" sp_order[i+0] "," sp_order[i+2] "}"
	if ((i in sp_teams) && !players)
		return sp_teams[i]
	else
		return sp_order[i+0] "/" sp_order[i+2]
}

function sp_bags(i,	bags)
{
	bags = sp_scores[i] % sp_limit
	if (bags < 0)
		bags += sp_limit
	return bags
}

function sp_bid(who)
{
	return sp_nil[who] == 0 ? sp_bids[who] :
	       sp_nil[who] == 1 ? "nil"        :
	       sp_nil[who] == 2 ? "blind"      : "n/a"
}

function sp_passer(who)
{
	return sp_nil[(who+0)%4] == 2 || sp_nil[(who+1)%4] != 0 ||
	       sp_nil[(who+2)%4] == 2 || sp_nil[(who+3)%4] != 0
}

function sp_bidders(	i, turn, bid, bids)
{
	for (i = 0; i < 4; i++) {
		turn = (sp_dealer + i) % 4
		if (bid = sp_bid(turn))
			bids = bids " " sp_order[turn] ":" bid
	}
	gsub(/^ +| +$/, "", bids)
	return bids
}

function sp_extra(	n, s)
{
	n = sp_bids[0] + sp_bids[1] + sp_bids[2] + sp_bids[3];
	s = n == 12 || n == 14 ? "" : "s";

	return n<13 ? "Playing with " 13-n " bag"   s "!" :
	       n>13 ? "Fighting for " n-13 " trick" s "!" : "No bags!";
}

function sp_score(	bids, times, tricks)
{
	for (i=0; i<2; i++) {
		bids   = sp_bids[i]   + sp_bids[i+2]
		tricks = sp_tricks[i] + sp_tricks[i+2]
		bags   = tricks - bids
		times  = int((sp_bags(i) + bags) / sp_limit)
		if (times > 0) {
			sp_say(sp_team(i) " bag" (times>1?" way ":" ") "out")
			sp_scores[i] -= sp_limit * 10 * times;
		}
		if (tricks >= bids) {
			sp_say(sp_team(i) " make their bid: " tricks "/" bids)
			sp_scores[i] += bids*10 + bags;
		} else {
			sp_say(sp_team(i) " go bust: " tricks "/" bids)
			sp_scores[i] -= bids*10;
		}
	}
	for (i=0; i<4; i++) {
		if (!sp_nil[i])
			continue
		sp_say(sp_order[i] " " \
		    (sp_nil[i] == 1 && !sp_tricks[i] ? "makes nil!"       :
		     sp_nil[i] == 1 &&  sp_tricks[i] ? "fails at nil!"    :
		     sp_nil[i] == 2 && !sp_tricks[i] ? "makes blind nil!" :
		     sp_nil[i] == 2 &&  sp_tricks[i] ? "fails miserably at blind nil!" :
		                                       "unknown"))
		sp_scores[i%2] += sp_limit * 10 * sp_nil[i] * \
			(sp_tricks[i] == 0 ? 1 : -1)
	}
	if (sp_scores[0] > sp_scores[1])
		sp_say(sp_team(0) " lead " sp_scores[0] " to " sp_scores[1] " of " sp_playto)
	else if (sp_scores[1] > sp_scores[0])
		sp_say(sp_team(1) " lead " sp_scores[1] " to " sp_scores[0] " of " sp_playto)
	else
		sp_say("tied at " sp_scores[0] " of " sp_playto)
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
		sp_say(sp_pile[winner] " wins with " sp_pretty(winner, FROM) \
		       " (" sp_pretty(sp_piles, FROM) ")")
		sp_last["player"] = sp_pile[winner];
		sp_last["pile"]   = sp_piles;
		sp_next(sp_pile[winner])
		sp_reset(0)
	}

	# Finish round
	if (sp_tricks[0] + sp_tricks[1] + \
	    sp_tricks[2] + sp_tricks[3] == 13) {
		sp_say("Round over!")
		sp_score()
		if ((sp_scores[0] >= sp_playto || sp_scores[1] >= sp_playto) &&
		    (sp_scores[0]              != sp_scores[1])) {
			sp_say("Game over!")
			winner = sp_scores[0] > sp_scores[1] ? 0 : 1
			looser = !winner
			say(CHANNEL, sp_team(winner) " wins the game " \
			    sp_scores[winner] " to " sp_scores[looser])
			say(CHANNEL, sp_order[winner+0] "++")
			say(CHANNEL, sp_order[winner+2] "++")
			sp_reset(2)

		} else {
			if (sp_scores[0] == sp_scores[1] &&
			    sp_scores[0] >= sp_playto)
				sp_say("It's a tie! Playing an extra round!");
			sp_reset(1)
			sp_deal()
		}
	}
}

# Statistics
function sp_delay(sec)
{
	return (sec > 60*60*24 ? int(sec/60/60/24) "d " : "") \
	       (sec > 60*60    ? int(sec/60/60)%24 "h " : "") \
	                         int(sec/60)%60    "m"
}

function sp_max(list,    i, max)
{
	for (i=0; i<length(list); i++)
		if (max == "" || list[i] > max)
			max = list[i]
	return max
}

function sp_avg(list,    i, sum)
{
	for (i=0; i<length(list); i++)
		sum += list[i]
	return sum / length(list)
}

function sp_cur(list)
{
	return list[length(list)-1]
}

function sp_stats(file,   line, arr, time, user, turn, start, delay, short, extra)
{
	# Process log file
	while ((stat = getline line < file) > 0) {
		# Parse date
		if (!match(line, /^([0-9\- \:]*) \| (.*)$/, arr))
			continue
		gsub(/[:-]/, " ", arr[1])
		time = mktime(arr[1])

		# Parse user
		if (!match(arr[2], /^([^:]*): (.*)$/, arr))
			continue
		user = arr[1]

		# Record user latency
		if (turn) {
			delay[turn][length(delay[turn])] = time - start
			turn  = 0
		}
		if (match(arr[2], /^(it is your|you .*(first|lead)!$)/, arr)) {
			turn  = user
			start = time
		}
	}
	close(file)

	# Add current latency
	if (turn) {
		delay[turn][length(delay[turn])] = systime() - start
		debug("time: " (systime() - start))
	}

	# Check for error
	if (stat < 0)
		reply("File does not exist: " file);

	# Output statistics
	for (user in delay) {
		short = length(user) <= 4 ? user : substr(user, 0, 4)
		extra = (user != turn) ? "" : \
			", " sp_delay(sp_cur(delay[user])) " (cur)";
		say("latency for " short \
			": " sp_delay(sp_avg(delay[user])) " (avg)" \
			", " sp_delay(sp_max(delay[user])) " (max)" extra)
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
	sp_load("var/sp_cur.json")
	sp_sock = "/inet/udp/0/localhost/6173"
	print "starting rhawk" |& sp_sock
	#if (sp_channel)
	#	sp_say("Game restored.")
}

// {
	sp_from  = AUTH in sp_auths ? sp_auths[AUTH] : \
	           AUTH in sp_share ? sp_share[AUTH] : FROM
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
/^\.help$/ {
	say(".help spades -- play a game of spades")
}

/^\.help [Ss]pades$/ {
	say("Spades -- play a game of spades")
	say(".help game -- setup and administer the game")
	say(".help play -- commands for playing spades")
	say(".help auth -- control player authorization")
	next
}

/^\.help game$/ {
	say(".newgame [score] -- start a game to <score> points, default 300")
	say(".endgame -- abort the current game")
	say(".savegame -- save the current game to disk")
	say(".loadgame -- load the previously saved game")
	next
}

/^\.help play$/ {
	say(".join -- join the current game")
	say(".look -- look at your cards")
	say(".bid [n] -- bid for <n> tricks")
	say(".pass [card] -- pass a card to your partner")
	say(".play [card] -- play a card")
	say(".team [name] -- set your team name")
	say(".last -- show who took the previous trick")
	say(".turn -- check whose turn it is")
	say(".bids -- check what everyone bid")
	say(".tricks -- check how many trick have been taken")
	say(".score -- check the score")
	next
}

/^\.help auth$/ {
	say(".auth [who] -- display authentication info for a user")
	say(".allow [who] -- allow another person to play on your behalf")
	say(".deny [who] -- prevent a previously allowed user from playing")
	say(".show -- display which users can play for which players")
	say(".notify [addr] -- email user when it is their turn")
	next
}

# Debugging
AUTH == OWNER &&
/^\.deal (\w+) (.*)/ {
	sp_say(FROM " is cheating for " $2)
	delete sp_hands[$2]
	for (i=3; i<=NF; i++)
		sp_hands[$2][$i] = 1
	next
}

AUTH == OWNER &&
/^\.order (\w+) ([0-4])/ {
	sp_say(FROM " is cheating for " $2)
	sp_order[$3] = $2
	sp_players[$2] = $3
	sp_player = sp_order[sp_turn]
}

AUTH == OWNER &&
sp_state == "play" &&
/^\.force (\w+) (\S+)$/ {
	sp_say(FROM " is cheating for " $2)
	sp_from = $2
	sp_play($3)
	next
}


# Setup
match($0, /^\.newgame ?([1-9][0-9]*) *- *([1-9][0-9]*)$/, _arr) {
	if (_arr[2] > _arr[1])
		$0 = $1 " " int(rand() * (_arr[2]-_arr[1])+_arr[1])
}

/^\.newgame ?([1-9][0-9]*)?$/ {
	if (sp_state != "new") {
		reply("There is already a game in progress.")
	} else {
		$1         = ".join"
		sp_owner   = FROM
		sp_playto  = $2 ? $2 : 300
		sp_limit   = sp_playto > 200 ? 10 : 5;
		sp_state   = "join"
		sp_channel = DST
		sp_log     = strftime("%Y%m%d_%H%M%S.log")
		sp_say(sp_owner " starts a game of Spades to " sp_playto " with " sp_limit " bags!")
	}
}

(sp_from == sp_owner || AUTH == OWNER) &&
/^\.endgame$/ {
	if (sp_state == "new") {
		reply("There is no game in progress.")
	} else {
		sp_say(FROM " ends the game")
		sp_reset(2)
	}
}

/^\.join/ {
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
		sp_say(FROM " joins the game!")
	}
	if (sp_state == "join" && sp_turn == 0) {
		sp_shuf()
		sp_deal()
	}
}

/^\.allow \S+$/ {
	_who = $2 in USERS ? USERS[$2]["auth"] : ""
	_str = _who && _who != $2 ? $2 " (" _who ")" : $2
	if (sp_state ~ "new|join") {
		reply("The game has not yet started")
	}
	else if (!(sp_from in sp_players)) {
		reply("You are not playing")
	}
	else if (!_who) {
		reply(_str " is not logged in")
	}
	else if (_who in sp_players || _who in sp_auths) {
		reply(_str " is a primary player")
	}
	else if (_who in sp_share) {
		reply(_str " is already playing for " sp_share[_who])
	}
	else {
		sp_say(_str " can now play for " sp_from)
		sp_share[_who] = sp_from
	}
}

/^\.deny \S+$/ {
	_who = $2 in USERS ? USERS[$2]["auth"] : $2
	_str = _who && _who != $2 ? $2 " (" _who ")" : $2
	if (sp_state ~ "new|join") {
		reply("The game has not yet started")
	}
	else if (!(sp_from in sp_players)) {
		reply("You are not playing")
	}
	else if (_who in sp_players || _who in sp_auths) {
		reply(_str " is a primary player")
	}
	else if (!(_who in sp_share) || sp_share[_who] != sp_from) {
		reply(_str " is not playing for " sp_from)
	}
	else {
		sp_say(_str " can no longer play for " sp_from)
		delete sp_share[_who]
	}
}

/^\.team/ {
	gsub(/^\.team */, "")
	_team = sp_from in sp_players ? sp_players[sp_from] % 2 : 0
	if (sp_state ~ "new|join") {
		reply("The game has not yet started")
	}
	else if (!(sp_from in sp_players)) {
		reply("You are not playing")
	}
	else if ($0 ~ /^[^a-zA-Z0-9]/) {
		reply("Invalid team name")
	}
	else if ($0 ~ /^./) {
		sp_teams[_team] = substr($0, 0, 32)
		sp_say(sp_team(_team,1) " are now known as " sp_team(_team))
	}
	else {
		delete sp_teams[_team]
		sp_say(sp_team(_team,1) " are boring")
	}
}

/^\.whoami/ {
	if (!(sp_from in sp_players))
		reply("You are not playing")
	else if (sp_from == FROM)
		say(FROM " has an existential crisis")
	else
		reply("You are playing for " sp_from);
}

/^\.notify$/ {
	if (sp_from in sp_notify)
		reply("Your address is " sp_notify[sp_from])
	else
		reply("Your address is not set")
}

/^\.notify clear$/ {
	if (sp_from in sp_notify) {
		reply("Removing address " sp_notify[sp_from])
		delete sp_notify[sp_from]
	} else {
		reply("Your address is not set")
	}
}

/^\.notify \S+@\S+.\S+$/ {
	_addr = $2
	gsub(/[^a-zA-Z0-9_+@.-]/, "", _addr)
	sp_notify[sp_from] = _addr
	reply("Notifying you at " _addr)
}

sp_state ~ "(bid|pass|play)" &&
/^\.show/ {
	delete _lines
	for (_i in sp_share)
		_lines[sp_share[_i]] = _lines[sp_share[_i]] " " _i
	for (_i in _lines)
		say(_i " allowed:" _lines[_i])
}

!sp_valid &&
(sp_state == "bid" || sp_state == "play") &&
/^\.(bid|play)\>/ {
	if (sp_from in sp_players)
		reply("It is not your turn.")
	else
		reply("You are not playing.")
}

sp_valid &&
sp_state == "bid" &&
/^\.bid (0|[1-9][0-9]*)$/ {
	if ($2 < 0 || $2 > 13) {
		reply("You can only bid from 0 to 13")
	} else {
		i = sp_next()
		sp_bids[i] = $2
		if ($2 == 0 && !sp_looked[i]) {
			sp_say(FROM " goes blind nil!")
			sp_nil[i] = 2
		} else if ($2 == 0) {
			sp_say(FROM " goes nil!")
			sp_nil[i] = 1
		} else {
			sp_nil[i] = 0
		}
		if (sp_turn != sp_dealer) {
			sp_say(sp_player ": it is your bid! (" sp_bidders() ")")
		} else {
			sp_say(sp_extra() " (" sp_bidders() ")")
			for (p in sp_players)
				say(p, "You have: " sp_hand(p, p))
			sp_state = "play"
			for (i=0; i<2; i++) {
				if (sp_passer(i)) {
					sp_say(sp_team(i,1) ": select a card to pass " \
					    "(/msg " NICK " .pass <card>)")
					sp_state = "pass"
				}
			}
			if (sp_state == "play")
				sp_say(sp_player ": you have the opening lead!")
		}
	}
}

sp_state == "pass" &&
/^\.pass (\S+)$/ {
	_card = $2
	_team = sp_from in sp_players ? sp_players[sp_from] % 2 : 0

	# check validity and pass
	if (!(sp_from in sp_players)) {
		reply("You are not playing.")
	}
	else if (!sp_passer(_team)) {
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
		sp_say(FROM " passes a card")
	}

	# check for end of passing
	if ((!sp_passer(0) || (sp_pass[0] && sp_pass[2])) &&
	    (!sp_passer(1) || (sp_pass[1] && sp_pass[3]))) {
		for (i in sp_pass) {
			_partner = (i+2)%4
			_card    = sp_pass[i]
			delete sp_hands[sp_order[i]][_card]
			sp_hands[sp_order[_partner]][_card] = 1
		}
		sp_say("Cards have been passed!")
		sp_say(sp_player ": you have the opening lead!")
		for (p in sp_players)
			say(p, "You have: " sp_hand(p, p))
		sp_state = "play"
	}
}

sp_state ~ "(bid|pass|play)" &&
/^\.look$/ {
	if (!(sp_from in sp_players)) {
		reply("You are not playing.")
	} else {
		sp_looked[sp_players[sp_from]] = 1
		say(FROM, "You have: " sp_hand(FROM, sp_from))
	}
}

sp_valid &&
sp_state == "play" &&
/^\.play (\S+)/ {
	_card = $2
	gsub(/[^A-Za-z0-9]/, "", _card);
	if (!(_card in sp_deck)) {
		reply("Invalid card")
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
	else if (!(_card in sp_hands[sp_from])) {
		reply("You do not have that card")
	}
	else {
		sp_play(_card)
		if (sp_state == "play") {
			if (length(sp_hands[sp_from]))
				say(FROM, "You have: " sp_hand(FROM, sp_from))
			if (sp_piles)
				sp_say(sp_player ": it is your turn! " \
				    "(" sp_pretty(sp_piles, sp_player) ")")
			else
				sp_say(sp_player ": it is your turn!")
		}
	}
}

/^\.last/ && sp_state == "play" {
	if (!isarray(sp_last))
		say("No tricks have been taken!");
	else
		say(sp_last["player"] " took " \
		    sp_pretty(sp_last["pile"], FROM));
}

/^\.bids/ && sp_state == "bid" ||
/^\.turn/ && sp_state ~ "(bid|pass|play)" {
	_bids   = sp_bidders()
	_pile   = sp_pretty(sp_piles, FROM)
	_extra  = ""
	delete _notify

	if (/!!/)
		_notify[0] = sp_player
	for (_i in sp_share) {
		if (sp_share[_i] != sp_player)
			continue
		if (/!/)
			_extra = _extra " " _i "!"
		if (/!!!/)
			_notify[length(_notify)] = _i
	}

	if (sp_state == "bid" && !_bids)
		say("It is " sp_player "'s bid!" _extra)
	if (sp_state == "bid" && _bids)
		say("It is " sp_player "'s bid!" _extra " (" _bids ")")
	if (sp_state == "play" && !_pile)
		say("It is " sp_player "'s turn!" _extra)
	if (sp_state == "play" && _pile)
		say("It is " sp_player "'s turn!" _extra " (" _pile ")")

	if (sp_state == "bid" || sp_state == "play") {
		for (_i in _notify) {
			if (_notify[_i] in sp_notify) {
				_bids = _bids ? _bids    : "none"
				_pile = _pile ? sp_piles : "none"
				mail_send(sp_notify[_notify[_i]],     \
					"It is your " sp_state "!", \
					"Bids so far:  " _bids "\n" \
					"Cards played: " _pile)
				say("Notified " _notify[_i] " at " sp_notify[_notify[_i]])
			} else {
				say("No email address for " _notify[_i])
			}
		}
	}

	for (_i=0; sp_state == "pass" && _i<4; _i++)
		if (sp_passer(_i) && !sp_pass[_i])
			say("Waiting for " sp_order[_i] " to pass a card!")
}

/^\.bids$/ && sp_state ~ "(pass|play)" {
	say(sp_order[0] " bid " sp_bid(0) ", " \
	    sp_order[2] " bid " sp_bid(2) ", " \
	    "total: " sp_bids[0] + sp_bids[2])
	say(sp_order[1] " bid " sp_bid(1) ", " \
	    sp_order[3] " bid " sp_bid(3) ", " \
	    "total: " sp_bids[1] + sp_bids[3])
}

/^\.tricks$/ && sp_state == "play" {
	say(sp_order[0] " took " int(sp_tricks[0]) "/" sp_bid(0) ", " \
	    sp_order[2] " took " int(sp_tricks[2]) "/" sp_bid(2))
	say(sp_order[1] " took " int(sp_tricks[1]) "/" sp_bid(1) ", " \
	    sp_order[3] " took " int(sp_tricks[3]) "/" sp_bid(3))
}

(TO == NICK || DST == sp_channel) &&
/^\.(score|status)$/ {
	if (sp_state == "new") {
		say("There is no game in progress")
	}
	if (sp_state ~ "join|bid|pass|play") {
		say("Playing to: " \
		    sp_playto " points, " \
		    sp_limit  " bags")
	}
	if (sp_state == "join") {
		say("Waiting for players: " \
		    sp_order[0] " " sp_order[1] " " \
		    sp_order[2] " " sp_order[3])
	}
	if (sp_state ~ "bid|pass|play") {
		say(sp_team(0) ": " \
		    int(sp_scores[0]) " points, " \
		    int(sp_bags(0))   " bags")
		say(sp_team(1) ": " \
		    int(sp_scores[1]) " points, " \
		    int(sp_bags(1))   " bags")
	}
}

(TO == NICK || DST == sp_channel) &&
/^\.log/ {
	say("http://pileus.org/andy/spades/" sp_log)
}

(TO == NICK || DST == sp_channel) &&
/^\.stats$/ {
	sp_stats("logs/" sp_log);
}

(TO == NICK || DST == sp_channel) &&
/^\.stats ([0-9]+_[0-9]+)(\.log)$/ {
	gsub(/\.log$/, "", $2);
	sp_stats("logs/" $2 ".log");
}

/^\.((new|end|load)game|join|look|bid|pass|play|allow|deny|team|notify)/ {
	sp_save("var/sp_cur.json");
}
