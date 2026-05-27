I want to create an Elixir library that calculates C.R.A.P. scores
(combining test coverage and cyclomatic complexity). The library should be able
to be executed with `mix` to be run locally and in CI environments. And it
should have the ability to give me a score. If the score is beyond a certain
level, we should be able to fail CI (same as is possible with tools like Credo).
