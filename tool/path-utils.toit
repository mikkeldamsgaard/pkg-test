import host.os
import host.file
import host.directory

dir-separator_ ::= platform == PLATFORM-WINDOWS ? "\\" : "/"

path-to path/string:
  last-dir-separator := path.index-of --last dir-separator_
  if last-dir-separator == -1: return ""
  return path[0..path.index-of --last dir-separator_]

base-name path/string:
  return path[(path.index-of --last dir-separator_) + 1 ..]

which executable:
  path := os.env["PATH"]
  path-sep := platform == PLATFORM-WINDOWS ? ";" : ":"
  (path.split path-sep).do: | p/string |
    full := "$p$dir-separator_$executable"
    if file.is-file full: return full

  return null

list-dir_ base/string [block]:
  stream := directory.DirectoryStream base
  while true:
    next := stream.next
    if not next:
      stream.close
      return

    block.call next

concat-dirs base sub: return "$base$dir-separator_$sub"

find-recursive base/string child-of-tests/bool=false -> Set:
  result := Set

  list-dir_ base: | entry-name/string |
    entry :=  concat-dirs base entry-name

    if file.is-directory entry:
      if entry-name == "tests":
        result.add-all (find-recursive entry true)
      else if not entry-name.starts-with ".":
        result.add-all (find-recursive entry child-of-tests)
    else if file.is-file entry:
      if child-of-tests and entry.ends-with ".toit":
        result.add entry


  return result