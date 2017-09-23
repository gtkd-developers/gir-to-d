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

module gtd.GirField;

import std.algorithm: among, endsWith;
import std.conv;
import std.range;
import std.string: splitLines, strip;

import gtd.Log;
import gtd.GirFunction;
import gtd.GirStruct;
import gtd.GirType;
import gtd.GirWrapper;
import gtd.XMLReader;

final class GirField
{
	string name;
	string doc;
	GirType type;
	int bits = -1;
	bool writable = false;

	GirFunction callback;
	GirUnion gtkUnion;
	GirStruct gtkStruct;

	GirWrapper wrapper;

	this(GirWrapper wrapper)
	{
		this.wrapper = wrapper;
	}

	void parse(T)(XMLReader!T reader)
	{
		name = reader.front.attributes["name"];

		if ( "bits" in reader.front.attributes )
			bits = to!int(reader.front.attributes["bits"]);
		if ( auto write = "writable" in reader.front.attributes )
			writable = *write == "1";

		//TODO: readable private?

		reader.popFront();

		while( !reader.empty && !reader.endTag("field") )
		{
			if ( reader.front.type == XMLNodeType.EndTag )
			{
				reader.popFront();
				continue;
			}

			switch(reader.front.value)
			{
				case "doc":
					reader.popFront();
					doc ~= reader.front.value;
					reader.popFront();
					break;
				case "doc-deprecated":
					reader.popFront();
					doc ~= "\n\nDeprecated: "~ reader.front.value;
					reader.popFront();
					break;
				case "array":
				case "type":
					type = new GirType(wrapper);
					type.parse(reader);
					break;
				case "callback":
					callback = new GirFunction(wrapper, null);
					callback.parse(reader);
					break;
				default:
					error("Unexpected tag: ", reader.front.value, " in GirField: ", name, reader);
			}
			reader.popFront();
		}
	}

	/**
	 * A special case for fields, we need to know about all of then
	 * to properly construct the bitfields.
	 */
	static string[] getFieldDeclarations(GirField[] fields, GirWrapper wrapper)
	{
		string[] buff;
		int bitcount;

		void endBitfield()
		{
			//AFAIK: C bitfields are padded to a multiple of sizeof uint.
			int padding = 32 - (bitcount % 32);

			if ( padding > 0 && padding < 32)
			{
				buff[buff.length-1] ~= ",";
				buff ~= "uint, \"\", "~ to!string(padding);
				buff ~= "));";
			}
			else
			{
				buff ~= "));";
			}

			bitcount = 0;
		}

		foreach ( field; fields )
		{
			if ( field.callback )
			{
				if ( bitcount > 0 )
					endBitfield();
				buff ~= field.callback.getFunctionPointerDecleration();
				continue;
			}

			if ( field.gtkUnion )
			{
				if ( bitcount > 0 )
					endBitfield();
				buff ~= field.gtkUnion.getUnionDeclaration();
				continue;
			}

			if ( field.gtkStruct )
			{
				if ( bitcount > 0 )
					endBitfield();
				buff ~= field.gtkStruct.getStructDeclaration();
				buff ~= stringToGtkD(field.gtkStruct.cType ~" "~ field.gtkStruct.name ~";", wrapper.aliasses);
				continue;
			}

			if ( field.bits > 0 )
			{
				if ( bitcount == 0 )
				{
					buff ~= "import std.bitmanip: bitfields;";
					buff ~= "mixin(bitfields!(";
				}
				else
				{
					buff[buff.length-1] ~= ",";
				}

				bitcount += field.bits;
				buff ~=stringToGtkD(field.type.cType ~", \""~ field.name ~"\", "~ to!string(field.bits), wrapper.aliasses);
				continue;
			}
			else if ( bitcount > 0)
			{
				endBitfield();
			}

			if ( field.doc !is null && wrapper.includeComments && field.bits < 0 )
			{
				buff ~= "/**";
				foreach ( line; field.doc.splitLines() )
					buff ~= " * "~ line.strip();
				buff ~= " */";
			}

			string dType;

			if ( field.type.size == -1 )
			{
				if ( field.type.cType.empty )
					dType = stringToGtkD(field.type.name, wrapper.aliasses);
				else
					dType = stringToGtkD(field.type.cType, wrapper.aliasses);
			}
			else if ( field.type.elementType.cType.empty )
			{
				//Special case for GObject.Value.
				dType = stringToGtkD(field.type.elementType.name, wrapper.aliasses);
				dType ~= "["~ to!string(field.type.size) ~"]";
			}
			else
			{
				dType = stringToGtkD(field.type.elementType.cType, wrapper.aliasses);
				dType ~= "["~ to!string(field.type.size) ~"]";
			}

			buff ~= dType ~" "~ tokenToGtkD(field.name, wrapper.aliasses) ~";";
		}

		if ( bitcount > 0)
		{
			endBitfield();
		}

		return buff;
	}

	string[] getProperty(GirStruct parent)
	{
		string[] buff;

		if ( !writable )
			return null;

		writeDocs(buff);
		writeGetter(buff, parent);

		buff ~= "";
		if ( wrapper.includeComments )
			buff ~= "/** Ditto */";

		writeSetter(buff, parent);

		return buff;
	}

	private void writeGetter(ref string[] buff, GirStruct parent)
	{
		GirStruct dType;

		if ( type.isArray() )
			dType = parent.pack.getStruct(type.elementType.name);
		else if ( auto dStrct = parent.pack.getStruct(parent.structWrap.get(type.name, "")) )
			dType = dStrct;
		else
			dType = parent.pack.getStruct(type.name);

		if ( type.isString() )
		{
			if ( type.isArray() )
			{
				buff ~= "public string[] "~ tokenToGtkD(name, wrapper.aliasses, parent.aliases) ~"()";
				buff ~= "{";
				buff ~= "return Str.toStringArray("~ parent.getHandleVar() ~"."~ tokenToGtkD(name, wrapper.aliasses) ~");";
				buff ~= "}";
			}
			else
			{
				buff ~= "public string "~ tokenToGtkD(name, wrapper.aliasses, parent.aliases) ~"()";
				buff ~= "{";
				buff ~= "return Str.toString("~ parent.getHandleVar() ~"."~ tokenToGtkD(name, wrapper.aliasses) ~");";
				buff ~= "}";
			}
		}
		else if ( dType && dType.isDClass() && type.cType.endsWith("*") )
		{
			string dTypeName;

			if ( dType.name in parent.structWrap )
				dTypeName = parent.structWrap[dType.name];
			else if ( dType.type == GirStructType.Interface )
				dTypeName = dType.name ~"IF";
			else
				dTypeName = dType.name;

			if ( type.isArray() )
			{
				buff ~= "public "~ dTypeName ~"[] "~ tokenToGtkD(name, wrapper.aliasses, parent.aliases) ~"()";
				buff ~= "{";
				buff ~= dTypeName ~"[] arr = new "~ dTypeName ~"[getArrayLength("~ parent.getHandleVar() ~"."~ tokenToGtkD(name, wrapper.aliasses) ~")];";
				buff ~= "for ( int i = 0; i < arr.length; i++ )";
				buff ~= "{";
				
				if ( dType.pack.name.among("cairo", "glib", "gthread") )
					buff ~= "arr[i] = new "~ dTypeName ~"("~ parent.getHandleVar() ~"."~ tokenToGtkD(name, wrapper.aliasses) ~"[i], false);";
				else if( dType.type == GirStructType.Interface )
					buff ~= "arr[i] = ObjectG.getDObject!("~ dTypeName ~", "~ dTypeName ~"IF)("~ parent.getHandleVar() ~"."~ tokenToGtkD(name, wrapper.aliasses) ~"[i], false);";
				else
					buff ~= "arr[i] = ObjectG.getDObject!("~ dTypeName ~")("~ parent.getHandleVar() ~"."~ tokenToGtkD(name, wrapper.aliasses) ~"[i], false);";

				buff ~= "}";
				buff ~= "";
				buff ~= "return arr;";
				buff ~= "}";
			}
			else
			{
				buff ~= "public "~ dTypeName ~" "~ tokenToGtkD(name, wrapper.aliasses, parent.aliases) ~"()";
				buff ~= "{";
				
				if ( dType.pack.name.among("cairo", "glib", "gthread") )
					buff ~= "return new "~ dTypeName ~"("~ parent.getHandleVar() ~"."~ tokenToGtkD(name, wrapper.aliasses) ~", false);";
				else if( dType.type == GirStructType.Interface )
					buff ~= "return ObjectG.getDObject!("~ dTypeName ~", "~ dTypeName ~"IF)("~ parent.getHandleVar() ~"."~ tokenToGtkD(name, wrapper.aliasses) ~", false);";
				else
					buff ~= "return ObjectG.getDObject!("~ dTypeName ~")("~ parent.getHandleVar() ~"."~ tokenToGtkD(name, wrapper.aliasses) ~", false);";

				buff ~= "}";
			}
		}
		else if ( type.name.among("bool", "gboolean") || ( type.isArray && type.elementType.name.among("bool", "gboolean") ) )
		{
			if ( type.isArray() )
			{
				buff ~= "public bool[] "~ tokenToGtkD(name, wrapper.aliasses, parent.aliases) ~"()";
				buff ~= "{";
				buff ~= "return "~ parent.getHandleVar ~"."~ tokenToGtkD(name, wrapper.aliasses) ~"[0..getArrayLength("~ parent.getHandleVar() ~"."~ tokenToGtkD(name, wrapper.aliasses) ~")];";
				buff ~= "}";
			}
			else
			{
				buff ~= "public bool "~ tokenToGtkD(name, wrapper.aliasses, parent.aliases) ~"()";
				buff ~= "{";
				buff ~= "return "~ parent.getHandleVar() ~"."~ tokenToGtkD(name, wrapper.aliasses) ~" != 0;";
				buff ~= "}";
			}
		}
		else
		{
			if ( type.isArray() )
			{
				buff ~= "public "~ stringToGtkD(type.cType[0..$-1], wrapper.aliasses, parent.aliases) ~"[] "~ tokenToGtkD(name, wrapper.aliasses, parent.aliases) ~"()";
				buff ~= "{";
				buff ~= "return "~ parent.getHandleVar() ~"."~ tokenToGtkD(name, wrapper.aliasses) ~"[0..getArrayLength("~ parent.getHandleVar() ~"."~ tokenToGtkD(name, wrapper.aliasses) ~")];";
				buff ~= "}";
			}
			else
			{
				buff ~= "public "~ stringToGtkD(type.cType, wrapper.aliasses, parent.aliases) ~" "~ tokenToGtkD(name, wrapper.aliasses, parent.aliases) ~"()";
				buff ~= "{";
				buff ~= "return "~ parent.getHandleVar() ~"."~ tokenToGtkD(name, wrapper.aliasses) ~";";
				buff ~= "}";
			}
		}
	}

	private void writeSetter(ref string[] buff, GirStruct parent)
	{
		GirStruct dType;

		if ( type.isArray() )
			dType = parent.pack.getStruct(type.elementType.name);
		else if ( auto dStrct = parent.pack.getStruct(parent.structWrap.get(type.name, "")) )
			dType = dStrct;
		else
			dType = parent.pack.getStruct(type.name);

		if ( type.isString() )
		{
			if ( type.isArray() )
			{
				buff ~= "public void "~ tokenToGtkD(name, wrapper.aliasses, parent.aliases) ~"(string[] value)";
				buff ~= "{";
				buff ~= parent.getHandleVar() ~"."~ tokenToGtkD(name, wrapper.aliasses) ~" = Str.toStringzArray(value);";
				buff ~= "}";
			}
			else
			{
				buff ~= "public void "~ tokenToGtkD(name, wrapper.aliasses, parent.aliases) ~"(string value)";
				buff ~= "{";
				buff ~= parent.getHandleVar() ~"."~ tokenToGtkD(name, wrapper.aliasses) ~" = Str.toStringz(value);";
				buff ~= "}";
			}
		}
		else if ( dType && dType.isDClass() && type.cType.endsWith("*") )
		{
			string dTypeName;

			if ( dType.name in parent.structWrap )
				dTypeName = parent.structWrap[dType.name];
			else if ( dType.type == GirStructType.Interface )
				dTypeName = dType.name ~"IF";
			else
				dTypeName = dType.name;

			if ( type.isArray() )
			{
				buff ~= "public void "~ tokenToGtkD(name, wrapper.aliasses, parent.aliases) ~"("~ dTypeName ~"[] value)";
				buff ~= "{";
				buff ~= dType.cType ~"*[] arr = new "~ dType.cType ~"*[value.length+1];";
				buff ~= "for ( int i = 0; i < value.length; i++ )";
				buff ~= "{";
				buff ~= "arr[i] = value[i]."~ dType.getHandleFunc() ~"();";
				buff ~= "}";
				buff ~= "arr[value.length] = null;";
				buff ~= "";
				buff ~= parent.getHandleVar() ~"."~ tokenToGtkD(name, wrapper.aliasses) ~" = arr.ptr;";
				buff ~= "}";
			}
			else
			{
				buff ~= "public void "~ tokenToGtkD(name, wrapper.aliasses, parent.aliases) ~"("~ dTypeName ~" value)";
				buff ~= "{";
				buff ~= parent.getHandleVar() ~"."~ tokenToGtkD(name, wrapper.aliasses) ~" = value."~ dType.getHandleFunc() ~"();";
				buff ~= "}";
			}
		}
		else if ( type.name.among("bool", "gboolean") || ( type.isArray && type.elementType.name.among("bool", "gboolean") ) )
		{
			if ( type.isArray() )
			{
				buff ~= "public void "~ tokenToGtkD(name, wrapper.aliasses, parent.aliases) ~"(bool[] value)";
				buff ~= "{";
				buff ~= parent.getHandleVar() ~"."~ tokenToGtkD(name, wrapper.aliasses) ~" = value.ptr;";
				buff ~= "}";
			}
			else
			{
				buff ~= "public void "~ tokenToGtkD(name, wrapper.aliasses, parent.aliases) ~"(bool value)";
				buff ~= "{";
				buff ~= parent.getHandleVar() ~"."~ tokenToGtkD(name, wrapper.aliasses) ~" = value;";				
				buff ~= "}";
			}
		}
		else
		{
			if ( type.isArray() )
			{
				buff ~= "public void "~ tokenToGtkD(name, wrapper.aliasses, parent.aliases) ~"("~ stringToGtkD(type.cType[0..$-1], wrapper.aliasses, parent.aliases) ~"[] value)";
				buff ~= "{";
				buff ~= parent.getHandleVar() ~"."~ tokenToGtkD(name, wrapper.aliasses) ~" = value.ptr;";
				buff ~= "}";
			}
			else
			{
				buff ~= "public void "~ tokenToGtkD(name, wrapper.aliasses, parent.aliases) ~"("~ stringToGtkD(type.cType, wrapper.aliasses, parent.aliases) ~" value)";
				buff ~= "{";
				buff ~= parent.getHandleVar() ~"."~ tokenToGtkD(name, wrapper.aliasses) ~" = value;";
				buff ~= "}";
			}
		}
	}

	private void writeDocs(ref string[] buff)
	{
		if ( doc !is null && wrapper.includeComments )
		{
			buff ~= "/**";
			foreach ( line; doc.splitLines() )
				buff ~= " * "~ line.strip();

			//if ( libVersion )
			//{
			//	buff ~= " *\n * Since: "~ libVersion;
			//}

			buff ~= " */";
		}
		else if ( wrapper.includeComments )
		{
			buff ~= "/** */";
		}
	}
}
