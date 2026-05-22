# CRAP Feature Scenarios

This document translates the outermost behavior covered by the current test suite into Gherkin-style scenarios. It groups low-level examples and property tests by user-visible capability rather than listing every generated case separately.

## Feature: Calculate CRAP Scores

```gherkin
Feature: Calculate CRAP scores
  As a developer
  I want CRAP scores derived from complexity and coverage
  So that I can identify risky, under-tested functions

  Scenario: Fully covered code keeps its complexity score
    Given a function has complexity 7
    And the function has 100% coverage
    When I calculate its CRAP score
    Then the score is 7.00

  Scenario: Uncovered code adds risk to its complexity score
    Given a function has complexity 4
    And the function has 0% coverage
    When I calculate its CRAP score
    Then the score is 20.00

  Scenario: Partially covered code preserves fractional scores
    Given a function has complexity 4
    And the function has 75% coverage
    When I calculate its CRAP score
    Then the score is 4.25

  Scenario: Invalid complexity values are rejected
    Given a function has a negative or non-numeric complexity value
    When I calculate its CRAP score
    Then I receive an invalid complexity error

  Scenario: Invalid coverage percentages are rejected
    Given a function has coverage below 0%, above 100%, or a non-numeric coverage value
    When I calculate its CRAP score
    Then I receive an invalid coverage error
```

## Feature: Analyze Source Strings

```gherkin
Feature: Analyze Elixir source strings
  As a developer
  I want to analyze Elixir source text
  So that I can get per-function complexity, coverage, and CRAP results

  Scenario: A function with matching coverage receives a scored result
    Given Elixir source containing a function with one if expression
    And coverage data exists for that function
    When I analyze the source string
    Then the result contains the function module, name, arity, and complexity
    And the result includes the matching coverage percentage
    And the result includes the calculated CRAP score
    And the result status is scored

  Scenario: A function without matching coverage is scored as 0% covered
    Given Elixir source containing an analyzable function
    And no coverage data exists for that function
    When I analyze the source string
    Then the result coverage percentage is 0%
    And the result includes a CRAP score based on 0% coverage
    And the result status is scored

  Scenario: Valid source with no analyzable bodies returns no results
    Given Elixir source containing only callback declarations
    When I analyze the source string
    Then the result is an empty list

  Scenario: Invalid source returns an invalid source error
    Given syntactically invalid Elixir source
    When I analyze the source string
    Then I receive an invalid source error

  Scenario: Coverage input must be a map
    Given Elixir source containing an analyzable function
    And coverage data is not a map
    When I analyze the source string
    Then I receive an invalid coverage map error

  Scenario: Invalid coverage values are surfaced on affected functions
    Given Elixir source containing an analyzable function
    And coverage data for that function is outside 0% through 100%
    When I analyze the source string
    Then the function result has an invalid coverage status
```

## Feature: Analyze Source Files

```gherkin
Feature: Analyze Elixir source files
  As a developer
  I want to analyze source files from disk
  So that file-based project scans can produce CRAP results

  Scenario: A realistic source file is analyzed with explicit coverage
    Given a readable Elixir source file with several functions
    And coverage data exists for those functions
    When I analyze the file
    Then each analyzable function receives the expected CRAP score

  Scenario: A source file with no analyzable bodies returns no results
    Given a readable Elixir source file containing only callback declarations
    When I analyze the file
    Then the result is an empty list

  Scenario: File analysis requires coverage data to be a map
    Given a readable Elixir source file
    And coverage data is not a map
    When I analyze the file
    Then I receive an invalid coverage map error

  Scenario: Unreadable files return file read errors
    Given a missing Elixir source file path
    When I analyze the file for complexity
    Then I receive the file read error

  Scenario: File paths must be strings
    Given a non-string file path
    When I analyze the file for complexity
    Then I receive an invalid path error
```

## Feature: Discover Source Files

```gherkin
Feature: Discover project source files
  As a developer
  I want the scanner to find only root project source files
  So that CRAP reports are scoped predictably

  Scenario: Root lib source files are returned in sorted order
    Given a project with multiple files under root lib
    And files under test
    And files under an umbrella child app
    When I ask for source files
    Then only root lib/**/*.ex files are returned
    And the returned paths are sorted

  Scenario: Source discovery defaults to the current working directory
    Given the current working directory contains a lib source file
    When I ask for source files without passing a root
    Then the lib source file from the current working directory is returned
```

## Feature: Scan Project Source

```gherkin
Feature: Scan project source
  As a developer
  I want source files analyzed with their paths attached
  So that reports can show where each function came from

  Scenario: Scanned files are analyzed and annotated with source paths
    Given a project root containing an analyzable lib source file
    When I scan the project
    Then the result includes each function's module, name, arity, and complexity
    And each result includes the source file path

  Scenario: Project scanning defaults to the current working directory
    Given the current working directory contains an analyzable lib source file
    When I scan without passing a root
    Then the function in that file is analyzed
    And the result includes that source file path

  Scenario: A project with no root lib source files returns no results
    Given a project root with no lib/**/*.ex files
    When I scan the project
    Then the result is an empty list

  Scenario: Source files with no analyzable bodies are skipped
    Given a project root containing only callback-only source files
    When I scan the project
    Then the result is an empty list

  Scenario: Scanning continues after files with no analyzable bodies
    Given a project root containing a callback-only source file
    And another root lib source file with an analyzable function
    When I scan the project
    Then the analyzable function is returned

  Scenario: Files with default-argument heads are analyzed
    Given a source file with a default-argument function head
    And a matching implementation clause
    When I scan the project
    Then the implemented function is analyzed with its correct arity and complexity

  Scenario: Invalid source reports the failing file
    Given a project root containing an invalid Elixir source file
    When I scan the project
    Then I receive an invalid source error paired with the file path
```

## Feature: Import Coverage Data

```gherkin
Feature: Import coverage data
  As a developer
  I want persisted coverdata converted to function coverage percentages
  So that CRAP scores can be calculated from Mix/Erlang coverage output

  Scenario: Function coverage rows are converted to percentages
    Given cover rows with covered and uncovered counts
    When I convert the rows to coverage percentages
    Then fully covered functions have 100% coverage
    And uncovered functions have 0% coverage
    And partially covered functions have proportional coverage
    And functions with no executable coverage points have 0% coverage

  Scenario: Macro coverage keys are normalized
    Given cover rows containing a MACRO-prefixed function name
    When I convert the rows to coverage percentages
    Then the macro key is stored using the plain macro name
    And the macro arity is adjusted to match the source-level macro arity

  Scenario: Exported coverdata is imported into function coverage
    Given a real exported coverdata file
    When I import the coverdata
    Then coverage is returned by module, function, and arity

  Scenario: Missing coverdata returns a clear unreadable-coverdata error
    Given a coverdata path that does not exist
    When I import the coverdata
    Then I receive an unreadable-coverdata error containing the path
```

## Feature: Calculate Function Complexity

```gherkin
Feature: Calculate function complexity
  As a developer
  I want Elixir constructs mapped to cyclomatic complexity
  So that CRAP scores reflect branching risk

  Scenario: A simple function has base complexity
    Given source containing one simple function body
    When I analyze complexity
    Then the function has complexity 1

  Scenario: Module-level conditionals can contain function definitions
    Given source with functions defined inside module-level if, else, and unless blocks
    When I analyze complexity
    Then those functions are discovered
    And each receives its own base complexity

  Scenario: Supported module name forms are resolved
    Given source with modules named by aliases, atoms, __MODULE__, or Module.concat forms
    When I analyze complexity
    Then function results use the resolved module names

  Scenario: Unsupported module-level definition list expressions are invalid
    Given source with supported definitions inside a module-level list expression
    When I analyze complexity
    Then I receive an invalid source error

  Scenario: Boolean decisions increase complexity
    Given a function body or guard containing boolean operators
    When I analyze complexity
    Then each supported boolean operator contributes to complexity

  Scenario: Branching constructs increase complexity
    Given a function containing if, unless, case, cond, with, try, for, receive, or anonymous function clauses
    When I analyze complexity
    Then the function complexity includes the supported branches, generators, filters, handlers, and clauses

  Scenario: Keyword literals are not confused with control-flow keyword blocks
    Given a function containing keyword literals near case or with expressions
    When I analyze complexity
    Then only actual control-flow blocks contribute control-flow branch counts

  Scenario: Multiple clauses of the same function are aggregated
    Given a function implemented with multiple clauses of the same name and arity
    When I analyze complexity
    Then a single function result is returned
    And its complexity is the sum of the clause complexities

  Scenario: Different functions are returned separately
    Given a module with multiple different functions
    When I analyze complexity
    Then each function receives its own result row

  Scenario: Macros are analyzable executable containers
    Given source containing defmacro or defmacrop definitions
    When I analyze complexity
    Then each macro definition receives a function result

  Scenario: Nested module bodies do not inflate enclosing function complexity
    Given a function body containing a nested defmodule
    When I analyze complexity
    Then the enclosing function's complexity excludes the nested module body

  Scenario: Non-analyzable valid source returns no results
    Given valid source containing protocols, callback-only modules, empty modules, declarations, aliases, imports, requires, attributes, structs, or uses without executable bodies
    When I analyze complexity
    Then no function results are returned

  Scenario: Declarations without matching implementations are invalid
    Given a bodyless supported definition head without a matching implementation
    When I analyze complexity
    Then I receive an invalid source error

  Scenario: Declarations implemented by a different definition kind are invalid
    Given a bodyless definition head and an implementation with a different definition kind
    When I analyze complexity
    Then I receive an invalid source error

  Scenario: Malformed supported definition heads are invalid
    Given source containing malformed def, defp, defmacro, or defmacrop heads
    When I analyze complexity
    Then I receive an invalid source error

  Scenario: Incomplete or malformed executable containers are invalid
    Given source containing incomplete defmodule, defimpl, or supported definition containers
    When I analyze complexity
    Then I receive an invalid source error

  Scenario: Invalid Elixir syntax is invalid source
    Given syntactically invalid Elixir source
    When I analyze complexity
    Then I receive an invalid source error

  Scenario: Source is parsed without being evaluated
    Given source that would raise if evaluated
    When I analyze complexity
    Then analysis succeeds from the AST without executing the source
```

## Feature: Analyze Protocol Implementations

```gherkin
Feature: Analyze protocol implementations
  As a developer
  I want defimpl blocks attributed to the protocol target modules
  So that protocol implementation functions appear in CRAP reports

  Scenario: Functions inside defimpl blocks are analyzed
    Given source containing a defimpl block with a function body
    When I analyze complexity
    Then the implementation function is returned
    And its module is the protocol implementation module

  Scenario: Keyword-form defimpl blocks are analyzed
    Given source containing a keyword-form defimpl block
    When I analyze complexity
    Then the implementation function is returned

  Scenario: Multi-target defimpl blocks produce one result per target
    Given source containing a defimpl block for multiple target modules
    When I analyze complexity
    Then each target receives an implementation function result

  Scenario: defimpl supports Module.concat protocol and target forms
    Given source containing defimpl protocol or target names built with Module.concat
    When I analyze complexity
    Then the implementation module names are resolved correctly

  Scenario: Nested implicit defimpl blocks target the current module
    Given a defimpl block nested in a module without an explicit target
    When I analyze complexity
    Then the implementation target is the current module

  Scenario: Empty defimpl options nested in a module imply the current module
    Given a nested defimpl block with empty options
    When I analyze complexity
    Then the implementation target is the current module

  Scenario: defimpl for nil is analyzed
    Given a defimpl block targeting nil
    When I analyze complexity
    Then the implementation function is returned under the protocol module

  Scenario: Local protocol declarations affect later nested defimpl resolution
    Given a nested local protocol declaration before a defimpl block
    When I analyze complexity
    Then the defimpl protocol resolves to the local protocol module

  Scenario: Local module declarations affect later nested defimpl targets
    Given a nested local module declaration before a defimpl block
    When I analyze complexity
    Then the defimpl target resolves to the local module

  Scenario: Later declarations do not retroactively change earlier defimpl resolution
    Given a defimpl appears before a local module declaration
    When I analyze complexity
    Then the earlier defimpl target is resolved without using the later declaration

  Scenario: Local aliases affect nested defimpl protocol and target resolution
    Given nested defimpl source with local aliases or grouped aliases
    When I analyze complexity
    Then protocol and target modules resolve through aliases that are in scope

  Scenario: Aliases declared after defimpl blocks do not affect earlier defimpl blocks
    Given a defimpl appears before an alias declaration
    When I analyze complexity
    Then the earlier defimpl does not use the later alias

  Scenario: Undeclared multi-part aliases remain absolute
    Given a nested defimpl with undeclared multi-part protocol or target aliases
    When I analyze complexity
    Then those aliases are treated as absolute module names

  Scenario: Unsupported defimpl shapes are invalid
    Given a defimpl block with an unsupported shape or missing required parts
    When I analyze complexity
    Then I receive an invalid source error

  Scenario: Top-level implicit defimpl blocks are invalid
    Given a top-level defimpl block without an explicit target
    When I analyze complexity
    Then I receive an invalid source error
```

## Feature: Render Reports

```gherkin
Feature: Render CRAP reports
  As a developer
  I want scored function rows rendered as a readable report
  So that I can review risky functions quickly

  Scenario: Rows combine function metadata with matching coverage
    Given discovered function metadata
    And matching coverage data
    When report rows are built
    Then each row includes file, module, function, arity, complexity, coverage, score, and status

  Scenario: Rows use 0% for missing coverage
    Given discovered function metadata
    And no matching coverage data
    When report rows are built
    Then coverage is 0%
    And the row is scored using 0% coverage

  Scenario: Invalid coverage is isolated to affected rows
    Given multiple discovered functions
    And one function has invalid coverage
    When report rows are built
    Then the invalid row has an error status and no score
    And unrelated rows are still scored

  Scenario: File paths can be normalized relative to a project root
    Given discovered functions with absolute file paths
    And a project root
    When report rows are built
    Then row file paths are relative to the project root

  Scenario: Report output is sorted and includes a summary
    Given several scored rows
    When the report is rendered
    Then the report includes a header
    And rows are ordered by risk before lower scores
    And the summary includes file count, function count, scored count, and worst score

  Scenario: High scores render without raising
    Given a scored row with a high CRAP score
    When the report is rendered
    Then the high score appears in the output

  Scenario: Failures are grouped by high score and score errors
    Given rows above the configured threshold
    And rows with score calculation errors
    When failures are collected
    Then high scores and score errors are reported separately

  Scenario: Scores equal to the threshold are allowed
    Given a row whose score equals the threshold
    When failures are collected
    Then the row is not reported as a high-score failure
```

## Feature: Run the Mix Task

```gherkin
Feature: Run mix crap
  As a developer
  I want a Mix task that prints CRAP reports and enforces thresholds
  So that CRAP analysis can run from the command line

  Scenario: Task metadata describes usage and options
    Given the mix task is loaded
    When I inspect its short documentation and module documentation
    Then the docs mention mix crap usage
    And the docs mention persisted coverage generation
    And the docs mention coverdata and max-score options
    And the docs mention root lib/**/*.ex scanning
    And the docs mention skipped non-analyzable files and missing coverage behavior

  Scenario: Help prints usage
    Given I run mix crap with --help
    Then usage text is printed
    And the output includes coverdata, max-score, and lib/**/*.ex guidance

  Scenario: Invalid max-score values are rejected
    Given I run mix crap with a non-positive or non-numeric max score
    Then the task raises an invalid max-score error

  Scenario: Unknown options are rejected
    Given I run mix crap with an unknown option
    Then the task raises an unknown option error

  Scenario: Positional arguments are rejected
    Given I run mix crap with a positional argument
    Then the task raises an unexpected argument error

  Scenario: Missing explicit coverdata is rejected
    Given a project has analyzable source files
    And I pass an explicit coverdata path that does not exist
    When I run mix crap
    Then the task raises a coverage data unreadable error

  Scenario: A project with no root source files prints guidance
    Given a project has no root lib/**/*.ex files
    When I run mix crap
    Then the task prints that no root source files were found

  Scenario: A project with only non-analyzable source files prints guidance
    Given a project has root lib source files with no analyzable function bodies
    When I run mix crap
    Then the task prints that no analyzable function bodies were found
    And it does not ask for coverage data

  Scenario: A project with any analyzable function requires coverage data
    Given a project has both non-analyzable source files and an analyzable function
    And no default coverdata exists
    When I run mix crap
    Then the task prints missing coverage guidance
    And raises a coverage data missing error

  Scenario: Invalid source fails with a source analysis error
    Given a project has an invalid root lib source file
    When I run mix crap
    Then the task raises an error naming the relative source file and analysis reason

  Scenario: Missing default coverdata prints recovery guidance
    Given a project has analyzable source files
    And cover/default.coverdata is missing
    When I run mix crap without --coverdata
    Then the task explains how to generate persisted coverage
    And explains that plain mix test --cover does not leave importable coverdata
    And raises a coverage data missing error

  Scenario: Explicit coverdata produces a report when scores pass the threshold
    Given a project has analyzable source files
    And I provide explicit coverdata
    And all rows are under the threshold
    When I run mix crap
    Then the task prints a CRAP report
    And does not print raw cover analysis chatter

  Scenario: High scores fail after printing the report
    Given a project has analyzable source files
    And I provide explicit coverdata
    And I configure a max score below a row's score
    When I run mix crap
    Then the task prints the report
    And raises a threshold failure summarizing the high score

  Scenario: Missing function coverage is scored as zero and can pass threshold
    Given a project has a function missing from coverage data
    And that function's 0% coverage CRAP score is within the threshold
    When I run mix crap
    Then the report shows 0.00% coverage
    And the row is scored
    And the task does not emit a separate missing coverage warning

  Scenario: Missing function coverage fails if its zero-coverage score exceeds threshold
    Given a project has a complex function missing from coverage data
    And that function's 0% coverage CRAP score exceeds the threshold
    When I run mix crap
    Then the report shows the zero-coverage score
    And the task raises a threshold failure summarizing the high score
```

## Feature: Property-Tested Complexity Behavior

```gherkin
Feature: Property-tested complexity behavior
  As a maintainer
  I want generated source examples to exercise supported syntax families
  So that the analyzer remains correct across many valid and invalid shapes

  Scenario: Generated valid function definitions match model-derived complexity
    Given generated valid functions with supported definition kinds, arities, guards, and bodies
    When each source example is analyzed
    Then the analyzer returns the model-derived result

  Scenario: Generated valid branching bodies are scored consistently
    Given generated valid functions using boolean operators, unless, cond, try, for, receive, anonymous functions, and shallow nested constructs
    When each source example is analyzed
    Then the calculated complexity matches the generated model

  Scenario: Generated bodyless declarations are valid only with matching implementations
    Given generated declaration heads
    When matching implementation clauses exist
    Then only the implementation contributes result rows
    When matching implementation clauses are missing or use a different definition kind
    Then analysis returns invalid source

  Scenario: Generated malformed definitions and defimpl shapes are invalid
    Given generated malformed supported definitions or unsupported defimpl forms
    When each source example is analyzed
    Then analysis returns invalid source

  Scenario: Generated non-analyzable source returns no results
    Given generated valid source with no executable analyzable bodies
    When each source example is analyzed
    Then analysis returns an empty result list

  Scenario: Generated defimpl forms resolve expected protocol target rows
    Given generated defimpl blocks with single targets, multiple targets, Module.concat forms, nested implicit targets, aliases, grouped aliases, local protocols, and local modules
    When each source example is analyzed
    Then implementation rows are attributed to the expected protocol target modules

  Scenario: Generated nested and atom-named modules resolve expected result modules
    Given generated nested modules and atom-named modules
    When each source example is analyzed
    Then function rows use the expected resolved module names

  Scenario: Generated invalid module names are rejected
    Given generated invalid defmodule names
    When each source example is analyzed
    Then analysis returns invalid source
```

## Notes on Scope

Some tests are intentionally closer to parser and AST edge cases than end-user workflows. They are included here because they still exercise public APIs (`ExCrap.Complexity.from_string/1`, `ExCrap.Scanner.analyze/1`, `ExCrap.Report.rows/3`, `Mix.Tasks.Crap.run/1`) and define externally observable behavior.
