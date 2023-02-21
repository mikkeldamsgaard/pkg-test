import host.os
import host.file
import host.directory

dir_separator_ ::= platform == PLATFORM_WINDOWS ? "\\" : "/"


path_to path/string:
  last_dir_separator := path.index_of --last dir_separator_
  if last_dir_separator == -1: return ""
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

list_dir_ base/string [block]:
  stream := directory.DirectoryStream base
  while true:
    next := stream.next
    if not next:
      stream.close
      return

    block.call next

concat_dirs base sub: return "$base$dir_separator_$sub"

find_recursive base/string child_of_tests/bool=false -> Set:
  result := Set

  list_dir_ base: | entry_name/string |
    entry :=  concat_dirs base entry_name

    if file.is_directory entry:
      if entry_name == "tests":
        result.add_all (find_recursive entry true)
      else if not entry_name.starts_with ".":
        result.add_all (find_recursive entry child_of_tests)
    else if file.is_file entry:
      if child_of_tests and entry.ends_with ".toit":
        result.add entry


  return result