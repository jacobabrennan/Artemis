

//------------------------------------------------------------------------------

ceres
	var/global
		ceres/quickLinker/linker = new()
ceres/quickLinker
	parent_type = /datum
	proc
		linkParse(txt)
			return parse(txt)


//-- Quicklinks by Kuraudo -----------------------------------------------------
/*

	libquicklink ©2009 Zac Stringham a.k.a. "Kuraudo"


	This library provides two datums, /quicklink and /quicklink_parser.

	To use, you first define your quicklinks as children of the /quicklink datum. e.g.

		quicklink/myquicklink
			// extend here

	Then you either override /quicklink_parser (via a child type, again), or use
	the default one (depending on your needs).

	Finally, you just have to create an instance of your /quicklink_parser type
	and call my_parser.parse(string), to return the parsed string.

	A full, short example of a way to use this library with 4 fully-functional
	quicklinks can be found in demo.dm. See quicklink.dm and quicklink_parser.dm
	for their datums' respective details on overriding for your own needs.

	Enjoy.

*/


/*

	This is the internal quicklink_parser datum. You will need at least one instance of this to parse
	quicklinks. The reason for use of this datum is that it allows you to create many different quicklink
	parsers, which for instance is useful if you want each player to be able to specify which quicklinks
	to parse. The quicklink_parser only has a few noteworthy features:

	/quicklink_parser
		var/list/quicklinks		// a list of instantiated /quicklink objects

		proc
			init_all()
				// sets quicklinks list to all available quicklinks
				// this is automatically called in New() unless you override New() and don't call ..().

			parse(str)
				// returns a parsed version of str, with consideration to the quicklinks list
*/

ceres/quickLinker
	var
		list/quicklinks

	New()
		init_all()

	proc

		init_all()
			quicklinks = new
			for(var/quicklink in typesof(/ceres/quickLinker/quicklink)-/ceres/quickLinker/quicklink)
				quicklinks += new quicklink

		parse(str)
			var/start = 1
			for()
				var
					ceres/quickLinker/quicklink/min_link
					min_pos = 0
				for(var/ceres/quickLinker/quicklink/Q in quicklinks)
					var/pos = findtextEx(str, Q.name, start)
					if(pos && (!min_pos || pos < min_pos))
						min_pos = pos
						min_link = Q
				if(min_pos)
					var
						query_start = min_pos + min_link.name_len
						query = (query_start>length(str) ? null : min_link.get_query(str, query_start))
						qlink = min_link.make(query)
						offset = (!min_link.numeric && min_link.is_quoted(str, query_start)) \
							? min_link.quote_len \
							: 0
					str = copytext(str, 1, min_pos) + qlink + \
						copytext(str, min_pos + min_link.name_len + length(query) + offset)
					start += length(qlink)
				else
					break
			return str

/*

	This file describes the /quicklink datum, which you can use to define your own set of
	parsed quicklinks. The quicklink looks like so:


	quicklink
		var
			name	// the part preceding the query, e.g. id:3030; name would be "id:"
			name_len	// internal use only
			url		// the URL preceding the query, eg. "http://google.com/search?q="
			numeric = FALSE		// if it can only ever have a numeric query

			quote_len	// the number of characters involved in quotation
		proc
			is_quoted(str, pos)
				// returns the position of the ending quote in a quoted query, e.g.
				// google:"hello world"
				// returns 0 if query is does not start with a quote and have an end
				// str is the string to search from, pos is the query start position

			get_quoted_text(str, pos, endquo_pos)
				// get_query() uses this if is_quoted(str, pos) is nonzero to retrieve
				// the query string. By default this copies from pos+1 and stops before
				// endquo_pos. By overriding is_quoted() and get_quoted_text(), you
				// can redefine your own quote mechanism.

			get_query(str, pos)
				// returns the query string (unmodified, as in no editing and no
				// URL-encoding) from str, where the start position is pos.

			make(query)
				// returns the final URL string of the quicklink

	Any of these methods can be overridden in your own quicklink definitions as long
	as they provide matching behavior to what is expected. For example, if you wanted,
	you could make a non-numeric quicklink first check for various query strings, such
	as "help" or "cp" and then if neither match, only allow numbers as a query string.
*/

ceres/quickLinker/quicklink
	parent_type = /datum
	var
		name
		url
		numeric = FALSE
		name_len	// set automatically
		quote_len = 2	// change at your own risk!

	New()
		name_len = length(name)

	proc
		make(query)	// quicklink:query
			return query \
				? "<a href=\"[url][url_encode(query)]\">[name][url_encode(query)]</a>" \
				: name

		is_quoted(str, pos)
			return (!numeric) && text2ascii(str, pos)==34 && findtextEx(str, "\"", pos+1)

		get_quoted_text(str, pos, endquo_pos)	// pos = first letter of query
			return copytext(str, pos+1, endquo_pos)

		get_query(str, pos)
			if(numeric)
				var/len = length(str)
				for(var/i=pos, i<=len, ++i)
					var/char = text2ascii(str, i)
					if(char < 48 || char > 57)
						return copytext(str, pos, i)
				return copytext(str, pos)
			else
				var/quoted = is_quoted(str, pos)	// position of ending quote
				if(quoted)	// quote
					return get_quoted_text(str, pos, quoted)
				else
					return copytext(str, pos, findtextEx(str, " ", pos+1))
	/*
		Link_Filters(var/T){
			T=Link_Parse(T,"http://developer.byond.com/forum/index.cgi?id=","ID:")
			T=Link_Parse(T,"http://www.google.com/search?q=","google:",":")//For ease, end your begining term with your ending term
			T=Link_Parse(T,"http://dictionary.reference.com/search?q=","define:",":")
			T=Link_Parse(T,"http://games.byond.com/hub/","hub:")//hub:xkey/xgame
			T=Link_Parse(T,"http://byond.com/members/","people:")//hub:xkey/xgame
			return T
			}
		*/

/**************************************************************
	Basic Library Usage

	Now I'll begin defining my various /quicklink types.

	These first few will be accomplished entirely by setting
	the various /quicklink variables.
**************************************************************/

ceres/quickLinker/quicklink
	byond_dev_forum		// Example: id:3306
		name = "id:"
		url = "http://byond.com/developer/forum?id="
		numeric = TRUE

	people	// Example: people:"scoobert"
		name = "people:"
		url = "http://byond.com/members/"

	byond_hub	// Example: hub://Kuraudo.ListSort
		name = "hub:"
		url = "http://byond.com/hub/"

	google	// Example: google:"The meaning of life"
		name = "google:"
		url = "http://google.com/search?q="

	define
		name = "define:"
		url = "http://www.google.com/search?q=define:"

	wikipedia
		name = "wiki:"
		url = "http://wikipedia.org/wiki/"


/**************************************************************
	Advanced Library Usage

	Next I'll start tinkering with some of the /quicklink
	procs to provide some customized behavior. The next
	few types will all be similar to the above google:
	quicklink, except they will have additional rules
	or different syntaxes placed on them.
**************************************************************/

	/*
		By default, libquicklink allows for text queries to
		be quoted, allowing for spaces in the query string;
		e.g., google:"Hello world"

		This can be prevented entirely by always making
		is_quoted() return a false value. Or, is_quoted() could
		be overridden to customize what is used for quotes;
		e.g., google2:$Hello world$

		This example demonstrates the latter method.
	*/
	google2		// Example: google2:$The meaning of life$
		name = "google2:"
		url = "http://www.google.com/search?q="

		is_quoted(str, pos)
			return text2ascii(str, pos)==36 && findtextEx(str, "$", pos+1)


	/*
		If you need to totally change the way quotation works, you can
		do so by modifying:
			is_quoted(str, pos),
			get_quoted_text(str, pos, endquo_pos),
			quote_len	(defaults to 2)

		quote_len must equal the number of quote characters that do not
		appear in the string returned from get_quoted_text(). By default,
		for "hello", this would be 2.

		I'll demonstrate by making the quotes for google3 out of /* and */
	*/
	google3		// Example: google3:/*The meaning of life*/
		name = "google3:"
		url = "http://www.google.com/search?q="
		quote_len = 4	// length("/*") + length("*/")

		is_quoted(str, pos)
			return cmptextEx(copytext(str, pos, pos+2), "/*") \
				&& findtextEx(str, "*/", pos+2)

		get_quoted_text(str, pos, endquo_pos)
			return copytext(str, pos+2, endquo_pos)

	/*
		You can also override the make(query) proc. By default, if query
		is not null, this returns a link formed by concatenating src.url
		and query. If it is null, it just returns the text src.name.

		This simplistic override will turn google4: into a Google search,
		but if google4:mail is used, it will go to mail.google.com.
	*/
	google4		// Example: google4:mail | google4:foo
		name = "google4:"
		url = "http://www.google.com/search?q="

		make(query)
			if(query)
				if(cmptext(query, "mail"))
					return "<a href=\"http://mail.google.com\">[name][query]</a>"
				else
					return "<a href=\"[url][url_encode(query)]\">[name][url_encode(query)]</a>"
			else
				return name

	/*
		Scoobert.QuickLinks uses its own take on quotation: You provide a
		terminating character (the demo uses ":"). For strings that use this,
		it also -requires- the colon. I'll model this behavior in the most
		technical example yet, google5:
	*/
	google5		// Example: google5:The meaning of life:
		name = "google5:"
		url = "http://www.google.com/search?q="
		quote_len = 0	// the ending colon is returned by get_quoted_text()

		is_quoted(str, pos)
			return findtextEx(str, ":", pos)

		get_quoted_text(str, pos, endquo_pos)
			return copytext(str, pos, endquo_pos+1)

		make(query)	// if quoted, the terminating colon will be in query
			if(query)
				var/len = length(query)
				if(len>1 && text2ascii(query, len)==58)	// ends in ":"
					query = copytext(query, 1, len)	// trim ending colon
					return "<a href=\"[url][url_encode(query)]\">[name][url_encode(query)]:</a>"
				else
					return name + query

			else
				return name