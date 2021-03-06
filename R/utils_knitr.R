knitr_deps <- function(path) {
  expr <- knitr_expr(path)
  counter <- counter_init()
  walk_expr(expr, counter)
  counter_get_names(counter)
}

knitr_expr <- function(path) {
  tryCatch(
    parse(text = knitr_lines(path)),
    error = function(e) {
      throw_validate(
        "Could not parse knitr report ",
        path,
        " to detect dependencies: ",
        conditionMessage(e)
      )
    }
  )
}

knitr_lines <- function(path) {
  handle <- basename(tempfile())
  connection <- textConnection(handle, open = "w", local = TRUE)
  on.exit(close(connection))
  withr::with_options(
    new = list(knitr.purl.inline = TRUE),
    code = knitr::knit(path, output = connection, tangle = TRUE, quiet = TRUE)
  )
  textConnectionValue(connection)
}

walk_expr <- function(expr, counter) {
  if (!length(expr)) {
    return()
  } else if (is.call(expr)) {
    walk_call(expr, counter)
  } else if (typeof(expr) == "closure") {
    walk_expr(formals(expr), counter = counter)
    walk_expr(body(expr), counter = counter)
  } else if (is.pairlist(expr) || is.recursive(expr)) {
    lapply(expr, walk_expr, counter = counter)
  }
}

walk_call <- function(expr, counter) {
  name <- safe_deparse(expr[[1]], backtick = FALSE)
  if (name %in% paste0(c("", "targets::", "targets:::"), "tar_load")) {
    register_load(expr, counter)
  }
  if (name %in% paste0(c("", "targets::", "targets:::"), "tar_read")) {
    register_read(expr, counter)
  }
  lapply(expr, walk_expr, counter = counter)
}

register_load <- function(expr, counter) {
  expr <- match.call(targets::tar_load, as.call(expr))
  names <- all.vars(expr$names, functions = FALSE, unique = TRUE)
  counter_set_names(counter, names)
}

register_read <- function(expr, counter) {
  expr <- match.call(targets::tar_read, as.call(expr))
  names <- all.vars(expr$name, functions = FALSE, unique = TRUE)
  counter_set_names(counter, names)
}
