## Resubmission

This is a resubmission. In response to the review:

* All acronyms in the Description are now written out: Transport Layer Security (TLS), Amazon Web Services (AWS), Identity and Access Management (IAM).
* The Description now explains the package functionality in more detail: connection types, commands and pipelines, reply conversion, storage of R objects, 'ElastiCache' token signing and reconnect behaviour.
* Single quotes are now used only around software names ('Redis', 'Valkey', 'Rust', 'redis-rs', 'ElastiCache'). They were removed from 'AWS'.

## R CMD check results

0 errors | 0 warnings | 1 note

* This is a new release.
* The NOTE may list "IAM", "TLS" and "AWS" as possibly misspelled words. They are abbreviations, written out in the Description.

## Rust

* The package uses Rust through 'extendr'. All crates are vendored in `src/rust/vendor.tar.xz`, and the build runs `cargo` with `--offline` and `-j 2`.
* The build stops with a clear message if `rustc` is older than 1.88, the minimum version that 'redis-rs' needs.
* The authors of the vendored crates are listed in `LICENSE.note` and in `Authors@R` as `cph`.

## Tests

* The integration tests need Redis servers. They skip on CRAN with `skip_on_cran()`. The unit tests for argument encoding, errors and IAM token signatures run everywhere.

## Test environments

* win-builder, R-devel (2026-10-09 r90655 ucrt) and R-release 4.6.1: 1 NOTE (new submission, the words above). This was the build before the last fixes. These fixes changed R code and two crate versions (rustls, rustls-webpki) and passed the checks on GitHub Actions.
* R-hub v2, R-devel on Linux, macOS arm64 and Windows: OK.
* GitHub Actions, R-release on Ubuntu, macOS and Windows: OK.
* GitHub Actions, offline install of the built tarball on Ubuntu with no network: OK.
* Local Arch Linux, R 4.6.1: OK.

The macOS builder (mac.r-project.org) returned HTTP 502, so it is not in this list.
