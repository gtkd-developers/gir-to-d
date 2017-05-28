/*
 * This file is part of gtkD.
 *
 * gtkD is free software; you can redistribute it and/or modify
 * it under the terms of the GNU Lesser General Public License
 * as published by the Free Software Foundation; either version 3
 * of the License, or (at your option) any later version, with
 * some exceptions, please read the COPYING file.
 *
 * gtkD is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU Lesser General Public License for more details.
 *
 * You should have received a copy of the GNU Lesser General Public License
 * along with gtkD; if not, write to the Free Software
 * Foundation, Inc., 51 Franklin St, Fifth Floor, Boston, MA 02110, USA
 */

module gtd.DefReader;

import std.algorithm;
import std.array;
import std.file;
import std.string : splitLines, strip, indexOf;

import gtd.WrapException;

public final class DefReader
{
	string fileName;
	string key;
	string subKey;
	string value;

	int lineNumber;
	string[] lines;

	public this(string fileName)
	{
		this.fileName = fileName;

		lines = readText(fileName).splitLines();
		//Skip utf8 BOM.
		lines[0].skipOver(x"efbbbf");

		this.popFront();
	}

	public void popFront()
	{
		string line;

		if ( !lines.empty )
		{
			line = lines.front.strip();
			lines.popFront();
			lineNumber++;

			while ( !lines.empty && ( line.empty || line.startsWith("#") ) )
			{
				line = lines.front.strip();
				lines.popFront();
				lineNumber++;
			}
		}

		if ( !line.empty && !line.startsWith("#") )
		{
			size_t index = line.indexOf(':');

			key   = line[0 .. max(index, 0)].strip();
			value = line[index +1 .. $].strip();

			index = key.indexOf(' ');
			if ( index != -1 )
			{
				subKey = key[index +1 .. $].strip();
				key    = key[0 .. index].strip();
			}
		}
		else
		{
			key.length = 0;
			value.length = 0;
		}
	}

	/**
	 * Gets the contends of a block value
	 */
	public string[] readBlock(string key = "")
	{
		string[] block;

		if ( key.empty )
			key = this.key;

		while ( !lines.empty )
		{
			if ( startsWith(lines.front.strip(), key) )
			{
				lines.popFront();
				lineNumber++;
				return block;
			}

			block ~= lines.front ~ '\n';
			lines.popFront();
			lineNumber++;
		}

		throw new LookupException(this, "Found EOF while expecting: \""~key~": end\"");
	}

	/**
	 * Gets the current value as a bool
	 */
	public @property bool valueBool()
	{
		return !!value.among("1", "ok", "OK", "Ok", "true", "TRUE", "True", "Y", "y", "yes", "YES", "Yes");
	}

	public @property bool empty()
	{
		return lines.empty && key.empty;
	}
}

class LookupException : WrapException
{
	this(DefReader defReader, string msg)
	{
		super(msg, defReader.fileName, defReader.lineNumber);
	}
}
