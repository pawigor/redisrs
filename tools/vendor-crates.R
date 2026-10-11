# Vendors the Rust crates into src/rust/vendor.tar.xz and makes the archive small
# enough for CRAN. Run it from the package root after any change to Cargo.toml
# or Cargo.lock:
#
#   Rscript tools/vendor-crates.R
#
# It does what rextendr::vendor_crates() does, plus three size steps:
# 1. Windows import libraries are kept only for x86_64-pc-windows-gnu, the only
#    Windows target that CRAN builds (Rtools). Other targets get an empty lib/.
# 2. windows-sys modules that no enabled feature uses are deleted. The keep list
#    comes from `cargo tree`, so it follows dependency updates.
# 3. The archive uses xz -9e.
# Each changed crate gets an empty file list in .cargo-checksum.json, so that
# cargo accepts the changed sources.

windows_target <- "x86_64-pc-windows-gnu"
keep_import_libs <- "windows_x86_64_gnu"

run <- function(cmd, args, ...) {
  out <- system2(cmd, args, stdout = TRUE, ...)
  status <- attr(out, "status")
  if (!is.null(status) && status != 0) stop(cmd, " failed with status ", status)
  out
}

clear_checksums <- function(crate_dir) {
  path <- file.path(crate_dir, ".cargo-checksum.json")
  json <- readLines(path, warn = FALSE)
  pkg <- regmatches(json, regexpr('"package":"[0-9a-f]+"', json))
  writeLines(paste0('{"files":{},', pkg, "}"), path)
}

crate_version <- function(crate_dir) {
  toml <- readLines(file.path(crate_dir, "Cargo.toml"), warn = FALSE)
  sub('^version = "(.*)"$', "\\1", grep("^version = ", toml, value = TRUE)[1])
}

used_windows_sys_modules <- function(version) {
  tree <- run("cargo", c(
    "tree", "-q", "-e", "features", "--target", windows_target,
    "-i", paste0("windows-sys@", version)
  ))
  features <- unique(regmatches(tree, regexpr('windows-sys feature "[A-Za-z0-9_]+"', tree)))
  features <- sub('windows-sys feature "(.*)"', "\\1", features)
  gsub("_", "/", setdiff(features, "default"))
}

prune_windows_sys <- function(crate_dir) {
  keep <- used_windows_sys_modules(crate_version(crate_dir))
  root <- file.path(crate_dir, "src", "Windows")
  entries <- list.files(root, recursive = TRUE, include.dirs = TRUE)
  modules <- sub("(/mod)?\\.rs$", "", entries)
  # A module stays if a used feature is the module itself or lies below it.
  used <- vapply(modules, function(m) any(keep == m | startsWith(keep, paste0(m, "/"))), TRUE)
  # mod.rs files belong to their directory, which is checked on its own.
  drop <- entries[!used & !grepl("(^|/)mod\\.rs$", entries)]
  unlink(file.path(root, drop), recursive = TRUE)
  message("windows-sys ", crate_version(crate_dir), ": kept ", length(keep), " feature modules")
  clear_checksums(crate_dir)
}

strip_import_libs <- function(crate_dir) {
  libs <- list.files(file.path(crate_dir, "lib"), full.names = TRUE)
  if (length(libs) == 0L) return(invisible())
  unlink(libs)
  clear_checksums(crate_dir)
}

old <- setwd(file.path("src", "rust"))
on.exit(setwd(old))

unlink("vendor", recursive = TRUE)
config <- run("cargo", c("vendor", "--locked", "--manifest-path", "Cargo.toml"), stderr = FALSE)
writeLines(config[nzchar(config)], "vendor-config.toml")

crates <- list.dirs("vendor", recursive = FALSE)
for (dir in crates[grepl("^windows_", basename(crates)) & basename(crates) != keep_import_libs]) {
  strip_import_libs(dir)
}
for (dir in crates[grepl("^windows-sys(-[0-9.]+)?$", basename(crates))]) {
  prune_windows_sys(dir)
}

unlink("vendor.tar.xz")
Sys.setenv(XZ_OPT = "-9e")
invisible(run("tar", c(
  "--sort=name", "--mtime=@0", "--owner=0", "--group=0", "--numeric-owner",
  "--no-xattrs", "-cJf", "vendor.tar.xz", "vendor"
)))
unlink("vendor", recursive = TRUE)
message("vendor.tar.xz: ", format(file.size("vendor.tar.xz"), big.mark = ","), " bytes")
