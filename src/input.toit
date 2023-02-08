import host.file

resolve_input_file_name data_name/string -> string:
  return "input/$data_name"

as_byte_array data_name/string -> ByteArray:
  return file.read_content (resolve_input_file_name data_name)

as_string --throwing/bool=false data_name/string -> string:
  if throwing:
    return (as_byte_array data_name).to_string
  else:
    return (as_byte_array data_name).to_string_non_throwing
