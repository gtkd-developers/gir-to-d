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

module girtod;

import std.array;
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
	string inputDir;
	string outputDir;
	string girDir;

	try
	{
		auto helpInformation = getopt(
			args,
			"input|i",            "Directory containing the API description. (Default: ./)", &inputDir,
			"output|o",           "Output directory for the generated binding. (Default: {input dir}/out)", &outputDir,
			"use-runtime-linker", "Link the gtk functions with the runtime linker.", &useRuntimeLinker,
			"gir-directory|g",    "Directory to search for gir files before the system directory.", &girDir,
			"print-free",         "Print functions that don't have a parrent module.", &printFree,
			"use-bind-dir",       "Include public imports for the old gtkc package.", &useBindDir
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

	if ( inputDir.empty )
		inputDir = "./";
	if ( outputDir.empty )
		outputDir = buildPath(inputDir, "out");

	try
	{
		//Read in the GIR and API files.
		GirWrapper wrapper = new GirWrapper(inputDir, outputDir, useRuntimeLinker);

		wrapper.commandlineGirPath = girDir;
		wrapper.useBindDir = useBindDir;

		wrapper.proccess("APILookup.txt");

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
