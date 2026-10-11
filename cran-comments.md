## R CMD check results

0 errors | 0 warnings | 1 note

* This is a new release.

## Rust

* The package uses Rust through 'extendr'. All crates are vendored in `src/rust/vendor.tar.xz`, and the build runs `cargo` with `--offline` and `-j 2`.
* The build stops with a clear message if `rustc` is older than 1.88, the minimum version that 'redis-rs' needs.
* The authors of the vendored crates are listed in `LICENSE.note` and in `Authors@R` as `cph`.

## Tests

* The integration tests need Redis servers. They skip on CRAN with `skip_on_cran()`. The unit tests for argument encoding, errors and IAM token signatures run everywhere.

## Test environments

(Fill in from Step 9.)
