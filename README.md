# Sometimes Assert

This repo is highly inspired by the docs from Antithesis:
https://antithesis.com/docs/best_practices/sometimes_assertions/

A minimal proof of concept of this is demonstrated for Zig.

## Details
Zig is lazy, and so am I. If a sometimes assert isn't hit, then it doesn't affect test results at all.
This limitation can probably be bypassed by tying into the build system more deeply, or even by using
server mode for the test runner.

## Example Output

```
zig build test -Denable_sometimes=true
simple test (0.11ms)
test 1 myFunc (0.00ms)
test 2 myFunc (0.00ms)
Sometimes assert was always false: main.zig:18:23
3 of 3 tests passed
1 sometimes assertion not covered

Slowest 3 tests:
  0.00ms        test 2 myFunc
  0.00ms        test 1 myFunc
  0.11ms        simple test
```