# value:
# 	object: { string : value, .. }
# 	array:  [ value, .. ]
# 	string: "char .."
# 	number: (builtin)
# 	true
# 	false
# 	null
# 
# chars:
# 	any-Unicode-character-except-"-or-\-or-control-character
# 	\"
# 	\\
# 	\/
# 	\b
# 	\f
# 	\n
# 	\r
# 	\t
# 	\u four-hex-digits

# Helpers
function json_gettype(value,   key, sort, n, i)
{
	if (isarray(value)) { 
		for (key in value)
			if (isarray(key))
				return "error"
		n = asorti(value, sort)
		for (i = 0; i < n; i++)
			if (sort[i+1] != i)
				return "object"
		return "array"
	} else {
		if (value == 0 && value == "")
			return "null"
		if (value == value + 0)
			return "number"
		if (value == value "")
			return "string"
		return "error"
	}
}

function json_join(array, sep,   i, str)
{
	str = array[0]
	for (i = 1; i < length(array); i++)
		str = str sep array[i]
	return str
}

function json_copy(dst, to, src,   key)
{
	if (isarray(src)) {
		delete dst[to]
		for (key in src) {
			dst[to][key]
			json_copy(dst[to], key, src[key])
		}
	} else {
		dst[to] = src
	}
}


# Write functions
function json_write_value(value, pad)
{
	switch (json_gettype(value)) {
		case "object": return json_write_object(value, pad)
		case "array":  return json_write_array(value, pad)
		case "number": return json_write_number(value)
		case "string": return json_write_string(value)
		case "null":   return "null"
		default:       return "error"
	}
}

function json_write_object(object, pad,   n, i, sort, key, val, data, len, max)
{
	n = asorti(object, sort)
	for (i = 0; i < n; i++) {
		key = json_write_string(sort[i+1])
		if (length(key) > max)
			max = length(key)
	}
	for (i = 0; i < n; i++) {
		key = json_write_string(sort[i+1])
		val = json_write_value(object[sort[i+1]],
			sprintf("%s  %"max"s  ", pad, ""))
		data[i] = sprintf("%-"(max+1)"s %s", key":", val)
	}
	return "{ " json_join(data, ",\n  " pad) " }"
}

function json_write_array(array, pad,   i, data)
{
	for (i = 0; i < length(array); i++)
		data[i] = json_write_value(array[i], pad "  ")
	return "[ " json_join(data, ",\n  " pad) " ]"
}

function json_write_number(number)
{
	return "" number ""
}

function json_write_string(string)
{
	# todo: special characters
	return "\"" string "\""
}


# Read functions
function json_tokenize(str, tokens,   i, line, items, table, type, found)
{
	table["term"]  = "^[\\[\\]{}:,]"
	table["str"]   = "^\"[^\"]*\""
	table["num"]   = "^[+-]?[0-9]+(.[0-9]+)?"
	table["var"]   = "^(true|false|null)"
	table["space"] = "^[ \\t]+"
	table["line"]  = "^\n"
	i = 0;
	line = 1;
	while (length(str) > 0) {
		found = 0
		for (type in table) {
			#print "match: str=["str"] type="type" regex=/"table[type]"/"
			if (match(str, table[type], items) > 0) {
				#print "       len="RLENGTH" item=["items[0]"]"
				if (type == "line")
					line++;
				if (type == "term")
					type = items[0]
				if (type != "space" && type != "line") {
					tokens[i]["line"] = line
					tokens[i]["type"] = type
					tokens[i]["text"] = items[0]
					i++
				}
				str = substr(str, RLENGTH+1)
				found = 1
				break
			}
		}
		if (!found) {
			debug("line " line ": error tokenizing")
			return 0
		}
	}
	return i

	#for (i = 0; i < length(tokens); i++)
	#	printf "%-3s %-5s [%s]\n", i":",
	#		tokens[i]["type"], tokens[i]["text"]
}

function json_parse_value(tokens, i, value, key,   line, type, text)
{
	if (!i    ) i = 0;
	if (!depth) depth = 0
	depth++
	line = tokens[i]["line"]
	type = tokens[i]["type"]
	text = tokens[i]["text"]
	#printf "parse %d: i=%-2d type=%-3s text=%s\n", depth, i, type, text
	switch (type) {
		case "{":   i = json_parse_object(tokens, i, value, key); break
		case "[":   i = json_parse_array(tokens,  i, value, key); break
		case "str": i = json_parse_string(tokens, i, value, key); break
		case "num": i = json_parse_number(tokens, i, value, key); break
		case "var": i = json_parse_var(tokens,    i, value, key); break
		default:    debug("line "line": error type="type" text="text); return 0
	}
	depth--
	return i
}

function json_parse_object(tokens, i, value, key,   object, k, v)
{
	if (tokens[i++]["text"] != "{")
		return 0;

	do {
		delete k
		delete v
		if (!(i=json_parse_value(tokens, i, k, 0)))
			return 0
		if (tokens[i++]["text"] != ":")
			return 0
		if (!(i=json_parse_value(tokens, i, v, 0)))
			return 0
		json_copy(object, k[0], v[0]) 
	} while (tokens[i++]["text"] == ",")
	i--

	if (tokens[i++]["text"] != "}")
		return 0;

	json_copy(value, key, object)
	return i
}

function json_parse_array(tokens, i, value, key,   array, k, v)
{
	if (tokens[i++]["text"] != "[")
		return 0;

	do {
		delete v
		if (!(i=json_parse_value(tokens, i, v, 0)))
			return 0
		json_copy(array, k++, v[0]) 
	} while (tokens[i++]["text"] == ",")
	i--

	if (tokens[i++]["text"] != "]")
		return 0;

	json_copy(value, key, array)
	return i
}

function json_parse_number(tokens, i, value, key,   text)
{
	text = tokens[i++]["text"]
	json_copy(value, key, text + 0)
	#print "parse_number: " (text + 0)
	return i
}

function json_parse_string(tokens, i, value, key,   text)
{
	text = tokens[i++]["text"]
	len  = length(text);
	text = len == 2 ? "" : substr(text, 2, len-2)
	json_copy(value, key, text)
	#print "parse_string: [" text "]"
	return i
}

function json_parse_var(tokens, i, value, key,   text, null)
{
	switch (tokens[i++]["text"]) {
		case "true":  json_copy(value, key, 1==1); break;
		case "false": json_copy(value, key, 1==2); break;
		case "null":  json_copy(value, key, null); break;
	}
	#print "parse_var: " text " -> " text == "true"
	return i
}


# Nice API?
function json_load(file, var,   line, text, tokens, data, key)
{
	while ((getline line < file) > 0)
		text = text line
	close(file)
	if (!json_tokenize(text, tokens))
		return ""
	if (!json_parse_value(tokens, 0, data, 0))
		return ""
	if (!isarray(data[0]))
		return data[0]
	for (key in data[0])
		json_copy(var, key, data[0][key])
	return 1
}

function json_save(file, var,   cmd, tmp)
{
	cmd = "mktemp " file ".XXX"
	cmd | getline tmp
	close(cmd)
	print json_write_value(var) > tmp
	close(tmp)
	system("mv " tmp " " file)
}


# Test functions
function json_test_write()
{
	num      = 42
	str      = "hello, world"
	arr[0]   = "zero"
	arr[1]   = "one"
	arr[2]   = "two"
	obj["A"] = "a!"
	obj["B"] = "b!"
	obj["C"] = "c!"
	json_copy(mix, "number", num);
	json_copy(mix, "str",    str);
	json_copy(mix, "arr",    arr);
	json_copy(mix, "obj",    obj);
	json_copy(dub, "first",  mix);
	json_copy(dub, "second", mix);
	print json_write_value(num)
	print json_write_value(str)
	print json_write_value(arr)
	print json_write_value(obj)
	print json_write_value(mix)
	print json_write_value(dub)
}

function json_test_read()
{
	json_tokenize("[8, \"abc\", 9]", tokens)
	json_parse_value(tokens, 0, array, 0)
	print json_write_value(array[0])

	json_tokenize("{\"abc\": 1, \"def\": 2}", tokens)
	json_parse_value(tokens, 0, array, 0)
	print json_write_value(array[0])

	json = "{ \"first\":  { \"arr\":    [ \"\",             \n" \
	       "                              -1,               \n" \
	       "                              1.2,              \n" \
	       "                              true,             \n" \
	       "                              false,            \n" \
	       "                              null    ],        \n" \
	       "                \"number\": 42,                 \n" \
	       "                \"obj\":    { \"A\": \"a!\",    \n" \
	       "                              \"B\": \"b!\",    \n" \
	       "                              \"C\": \"c!\" },  \n" \
	       "                \"str\":    \"hello, world\" }, \n" \
	       "  \"second\": { \"arr\":    [ \"zero\",         \n" \
	       "                              \"one\",          \n" \
	       "                              \"two\" ],        \n" \
	       "                \"number\": 42,                 \n" \
	       "                \"obj\":    { \"A\": \"a!\",    \n" \
	       "                              \"B\": \"b!\",    \n" \
	       "                              \"C\": \"c!\" },  \n" \
	       "                \"str\":    \"hello, world\" } }\n"

	json_tokenize(json, tokens)
	json_parse_value(tokens, 0, array, 0)
	print json_write_value(array[0])
}

function json_test_files()
{
	print "load: [" json_load("email.txt", mail) "]"
	print "mail: "  json_write_value(mail, "      ")
	mail["andy753421"] = "andy753421@gmail.com"
	mail["andy"]       = "andy@gmail.com"
	mail["somebody"]   = "foo@example.com"
	print "mail: "  json_write_value(mail, "      ")
	print "save: [" json_save("email.txt", mail) "]"
}

# Main
BEGIN {
	#json_test_write()
	#json_test_read()
	#json_test_files()
}
