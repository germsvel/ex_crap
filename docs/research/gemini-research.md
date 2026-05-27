# Research Sources for Project CRAP.ex

This document compiles the essential literature and technical resources required for the research and development of the **CRAP.ex** library.

---

## 1. Theoretical Foundations & The CRAP Metric
* **Original 2007 Concept (Alberto Savoia):** [The Code C.R.A.P. Metric Hits the Fan](https://www.artima.com/weblogs/viewpost.jsp?thread=215899)  
    *Primary source for the mathematical formula and the initial "30" threshold.*
* **Google Testing Blog (2011 Update):** [This Code is CRAP](https://testing.googleblog.com/2011/02/this-code-is-crap.html)  
    *Reflections on the metric's usage at scale and refinements by Alberto Savoia.*
* **Cyclomatic Complexity (Thomas J. McCabe, 1976):** [A Complexity Measure (IEEE Transactions on Software Engineering)](https://ieeexplore.ieee.org/document/1702388)  
    *The foundational paper defining cyclomatic complexity ($v(G)$) via graph theory.*

---

## 2. Elixir Ecosystem Tools (Prior Art)
* **Credo (Static Analysis):** [GitHub Repository - rrrene/credo](https://github.com/rrrene/credo)  
    *Reference for AST traversal and calculating complexity in Elixir.*
* **ExCoveralls (Test Coverage):** [GitHub Repository - parroty/excoveralls](https://github.com/parroty/excoveralls)  
    *Reference for integrating coverage reporting into the Mix ecosystem.*
* **Sobelow (Security Analysis):** [GitHub Repository - sobelow/sobelow](https://github.com/sobelow/sobelow)  
    *Reference for specialized CLI tools, configuration handling, and CI exit-code logic.*

---

## 3. Reference Implementations in Other Languages
* **CRAP4Java (Uncle Bob Martin):** [GitHub Repository - unclebob/crap4java](https://github.com/unclebob/crap4java)  
    *A standalone CRAP metric tool for Java projects.*
* **GMetrics (Groovy/Java):** [GMetrics CRAP Metric Documentation](https://dx42.github.io/gmetrics/metrics/CrapMetric.html)  
    *Details on how other tools handle the Cobertura/JaCoCo coverage integration.*

---

## 4. Elixir & Erlang Internals
* **Erlang `:cover` Module:** [Official Erlang Documentation](https://www.erlang.org/doc/man/cover.html)  
    *The low-level module for statement coverage analysis.*
* **Elixir `Code` Module:** [HexDocs - Code](https://hexdocs.pm/elixir/Code.html)  
    *Essential for AST manipulation, quoting, and unquoting.*
* **Elixir `Mix` Task Documentation:** [HexDocs - Mix.Task](https://hexdocs.pm/mix/Mix.Task.html)  
    *Guidelines for creating custom Mix tasks for local and CI execution.*

---

## 5. Gmail Search Reference (Internal Data)
* **Search Query:** `CRAP.ex research project`  
    *(Use this query to locate all internal discussions and communications related to this brief.)*
