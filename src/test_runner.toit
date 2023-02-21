import .tools.lsp.server.client
import .tools.lsp.server.protocol.document_symbol


import host.file
import host.os
import host.directory
import host.pipe

dir_separator_ ::= platform == PLATFORM_WINDOWS ? "\\" : "/"

path_to path/string:
  return path[0..path.index_of --last dir_separator_]

base_name path/string:
  return path[(path.index_of --last dir_separator_) + 1 ..]

which executable:
  path := os.env["PATH"]
  path_sep := platform == PLATFORM_WINDOWS ? ";" : ":"
  (path.split path_sep).do: | p/string |
    full := "$p$dir_separator_$executable"
    if file.is_file full: return full

  return null

read_tests toitc/string test_file/string -> List:
  tests := []
  with_lsp_client --toitc=toitc --lsp_server=null : | client/LspClient |
    outline := client.send_outline_request --path=test_file
    outline.do: | block |
      if block["kind"] == SymbolKind.FUNCTION:
        name := block["name"] as string
        if name.starts_with "test_": tests.add name
  return tests

main args:
  toitc := which "toit.compile"
  if not toitc: print "Could not find toit.compile in path"
  args.do: | test_file/string |
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
      print test_base_no_extension

      out_stream.write """
      import test
      import ..$test_base_no_extension
      main args:
      """

      tests.do: | test/string |
        out_stream.write """  test.add_test "$test" :: $test\n"""

      out_stream.write "  test.run args\n"
      out_stream.close
      arguments := ["toit.run", out_file_name]
      pipe_result := pipe.fork true pipe.PIPE_INHERITED pipe.PIPE_INHERITED pipe.PIPE_INHERITED arguments[0] arguments
      exit_code := pipe.exit_code (pipe.wait_for pipe_result[3])
      print "Exit code: $exit_code"
  exit 1
