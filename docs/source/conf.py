#!/usr/bin/env python3
# -*- coding: utf-8 -*-
#   Copyright 2022 <Huawei Technologies Co., Ltd>
#
#   Licensed under the Apache License, Version 2.0 (the "License");
#   you may not use this file except in compliance with the License.
#   You may obtain a copy of the License at
#
#       http://www.apache.org/licenses/LICENSE-2.0
#
#   Unless required by applicable law or agreed to in writing, software
#   distributed under the License is distributed on an "AS IS" BASIS,
#   WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
#   See the License for the specific language governing permissions and
#   limitations under the License.

# Configuration file for the Sphinx documentation builder.
#
# This file only contains a selection of the most common options. For a full
# list see the documentation:
# http://www.sphinx-doc.org/en/master/config

"""Sphinx configuration file for MindQuantum."""

# -- Path setup --------------------------------------------------------------

import os
import pathlib
import subprocess

try:
    import importlib.metadata as importlib_metadata  # pragma: no cover (PY38+)
except ImportError:
    import importlib_metadata  # pragma: no cover (<PY38)

conf_path = pathlib.Path(__file__).parent.resolve()

# -- General declarations ----------------------------------------------------

# Mock
autodoc_mock_imports = ['cirq', 'projectq', 'mindspore']

on_rtd = os.environ.get('READTHEDOCS', None) == 'True'

if on_rtd:
    # C++ compilation will fail on RTD so we create a "dummy" package to allow a successful importation of MindQuantum
    mqbackend = conf_path.parent.parent / 'mindquantum' / 'mqbackend.py'
    if not mqbackend.exists():
        mqbackend.write_text('')
    doxygen_cmd = f'cd {conf_path.parent} && mkdir -p doxygen && doxygen'
    print(f'INFO: Calling doxygen: {doxygen_cmd}')
    subprocess.run(doxygen_cmd)  # noqa: SCS103

# -- Project information -----------------------------------------------------

project = 'MindQuantum'
description = '''MindQuantum is a general quantum computing framework developed by MindSpore and HiQ, that can be used
to build and train different quantum neural networks. Thanks to the powerful algorithm of quantum software group of
Huawei and High-performance automatic differentiation ability of MindSpore, MindQuantum can efficiently handle
problems such as quantum machine learning, quantum chemistry simulation, and quantum optimization, which provides an
efficient platform for researchers, teachers and students to quickly design and verify quantum machine learning
algorithms.'''
copyright = '2020, Huawei HiQ'
author = 'Huawei HiQ developers'

# -- General configuration ---------------------------------------------------

# Add any Sphinx extension module names here, as strings. They can be
# extensions coming with Sphinx (named 'sphinx.ext.*') or your custom
# ones.

extensions = [
    'sphinx.ext.autodoc',
    'sphinx.ext.napoleon',
    'sphinx.ext.mathjax',
    'sphinx.ext.autosummary',
    'breathe',
    'myst_parser',
]

autosummary_generate = True

# Add any paths that contain templates here, relative to this directory.
templates_path = ['_templates']

# List of patterns, relative to source directory, that match files and directories to ignore when looking for source
# files.
# This pattern also affects html_static_path and html_extra_path.
exclude_patterns = []

source_suffix = ['.rst', '.md']

# The master toctree document.
master_doc = 'index'

release = importlib_metadata.version('mindquantum')  # Full version string
version = '.'.join(release.split('.')[:3])  # X.Y.Z

# The language for content autogenerated by Sphinx. Refer to documentation for a list of supported languages.
#
# This is also used if you do content translation via gettext catalogs.  Usually you set "language" from the command
# line for these cases.
language = None

# List of patterns, relative to source directory, that match files and directories to ignore when looking for source
# files.  This patterns also effect to html_static_path and html_extra_path
exclude_patterns = ['_build', 'Thumbs.db', '.DS_Store', 'README.md']

# The name of the Pygments (syntax highlighting) style to use.
pygments_style = 'sphinx'

# If true, `todo` and `todoList` produce output, else they produce nothing.
todo_include_todos = False

# -- Options for C++ documentation

breathe_projects = {'mindquantum': f'{conf_path.parent}/doxygen/xml'}
breathe_default_members = ('members', 'undoc-members')

highlight_language = 'c++'

# -- Options for HTML output -------------------------------------------------

# The theme to use for HTML and HTML Help pages.  See the documentation for a list of builtin themes.
#
html_theme = 'sphinx_rtd_theme'

# Output file base name for HTML help builder.
htmlhelp_basename = 'mqdoc'

# ----------------------------------------------------------------------------

# -- Options for LaTeX output ---------------------------------------------

# Grouping the document tree into LaTeX files. List of tuples (source start file, target name, title, author,
# documentclass [howto, manual, or own class]).
latex_documents = [
    (master_doc, 'MindQuantum.tex', '{} Documentation'.format(project), 'a', 'manual'),
]

# -- Options for manual page output ---------------------------------------

# One entry per manual page. List of tuples (source start file, name, description, authors, manual section).
man_pages = [(master_doc, project, '{} Documentation'.format(project), [author], 1)]

# -- Options for Texinfo output -------------------------------------------

# Grouping the document tree into Texinfo files. List of tuples (source start file, target name, title, author, dir
# menu entry, description, category)
texinfo_documents = [
    (master_doc, project, '{} Documentation'.format(project), author, project, description),
]

# -- Options for sphinx.ext.linkcode --------------------------------------

# Nothing here yet
