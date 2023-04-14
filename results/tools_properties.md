What can we learn from the results on the datasets:
* `multi` - synthesized from requiring 2 up to 10 TX, with varying fuzzing
  roadblocks with `require({X} {OP} {Y});` constraints
* `complex` - 5, 7, and 10 transactions required with a multitude of different
  analysis hurdles
* `justlen` - use array operations (push, pop, double, halve, clear, ...) to
  reach a certain array length.
* `multi_simple` - requires finding the right ordering of 10 function calls

* Confuzzius (hybrid concolic fuzzing)
    * `-` very bad at stitching transaction sequences
        * worst in `multi_simple`
        * worst in `justlen`, but does not fail
    * `-` does not solve complex path constraints
        * performs poorly on `multi` (third worst)
* echidna2 (fuzzing)
    * `+` very good at stitching transaction sequences
        * performs well on `justlen` (second best) and `multi_simple` (best)
    * `-` does not solve complex path constraints
        * performs poorly on `multi` (second worst)
    * `+` relatively lightweight with quick startup
* EF/CF (fuzzing with input-to-state + grammar + auto-dict)
    * `+` good at stitching transaction sequences
        * third place shared with manticore on `multi_simple`
        * best in the `justlen` benchmark
    * `+` solves all types of path constraints
        * only tool to solve `complex` with 9 TX
        * comparable performance on `multi` to symbolic tools (manticore,
          verismart) and much better than all other fuzzers
    * `-` high startup cost that amortizes over longer fuzzing runs
* EthBMC
    * `-` fails for any TX sequence > 3 due to a bug.
* maian (concolic)
    * `+` very good at stitching transaction sequences
        * performs well on `multi` (best) and `multi_simple` (second best)
    * `-` has some trouble with state explosion (e.g., loops, arrays, etc.)
        * performs bad in `complex`, but manages up to 7 TX
        * fails in `justlen` with anything but the easiest length of 8
    * `+` very good at solving integer-based path constraints
    * `+` relatively lightweight with quick startup
* manticore (symbolic)
    * `+` can also stitch long transaction sequences
        * third place shared with EF/CF on `multi_simple`
    * `-` but only if they do not contain state explosion (e.g., loops, arrays, etc.)
        * fails on `justlen` and `complex`
    * `+` good at solving integer-based path constraints
        * works well up to 9 TX on `multi`
* Smartian (hybrid concolic fuzzing)
    * `-` very bad at stitching transaction sequences
        * second worst in `multi_simple`
        * second worst in `justlen`, but does not fail
    * `-` does not solve complex path constraints
        * performs poorly on `multi` (worst)
* teether (concolic + data-flow guidance?)
    * `-` generally not so good, except for somewhat reasonable performance on
      `multi`
* verismart (symbolic)
    * `+` can also stitch long transaction sequences
        * fourth place on `multi_simple`, still way better than
          smartian/confuzzius
        * second place on `multi`, similar perf to manticore and EF/CF
    * `-` has some trouble with state explosion (e.g., loops, arrays, etc.)
        * performs bad in `complex`, but manages up to 7 TX
        * fails in `justlen` with anything but the easiest length of 8
    * `+` good at solving integer-based path constraints
        * works well up to 9 TX on `multi`


