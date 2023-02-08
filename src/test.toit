import cli

import system.api.log show LogService
import system.api.print show PrintService
import system.services

test_cases_ ::= {:}

add_test name/string test/Lambda:
  test_cases_[name]=test

run args/List:
  root := cli.Command "root"
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
                     --short_name="o"
                     ]
      --rest=[cli.Option "test_cases" --multi
                  --short_help="List of test cases to run"]
      --run=:: run_ it

  root.run args

run_ parsed/cli.Parsed:

  cases/List := parsed["test-cases"]
  tests/Map := ?
  if cases.is_empty:
    tests = test_cases_
  else:
    tests = test_cases_.filter: |k v| cases.contains k

  if tests.is_empty:
    print "No tests specified"
    exit 1

  do_case_output := parsed["output"]
  test_reporter/TestPrinter_ := ?
  if do_case_output:
    test_reporter = OutputTestPrinter_
  else:
    test_reporter = NoOutputTestPrinter_
    install_services_

  max_key := tests.keys.reduce --initial=0: |p k/string| max p k.size

  any_failed/bool := false
  tests.do: | k v |
    test_reporter.print_start max_key k
    e :=
      catch
          --trace=(: not it is TestFailure_)
          --unwind=(: not it is TestFailure_):
        v.call

    if not e:
      test_reporter.print_success
    else if e is TestFailure_:
      any_failed = true
      test_reporter.print_failure e.message
    else:
      unreachable

  if any_failed: exit 1
  else: exit 0

fail message/string: throw (TestFailure_ message)

expect_equals expected/any actual/any message/string?=null:
  if expected != actual:
    fail "Expected $expected got $actual$(message?", $message":"")"

expect_true value/bool message/string?=null:
  if not value:
    fail (message?message:"")

expect_false value/bool message/string?=null:
  if value:
    fail (message?message:"")

expect_exception --exception_value=null [block]:
  e := catch: block.call
  if not e: fail "No exception thrown"
  if exception_value == null: return
  fail "Wrong exception was thrown. Expected $exception_value and got $e"

class TestFailure_:
  message/string
  constructor .message:

interface TestPrinter_:
  print_start max_length/int name/string
  print_success
  print_failure message/string

class OutputTestPrinter_ implements TestPrinter_:
  print_start max_length/int name/string: print "Starting test for $name"
  print_success: print "Test successful"
  print_failure message/string: print "Test failed: $message"

class NoOutputTestPrinter_ implements TestPrinter_:
  print_start max_length/int name/string:
    write_on_stdout_ "Running test $name $(pad_dots_ (max_length + 3) name) " false

  print_success:
    write_on_stdout_ "Ok" true

  print_failure message/string:
    write_on_stdout_ "Failed: $message" true

  pad_dots_ right_justification label/string -> string:
    return (List (right_justification - label.size) ".").join ""

install_services_:
  (LogServiceDefinition).install
  (PrintServiceDefinition).install

class PrintServiceDefinition extends services.ServiceDefinition:
  constructor:
    super "" --major=PrintService.MAJOR --minor=PrintService.MINOR
    provides PrintService.UUID PrintService.MAJOR PrintService.MINOR

  handle pid/int client/int index/int arguments/any -> any:
    // Ignore everything
    return null

class LogServiceDefinition extends services.ServiceDefinition:
  constructor:
    super "" --major=LogService.MAJOR --minor=LogService.MINOR
    provides LogService.UUID LogService.MAJOR LogService.MINOR

  handle pid/int client/int index/int arguments/any -> any:
    // Ignore everything
    return null
