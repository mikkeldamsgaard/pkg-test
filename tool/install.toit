import .path_utils
import host.pipe
import host.directory
import host.file

main:
  path_to_program := (path_to program_name)
  if path_to_program != "": directory.chdir path_to_program

  toitc := which "toit.compile"
  if not toitc:
    print "Could not find toit.compile in path"
    exit 1

  git := which "git"
  if not git:
    print "Could not locate git in path, needed for install"
    exit 1

  install_dir := path_to toitc
  print "Installing in $install_dir"

  cloned := false
  if not file.is_directory "toit":
    pipe.backticks ["git", "clone", "--branch", "v2.0.0-alpha.82", "--depth", "1", "https://github.com/toitlang/toit.git"]
    cloned = true

  pipe.backticks [toitc, "-o", concat_dirs install_dir "toit.test", "test_runner.toit"]

  if cloned and file.is_directory "toit": directory.rmdir --recursive "toit"