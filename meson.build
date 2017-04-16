project('GIR-D-Generator', 'd')

source = [
	'source/girtod.d',
	'source/gtd/DefReader.d',
	'source/gtd/GlibTypes.d',
	'source/gtd/GirAlias.d',
	'source/gtd/GirEnum.d',
	'source/gtd/GirFunction.d',
	'source/gtd/GirPackage.d',
	'source/gtd/GirStruct.d',
	'source/gtd/GirType.d',
	'source/gtd/GirWrapper.d',
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
