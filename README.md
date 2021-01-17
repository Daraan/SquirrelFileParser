# SquirrelFileParser Standalone v0.1
Parser for .txt and .csv like files for the Squirrel language

This is an extraction of one of my scripts from https://github.com/Daraan/Dark-Squirrel-Scripts which works as standalone for the Squirrel language.

Currently there are still three locations which reference a non standard API.

`dblob.open` can not be used.
`dCSV.open` if the given file path is invalid.
`dfile.constructor` if the given file path is invalid. But solved by a try...catch

Feel free to use the contents of this repistory in any way you like.

Improvements especially to the CSV parser are greatly appreciated.
