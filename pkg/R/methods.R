print.stabsel <- function(x, decreasing = FALSE, print.all = TRUE, ...) {

    cat("\tStability Selection")
    if (x$assumption == "none")
        cat(" without further assumptions\n")
    if (x$assumption == "unimodal")
        cat(" with unimodality assumption\n")
    if (x$assumption == "r-concave")
        cat(" with r-concavity assumption\n")
    if (length(x$selected) > 0) {
        cat("\nSelected base-learners:\n")
        print(x$selected)
    } else {
        cat("\nNo base-learner selected\n")
    }
    cat("\nSelection probabilities:\n")
    if (print.all) {
        print(sort(x$max, decreasing = decreasing))
    } else {
        print(sort(x$max[x$max > 0], decreasing = decreasing))
    }
    cat("\n")
    print.stabsel_parameters(x, heading = FALSE)
    cat("\n")
    invisible(x)
}

print.stabsel_parameters <- function(x, heading = TRUE, ...) {
    if (heading) {
        cat("Stability Selection")
        if (x$assumption == "none")
            cat(" without further assumptions\n")
        if (x$assumption == "unimodal")
            cat(" with unimodality assumption\n")
        if (x$assumption == "r-concave")
            cat(" with r-concavity assumption\n")
    }
    cat("Cutoff: ", x$cutoff, "; ", sep = "")
    cat("q: ", x$q, "; ", sep = "")
    if (x$sampling.type == "MB")
        cat("PFER: ", x$PFER, "\n")
    else
        cat("PFER(*): ", x$PFER,
            "\n   (*) or expected number of low selection probability variables\n")
    invisible(x)
}

plot.stabsel <- function(x, main = deparse(x$call), type = c("maxsel", "paths"),
                         col = NULL, ymargin = 10, np = sum(x$max > 0),
                         labels = NULL, ...) {

    type <- match.arg(type)

    if (is.null(col))
        col <- hcl(h = 40, l = 50, c = x$max / max(x$max) * 490)

    if (type == "paths") {
        ## if par(mar) not set by user ahead of plotting
        if (all(par()[["mar"]] == c(5, 4, 4, 2) + 0.1))
            ..old.par <- par(mar = c(5, 4, 4, ymargin) + 0.1)
        h <- x$phat
        h <- h[rowSums(h) > 0, , drop = FALSE]
        matplot(t(h), type = "l", lty = 1,
                xlab = "Number of boosting iterations",
                ylab = "Selection probability",
                main = main, col = col[x$max > 0], ylim = c(0, 1), ...)
        abline(h = x$cutoff, lty = 1, col = "lightgray")
        if (is.null(labels))
            labels <- rownames(x$phat)
        axis(4, at = x$phat[rowSums(x$phat) > 0, ncol(x$phat)],
             labels = labels[rowSums(x$phat) > 0], las = 1)
    } else {
        ## if par(mar) not set by user ahead of plotting
        if (all(par()[["mar"]] == c(5, 4, 4, 2) + 0.1))
            ..old.par <- par(mar = c(5, ymargin, 4, 2) + 0.1)
        if (np > length(x$max))
            stop(sQuote("np"), "is set too large")
        inc_freq <- x$max  ## inclusion frequency
        plot(tail(sort(inc_freq), np), 1:np,
             type = "n", yaxt = "n", xlim = c(0, 1),
             ylab = "", xlab = expression(hat(pi)),
             main = main, ...)
        abline(h = 1:np, lty = "dotted", col = "grey")
        points(tail(sort(inc_freq), np), 1:np, pch = 19,
               col = col[tail(order(inc_freq), np)])
        if (is.null(labels))
            labels <- names(x$max)
        axis(2, at = 1:np, labels[tail(order(inc_freq), np)], las = 2)
        ## add cutoff
        abline(v = x$cutoff, col = "grey")
    }
    if (exists("..old.par"))
        par(..old.par) # reset plotting settings
}

selected.stabsel <- function(object, ...)
    object$selected