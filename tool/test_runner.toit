import .toit.tools.lsp.server.client
import .toit.tools.lsp.server.protocol.document_symbol

import cli

import host.file
import host.directory
import host.pipe

import ..src.test

import .path_utils

read_tests toitc/string test_file/string -> List:
  tests := []
  with_lsp_client --toitc=toitc --lsp_server=null : | client/LspClient |
    outline := client.send_outline_request --path=test_file
    outline.do: | block |
      if block["kind"] == SymbolKind.FUNCTION:
        name := block["name"] as string
        if name.starts_with "test_": tests.add name
  return tests

root ::= cli.Command "root"
             --long_help="""
               Run tests defined by a test file.
               """
             --options=[cli.Flag "output" --default=false
                            --short_help="""
                              Toggle output from test cases.
                              By default this is off and the test system installs a logger service
                              and a print service to intercept logs and prints. If the system under test
                              uses either of these, this flag should be set to not install the
                              test systems services
                              """
                            --short_name="o",
                       cli.OptionString "test_cases" --multi=true
                            --short_name="c"
                            --short_help="""
                              Selects a list of test cases to run from the input file.
                              By default all test cases are run
                              """,
                       cli.OptionString "recursive"
                            --short_name="r"
                            --short_help="""
                              Recursively search the supplied dir for sub directories called 'tests'
                              and then search for tests in all toit files in those subdirectories.
                              The recursive search skips directories starting with '.', as
                              for example '.packages' and '.testing'
                            """
                       ]
             --rest=[cli.Option "test_files" --multi
                         --short_help="List of files to search for test cases"]
             --run=:: run_ it

main args:
  root.run args

run_ parsed/cli.Parsed:
  install_services_
  do_output_ = true
  toitc := which "toit.compile"
  if not toitc:
    print "Could not find toit.compile in path"
    exit 1

  test_files := Set
  test_files.add_all parsed["test_files"]
  if parsed["recursive"]:
    test_files.add_all
        find_recursive
          directory.realpath
             parsed["recursive"]

  if test_files.is_empty:
    if parsed["recursive"]:
      print "No test files found in specified directory"
    else:
      print "Specify either --recursive or a list of test files"
    print root.help
    exit 1

  failed := 0
  first := true
  test_files.do: | test_file/string |
    do_output_ = false
    if file.is_file test_file:
      real_test_path := directory.realpath test_file
      tests := read_tests toitc real_test_path
      test_path_dir := path_to real_test_path
      testing_dir := "$test_path_dir$(dir_separator_).testing"
      if not (file.is_directory testing_dir):
        directory.mkdir testing_dir
      test_base := base_name real_test_path
      out_file_name := "$testing_dir$dir_separator_$test_base"
      out_stream := file.Stream.for_write out_file_name

      test_base_no_extension := test_base[0..(test_base.index_of ".")]

      if parsed["test_cases"].size > 0:
        found_ay := false
        parsed["test_cases"].do:
          if tests.contains it: found_ay = true

        if not found_ay:  continue.do

      out_stream.write """
      import test
      import ..$test_base_no_extension
      main args:
      """

      tests.do: | test/string |
        out_stream.write """  test.add_test "$test" :: $test\n"""

      out_stream.write "  test.run args\n"
      out_stream.close
      do_output_ = true
      if not first: print ""
      print "Running tests from $test_file:"
      arguments := ["toit.run", out_file_name,"-p","  "]

      if parsed["test_cases"].size > 0: arguments.add_all parsed["test_cases"]
      if parsed["output"]: arguments.add "-o"

      pipe_result := pipe.fork true pipe.PIPE_INHERITED pipe.PIPE_INHERITED pipe.PIPE_INHERITED arguments[0] arguments
      exit_code := pipe.exit_code (pipe.wait_for pipe_result[3])
      failed += exit_code != 0 ? 1 : 0
      first = false
  exit failed
