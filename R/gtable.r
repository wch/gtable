#' Create a new grob table.
#'
#' A table grid captures all the information needed to layout grobs in a table
#' structure. It supports row and column spanning, and offers some tools to
#' automatically figure out correct dimensions.
#'
#' Each grob is put in its own viewport - grobs in the same location are 
#' not combined into one cell. Each grob takes up the entire cell viewport
#' so justification control is not available.
#'
#' It constructs both the viewports and the gTree needed to display the table.
#'
#' @section Components:
#'
#' There are three basics components to a grob table: the specification of 
#' table (cell heights and widths), the layout (for each grob, its position,
#' name and other settings), and global parameters.
#' 
#' It's easier to understand how \code{gtable} works if in your head you keep
#' the table separate from it's contents.  Each cell can have 0, 1, or many
#' grobs inside. Each grob must belong to at least one cell, but can span
#' accross many cells.
#'
#' @section Layout:
#' 
#' The layout details are stored in a data frame with one row for each grob,
#' and columns:
#'
#' \itemize{
#'   \item \code{t} top extent of grob
#'   \item \code{r} right extent of grob
#'   \item \code{b} bottom extent of
#'   \item \code{l} left extent of grob
#'   \item \code{z} the z-order of the grob - used to reorder the grobs 
#'     before they are rendered
#'   \item \code{clip} a string, specifying how the grob should be clipped:
#'     either \code{"on"}, \code{"off"} or \code{"inherit"}
#'   \item \code{name}, a character vector used to name each grob and its
#'     viewport
#' }
#' 
#' You should not need to modify this data frame directly - instead use
#' functions like \code{gtable_add_grob}.
#'
#' @param widths a unit vector giving the width of each column
#' @param heights a unit vector giving the height of each row
#' @param respect a logical vector of length 1: should the aspect ratio of 
#'   height and width specified in null units be respected.  See
#'   \code{\link{grid.layout}} for more details
#' @param name a string giving the name of the table. This is used to name
#'   the layout viewport
#' @param rownames,colnames character vectors of row and column names, used
#'   for characteric subsetting, particularly for \code{\link{gtable_align}},
#'   and \code{\link{gtable_join}}. 
#' @export
#' @seealso \code{\link{gtable_row}}, \code{\link{gtable_col}} and
#'   \code{\link{gtable_matrix}} for convenient ways of creating gtables.
#' @examples
#' a <- gtable(unit(1:3, c("cm")), unit(5, "cm"))
#' a
#' gtable_show_layout(a)
#'
#' # Add a grob:
#' rect <- rectGrob(gp = gpar(fill = "black"))
#' a <- gtable_add_grob(a, rect, 1, 1)
#' a
#' plot(a)
#' 
#' # gtables behave like matrices:
#' dim(a)
#' t(a)
#' plot(t(a))
#' 
#' # when subsetting, grobs are retained if their extents lie in the 
#' # rows/columns that retained.
#' 
#' b <- gtable(unit(c(2, 2, 2), "cm"), unit(c(2, 2, 2), "cm"))
#' b <- gtable_add_grob(b, rect, 2, 2)
#' b[1, ]
#' b[, 1]
#' b[2, 2]
#'
#' # gtable have row and column names
#' rownames(b) <- 1:3
#' rownames(b)[2] <- 200
#' colnames(b) <- letters[1:3]
#' dimnames(b)
gtable <- function(widths = list(), heights = list(), respect = FALSE, name = "layout", rownames = NULL, colnames = NULL) {
  
  if (length(widths) > 0) {
    stopifnot(is.unit(widths))
    stopifnot(is.null(colnames) || length(colnames == length(widths)))
  }
  if (length(heights) > 0) {
    stopifnot(is.unit(heights))
    stopifnot(is.null(rownames) || length(rownames == length(heights)))
  }
  
  grobs <- list()
  layout <- data.frame(
    t = numeric(), r = numeric(), b = numeric(), l = numeric(), z = numeric(),
    clip = character(), name = character(), stringsAsFactors = FALSE)
  
  stopifnot(length(grobs) == nrow(layout))
  
  structure(list(
    grobs = grobs, layout = layout, widths = widths, 
    heights = heights, respect = respect, name = name,
    rownames = rownames, colnames = colnames),
    class = "gtable")
}

#' @S3method print gtable
print.gtable <- function(x, ...) {
  cat("TableGrob (", nrow(x), " x ", ncol(x), ") \"", x$name, "\": ", 
    length(x$grobs), " grobs\n", sep = "")
  
  if (nrow(x$layout) == 0) return()
  
  x$layout <- x$layout[order(x$layout$z), , drop = FALSE]
  
  pos <- as.data.frame(format(as.matrix(x$layout[c("t", "r", "b", "l")])), 
    stringsAsFactors = FALSE)
  grobNames <- vapply(x$grobs, as.character, character(1))
    
  cat(paste("  (", pos$l, "-", pos$r, ",", pos$t, "-", pos$b, ") ",
    x$layout$name, ": ", grobNames, sep = "", collapse = "\n"), "\n")  
}


#' @S3method dim gtable
dim.gtable <- function(x) c(length(x$heights), length(x$widths))

#' @S3method dimnames gtable
dimnames.gtable <- function(x, ...) list(x$rownames, x$colnames)

#' @S3method dimnames<- gtable
"dimnames<-.gtable" <- function(x, value) {
  x$rownames <- value[[1]]
  x$colnames <- value[[2]]
  
  if (anyDuplicated(x$rownames)) stop("rownames must be distinct", 
    call. = FALSE)
  if (anyDuplicated(x$colnames)) stop("colnames must be distinct", 
    call. = FALSE)
  
  x
}

#' @S3method plot gtable
#' @importFrom grid grid.newpage grid.draw
plot.gtable <- function(x, ...) {
  grid.newpage()
  grid.draw(x)
}

#' Is this a gtable?
#' 
#' @param x object to test
#' @export
is.gtable <- function(x) {
  inherits(x, "gtable")
}

#' @S3method t gtable
t.gtable <- function(x) {
  new <- x
  
  new$layout$t <- x$layout$l
  new$layout$r <- x$layout$b
  new$layout$b <- x$layout$r
  new$layout$l <- x$layout$t
  
  new$widths <- x$heights
  new$heights <- x$widths
  
  new
}

#' @S3method [ gtable
"[.gtable" <- function(x, i, j) {
  # Convert indicies to (named) numeric
  rows <- setNames(seq_along(x$heights), rownames(x))[i]
  cols <- setNames(seq_along(x$widths), colnames(x))[j]

  i <- seq_along(x$heights) %in% seq_along(x$heights)[rows]
  j <- seq_along(x$widths) %in% seq_along(x$widths)[cols]  
  
  x$heights <- x$heights[rows]
  x$rownames <- x$rownames[rows]
  x$widths <- x$widths[cols]
  x$colnames <- x$colnames[cols]
  
  keep <- x$layout$t %in% rows & x$layout$b %in% rows & 
          x$layout$l %in% cols & x$layout$r %in% cols
  x$layout <- x$layout[keep, , drop = FALSE]
  x$grobs <- x$grobs[keep]
  
  adj_rows <- cumsum(!i)
  adj_cols <- cumsum(!j)
  
  x$layout$r <- x$layout$r - adj_cols[x$layout$r]
  x$layout$l <- x$layout$l - adj_cols[x$layout$l]
  x$layout$t <- x$layout$t - adj_rows[x$layout$t]
  x$layout$b <- x$layout$b - adj_rows[x$layout$b]
  
  x
}

#' @S3method length gtable
length.gtable <- function(x) length(x$grobs)
