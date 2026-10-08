# Changelog

## 0.1.1 - 2026-10-08

### Fixes

- fix: handle nil-argument with expressions during complexity analysis [b0eeab3]
- fix: prevent analysis crashes on __MODULE__ aliases and non-list branch args (#5) [d928c89]

[b0eeab3]: https://github.com/germsvel/ex_crap/commit/b0eeab3
[d928c89]: https://github.com/germsvel/ex_crap/commit/d928c89
[9963e57]: https://github.com/germsvel/ex_crap/commit/9963e57
[ae140eb]: https://github.com/germsvel/ex_crap/commit/ae140eb

## 0.1.0 - 2026-06-15

Initial release with CRAP score calculation, source analysis APIs, the `mix crap` task, and a coverage import workflow for persisted Mix/Erlang coverdata.
