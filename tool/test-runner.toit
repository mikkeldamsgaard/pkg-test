import .toit.tools.lsp.server.client
import .toit.tools.lsp.server.protocol.document-symbol

import cli

import host.file
import host.directory
import host.pipe

import ..src.test

import .path-utils

read-tests toitc/string test-file/string -> List:
  tests := []
  with-lsp-client --toitc=toitc --lsp-server=null : | client/LspClient |
    outline := client.send-outline-request --path=test-file
    outline.do: | block |
      if block["kind"] == SymbolKind.FUNCTION:
        name := block["name"] as string
        if name.starts-with "test_": tests.add name
  return tests

root ::= cli.Command "root"
             --long-help="""
               Run tests defined by a test file.
               """
             --options=[cli.Flag "output" --default=false
                            --short-help="""
                              Toggle output from test cases.
                                By default this is off and the test system installs a logger service
                                and a print service to intercept logs and prints. If the system under test
                                uses either of these, this flag should be set to not install the
                                test systems services
                              """
                            --short-name="o",
                       cli.OptionString "test_cases" --multi=true
                            --short-name="c"
                            --short-help="""
                              Selects a list of test cases to run from the input file.
                                By default all test cases are run
                              """,
                       cli.OptionString "recursive"
                            --short-name="r"
                            --short-help="""
                              Recursively search the supplied dir for sub directories called 'tests'
                                and then search for tests in all toit files in those subdirectories.
                                The recursive search skips directories starting with '.', as
                                for example '.packages' and '.testing'
                              """
                       ]
             --rest=[cli.Option "test_files" --multi
                         --short-help="List of files to search for test cases"]
             --run=:: run_ it

main args:
  root.run args

run_ parsed/cli.Parsed:
  install-services_
  do-output_ = true
  toitc := which "toit.compile"
  if not toitc:
    print "Could not find toit.compile in path"
    exit 1

  test-files := Set
  test-files.add-all parsed["test_files"]
  if parsed["recursive"]:
    test-files.add-all
        find-recursive
          directory.realpath
             parsed["recursive"]

  if test-files.is-empty:
    if parsed["recursive"]:
      print "No test files found in specified directory"
    else:
      print "Specify either --recursive or a list of test files"
    print root.help
    exit 1

  failed := 0
  first := true
  test-files.do: | test-file/string |
    do-output_ = false
    if file.is-file test-file:
      real-test-path := directory.realpath test-file
      tests := read-tests toitc real-test-path
      test-path-dir := path-to real-test-path
      testing-dir := "$test-path-dir$(dir-separator_).testing"
      if not (file.is-directory testing-dir):
        directory.mkdir testing-dir
      test-base := base-name real-test-path
      out-file-name := "$testing-dir$dir-separator_$test-base"
      out-stream := file.Stream.for-write out-file-name

      test-base-no-extension := test-base[0..(test-base.index-of ".")]

      if parsed["test_cases"].size > 0:
        found-ay := false
        parsed["test_cases"].do:
          if tests.contains it: found-ay = true

        if not found-ay:  continue.do

      out-stream.write """
      import test
      import ..$test-base-no-extension
      main args:
      """

      tests.do: | test/string |
        out-stream.write """  test.add_test "$test" :: $test\n"""

      out-stream.write "  test.run args\n"
      out-stream.close
      do-output_ = true
      if not first: print "\0"
      print "\0Running tests from $test-file:"
      arguments := ["toit.run", out-file-name, "-p", "  "]

      if parsed["test_cases"].size > 0: arguments.add-all parsed["test_cases"]
      if parsed["output"]: arguments.add "-o"

      pipe-result := pipe.fork true pipe.PIPE-INHERITED pipe.PIPE-INHERITED pipe.PIPE-INHERITED arguments[0] arguments
      print_ "!\$>> Waitfor"
      e := catch --trace=(: it != DEADLINE-EXCEEDED-ERROR):
        with-timeout --ms=30000:
          exit-code := pipe.exit-code (pipe.wait-for pipe-result[3])
          print_ "!\$>> Waitfor.done"
          failed += exit-code != 0 ? 1 : 0
      if e:
        print "\0Timeout"
        failed += 1
      first = false
  exit failed
