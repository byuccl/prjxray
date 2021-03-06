# Notice
This fork of Project X-Ray is meant for use with [Maverick](https://github.com/byuccl/maverick).
At the time this fork was made, Project X-Ray did not support Zynq devices, such as the xc7z020clg400-1 SoC on the PYNQ-Z1 board.
This fork contains modified fuzzers that add support for generating a database for a region of the xc7z020clg400-1 device.
Additionally, this fork contains xc7PartialPatch - a program similar to xc7Patch for patching partial bitstreams with FRM files.

Since this fork and these changes were made, many changes and improvements have been made to Project X-Ray.
It now supports Zynq devices and the format of several files, including the FASM format and the tile grid format, have changed.
As such, the modified files and xc7PartialPatch will not work with the current versions of Project X-Ray without additional effort.

# Project X-Ray

Documenting the Xilinx 7-series bit-stream format.

This repository contains both tools and scripts which allow you to document the
bit-stream format of Xilinx 7-series FPGAs.

More documentation can be found published on [prjxray ReadTheDocs site](http://prjxray.readthedocs.io/en/latest/) - this includes;
 * [Highlevel Bitstream Architecture](http://prjxray.readthedocs.io/en/latest/architecture/overview.html)
 * [Overview of DB Development Process](http://prjxray.readthedocs.io/en/latest/db_dev_process/overview.html)

# Quickstart Guide

Install Vivado 2017.2 (2017.3 has a known compatibility issue, see
https://github.com/SymbiFlow/prjxray/issues/14). Then source the settings
script, ie

    source /opt/Xilinx/Vivado/2017.2/settings64.sh

Pull submodules:

    git submodule update --init --recursive

Get a head start by downloading current database:

    # Give the argument;
    # - https if you to use the https protocol (default)
    # - git+ssh if you want to use git+ssh protocol
    # - git if you want to use the git protocol
    ./download-latest-db.sh

Install CMake and build the C++ tools:

    sudo apt-get install cmake # version 3.5.0 or later required,
                               # for Ubuntu Trusty pkg is called cmake3
    mkdir build
    pushd build
    cmake ..
    make
    popd

Always make sure to set the environment for the device you are working on before
running any other commands:

    source database/artix7/settings.sh

Creating HTML documentation:

    cd htmlgen
    python3 htmlgen.py

(Re-)creating the database:

    cd fuzzers
    make -j$(nproc)

(Re-)creating parts of the database, for example LUT init bits:

    cd fuzzers/010-lutinit
    make -j$(nproc) run

Tests are not built by default.  Setting the PRJXRAY\_BUILD\_TESTING option to
ON when running cmake will include them:

    cmake -DPRJXRAY_BUILD_TESTING=ON ..
    make

The default C++ build configuration is for releases (optimizations enabled, no
debug info). A build configuration for debugging (no optimizations, debug info)
can be chosen via the CMAKE\_BUILD\_TYPE option:

    cmake -DCMAKE_BUILD_TYPE=Debug ..
    make

The options to build tests and use a debug build configuration are independent
to allow testing that optimizations do not cause bugs.  The build configuration
and build tests options may be combined to allow all permutations.

# Process

The documentation is done through a "black box" process were Vivado is asked to
generate a large number of designs which then used to create bitstreams. The
resulting bit streams are then cross correlated to discover what different bits
do.

## Parts

### [Minitests](minitests)

There are also "minitests" which are designs which can be viewed by a human in
Vivado to better understand how to generate more useful designs.

### [Experiments](experiments)

Experiments are like "minitests" except are only useful for a short period of
time. Files are committed here to allow people to see how we are trying to
understand the bitstream.

When an experiment is finished with, it will be moved from this directory into
the latest "prjxray-experiments-archive-XXXX" repository.

### [Fuzzers](fuzzers)

Fuzzers are the scripts which generate the large number of bitstream.

They are called "fuzzers" because they follow an approach similar to the
[idea of software testing through fuzzing](https://en.wikipedia.org/wiki/Fuzzing).

### [Tools](tools) & [Libs](libs)

Tools & libs are useful tools (and libraries) for converting the resulting
bitstreams into various formats.

Binaries in the tools directory are considered more mature and stable then
those in the [utils](utils) directory and could be actively used in other
projects.

### [Utils](utils)

Utils are various tools which are still highly experimental. These tools should
only be used inside this repository.

### [Third Party](third_party)

Third party contains code not developed as part of Project X-Ray.


# Database

Running the all fuzzers in order will produce a database which documents the
bitstream format in the [database](database) directory.

As running all these fuzzers can take significant time,
[Tim 'mithro' Ansell <me@mith.ro>](https://github.com/mithro) has graciously
agreed to maintain a copy of the database in the
[prjxray-db](https://github.com/SymbiFlow/prjxray-db) repository.

Please direct enquires to [Tim](mailto:me@mith.ro) if there are any issues with
it.

# Current Focus

Current the focus has been on the Artix-7 50T part. This structure is common
between all footprints of the 15T, 35T and 50T varieties.

We have also started experimenting with the Kintex-7 parts.

The aim is to eventually document all parts in the Xilinx 7-series FPGAs but we
can not do this alone, **we need your help**!


## TODO List

 - [ ] Write a TODO list


# Contributing

There are a couple of guidelines when contributing to Project X-Ray which are
listed here.

### Sending

All contributions should be sent as
[GitHub Pull requests](https://help.github.com/articles/creating-a-pull-request-from-a-fork/).

### License

All code in the Project X-Ray repository is licensed under the very permissive
[ISC Licence](COPYING). A copy can be found in the [`COPYING`](COPYING) file.

All new contributions must also be released under this license.

### Code of Conduct

By contributing you agree to the [code of conduct](CODE_OF_CONDUCT.md). We
follow the open source best practice of using the [Contributor
Covenant](https://www.contributor-covenant.org/) for our Code of Conduct.

### Sign your work

To improve tracking of who did what, we follow the Linux Kernel's
["sign your work" system](https://github.com/wking/signed-off-by).
This is also called a
["DCO" or "Developer's Certificate of Origin"](https://developercertificate.org/).

**All** commits are required to include this sign off and we use the
[Probot DCO App](https://github.com/probot/dco) to check pull requests for
this.

The sign-off is a simple line at the end of the explanation for the
patch, which certifies that you wrote it or otherwise have the right to
pass it on as a open-source patch.  The rules are pretty simple: if you
can certify the below:

        Developer's Certificate of Origin 1.1

        By making a contribution to this project, I certify that:

        (a) The contribution was created in whole or in part by me and I
            have the right to submit it under the open source license
            indicated in the file; or

        (b) The contribution is based upon previous work that, to the best
            of my knowledge, is covered under an appropriate open source
            license and I have the right under that license to submit that
            work with modifications, whether created in whole or in part
            by me, under the same open source license (unless I am
            permitted to submit under a different license), as indicated
            in the file; or

        (c) The contribution was provided directly to me by some other
            person who certified (a), (b) or (c) and I have not modified
            it.

	(d) I understand and agree that this project and the contribution
	    are public and that a record of the contribution (including all
	    personal information I submit with it, including my sign-off) is
	    maintained indefinitely and may be redistributed consistent with
	    this project or the open source license(s) involved.

then you just add a line saying

	Signed-off-by: Random J Developer <random@developer.example.org>

using your real name (sorry, no pseudonyms or anonymous contributions.)

You can add the signoff as part of your commit statement. For example:

    git commit --signoff -a -m "Fixed some errors."

*Hint:* If you've forgotten to add a signoff to one or more commits, you can use the
following command to add signoffs to all commits between you and the upstream
master:

    git rebase --signoff upstream/master

### Contributing to the docs

In addition to the above contribution guidelines, see the guide to
[updating the Project X-Ray docs](UPDATING-THE-DOCS.md).
