artemis/proc
	// next two procs from Deadron.TextHandling, but without the annoyance of Deadron.Test
		// And some minor changes
	text2list(text, separator)
		var textlength      = length(text) // now using length() instead of depricated lentext()
		var separatorlength = length(separator)
		var list/textList   = list()
		var searchPosition  = 1
		var findPosition    = 1
		var buggyText
		while(1)
			findPosition = findtextEx(text, separator, searchPosition, 0)
			buggyText = copytext(text, searchPosition, findPosition)
			textList.Add("[buggyText]")
			searchPosition = findPosition + separatorlength
			if(findPosition == 0)
				return textList
			else
				if(searchPosition > textlength)
					// textList += ""   NO EMPTY ELEMENTS AT EMD
					return textList

	list2text(list/theList, separator)
		var total = theList.len
		if(!total) return
		var newText = "[theList[1]]"
		for(var/count = 2 to total)
			if(separator)
				newText += separator
			newText += "[theList[count]]"
		return newText
	/*replace_char(string, char, replacement){
		var/list/L = text2list(string, char)
		var/replaced = {""}
		for(var/I = 1 to L.len){
			replaced += L[I]
			if(I < L.len){
				replaced += replacement
				}
			}
		return replaced
		}*/
	alphanumeric(string)
		var new_string = ""
		for(var/I = 1 to length(string))
			var char = copytext(string, I, I+1)
			switch(text2ascii(char))
				if(45, 48 to 57, 65 to 90, 95, 97 to 122)
					new_string += char
		return new_string
