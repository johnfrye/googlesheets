% Generated by roxygen2 (4.1.1): do not edit by hand
% Please edit documentation in R/consume-data.R
\name{reshape_cf}
\alias{reshape_cf}
\title{Reshape cell-level data and convert to data.frame}
\usage{
reshape_cf(x, header = TRUE)
}
\arguments{
\item{x}{a data.frame returned by \code{get_via_cf()}}

\item{header}{logical indicating whether first row should be taken as
  variable names}
}
\description{
Reshape cell-level data and convert to data.frame
}
\examples{
\dontrun{
gap_ss <- gs_gap() # register the Gapminder example sheet
get_via_cf(gap_ss, "Asia", max_row = 4)
reshape_cf(get_via_cf(gap_ss, "Asia", max_row = 4))
}
}
\seealso{
Other data.consumption.functions: \code{\link{get_cells}};
  \code{\link{get_col}}; \code{\link{get_row}};
  \code{\link{get_via_cf}}; \code{\link{get_via_csv}};
  \code{\link{get_via_lf}}; \code{\link{simplify_cf}}
}

