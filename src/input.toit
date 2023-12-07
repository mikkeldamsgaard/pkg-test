import host.file

resolve-input-file-name data-name/string -> string:
  return "input/$data-name"

as-byte-array data-name/string -> ByteArray:
  return file.read-content (resolve-input-file-name data-name)

as-string --throwing/bool=false data-name/string -> string:
  if throwing:
    return (as-byte-array data-name).to-string
  else:
    return (as-byte-array data-name).to-string-non-throwing
