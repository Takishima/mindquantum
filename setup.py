# -*- coding: utf-8 -*-
# Copyright 2021 Huawei Technologies Co., Ltd
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
# http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
# ============================================================================

"""Setup.py file."""

import copy
import itertools
import logging
import multiprocessing
import os
import pathlib
import platform
import shutil
import subprocess
import sys
import sysconfig
from distutils.command.clean import clean
from pathlib import Path

import setuptools
from setuptools.command.build_ext import build_ext

sys.path.append(str(Path(__file__).parent.resolve()))

from _build.utils import (  # pylint: disable=wrong-import-position  # noqa: E402
    fdopen,
    get_cmake_command,
    get_executable,
    remove_tree,
)

# ==============================================================================
# Helper variables

on_rtd = os.environ.get('READTHEDOCS') == 'True'
cur_dir = Path(__file__).resolve().parent
ext_errors = (subprocess.CalledProcessError, FileNotFoundError)
cmake_extra_options = []

# ==============================================================================
# Helper functions and classes


def important_msgs(*msgs):
    """Print an important message."""
    print('*' * 75)
    for msg in msgs:
        print(msg)
    print('*' * 75)


def get_extra_cmake_options():
    """
    Parse CMake options from python3 setup.py command line.

    Read --unset, --set, -A and -G options from the command line and add them as cmake switches.
    """
    _cmake_extra_options = []

    opt_key = None

    has_generator = False

    argv = copy.deepcopy(sys.argv)
    # parse command line options and consume those we care about
    for arg in argv:
        if opt_key == 'G':
            has_generator = True
            _cmake_extra_options += ['-G', arg.strip()]
        elif opt_key == 'A':
            _cmake_extra_options += ['-A', arg.strip()]
        elif opt_key == 'unset':
            _cmake_extra_options.append(f'-D{arg.strip()}:BOOL=OFF')
        elif opt_key == 'set':
            _cmake_extra_options.append(f'-D{arg.strip()}:BOOL=ON')

        if opt_key:
            sys.argv.remove(arg)
            opt_key = None
            continue

        if arg in ['--unset', '--set', '--compiler-flags']:
            opt_key = arg[2:].lower()
            sys.argv.remove(arg)
            continue
        if arg in ['-A']:
            opt_key = arg[1:]
            sys.argv.remove(arg)
            continue
        if arg in ['-G']:
            opt_key = arg[1:]
            sys.argv.remove(arg)
            continue

    # If no explicit CMake Generator specification, prefer MinGW Makefiles on Windows
    if (not has_generator) and (platform.system() == 'Windows'):
        _cmake_extra_options += ['-G', 'MinGW Makefiles']

    return _cmake_extra_options


# ==============================================================================


def get_python_executable():
    """Retrieve the path to the Python executable."""
    return get_executable(sys.executable)


# ==============================================================================


class BuildFailed(Exception):
    """Extension raised if the build fails for any reason."""

    def __init__(self):
        """Initialize a BuildFailed exception."""
        super().__init__()
        self.cause = sys.exc_info()[1]  # work around py 2/3 different syntax


# ==============================================================================


class CMakeExtension(setuptools.Extension):  # pylint: disable=too-few-public-methods
    """Class defining a C/C++ Python extension to be compiled using CMake."""

    def __init__(self, pymod, target=None, optional=False):
        """
        Initialize a CMakeExtension object.

        Args:
            src_dir (string): Path to source directory
            target (string): Name of target
            pymod (string): Name of compiled Python module
            optional (bool): (optional) If true, not building this extension is not considered an error
        """
        # NB: the main source directory is the one containing the setup.py file
        self.src_dir = Path().resolve()
        self.pymod = pymod
        self.target = target if target is not None else pymod.split('.')[-1]

        self.lib_filepath = str(Path(*pymod.split('.')))
        super().__init__(pymod, sources=[], optional=optional)


# ------------------------------------------------------------------------------


class CMakeBuildExt(build_ext):
    """Custom build_ext command class."""

    user_options = build_ext.user_options + [
        ('no-arch-native', None, 'Do not use the -march=native flag when compiling'),
        ('clean-build', None, 'Build in a clean build environment'),
    ]

    boolean_options = build_ext.boolean_options + ['no-arch-native', 'clean-build']

    def initialize_options(self):
        """Initialize all options of this custom command."""
        build_ext.initialize_options(self)
        self.no_arch_native = None
        self.clean_build = None

    def build_extensions(self):
        """Build a C/C++ extension using CMake."""
        # pylint: disable=attribute-defined-outside-init
        if on_rtd:
            important_msgs('skipping CMake build on ReadTheDocs and creating dummy extension packages')
            ext_suffix = sysconfig.get_config_var('EXT_SUFFIX')
            for ext in self.extensions:
                dest_path = pathlib.Path(self.get_ext_fullpath(ext.lib_filepath).rstrip(ext_suffix)).with_suffix('.py')
                if not dest_path.exists():
                    logging.info('creating empty file at %s', dest_path)
                    dest_path.write_text('')
            return
        cmake_cmd = get_cmake_command()
        if cmake_cmd is None:
            raise RuntimeError('Unable to locate the CMake command!')
        self.cmake_cmd = [cmake_cmd]
        logging.info('using cmake command: %s', ' '.join(self.cmake_cmd))

        self.configure_extensions()
        build_ext.build_extensions(self)
        self.cmake_install()

    def configure_extensions(self):
        """Run a CMake configuration and generation step for one extension."""
        # pylint: disable=attribute-defined-outside-init

        def _src_dir_pred(ext):
            return ext.src_dir

        cmake_args = [
            '-DPython_EXECUTABLE:FILEPATH=' + get_python_executable(),
            '-DBUILD_TESTING:BOOL=OFF',
            '-DIN_PLACE_BUILD:BOOL=OFF',
            '-DIS_PYTHON_BUILD:BOOL=ON',
            '-DCMAKE_VERBOSE_MAKEFILE:BOOL=ON',
            f'-DVERSION_INFO="{self.distribution.get_version()}"',
            f'-DMQ_PYTHON_PACKAGE_NAME:STRING={self.distribution.get_name()}',
            # NB: make sure that the install path is absolute!
            f'-DCMAKE_INSTALL_PREFIX:FILEPATH={Path(self.build_lib, Path().resolve().name).resolve()}',
        ]  # yapf: disable

        if self.no_arch_native:
            cmake_args += ['-DUSE_NATIVE_INTRINSICS=OFF']

        cfg = 'Debug' if self.debug else 'Release'
        self.build_args = ['--config', cfg]

        if platform.system() == 'Windows':
            # self.build_args += ['--', '/m']
            pass
        else:
            cmake_args += ['-DCMAKE_BUILD_TYPE=' + cfg]
            if platform.system() == 'Darwin' and 'TRAVIS' in os.environ:
                self.build_args += ['--']
            else:
                self.build_args += [
                    f'-j {self.parallel if self.parallel else multiprocessing.cpu_count()}',
                    '--',
                ]

        cmake_args.extend(cmake_extra_options)

        env = os.environ.copy()

        # This can in principle handle the compilation of extensions outside the main CMake directory (ie. outside the
        # one containing this setup.py file)
        for src_dir, extensions in itertools.groupby(sorted(self.extensions, key=_src_dir_pred), key=_src_dir_pred):
            self.cmake_configure_build(src_dir, extensions, cmake_args, env)

    def cmake_configure_build(self, src_dir, extensions, cmake_args, env):
        """Run a CMake build command for a list of extensions."""
        args = cmake_args.copy()
        for ext in extensions:
            dest_path = Path(self.get_ext_fullpath(ext.lib_filepath)).resolve().parent
            args.append(f'-D{ext.target.upper()}_OUTPUT_DIR={dest_path}')

        build_temp = self._get_temp_dir(src_dir)
        if self.clean_build:
            remove_tree(build_temp)
        if not Path(build_temp).exists():
            Path(build_temp).mkdir(parents=True, exist_ok=True)

        logging.info(' Configuring from %s '.center(80, '-'), src_dir)
        logging.info('CMake command: %s', ' '.join(self.cmake_cmd + [str(src_dir)] + args))
        logging.info('   cwd: %s', build_temp)
        try:
            subprocess.check_call(self.cmake_cmd + [src_dir] + args, cwd=build_temp, env=env)
        except ext_errors as err:
            raise BuildFailed() from err
        finally:
            logging.info(' End configuring from %s '.center(80, '-'), src_dir)

    def build_extension(self, ext):
        """Build a single C/C++ extension using CMake."""
        cwd = self._get_temp_dir(Path(ext.src_dir).resolve().name)
        logging.info(f' Building {ext.pymod} '.center(80, '-'))
        logging.info(
            'CMake command: %s', ' '.join(self.cmake_cmd + ['--build', '.', '--target', ext.target] + self.build_args)
        )
        logging.info('   cwd: %s', cwd)
        try:
            subprocess.check_call(
                self.cmake_cmd + ['--build', '.', '--target', ext.target] + self.build_args,
                cwd=cwd,
            )
        except ext_errors as err:
            if not ext.optional:
                raise BuildFailed() from err
            logging.info('Failed to compile optional extension %s (not an error)', ext.pymod)
        finally:
            logging.info(' End building %s '.center(80, '-'), ext.pymod)

    def cmake_install(self):
        """Run the CMake installation step."""
        cwd = self._get_temp_dir(Path().resolve().name)
        logging.info(' Building CMake install target '.center(80, '-'))
        logging.info(
            'CMake command: %s', ' '.join(self.cmake_cmd + ['--build', '.', '--target', 'install'] + self.build_args)
        )
        logging.info('   cwd: %s', cwd)
        try:
            subprocess.check_call(
                self.cmake_cmd + ['--build', '.', '--target', 'install'] + self.build_args,
                cwd=cwd,
            )
        finally:
            logging.info(' End building target install '.center(80, '-'))

    def copy_extensions_to_source(self):
        """Copy the extensions."""
        # pylint: disable=protected-access

        build_py = self.get_finalized_command('build_py')
        for ext in self.extensions:
            fullname = self.get_ext_fullname(ext.name)
            filename = Path(self.get_ext_filename(fullname))
            modpath = fullname.split('.')
            package = '.'.join(modpath[:-1])
            package_dir = build_py.get_package_dir(package)
            dest_filename = Path(package_dir, filename.name)
            src_filename = Path(self.build_lib, filename)

            # Always copy, even if source is older than destination, to ensure
            # that the right extensions for the current Python/platform are
            # used.
            if src_filename.exists() or not ext.optional:
                if self.dry_run or self.verbose:
                    logging.info('copy %s -> %s', src_filename, dest_filename)
                if not self.dry_run:
                    shutil.copyfile(src_filename, dest_filename)
                    if ext._needs_stub:
                        self.write_stub(str(package_dir) or os.curdir, ext, True)

    def get_outputs(self):
        """
        Get the list of files generated during a build.

        Mainly defined to properly handle optional extensions.
        """
        outputs = []
        for ext in self.extensions:
            if Path(self.get_ext_fullpath(ext.name)).exists() or not ext.optional:
                outputs.append(self.get_ext_fullpath(ext.name))
        return outputs

    def _get_temp_dir(self, src_dir):
        return Path(self.build_temp, Path(src_dir).name)


# ==============================================================================


class Clean(clean):
    """Custom clean command."""

    def run(self):
        """Run the clean command."""
        # Execute the classic clean command
        clean.run(self)
        import glob  # pylint: disable=import-outside-toplevel

        pkg_name = self.distribution.get_name().replace('-', '_')
        info = glob.glob(f'{pkg_name}.egg-info')
        if info:
            remove_tree(info[0])


# ==============================================================================


class GenerateRequirementFile(setuptools.Command):
    """A custom command to list the dependencies of the current."""

    description = 'List the dependencies of the current package'
    user_options = [
        ('include-all-extras', None, 'Include all extras_require into the list'),
        ('include-extras=', None, 'Include some of extras_requires into the list (comma separated)'),
    ]

    boolean_options = ['include-all-extras']

    def initialize_options(self):
        """Initialize this command's options."""
        self.include_extras = None
        self.include_all_extras = None
        self.extra_pkgs = []

    def finalize_options(self):
        """Finalize this command's options."""
        if self.include_extras:
            include_extras = self.include_extras.split(',')
        else:
            include_extras = []

        try:
            for name, pkgs in self.distribution.extras_require.items():
                if self.include_all_extras or name in include_extras:
                    self.extra_pkgs.extend(pkgs)

        except TypeError:  # Mostly for old setuptools (< 30.x)
            for name, pkgs in self.distribution.command_options['options.extras_require'].items():
                if self.include_all_extras or name in include_extras:
                    self.extra_pkgs.extend(pkgs)

    def run(self):
        """Execute this command."""
        with fdopen('requirements.txt', 'w') as req_file:
            try:
                for pkg in self.distribution.install_requires:
                    req_file.write(f'{pkg}\n')
            except TypeError:  # Mostly for old setuptools (< 30.x)
                for pkg in self.distribution.command_options['options']['install_requires']:
                    req_file.write(f'{pkg}\n')
            req_file.write('\n')
            for pkg in self.extra_pkgs:
                req_file.write(f'{pkg}\n')


# ==============================================================================

ext_modules = [
    CMakeExtension(pymod='mindquantum.mqbackend'),
    CMakeExtension(pymod='mindquantum.experimental._cxx_core', optional=True),
    CMakeExtension(pymod='mindquantum.experimental._cxx_cengines', optional=True),
    CMakeExtension(pymod='mindquantum.experimental._cxx_ops', optional=True),
]


if __name__ == '__main__':
    remove_tree(Path(cur_dir, 'output'))
    cmake_extra_options.extend(get_extra_cmake_options())
    setuptools.setup(
        cmdclass={
            'build_ext': CMakeBuildExt,
            'clean': Clean,
            'gen_reqfile': GenerateRequirementFile,
        },
        ext_modules=ext_modules,
    )
