##		--/					 HEADER						--/

// File & Blob Library is standalone.
// v. 2021.01.18
// dblob.open can not be used in a non Thief environment


##		/--		§		§File_&_Blob_Library§		§		--\
//
//	This file contains tools to interact with files (read only) and blobs.
//	Ultimately enabling the extraction of data/parameters from files. 
//
//	Both are rather similar in use one point that could be overlooked easily:
//	Files are streamed from the OS system, means changing the file, changes the output.
//	 That's used for the cIngameLogOverlay for example.
#NOTE IMPORTANT! Getting parameters over line breaks might not work. Depending on what linebreak type is used in the file.
#					For windows (CR LF) it does add +1 additional character per line! On Unix (LF) it works correctly.
#					see: https://en.wikipedia.org/wiki/Newline
#					Problem the pointer skips it, adding +2 to the position without telling.

class dfile
{
/* More interestingly is the dblob class, but as most actions which work for blobs also work for files, this is the upper class but it the end they are codependant.*/
myblob = null								// As we will work more with the derived dblob class

	constructor(filename, path = ""){
		switch (::type(filename))
		{
			case "string":
				try {
					myblob = ::file(path+filename, "r")
					break
				} catch(notfound) {
					try{
						# FMizePath
						local str = string()
						filename = Version.FMizePath(path+filename, str)
						myblob = ::file(filename, "r")
						break
					}
					catch(notfound2)
						error("DScript ERROR!: "+filename+" not found. Necessary file for this script.")
					return
				}
			case "file" :
				myblob = filename
				break
			default :
				throw "Trying to construct with invalid parameters."
		}
	}

// |-- Special functions --|
	function getParam(param, def = "", separator = '"', offset = 0){
	/* There it is the extract a parameter function. Yay :)
		First scans until it finds the parameter, then looks for the next separator and the next behind it. Then returns the slice between these two.*/
	#NOTE IMPORTANT: dfile and dblob.getParam work differently when there are linebreaks! 
	#					dfile will give +1 character per linebreak on windows CR LF linebreaks. Unix LF is fine. #TODO didn't I fix this?
		local valid = find(param, offset)
		if (valid >= 0){										// Check if present
			if (find(separator, valid)){						// Search for next separator
				local rv = ""
				while(true){
					local c = readNext(separator)
					if (c)
						rv += c.tochar()
					else
						return rv
				}
			}
		}
		#DEBUG
		// DPrint(param + " or separator " + separator + "not found.")
		return def
	}

	function getParam2(param, def = "", start = 1, length = 0, offset = 0){
		if (find(param, offset) >= 0){ 			// Check if present and move pointer behind pattern
			myblob.seek(start+param.len()-1, 'c')				// move start forward
			local rv = ""
			for (local i = 0; (length? i < length : true); i++){		// if length == 0 it will read to the end of the line.
				local c = readNext('\n')
				if (c)
					rv += c.tochar()
				else break						// breaks at EOS and linebreaks.
			}
			return rv
		}
		#DEBUG
		// DPrint(param + " or separator " + separator + "not found.")
		return def
	}

	/*
	function getParamOld(param, separator = '"', offset = 0){
	// Old slim version. Throws if not found. New ones should be faster as well, as it writes 
		return slice(
				find(separator, find(param, offset)) +1 ,
				find(separator, myblob.tell())) 	}*/


//	|-- Blob & File functions --|
	function len()
		return myblob.len()
		
	function tell()
		return myblob.tell()
	
	function seek(offset, origin = 'b')
		myblob.seek(offset, origin)
	
	function readNext(separator = null){
		if (myblob.eos())
			return null
		local c = myblob.readn('c')
		if (c == '\\'){				// escape character
			myblob.seek(1,'c')		// skip the next
			c = myblob.readn('c')	// and get the next
		}
		if (c == separator)
			return false
		return c
	}

	function close(){
		myblob.flush()
		if (typeof myblob == "file")
			myblob.close()
		myblob = null
	}
	
	function flush(){
		return myblob.flush()
	}

//	|-- String like functions --|
	function slice(start, end = 0){
	/* Returns a copy containing only the elements from start to the end point.
		If start is negative it begins at the end of the stream; same for a negative end value it will take that value from the end of the stream.*/
		myblob.seek( start, start < 0? 'e' : 'b')
		if (end <= 0)
			end = myblob.len() + end			// get absolute position
		end = end - myblob.tell()				// end must be a length. So absolute position - current position
		if (end < 0){							// Still < 0? String slice would throw an error now. We slice backwards then.
			return slice(start + end, start)
		} 
		return ::dblob(myblob.readblob(end))
	}
	
	function CheckIfSubstring(str){
	/* Subfunction for find: Checks if the next characters in the blob match to the given substring.
		Assumes that you already have prechecked the first character. readn == str[0]*/
		for (local i = 1; i < str.len(); i++)
		{	
			if (myblob[tell() + i -1] != str[i]){
				return false	// One char does not match
			}
		}
		return true				// All matched
	}
	
	function find(pattern, start = 0, stopString = null){	// stopCharacter could be used as a hard terminator beside EOS
		if (pattern == "")
			return 0							
		myblob.seek( start, (start < 0)? 'e' : 'b')	// pointer to start or end.
		if (typeof pattern == "integer"){
			local stopChar = stopString? stopString[0] : -1;
			while (true){
				local c = readNext()
				if (c == pattern){
					return myblob.tell() - 1		// Start Position is 1 before.
				}
				if (c == stopChar && CheckIfSubstring(stopString)){
					// check if next characters match the stopString
					return false
				}
				if (!c)								// null is EOS, false is stopCharacter
					return c
			}
		} else {
			local length = pattern.len()
			if (length == 1)						// If the string has only length 1 we are done.
				return (pattern[0], myblob.tell(), stopString)
			while (true){
				local first = find(pattern[0], myblob.tell(), stopString)
				if (!first && first != 0)
					return null						// EOS
				if (CheckIfSubstring(pattern))
					return first
			}
		}
	}
	
	//	|-- Metamethods --|
	function _typeof()
		return typeof myblob
		
	function toblob()						// Child Labor!!!
		return (myblob.seek(0), ::dblob(myblob).toblob())	// as dblob(file) does not reset the seeker let's do it here.
	
	function todblob()	# dBlob
		return (myblob.seek(0), ::dblob(myblob))
	
	function _tostring(){	# This uses more memory, could be done more natural. Don't close file.
		local str = ::dblob(myblob, false).tostring()
		myblob.seek(0, 'b')
		return str
	}
		
	function _get(key){
		if (typeof key == "integer") {
			myblob.seek(key)
			return myblob.readn('c')
		}
		if (key == "myfile")
			return myblob
		throw null
	}
	
	function _nexti(previdx){
		if (myblob.len() == 0){
			return null
		} else if (previdx == null) {
			return 0;
		} else if (previdx == myblob.len()-1) {
			return null;
		} else {
			return previdx + 1;
		}
	}

}


class dblob extends dfile
{
/* This is a custom blob like class, which works as an interface between blobs, strings and files:
	It combines basic blob&file functions like seek, writec with string operations like slice, find, +
	And advanced functions like getParam to search and extract data from a blob. */

// --------------------------------------------------------------------------

/*

 |-- Interaction with other data types
 dblob("string")			-> stores the string as blob of 8bit characters.
 dblob(blob)	 			-> stores an actual blob directly.
 dblob("A") + "string" 		-> "Astring"
 dblob("A") + blob			-> dblob('A'blob)	a real blob gets append consisting out of bytes.
 dblob("A") + dblob("B") 	-> dblob('AB') 		combined
 dblob("A") * "string" 		-> dblob('Astring')	combined. This method is much faster!
 dblob(dblob("2"))			-> dblob('2')		no nesting.
 dblob(integer)				-> dblob(integer.tochar()) this at the moment will only write a single 8-bit character to the blob.
														only values between -128 and 127 make sense.
 
 dblob(a fi|le)				-> dblob('|le')		Pointer position in file matters.
 dblob.open(a fi|le, path)	-> dblob('|file')	File as a whole.
 
 |--  Get and set parts of the blob 
  dblob("ABCDE")[1] 			-> 'A'
  dblob("ABCDE")[2]  = "x"		-> dblob('AxCDE')
  dblob("ABCDE")[-2] = 'x'		-> dblob('ABCxE')
  dblob("ABCDE")[2]  = "xyz"	-> dblob('AxyzE')	this sets [3] and [4] as well.
  dblob("ABCDE")[-2] = "xyz"	-> dblob('ABCxyz')	blob will grow.

 Included functions:

 Blob like
 dblob.tell, len, writec		equal to dblob.myblob.tell, len, writen(*, 'c'); with writec expecting a string, array, blob to iterate.
 dblob.myblob or dblob.toblob() -> returns the stored blob
 
 --- String like ---
 
 dblob("A").tostring() 			-> "A"
 dblob(blob).tostring()			-> Same as above but use it to turn an actual blob into a string of characters.
 
 
 dblob.find(pattern, startposition = 0)					Both behave like the string.find and .slice functions.
 dblob.slice(begin, end = )					
 dblob.getParam(pattern, separator = '"' , offset = 0)	Looks for the pattern/parameter name and returns the part that it finds between the 
															next two occurrences of the separator.
*/


// |-- Constructor --|
	constructor(str, close=true){
		switch (typeof str)
		{
			case "string":
				myblob = ::blob(str.len())
				writec(str)
				break
			case "file" :
				// str.seek(0) let's not seek to make custom position possible.
				if (str instanceof ::dfile){
					myblob = str.myblob.readblob(str.len())
				}
				else {
					myblob = str.readblob(str.len())
				}
				if (close)
					str.close()
				break
			case "blob" :
					if (str instanceof dblob)
						myblob = str.myblob
					else
						myblob = str
				break
			case "float" :
				str.tointeger()
			case "integer" :
				myblob = ::blob()
				myblob.writen(str, 'c') // 'c' 8 bit signed integer (char)
				break
			default :
				throw "Trying to construct a dblob with invalid parameter."
			return this
		}
	}

	function open(filename, path = "", closefile=true){
		// TODO: Fmize this
		local fullpath = string()
		Version.FMizePath(path + filename, fullpath)
		try
			return dblob(::file(fullpath.tostring(), "r"), closefile)
		catch(notfound){
			throw(filename+" not found. Necessary file for this script.")//, kDoPrint, ePrintTo.kMonolog | ePrintTo.kLog | ePrintTo.kUI)
			return null
		}
	}

//	|-- Blob like function --|
	function writec(str){
		foreach (char in str)
			myblob.writen(char,'c')
	}
	
//	|-- Metamethods -- |
	function toblob()
		return myblob
	
	function _tostring(){
		local str = ""
		for (local i = 0; i < myblob.len(); i++){	// TODO test, readn method or internal tostring again.
			local c = myblob[i]
			if (c == '\\'){							// escape Char, skip it and add next.
				c = myblob[i+1]
				i += 1
			}
			str += c.tochar()
		}
		return str
	}		
		
	function _add(other){
		myblob.seek(0,'e')
		myblob.writeblob(other instanceof ::blob? other : other.myblob)	// distinguish between blob and dblob.
		return this
	}	
	
	function _mul(other){
		myblob.seek(0,'e')
		writec(other)
		return this
	}
	
	function _set(key, value){
		if (typeof key == "integer"){
			print("Im here")
			if (typeof value == "integer")
				myblob[key] = value
			else {
			print("don this")
				myblob.seek(key, key < 0? 'e' : 'b')
				writec(value)
			}
		}
	}
	
	function _get(key){
		if (typeof key == "integer") {
			if (key < 0)
				return myblob[myblob.len() + key]
			return myblob[key]
		}
		throw null
	}
	
}

class dCSV extends dblob
{
	useColumnKey 	= null	// will turn this into a table then
	useFile	  	= null
	lines		= null
	static default_args = {path = "[auto]", useColumnKey = true, stream = false, separator = ';', delimiter = '\'', commentstring = "//", streamFile = false}

// |-- Constructor --|	
	constructor(str, useFirstColumnAsKey = true, separator = ';', delimiter = '\'', commentstring = "//", streamFile = false){

		if (streamFile && typeof str == "file"){
			if (str instanceof ::dfile)
				myblob = str.myblob
			else
				myblob = str
		}
		else if (typeof str == "string"){
			try
				base.constructor(::file(str, "r"))
			catch (notfound)
				throw "DScript (dCSV) ERROR!: "+str+" not found. Necessary file for this script."
		}
		else
			base.constructor(str)				// file or blob
		// Construct
		this.useColumnKey	= useFirstColumnAsKey
		this.useFile 	  	= streamFile
		this.lines 		  	= []
		createCSVMatrix(separator, commentstring, delimiter)
	}

// open uses optional inputs via a list!
	function open(filename, args = null){
		if (!args)
			args = default_args
		else {
			if (typeof args != "table")
				throw "DScript ERROR: For dCSV.open(filename, path = \"\", args = null). args must be provides as a {parameter = value} table."
			args.setdelegate(default_args)	// look up defaults if not present.
		}
		if (args.path == "[auto]"){
			local fullpath = string()
			if (::Engine.FindFileInPath("uber_mod_path", filename, fullpath)){
				args.path = fullpath.tostring()
				filename = ""
			}
		}
		local fullpath = args.path + filename // for debug
		try
			return dCSV(::file(fullpath, "r"), args.useColumnKey, args.separator, args.delimiter, args.commentstring, args.streamFile)
		catch(FMizePath){
			// TODO: Maybe this should be the default?
			::print("DScript dCSV INFO: Adjusting import path to " + result)
			local result = string()
			::Version.FMizePath(fullpath, result)
			return dCSV(::file(result.tostring(), "r"), args.useColumnKey, args.separator, args.delimiter, args.commentstring, args.streamFile)
		}
	}

// |-- Input Interpretation --|
	function createCSVMatrix(separator = ';', commentstring = "//", delimiter = '\''){
		myblob.seek(0, 'b')						// Make sure pointer is at start
		do {									// This loop is a line
			local c = myblob[tell()]
			if (c == '\n' || c == '\r'){
				myblob.seek(1,'c')
				continue
			}
			local curline 		  	= []
			local delimiteractive 	= null
			local lineraw 			= ""
			while(true){				// This loops a cell
				local c = myblob.readn('c')
				if (c == delimiter){
					// check if next character is delimiter again, if it is it will be added if not sets delimiter = false and continue with next char.
					if (delimiteractive){
						c = myblob.readn('c')
						if (c != delimiter)
							delimiteractive = false
					} else if (delimiteractive == null){	// Turn on the delimiter
							delimiteractive = true
							c = myblob.readn('c')
					}
				} else if (delimiteractive == null)		// Disable Delimiter for this cell
							delimiteractive = false
				// comment fix from these alternative " used in spreadsheets.
				if (!delimiteractive){
					if (c == separator){
						// if active treat as char but if not separate here.
						#DEBUG POINT
						// print(lineraw)
						if (lineraw != "")
							curline.append(lineraw)
						lineraw = ""
						delimiteractive = null
						continue
					}
					if (c == '\n'){ 	// A newline can be added if within a delimiter
						if (lineraw != "")
							curline.append(lineraw)
						lineraw = ""
						break
					}
				}
				if (c == commentstring[0]){
					if (CheckIfSubstring(commentstring)){
						if (lineraw != "")
							curline.append(lineraw)
						find('\n', tell())	// move pointer to end of line.	
						break
					}
				}
				switch (c){
				// this fixes „“ to be a "
					case 108 - 255:
					case 109 - 255:
					case 124 - 255:
						c = '"'
				}
				lineraw += c.tochar()
				// lineraw = ::split(lineraw, separator)
				if (myblob.eos() && lineraw != ""){
					curline.append(lineraw)
					break
				}
			}
			if (curline.len())
				lines.append(curline)
			
		} while(!myblob.eos())
		
		if 	(useColumnKey){
			useColumnKey = {}
			foreach (line in lines){
				if (line.len() && line[0] != "")
					useColumnKey[line[0]] <- line					// Line is added as reference, so memory wise this is not expensive.
			}													// #NOTE: because of that the key is still present in the line.
		}
	}

// |-- Extract Data --|
	function _get(key){						// metamethod, dCSV[0] or dCSV[myRow] => dCSV[line][#column]
		if (typeof key == "integer") {
			return lines[key]
		}
		if (useColumnKey && key in useColumnKey)
			return useColumnKey[key]
		// Alternative CSV like notation: dCSV[A1], #NOTE here that A is column, and 1 is row
		if (key[0] < 91 && key[1] < 58)
			return lines[key.slice(1).tointeger() - 1][key[0] - 65]	// 65 is the ASCII difference between A and 0
		throw null
	}
	
	function _call(instance, line, column = null){
		line = this[line]							// via _get
		if (!column)
			return line
		if (typeof column == "integer")
			return line[column]
		local idx = lines[0].find(column)			// try to find header
		if (idx >= 0)
			return line[idx]			
		throw "CSV [" + line[0] + " / " + column + "] does not exist."
	}
	
	function _nexti(previdx){
	/* Allows to iterate over the lines. And with a double foreach over lines and entries */
		if (myblob.len() == 0){
			return null
		} else if (previdx == null) {
			return 0;
		} else if (previdx == this.lines.len()-1) {
			return null;
		} else {
			return previdx + 1;
		}
	}

// |-- Output --|
// remember print() uses tostring() and will print the raw context of the file/blob	
	function dump(unformatted = false){
	/* unformatted = true will dump two tables for tables that have been created with useColumnKey*/
		print("Amount of CSV lines:" + lines.len())
		if (useColumnKey){
			print("Lookup table with valid keys:\n\tKey\t:\tValues")
			foreach (key, line in useColumnKey){
			local output = ""
				foreach (entry in line)
					output += "\t"+entry
				::print.MPrint(key + "\t:" + output)
			}
			print("\n=====================================\n")
		} 
		else 
			unformatted = true
		if(unformatted){
			print("Stored Raw Data:")
			foreach (key, val in lines){
				local line = ""
				foreach (entry in val)
					line += "\t"+entry
				::print(key + ":" + line)
			}
		}
	}
	
	function GetMatrix(){
		return lines
	}
	
	function GetTable(axis = 0, closeafter = false){
	/* Uses the first column as key and adds all other contents of that row as array.
		axis = 1 uses the first row as key name and adds the column as array.*/
		local table = {}
		if (axis == 0){
			foreach (line in lines){
				table[line[0]] <- line.slice(1)
			}
		}
		else
		{
			// Reverse rows and columns
			foreach (column, header in lines[0]){
				table[header] <- ::array(lines.len() - 1)
			}
			foreach (row, line in lines){
				if (row == 0)
					continue
				foreach (column, entry in line){
					// skip first line
					table[lines[0][column]][row - 1] = entry
				}
			}
		}
		if (closeafter)
			this.close()
		return table
	}
	
	function GetColumnAsTable(column = 1, closeafter = false){
	/* Uses the first column as key and adds the second or any other as value.*/
		local table = {}
		foreach (line in lines){
			if (line.len() >= column+1)
				table[line[0]] <- line[column]
			else
				table[line[0]] <- null
		}
		if (closeafter)
			this.close()
		return table
	}
	
	function refresh(separator = ';', delimiter = '\'', commentstring = "//"){
		if (typeof myblob != "file")
			throw "dCSV not initialized as stream. Can't refresh. Use constructor or open again."
		createCSVMatrix(separator, commentstring, delimiter)
	}

	function close(){
		base.close()
		lines = null
		useColumnKey = null
	}

}
