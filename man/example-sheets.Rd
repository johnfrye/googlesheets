% Generated by roxygen2 (4.1.1): do not edit by hand
% Please edit documentation in R/gs_example_sheets.R
\name{example-sheets}
\alias{example-sheets}
\alias{gs_gap}
\alias{gs_gap_key}
\alias{gs_gap_url}
\alias{gs_gap_ws_feed}
\title{Examples of Google Sheets.}
\usage{
gs_gap_key()

gs_gap_url()

gs_gap_ws_feed(visibility = "public")

gs_gap()
}
\arguments{
\item{visibility}{either "public" (the default) or "private"; used when
  producing a worksheets feed}
}
\value{
the key, browser URL, worksheets feed or \code{\link{googlesheet}}
  object corresponding to one of the example sheets
}
\description{
These functions return information on some public Google Sheets we've made
available for examples and testing. For example, function names that include
\code{gap} refer to a spreadsheet based on the Gapminder data. This sheet is
"published to the web" and you can visit it in the browser:
}
\details{
\itemize{

\item \href{https://w3id.org/people/jennybc/googlesheets_gap_url}{Gapminder sheet}

}
}
\examples{
\dontrun{
gs_gap_key()
gs_gap_url()
browseURL(gs_gap_url())
gs_gap_ws_feed() # not so interesting to a user!
gs_gap()
}
}

