import .path-utils
import host.pipe
import host.directory
import host.file

main:
  path-to-program := (path-to program-name)
  if path-to-program != "": directory.chdir path-to-program

  toitc := which "toit.compile"
  if not toitc:
    print "Could not find toit.compile in path"
    exit 1

  git := which "git"
  if not git:
    print "Could not locate git in path, needed for install"
    exit 1

  install-dir := path-to toitc
  print "Installing in $install-dir"

  cloned := false
  if not file.is-directory "toit":
    pipe.backticks ["git", "clone", "--branch", "v2.0.0-alpha.82", "--depth", "1", "https://github.com/toitlang/toit.git"]
    cloned = true

  pipe.backticks [toitc, "-o", concat-dirs install-dir "toit.test", "test_runner.toit"]

  if cloned and file.is-directory "toit": directory.rmdir --recursive "toit"