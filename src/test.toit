import cli

import system.api.log show LogService
import system.api.print show PrintService
import system.services
import log.target

test-cases_ ::= {:}

add-test name/string test/Lambda:
  test-cases_[name]=test

run args/List:
  root := cli.Command "root"
      --long-help="""
        Run tests defined by a test file.
        """
      --options=[cli.Flag "output" --default=false
                     --short-help="""
                       Toggle output from test cases.

                       By default this is off and the test system installs a logger service
                       and a print service to intercept logs and prints. If the system under test
                       uses either of these, this flag should be set to not install the
                       test systems services
                       """
                     --short-name="o",
                  cli.OptionString "prefix"
                     --short-help="Prefix to add to all output lines"
                     --short-name="p"
                     ]
      --rest=[cli.Option "test_cases" --multi
                  --short-help="List of test cases to run"]
      --run=:: run_ it

  root.run args

run_ parsed/cli.Parsed:
  cases/List := parsed["test-cases"]
  tests/Map := ?
  if cases.is-empty:
    tests = test-cases_
  else:
    tests = test-cases_.filter: |k v| cases.contains k

  if tests.is-empty:
    print "No tests specified"
    exit 1

  install-services_

  do-case-output := parsed["output"]
  test-reporter/TestPrinter_ := ?
  if do-case-output:
    if parsed["prefix"]: print-prefix_ = parsed["prefix"]
    test-reporter = OutputTestPrinter_
    do-output_ = true
  else:
    test-reporter = NoOutputTestPrinter_ parsed["prefix"]

  max-key := tests.keys.reduce --initial=0: |p k/string| max p k.size

  any-failed/bool := false
  tests.do: | k v |
    test-reporter.print-start max-key k
    should-trace := : not it is TestFailure_
    e := catch --trace=should-trace --unwind=should-trace:
      v.call

    if not e:
      test-reporter.print-success
    else if e is TestFailure_:
      any-failed = true
      test-reporter.print-failure e.message
    else:
      unreachable

  if any-failed: exit 1
  else: exit 0

fail message/string: throw (TestFailure_ message)

expect-equals expected/any actual/any message/string?=null:
  if expected != actual:
    fail "Expected $expected got $actual$(message?", $message":"")"

expect-null actual/any message/string?=null:
  if actual != null:
    fail "Expected null got $actual$(message?", $message":"")"

expect-true value/bool message/string?=null:
  if not value:
    fail (message?message:"")

expect-false value/bool message/string?=null:
  if value:
    fail (message?message:"")

expect-exception --exception-value=null [block]:
  e := catch: block.call
  if not e: fail "No exception thrown"
  if exception-value == null: return
  fail "Wrong exception was thrown. Expected $exception-value and got $e"

class TestFailure_:
  message/string
  constructor .message:

interface TestPrinter_:
  print-start max-length/int name/string
  print-success
  print-failure message/string

class OutputTestPrinter_ implements TestPrinter_:
  print-start max-length/int name/string: print "\0Starting test for $name"
  print-success: print "\0Test successful"
  print-failure message/string: print "\0Test failed: $message"

class NoOutputTestPrinter_ implements TestPrinter_:
  prefix_/string := ""
  constructor prefix:
    if prefix: prefix_ = prefix

  print-start max-length/int name/string:
    write-on-stdout_ "$(prefix_)Running test $name $(pad-dots_ (max-length + 3) name) " false

  print-success:
    write-on-stdout_ "Ok" true

  print-failure message/string:
    write-on-stdout_ "Failed: $message" true

  pad-dots_ right-justification label/string -> string:
    return (List (right-justification - label.size) ".").join ""

services-installed_/bool := false
install-services_:
  if not services-installed_:
    (LogServiceProvider).install
    (PrintServiceProvider).install
    services-installed_ = true

do-output_/bool := false
print-prefix_ := ""
class PrintServiceProvider extends services.ServiceProvider implements services.ServiceHandler:
  constructor:
    super "" --major=1 --minor=0
    provides PrintService.SELECTOR --handler=this

  handle index/int arguments/any --gid/int --client/int -> any:
    if do-output_:
      if arguments.size > 0 and arguments[0] == 0:
        write-on-stdout_ "$(print-prefix_)$arguments[1..]" true
      else:
        write-on-stdout_ "$(print-prefix_)  >> $arguments" true

    return null


class LogServiceProvider extends services.ServiceProvider implements services.ServiceHandler:
  delegate/LogService := target.StandardLogService_
  constructor:
    super "" --major=1 --minor=0
    provides LogService.SELECTOR --handler=this

  handle index/int arguments/any --gid/int --client/int -> any:
    if do-output_:
      level/int := arguments[0]
      message/string := arguments[1]
      names/List? := arguments[2]
      keys/List? := arguments[3]
      values/List? := arguments[4]
      delegate.log level message names keys values
    return null
