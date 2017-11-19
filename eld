#!/bin/sh
#
#  Copyright 2017 Mikael Pettersson
#
#  Licensed under the Apache License, Version 2.0 (the "License");
#  you may not use this file except in compliance with the License.
#  You may obtain a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
#  Unless required by applicable law or agreed to in writing, software
#  distributed under the License is distributed on an "AS IS" BASIS,
#  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
#  See the License for the specific language governing permissions and
#  limitations under the License.
#
# eld - an Erlang Linker

set -x

# Subroutines

# link_single $SOURCE $OUTFILE [$ENTRY]
link_single() {
  { echo '#!/usr/bin/env escript'
    if [ -n "$3" ]; then
      echo '%%! -smp auto -noshell +Bd -escript main' "$3"
    else
      echo '%%! -smp auto -noshell +Bd'
    fi
    cat "$1"; } > $2 && chmod +x $2
}

# link_multiple "$BEAMS" "$ZIPS" $OUTFILE $ENTRY
# - each .zip/.ez argument should contain the following:
#   apporlib/ebin/*
# - assemble a temporary directory with the following layout:
#   tmpdir/
#     *.beam
#     apporlib1/ebin/*
#     ...
#     apporlibN/ebin/*
# - zip the directory together to form tmpdir.zip
# - link with tmpdir.zip as the source
# - clean up
link_multiple() {
  TMPDIR=`mktemp -d`
  { for i in $1; do cp $i $TMPDIR/; done
    for i in $2; do unzip -q $i -d $TMPDIR; done
    cd $TMPDIR
    zip -q -r $TMPDIR.zip .
    cd - > /dev/null
    rm -rf $TMPDIR
    link_single $TMPDIR.zip $3 $4
    rm $TMPDIR.zip; } || { rm -rf $TMPDIR; rm -f $TMPDIR.zip; exit 1; }
}

# Default output file name, override with "-o <OUTFILE>"
OUTFILE=a.out

# Erlang source input file
ERLSRC=

# BEAM input files
BEAMS=

# ZIP or EZ input files
ZIPS=

# Entry Module containing 'main/1', default 'main' except when linking a single BEAM, override with "-e <ENTRY>"
ENTRY=

# Scan argument list

while [ $# -gt 0 ]; do
  case "$1" in
    -o)
	shift
	if [ $# -eq 0 ]; then
	   echo option "'-o'" requires an argument
	   exit 1
	fi
	OUTFILE="$1"
	;;
    -e)
	shift
	if [ $# -eq 0 ]; then
	   echo option "'-e'" requires an argument
	   exit 1
	fi
	if [ -n "$ENTRY" ]; then
	   echo option "'-e'" multiply specified
	   exit 1
	fi
	if [ -n "$ERLSRC" ]; then
	   echo option "'-e'" cannot be used when linking an Erlang source file
	   exit 1
	fi
	ENTRY="$1"
	;;
    *.erl)
	if [ -n "$ERLSRC" ]; then
	   echo multiple Erlang source files specified, use compiled BEAM modules instead
	   exit 1
	fi
	if [ -n "$BEAMS" ]; then
	   echo cannot mix Erlang source files and compiled BEAM modules
	   exit 1
	fi
	if [ -n "$ZIPS" ]; then
	   echo cannot mix Erlang source files and ZIP files with compiled BEAM modules
	   exit 1
	fi
	if [ -n "$ENTRY" ]; then
	   echo option "'-e'" cannot be used when linking an Erlang source file
	   exit 1
	fi
	ERLSRC="$1"
	;;
    *.beam)
        if [ -n "$ERLSRC" ]; then
	   echo cannot mix Erlang source files and compiled BEAM modules
	   exit 1
	fi
        BEAMS="$BEAMS $1"
	;;
    *.zip|*.ez)
        if [ -n "$ERLSRC" ]; then
	   echo cannot mix Erlang source files and ZIP files with compiled BEAM modules
	   exit 1
	fi
        ZIPS="$ZIPS `realpath -e $1`"
	;;
    *)
	echo unknown argument "'$1'"
	exit 1
	;;
  esac
  shift
done

# See what we got and perform the corresponding actions:
# - detect links with a single source and avoid intermediate directory and zip
# - when linking a single BEAM check that ENTRY if specified matches the single BEAM
# - when linking ZIPs and/or multiple BEAMS, default ENTRY to main if not specified
# - produce ESCRIPT with the specificed source or assembled sources

if [ -n "$ERLSRC" ]; then
  link_single "$ERLSRC" "$OUTFILE"
elif [ -n "$BEAMS" -a -z "$ZIPS" ]; then
  set $BEAMS
  if [ $# -eq 1 ]; then
     if [ -n "$ENTRY" -a "$ENTRY" != `basename "$1" .beam` ]; then
     	echo specified entry module "'$ENTRY'" does not match single input module "'$1'"
	exit 1
     fi
    link_single "$1" "$OUTFILE"
  else
    link_multiple "$BEAMS" "" "$OUTFILE" "${ENTRY:-main}"
  fi
elif [ -z "$BEAMS" -a -n "$ZIPS" ]; then
  set $ZIPS
  if [ $# -eq 1 ]; then
    link_single "$1" "$OUTFILE" "${ENTRY:-main}"
  else
    link_multiple "" "$ZIPS" "$OUTFILE" "${ENTRY:-main}"
  fi
elif [ -n "$BEAMS" -a -n "$ZIPS" ]; then
  link_multiple "$BEAMS" "$ZIPS" "$OUTFILE" "${ENTRY:-main}"
else
  echo no input files specified
  exit 1
fi
