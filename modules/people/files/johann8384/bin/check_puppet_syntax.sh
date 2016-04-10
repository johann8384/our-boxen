#!/bin/bash
#Script to test puppet files have valid syntax.
#Intended for use with hudson/jenkins.

set -e
set -u

fail=0
#TODO: Run these in parallel - we have 4 cores.
#TODO: Control the environment (through the config dir?). 
#      We want to parse for all environments.  
#      Is this being done, contrary to puppet report?
#TODO: Even with --ignoreimport, some may be pulling in others, 
#      meaning we're checking multiple times.
all_files=`find -name "*.pp" -o -name "*.erb"`
num_files=`echo $all_files | wc -w`
if [[ $num_files -eq "0" ]]; then
  echo "ERROR: no .pp or .erb files found"
  exit 1
fi
echo "Checking $num_files *.pp and *.erb files for syntax errors."
echo "Puppet version is: `puppet --version`"

for x in $all_files; do
  set +e
  case $x in
  *.pp )
    puppet --parseonly --ignoreimport --color=false $x ;;
  *.erb )
    cat $x | erb -x -T - | ruby -c > /dev/null ;;
  esac
  rc=$?
  set -e
  if [[ $rc -ne 0 ]] ; then
    fail=1
    echo "ERROR in $x (see above)"
  fi
done

if [[ $fail -ne 0 ]] ; then
  echo "FAIL: at least one file failed syntax check."
else
  echo "SUCCESS: all .pp and *.erb files pass syntax check."
fi
exit $fail
