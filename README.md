# eld
eld - an Erlang Linker

Produces executable programs from Erlang code, either

- from a single Erlang module source file, or

- from a number of BEAM files (compiled Erlang source modules) and a number
  of Erlang library/application archives; such an archive must be a ZIP file
  with the following contents:

      apporlib/
          ebin/
              *.beam
              *.app   (optional for libraries)
          priv/       (optional)

The executables will be relocatable ESCRIPT files containing the code modules
specified above, and which will invoke the Erlang runtime system to execute them.

This is intendend for stand-alone programs implemented in Erlang, not for big
systems with continuously running services -- there are ample alternatives for
the latter.

Examples:

      eld hello.erl && ./a.out % starts in hello:main/1
      eld main.beam utils.beam && ./a.out % starts in main:main/1
      eld -e entry a.beam entry.beam z.beam && ./a.out % starts in entry:main/1
      eld -o main main.beam && ./main
      eld -e myapp myapp.beam mylib.zip thirdpartylib.zip

Runtime dependencies for eld:
- zip, unzip
- coreutils (basename, realpath, mktemp, rm, rmdir, cp, echo, cat, chmod)
- Bourne shell

Runtime dependencies for the generated executables:
- coreutils (/usr/bin/env)
- an Erlang installation (escript) in $PATH
