/*
 * This file is part of gir-to-d.
 *
 * gir-to-d is free software: you can redistribute it and/or modify
 * it under the terms of the GNU Lesser General Public License
 * as published by the Free Software Foundation, either version 3
 * of the License, or (at your option) any later version.
 *
 * gir-to-d is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU Lesser General Public License for more details.
 *
 * You should have received a copy of the GNU Lesser General Public License
 * along with gir-to-d.  If not, see <http://www.gnu.org/licenses/>.
 */

module girtod;

import std.array;
import std.file : isFile, exists;
import std.getopt;
import std.path;
import std.stdio;
import core.stdc.stdlib;

import gtd.GirWrapper;
import gtd.Log;
import gtd.WrapException;

void main(string[] args)
{

	bool printFree;
	bool useRuntimeLinker;
	bool useBindDir;
	string input;
	string outputDir;
	string lookupFile = "APILookup.txt";
	string girDir;

	try
	{
		auto helpInformation = getopt(
			args,
			"input|i",            "Directory containing the API description. Or a lookup file (Default: ./)", &input,
			"output|o",           "Output directory for the generated binding. (Default: ./out)", &outputDir,
			"use-runtime-linker", "Link the gtk functions with the runtime linker.", &useRuntimeLinker,
			"gir-directory|g",    "Directory to search for gir files before the system directory.", &girDir,
			"print-free",         "Print functions that don't have a parent module.", &printFree,
			"use-bind-dir",       "Include public imports for the old gtkc package.", &useBindDir,
			"version",            "Print the version and exit", (){ writeln("GIR to D ", import("VERSION")); exit(0); }
		);

		if (helpInformation.helpWanted)
		{
			defaultGetoptPrinter("girtod is an utility that generates D bindings using the GObject introspection files.\nOptions:", helpInformation.options);
			exit(0);
		}
	}
	catch (GetOptException e)
	{
		writeln ("Unable to parse parameters: ", e.msg);
		exit (1);
	}

	if ( input.empty )
	{
		input = "./";
	}
	else if ( input.exists && input.isFile() )
	{
		lookupFile = input.baseName();
		input = input.dirName();
	}

	if ( outputDir.empty )
		outputDir = "./out";

	try
	{
		//Read in the GIR and API files.
		GirWrapper wrapper = new GirWrapper(input, outputDir, useRuntimeLinker);

		wrapper.commandlineGirPath = girDir;
		wrapper.useBindDir = useBindDir;

		if ( lookupFile.extension == ".gir" )
			wrapper.proccessGIR(lookupFile);
		else
			wrapper.proccess(lookupFile);

		if ( printFree )
			wrapper.printFreeFunctions();

		//Generate the D binding
		foreach(pack; wrapper.packages)
		{
			if ( pack.name == "cairo" )
				continue;

			if ( useRuntimeLinker )
				pack.writeLoaderTable();
			else
				pack.writeExternalFunctions();

			pack.writeTypes();
			pack.writeClasses();
		}
	}
	catch (WrapException ex)
	{
		error(ex);
	}
}
