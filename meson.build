project('GIR-D-Generator', 'd')

source = [
	'source/girtod.d',
	'source/gtd/DefReader.d',
	'source/gtd/GlibTypes.d',
	'source/gtd/GtkAlias.d',
	'source/gtd/GtkEnum.d',
	'source/gtd/GtkFunction.d',
	'source/gtd/GtkPackage.d',
	'source/gtd/GtkStruct.d',
	'source/gtd/GtkType.d',
	'source/gtd/GtkWrapper.d',
	'source/gtd/IndentedStringBuilder.d',
	'source/gtd/LinkedHasMap.d',
	'source/gtd/WrapError.d',
	'source/gtd/XMLReader.d'
]

sources_dir = include_directories('source/')

executable(
	'girtod',
	[source],
	include_directories : [sources_dir],
	install : true
)
