# Simple test framework for toit
Facilitates running tests for toit code. The main focus for this project 
is to enable running tests of toit code on the host. 
For now the test framework is a convenience wrapper to launch tests,
provide standardised expected outcome comparison and help with managing
input artifacts.

## Installation
Unfortunately the installation is a little more complicated in this phase
than what should be necessary. There are two main prerequisites to enable 
installation
* `toit.compile` and `toit.run` must be in the path
* `git` must be installed in path
* The user running the installation must have write permissions to the 
path where `toit.compile` is located

### Installing the `toit.test` executable
The `toit.test` executable will be installed in the same directory as the 
`toit.compile` binary.

1. The first to do is to clone the repo: `git clone https://github.com/mikkeldamsgaard/pkg-test`
2. `cd pkg-test`
3. `toit.pkg install`
4. `toit.run tool/install.toit`

## Usage
When the `toit.test` executable is installed, it can be invoked from 
the command line and it can show a little help with `toit.test --help`

**Important**: In the project that you want to test, the `pkg-test` package
dependency must be added with `toit.pkg install pkg-test`

The `toit.test` tool is a way to orchestrate running tests. In the most 
simple form, it takes as input a Toit source file, looks for all methods in
that file that start with `test_` and executes them.

The tool can recursively search for files that should be inspected for 
test methods. The convention is that it will looks for all Toit files (`'*.toit`) in 
that has `tests` in it path. That way, if the project has a directory named
`tests` then it is assumed that all `.toit` files below that directory will
be test files and should be inspected for test methods.

## Example tests
A simple test of a fictional method `sum`

```toit
import ../sum.toit
import test

test_one_plus_one:
  test.expect_equals 2 (sum 1 1)
  
test_one_plus_two:
  test.expect_equals 3 (sum 1 2) 
```

## Input support
To help with managing input to test functions, the framework assumes that 
input files are placed in a subdirectory called `input` next to the test Toit file.

To use input data files, simple `import test.input` and start loading files:
```toit
import test.input
import test

test_load_input:
  hello := input.as_string "hello_world.txt"
  test.expect_equals "Hello World!" hello
```

(For this test to complete with `Ok` a file with content `Hello World!` should be 
placed in `input/hello_world.txt`)

## Real example
The pkg-slip package uses this test framework. To see it in action:
1. `git clone https://github.com/mikkeldamsgaard/pkg-slip`
2. `cd pkg-slip`
3. `toit.pkg install`
4. `toit.test -r .`
