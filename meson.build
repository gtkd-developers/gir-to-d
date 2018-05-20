project('GIR-to-D', 'd',
    meson_version: '>=0.46',
    license: 'LGPL-3.0',
    version: '0.15.0'
)

glibd_soversion = '0'
glibd_version = '2.56'

source = [
    'source/girtod.d',
    'source/gtd/DefReader.d',
    'source/gtd/GlibTypes.d',
    'source/gtd/GirAlias.d',
    'source/gtd/GirConstant.d',
    'source/gtd/GirEnum.d',
    'source/gtd/GirField.d',
    'source/gtd/GirFunction.d',
    'source/gtd/GirPackage.d',
    'source/gtd/GirStruct.d',
    'source/gtd/GirType.d',
    'source/gtd/GirVersion.d',
    'source/gtd/GirWrapper.d',
    'source/gtd/IndentedStringBuilder.d',
    'source/gtd/Log.d',
    'source/gtd/LinkedHasMap.d',
    'source/gtd/WrapException.d',
    'source/gtd/XMLReader.d'
]

sources_dir = include_directories('source/')

version = vcs_tag(command: ['git', 'describe', '--dirty=+', '--tags'], input: 'VERSION.in', output: 'VERSION')


if get_option('build-glibd')
    python = find_program('python3')
    glib_dep = dependency('glib-2.0')
    pkgc = import('pkgconfig')

    message('Building temporary girtod binary...')
    girtod_temp_create = run_command(python.path(), 'wrap/meson/create-temp-girtod.py')
    if girtod_temp_create.returncode() != 0
        error('Unable to build temporary GirToD binary:\n' + girtod_gen.stderr() + girtod_gen.stdout())
    endif

    message('Generating D interfaces from GIR...')
    girtod_gen = run_command(python.path(),
                             'wrap/meson/generate-bindings.py',
                             'wrap/')
    if girtod_gen.returncode() != 0
        error('Unable to build D intefaces from GIR:\n' + girtod_gen.stderr() + girtod_gen.stdout())
    endif

    gir_bind_dir = include_directories(join_paths('wrap.gen', 'glibd'))
    gir_binding_sources = girtod_gen.stdout().strip().split('\n')

    glibd_lib = library('glibd-2.0',
        [gir_binding_sources],
        include_directories: [gir_bind_dir],
        dependencies: [glib_dep],
        install: true,
        version: glibd_version,
        soversion: glibd_soversion
    )

    pkgc.generate(name: 'glibd-2.0',
        libraries: glibd_lib,
        subdirs: 'd/glibd',
        version: glibd_version,
        requires: ['glib-2.0'],
        description: 'D bindings for the GLib C Utility Library.'
    )

    install_subdir(join_paths(meson.build_root(), 'wrap.gen', 'glibd'), install_dir: 'include/d/glibd/')

endif

executable(
    'girtod',
    [source, version],
    include_directories : [sources_dir],
    d_import_dirs : meson.build_root(),
    install: true
)
