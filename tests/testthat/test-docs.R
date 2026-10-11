test_that("every exported function documents its value and has an example", {
  root <- test_path("..", "..")
  skip_if_not(dir.exists(file.path(root, "man")), "man/ is not available")
  db <- tools::Rd_db(dir = root)
  exports <- getNamespaceExports("redisrs")
  for (rd in db) {
    tags <- vapply(rd, function(x) attr(x, "Rd_tag"), "")
    aliases <- unlist(rd[tags == "\\alias"])
    if (!any(aliases %in% exports)) next
    name <- unlist(rd[tags == "\\name"])
    expect_true("\\value" %in% tags, label = paste(name, "has \\value"))
    expect_true("\\examples" %in% tags, label = paste(name, "has \\examples"))
  }
})
