#' Get all data from a rectangular worksheet as a tbl_df or data.frame
#'
#' This function consumes data using the \code{exportcsv} links found in the
#' worksheets feed. Don't be spooked by the "csv" thing -- the data is NOT
#' actually written to file during this process. In fact, this is much, much
#' faster than consumption via the list feed. Unlike using the list feed, this
#' method does not assume that the populated cells form a neat rectangle. All
#' cells within the "data rectangle", i.e. spanned by the maximal row and column
#' extent of the data, are returned. Empty cells will be assigned NA. Also, the
#' header row, potentially containing column or variable names, is not
#' transformed/mangled, as it is via the list feed. If you want all of your
#' data, this is the fastest way to get it.
#'
#' @inheritParams get_via_lf
#' @param ... further arguments to be passed to \code{\link{read.csv}} or,
#'   ultimately, \code{\link{read.table}}; note that \code{\link{read.csv}} is
#'   called with \code{stringsAsFactors = FALSE}, which is the blanket policy
#'   within \code{googlesheets} re: NOT converting character data to factor
#'
#' @family data consumption functions
#'
#' @return a tbl_df
#'
#' @examples
#' \dontrun{
#' gap_ss <- gs_gap() # register the Gapminder example sheet
#' oceania_csv <- get_via_csv(gap_ss, ws = "Oceania")
#' str(oceania_csv)
#' oceania_csv
#' }
#' @export
get_via_csv <- function(ss, ws = 1, ..., verbose = TRUE) {

  stopifnot(ss %>% inherits("googlesheet"))

  this_ws <- gs_ws(ss, ws, verbose)

  if(is.null(this_ws$exportcsv)) {
    stop(paste("This appears to be an \"old\" Google Sheet. The old Sheets do",
               "not offer the API access required by this function.",
               "Consider converting it from an old Sheet to a new Sheet.",
               "Or use another data consumption function, such as get_via_lf()",
               "or get_via_cf(). Or use gs_download() to export it to a local",
               "file and then read it into R."))
  }

  req <- gsheets_GET(this_ws$exportcsv, to_xml = FALSE)

  if(req$headers$`content-type` != "text/csv") {
    stop1 <- "Cannot access this sheet via csv."
    stop2 <- "Are you sure you have permission to access this Sheet?"
    stop3 <- "If this Sheet is supposed to be public, make sure it is \"published to the web\", which is NOT the same as \"public on the web\"."
    stop4 <- sprintf("status_code: %s", req$status_code)
    stop5 <- sprintf("content-type: %s", req$headers$`content-type`)
    stop(paste(stop1, stop2, stop3, stop4, stop5, sep = "\n"))
  }

  if(httr::content(req) %>% is.null()) {
    sprintf("Worksheet \"%s\" is empty.", this_ws$ws_title) %>%
      message()
    dplyr::data_frame()
  } else {
    ## for empty cells, numeric columns returned as NA vs "" for chr
    ## columns so set all "" to NA
    req %>%
      httr::content(type = "text/csv", na.strings = c("", "NA"),
                    encoding = "UTF-8", ...) %>%
      dplyr::as_data_frame()
  }
}

#' Get data from a rectangular worksheet as a tbl_df or data.frame
#'
#' Gets data via the list feed, which assumes populated cells form a neat
#' rectangle. The list feed consumes data row by row. First row regarded as
#' header row of variable or column names. The related function,
#' \code{get_via_csv}, also returns data from a neat rectangle of cells, so you
#' probably want to use that (unless you are dealing with an "old" Google Sheet,
#' which \code{get_via_csv} does not support).
#'
#' @note When you use the listfeed, the Sheets API transforms the variable or
#'   column names like so: 'The column names are the header values of the
#'   worksheet lowercased and with all non-alpha-numeric characters removed. For
#'   example, if the cell A1 contains the value "Time 2 Eat!" the column name
#'   would be "time2eat".' If this is intolerable to you, consume the data via
#'   the cell feed or csv download. Or, at least, consume the first row via the
#'   cell feed and manually restore the variable names post hoc.
#'
#' @param ss a registered Google spreadsheet
#' @param ws positive integer or character string specifying index or title,
#'   respectively, of the worksheet to consume
#' @param verbose logical; do you want informative messages?
#'
#' @family data consumption functions
#'
#' @return a tbl_df
#'
#' @examples
#' \dontrun{
#' gap_ss <- gs_gap() # register the Gapminder example sheet
#' oceania_lf <- get_via_lf(gap_ss, ws = "Oceania")
#' str(oceania_lf)
#' oceania_lf
#' }
#'
#' @export
get_via_lf <- function(ss, ws = 1, verbose = TRUE) {

  stopifnot(ss %>% inherits("googlesheet"))

  this_ws <- gs_ws(ss, ws, verbose)
  req <- gsheets_GET(this_ws$listfeed)

  ns <- xml2::xml_ns_rename(xml2::xml_ns(req$content), d1 = "feed")

  var_names <- req$content %>%
    xml2::xml_find_all("(//feed:entry)[1]", ns) %>%
    xml2::xml_find_all(".//gsx:*", ns) %>%
    xml2::xml_name()

  values <- req$content %>%
    xml2::xml_find_all("//feed:entry//gsx:*", ns) %>%
    xml2::xml_text()

  dat <- matrix(values, ncol = length(var_names), byrow = TRUE,
                dimnames = list(NULL, var_names)) %>%
    ## convert to integer, numeric, etc. but w/ stringsAsFactors = FALSE
    ## empty cells returned as empty string ""
    plyr::alply(2, type.convert, na.strings = c("NA", ""), as.is = TRUE) %>%
    ## get rid of attributes that are non-standard for tbl_dfs or data.frames
    ## and that are an artefact of the above (specifically, I think, the use of
    ## alply?); if I don't do this, the output is fugly when you str() it
    `attr<-`("split_type", NULL) %>%
    `attr<-`("split_labels", NULL) %>%
    `attr<-`("dim", NULL) %>%
    ## for some reason removing the non-standard dim attributes clobbers the
    ## variable names, so those must be restored
    `names<-`(var_names) %>%
    ## convert to data.frame (tbl_df, actually)
    dplyr::as_data_frame()

  dat

}

#' Create a data.frame of the non-empty cells in a rectangular region of a
#' worksheet
#'
#' This function consumes data via the cell feed, which, as the name suggests,
#' retrieves data cell by cell. No attempt is made here to shape the returned
#' data, but you can do that with \code{\link{reshape_cf}} and
#' \code{\link{simplify_cf}}). The output data.frame of \code{get_via_cf} will
#' have one row per cell.
#'
#' Use the limits, e.g. min_row or max_col, to delineate the rectangular region
#' of interest. You can specify any subset of the limits or none at all. If
#' limits are provided, validity will be checked as well as internal consistency
#' and compliance with known extent of the worksheet. If no limits are provided,
#' all cells will be returned but realize that \code{\link{get_via_csv}} and
#' \code{\link{get_via_lf}} are much faster ways to consume data from a
#' rectangular worksheet.
#'
#' Empty cells, even if "embedded" in a rectangular region of populated cells,
#' are not normally returned by the cell feed. This function won't return them
#' either when \code{return_empty = FALSE} (default), but will if you set
#' \code{return_empty = TRUE}. If you don't specify any limits AND you set
#' \code{return_empty = TRUE}, you could be in for several minutes wait, as the
#' feed will return all cells, which defaults to 1000 rows and 26 columns.
#'
#' @inheritParams get_via_lf
#' @param min_row positive integer, optional
#' @param max_row positive integer, optional
#' @param min_col positive integer, optional
#' @param max_col positive integer, optional
#' @param limits list, with named components holding the min and max for rows
#'   and columns; intended primarily for internal use
#' @param return_empty logical; indicates whether to return empty cells
#' @param return_links logical; indicates whether to return the edit and self
#'   links (used internally in cell editing workflow)
#'
#' @examples
#' \dontrun{
#' gap_ss <- gs_gap() # register the Gapminder example sheet
#' get_via_cf(gap_ss, "Asia", max_row = 4)
#' reshape_cf(get_via_cf(gap_ss, "Asia", max_row = 4))
#' reshape_cf(get_via_cf(gap_ss, "Asia",
#'                       limits = list(max_row = 4, min_col = 3)))
#' }
#' @family data consumption functions
#'
#' @export
get_via_cf <-
  function(ss, ws = 1,
           min_row = NULL, max_row = NULL, min_col = NULL, max_col = NULL,
           limits = NULL, return_empty = FALSE, return_links = FALSE,
           verbose = TRUE) {

    stopifnot(ss %>% inherits("googlesheet"))

    this_ws <- gs_ws(ss, ws, verbose)

    if(is.null(limits)) {
      limits <- list("min-row" = min_row, "max-row" = max_row,
                     "min-col" = min_col, "max-col" = max_col)
    } else{
      names(limits) <- names(limits) %>% stringr::str_replace("_", "-")
    }
    limits <- limits %>%
      validate_limits(this_ws$row_extent, this_ws$col_extent)

    query <- limits
    if(return_empty) {
      ## the return-empty parameter is not documented in current sheets API, but
      ## is discussed in older internet threads re: the older gdata API; so if
      ## this stops working, consider that they finally stopped supporting this
      ## query parameter
      query <- query %>% c(list("return-empty" = "true"))
    }

    ## to prevent appending of "?=" to url when query elements are all NULL
    if(query %>% unlist() %>% is.null()) {
      query <- NULL
    }

    req <- gsheets_GET(this_ws$cellsfeed, query = query)

    ns <- xml2::xml_ns_rename(xml2::xml_ns(req$content), d1 = "feed")

    x <- req$content %>%
      xml2::xml_find_all("//feed:entry", ns)

    if(length(x) == 0L) {
      # the pros outweighed the cons re: setting up a zero row data.frame that,
      # at least, has the correct variables
      x <- dplyr::data_frame(cell = character(),
                             cell_alt = character(),
                             row = integer(),
                             col = integer(),
                             cell_text = character(),
                             edit_link = character(),
                             cell_id = character())
    } else {
      edit_links <- x %>%
        xml2::xml_find_all(".//feed:link[@rel='edit']", ns) %>%
        xml2::xml_attr("href")

      ## this will be true if user does not have permission to edit
      if(length(edit_links) == 0) {
        edit_links <- NA
      }

      x <- dplyr::data_frame_(
        list(cell = ~ xml2::xml_find_all(x, ".//feed:title", ns) %>%
               xml2::xml_text(),
             edit_link = ~ edit_links,
             cell_id = ~ xml2::xml_find_all(x, ".//feed:id", ns) %>%
               xml2::xml_text(),
             cell_alt = ~ cell_id %>% basename(),
             row = ~ xml2::xml_find_all(x, ".//gs:cell", ns) %>%
               xml2::xml_attr("row") %>%
               as.integer(),
             col = ~ xml2::xml_find_all(x, ".//gs:cell", ns) %>%
               xml2::xml_attr("col") %>%
               as.integer(),
             cell_text = ~ xml2::xml_find_all(x, ".//gs:cell", ns) %>%
               xml2::xml_text()
        ))
      # see issue #19 about all the places cell data is (mostly redundantly)
      # stored in the XML, such as: content_text = x$content$text,
      # cell_inputValue = x$cell$.attrs["inputValue"], cell_numericValue =
      # x$cell$.attrs["numericValue"], when/if we think about formulas
      # explicitly, we will want to come back and distinguish between inputValue
      # and numericValue
    }

    x <- x %>%
      dplyr::select_(~ cell, ~ cell_alt, ~ row, ~ col, ~ cell_text,
                     ~ edit_link, ~ cell_id) %>%
      dplyr::as_data_frame()

    attr(x, "ws_title") <- this_ws$ws_title

    if(return_links) {
      x
    } else {
      x %>%
        dplyr::select_(~ -edit_link, ~ -cell_id)
    }

  }

#' Get data from a row or range of rows
#'
#' Get data via the cell feed for one row or for a range of rows.
#'
#' @inheritParams get_via_lf
#' @param row vector of positive integers, possibly of length one, specifying
#'   which rows to retrieve; only contiguous ranges of rows are supported, i.e.
#'   if \code{row = c(2, 8)}, you will get rows 2 through 8
#'
#' @family data consumption functions
#' @seealso \code{\link{reshape_cf}} to reshape the retrieved data into a more
#'   usable data.frame
#'
#' @examples
#' \dontrun{
#' gap_ss <- gs_gap() # register the Gapminder example sheet
#' get_row(gap_ss, "Europe", row = 1)
#' simplify_cf(get_row(gap_ss, "Europe", row = 1))
#' }
#'
#' @export
get_row <- function(ss, ws = 1, row, verbose = TRUE) {
  get_via_cf(ss, ws, min_row = min(row), max_row = max(row), verbose = verbose)
}

#' Get data from a column or range of columns
#'
#' Get data via the cell feed for one column or for a range of columns.
#'
#' @inheritParams get_via_lf
#' @param col vector of positive integers, possibly of length one, specifying
#'   which columns to retrieve; only contiguous ranges of columns are supported,
#'   i.e. if \code{col = c(2, 8)}, you will get columns 2 through 8
#'
#' @family data consumption functions
#' @seealso \code{\link{reshape_cf}} to reshape the retrieved data into a more
#'   usable data.frame
#'
#' @examples
#' \dontrun{
#' gap_ss <- gs_gap() # register the Gapminder example sheet
#' get_col(gap_ss, "Oceania", col = 1:2)
#' reshape_cf(get_col(gap_ss, "Oceania", col = 1:2))
#' }
#'
#' @export
get_col <- function(ss, ws = 1, col, verbose = TRUE) {
  get_via_cf(ss, ws, min_col = min(col), max_col = max(col), verbose = verbose)
}

#' Get data from a cell or range of cells
#'
#' Get data via the cell feed for a rectangular range of cells
#'
#' @inheritParams get_via_lf
#' @param range single character string specifying which cell or range of cells
#'   to retrieve; positioning notation can be either "A1" or "R1C1"; a single
#'   cell can be requested, e.g. "B4" or "R4C2" or a rectangular range can be
#'   requested, e.g. "B2:D4" or "R2C2:R4C4"
#'
#' @family data consumption functions
#' @seealso \code{\link{reshape_cf}} to reshape the retrieved data into a more
#'   usable data.frame
#'
#' @examples
#' \dontrun{
#' gap_ss <- gs_gap() # register the Gapminder example sheet
#' get_cells(gap_ss, "Europe", range = "B3:D7")
#' simplify_cf(get_cells(gap_ss, "Europe", range = "A1:F1"))
#' }
#'
#' @export
get_cells <- function(ss, ws = 1, range, verbose = TRUE) {

  limits <- range %>%
    cellranger::as.cell_limits() %>%
    limit_list()
  get_via_cf(ss, ws, limits = limits, verbose = verbose)

}

#' Reshape cell-level data and convert to data.frame
#'
#' @param x a data.frame returned by \code{get_via_cf()}
#' @param header logical indicating whether first row should be taken as
#'   variable names
#'
#' @family data consumption functions
#'
#' @examples
#' \dontrun{
#' gap_ss <- gs_gap() # register the Gapminder example sheet
#' get_via_cf(gap_ss, "Asia", max_row = 4)
#' reshape_cf(get_via_cf(gap_ss, "Asia", max_row = 4))
#' }
#' @export
reshape_cf <- function(x, header = TRUE) {

  limits <- x %>%
    dplyr::summarise_each_(dplyr::funs(min, max), list(~ row, ~ col))
  all_possible_cells <-
    with(limits,
         expand.grid(row = row_min:row_max, col = col_min:col_max)) %>%
    dplyr::as.tbl()
  suppressMessages(
    x_augmented <- all_possible_cells %>% dplyr::left_join(x)
  )
  ## tidyr::spread(), used below, could do something similar as this join, but
  ## it would handle completely missing rows and columns differently; still
  ## thinking about this

  if(header) {

    if(x_augmented$row %>% dplyr::n_distinct() < 2) {
      message("No data to reshape!")
      if(header) {
        message("Perhaps retry with `header = FALSE`?")
      }
      return(NULL)
    }

    row_one <- x_augmented %>%
      dplyr::filter_(~ (row == min(row))) %>%
      dplyr::mutate_(cell_text = ~ ifelse(cell_text == "", NA, cell_text))
    var_names <- ifelse(is.na(row_one$cell_text),
                        stringr::str_c("C", row_one$col),
                        row_one$cell_text) %>% make.names()
    x_augmented <- x_augmented %>%
      dplyr::filter_(~ row > min(row))
  } else {
    var_names <- limits$col_min:limits$col_max %>% make.names()
  }

  x_augmented %>%
    dplyr::select_(~ row, ~ col, ~ cell_text) %>%
    tidyr::spread_("col", "cell_text", convert = TRUE) %>%
    dplyr::select_(~ -row) %>%
    stats::setNames(var_names)
}

#' Simplify data from the cell feed
#'
#' In some cases, you might not want to convert the data retrieved from the cell
#' feed into a data.frame via \code{\link{reshape_cf}}. You might prefer it as
#' an atomic vector. That's what this function does. Note that, unlike
#' \code{\link{reshape_cf}}, empty cells will NOT necessarily appear in this
#' result. By default, the API does not transmit data for these cells;
#' \code{googlesheets} inserts these cells in \code{\link{reshape_cf}} because
#' it is necessary to give the data rectangular shape. In contrast, empty cells
#' will only appear in the output of \code{simplify_cf} if they were already
#' present in the data from the cell feed, i.e. if the original call to
#' \code{\link{get_via_cf}} had argument \code{return_empty} set to \code{TRUE}.
#'
#' @inheritParams reshape_cf
#' @param convert logical, indicating whether to attempt to convert the result
#'   vector from character to something more appropriate, such as logical,
#'   integer, or numeric; if TRUE, result is passed through \code{type.convert};
#'   if FALSE, result will be character
#' @param as.is logical, passed through to the \code{as.is} argument of
#'   \code{type.convert}
#' @param notation character; the result vector will have names that reflect
#'   which cell the data came from; this argument selects the positioning
#'   notation, i.e. "A1" vs. "R1C1"
#'
#' @return a named vector
#'
#' @examples
#' \dontrun{
#' gap_ss <- gs_gap() # register the Gapminder example sheet
#' get_row(gap_ss, row = 1)
#' simplify_cf(get_row(gap_ss, row = 1))
#' simplify_cf(get_row(gap_ss, row = 1), notation = "R1C1")
#' }
#'
#' @family data consumption functions
#'
#' @export
simplify_cf <- function(x, convert = TRUE, as.is = TRUE,
                        notation = c("A1", "R1C1"), header = NULL) {

  ## TO DO: If the input contains empty cells, maybe this function should have a
  ## way to request that cell entry "" be converted to NA?

  notation <- match.arg(notation)

  if(is.null(header) &&
     x$row %>% min() == 1 &&
     x$col %>% dplyr::n_distinct() == 1) {
    header <-  TRUE
  } else {
    header <- FALSE
  }

  if(header) {
    x <- x %>%
      dplyr::filter_(~ row > min(row))
  }

  y <- x$cell_text
  names(y) <- switch(notation,
                     A1 = x$cell,
                     R1C1 = x$cell_alt)
  if(convert) {
    y %>% type.convert(as.is = as.is)
  } else {
    y
  }
}

## argument validity checks and transformation

## re: min_row, max_row, min_col, max_col = query params for cell feed
validate_limits <-
  function(limits, ws_row_extent = NULL, ws_col_extent = NULL) {

    ## limits must be length one vector, holding a positive integer

    ## why do I proceed this way?
    ## [1] want to preserve original invalid limits for use in error message
    ## [2] want to be able to say which element(s) of limits is/are invalid
    tmp_limits <- limits %>% plyr::llply(affirm_not_factor)
    tmp_limits <- tmp_limits %>% plyr::llply(make_integer)
    tmp_limits <- tmp_limits %>% plyr::llply(affirm_length_one)
    tmp_limits <- tmp_limits %>% plyr::llply(affirm_positive)
    if(any(oops <- is.na(tmp_limits))) {
      mess <- sprintf(paste0("A row or column limit must be a single positive",
                             "integer (or not given at all).\nInvalid input:\n",
                             "%s"),
                      paste(capture.output(limits[oops]), collapse = "\n"))
      stop(mess)
    } else {
      limits <- tmp_limits
    }

    ## min must be <= max, min and max must be <= nominal worksheet extent
    jfun <- function(x, upper_bound) {
      x_name <- deparse(substitute(x))
      ub_name <- deparse(substitute(upper_bound))
      if(!is.null(x) && !is.null(upper_bound) && x > upper_bound) {
        mess <-
          sprintf("%s must be less than or equal to %s\n%s = %d, %s = %d\n",
                  x_name, ub_name, x_name, x, ub_name, upper_bound)
        stop(mess)
      }
    }

    jfun(limits[["min-row"]], limits[["max-row"]])
    jfun(limits[["min-row"]], ws_row_extent)
    jfun(limits[["max-row"]], ws_row_extent)
    jfun(limits[["min-col"]], limits[["max-col"]])
    jfun(limits[["min-col"]], ws_col_extent)
    jfun(limits[["max-col"]], ws_col_extent)

    limits
  }

affirm_not_factor <- function(x) {
  if(is.null(x) || !inherits(x, "factor")) {
    x
  } else {
    NA
  }
}

make_integer <- function(x) {
  suppressWarnings(try({
    if(!is.null(x)) {
      storage.mode(x) <- "integer"
      ## why not use as.integer? because names are lost :(
      ## must use this method based on storage.mode
      ## if coercion fails, x is NA
      ## note this will "succeed" and coerce, eg, 4.7 to 4L
    }
    x
  }, silent = FALSE))
}

affirm_length_one <- function(x) {
  if(is.null(x) || length(x) == 1L || is.na(x)) {
    x
  } else {
    NA
  }
}

affirm_positive <- function(x) {
  if(is.null(x) || x > 0 || is.na(x)) {
    x
  } else {
    NA
  }
}

