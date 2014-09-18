## Helper functions

### WHY DO WE NEED THIS FUNCTION?
## fitsel <- function(object, newdata = NULL, which = NULL, ...) {
##     fun <- function(model) {
##         tmp <- predict(model, newdata = newdata,
##                        which = which, agg = "cumsum")
##         ret <- c()
##         for (i in 1:length(tmp))
##             ret <- rbind(ret, tmp[[i]])
##         ret
##     }
##     ss <- cvrisk(object, fun = fun, ...)
##     ret <- matrix(0, nrow = nrow(ss[[1]]), ncol = ncol(ss[[1]]))
##     for (i in 1:length(ss))
##         ret <- ret + sign(ss[[i]])
##     ret <- abs(ret) / length(ss)
##     ret
## }


################################################################################
## Functions for improved error bounds
################################################################################

### Modified version of the code accompanying the paper:
###   Shah, R. D. and Samworth, R. J. (2013), Variable selection with error
###   control: Another look at Stability Selection, J. Roy. Statist. Soc., Ser.
###   B, 75, 55-80. DOI: 10.1111/j.1467-9868.2011.01034.x
###
### Original code available from
###   http://www.statslab.cam.ac.uk/~rds37/papers/r_concave_tail.R
### or
###   http://www.statslab.cam.ac.uk/~rjs57/r_concave_tail.R
D <- function(theta, which, B, r) {
    ## compute upper tail of r-concave distribution function
    ## If q = ceil{ B * 2 * theta} / B + 1/B,..., 1 return the tail probability.
    ## If q < ceil{ B * 2 * theta} / B return 1

    s <- 1/r
    thetaB <- theta * B
    k_start <- (ceiling(2 * thetaB) + 1)

    if (which < k_start)
        return(1)

    if(k_start > B)
        stop("theta to large")

    Find.a <- function(prev_a)
        uniroot(Calc.a, lower = 0.00001, upper = prev_a,
                tol = .Machine$double.eps^0.75)$root

    Calc.a <- function(a) {
        denom <- sum((a + 0:k)^s)
        num <- sum((0:k) * (a + 0:k)^s)
        num / denom - thetaB
    }

    OptimInt <- function(a, t, k, thetaB, s) {
        num <- (k + 1 - thetaB) * sum((a + 0:(t-1))^s)
        denom <- sum((k + 1 - (0:k)) * (a + 0:k)^s)
        1 - num / denom
    }

    ## initialize a
    a_vec <- rep(100000, B)

    ## compute a values
    for(k in k_start:B)
        a_vec[k] <- Find.a(a_vec[k-1])

    cur_optim <- rep(0, B)
    for (k in k_start:(B-1))
        cur_optim[k] <- optimize(f=OptimInt, lower = a_vec[k+1],
                                 upper = a_vec[k],
                                 t = which, k = k, thetaB = thetaB, s = s,
                                 maximum  = TRUE)$objective
    return(max(cur_optim))
}

## minD function for error bound in case of r-concavity
minD <- function(q, p, pi, B, r = c(-1/2, -1/4)) {
    ## get the integer valued multiplier W of
    ##   pi = W * 1/(2 * B)
    which <- ceiling(signif(pi / (1/(2* B)), 10))
    maxQ <- maxQ(p, B)
    if (q > maxQ)
        stop(sQuote("q"), " must be <= ", maxQ)
    min(c(1, D(q^2 / p^2, which - B, B, r[1]), D(q / p, which , 2*B, r[2])))
}


################################################################################
## Functions to compute the optimal cutoff and optimal q values
################################################################################

## function to find optimal cutoff in stabsel (when sampling.type = "SS")
optimal_cutoff <- function(p, q, PFER, B, assumption = "unimodal") {
    if (assumption == "unimodal") {
        ## cutoff values can only be multiples of 1/(2B)
        cutoffgrid <- 1/2 + (2:B)/(2*B)
        c_min <- min(0.5 + (q/p)^2, 0.5 + 1/(2*B) + 0.75 * (q/p)^2)
        cutoffgrid <- cutoffgrid[cutoffgrid > c_min]
        upperbound <- rep(NA, length(cutoffgrid))
        for (i in 1:length(cutoffgrid))
            upperbound[i] <- q^2 / p / um_const(cutoffgrid[i], B, theta = q/p)
        cutoff <- cutoffgrid[upperbound < PFER][1]
        return(cutoff)
    } else {
        ## cutoff values can only be multiples of 1/(2B)
        cutoff <- (2*B):1/(2*B)
        cutoff <- cutoff[cutoff >= 0.5]
        for (i in 1:length(cutoff)) {
            if (minD(q, p, cutoff[i], B) * p > PFER) {
                if (i == 1)
                    cutoff <- cutoff[i]
                else
                    cutoff <- cutoff[i - 1]
                break
            }
        }
        return(tail(cutoff, 1))
    }
}

## function to find optimal q in stabsel (when sampling.type = "SS")
optimal_q <- function(p, cutoff, PFER, B, assumption = "unimodal") {
    if (assumption == "unimodal") {
        if (cutoff <= 0.75) {
            upper_q <- max(p * sqrt(cutoff - 0.5),
                           p * sqrt(4/3 * (cutoff - 0.5 - 1/(2*B))))
            ## q must be an integer < upper_q
            upper_q <- ceiling(upper_q - 1)
        } else {
            upper_q <- p
        }
        q <- uniroot(function(q)
                     q^2 / p / um_const(cutoff, B, theta = q/p) - PFER,
                     lower = 1, upper = upper_q)$root
        return(floor(q))
    } else {
        for (q in 1:maxQ(p, B)) {
            if (minD(q, p, cutoff, B) * p > PFER) {
                q <- q - 1
                break
            }
        }
        return(max(1, q))
    }
}

## obtain maximal value possible for q
maxQ <- function(p, B) {
    if(B <= 1)
        stop("B must be at least 2")

    fact_1 <- 4 * B / p
    tmpfct <- function(q)
        ceiling(q * fact_1) + 1 - 2 * B

    res <- tmpfct(1:p)
    length(res[res < 0])
}

## obtain constant for unimodal bound
um_const <- function(cutoff, B, theta) {
    if (cutoff <= 3/4) {
        if (cutoff < 1/2 + min(theta^2, 1 / (2*B) + 3/4 * theta^2))
            stop ("cutoff out of bounds")
        return( 2 * (2 * cutoff - 1 - 1/(2*B)) )
    } else {
        if (cutoff > 1)
            stop ("cutoff out of bounds")
        return( (1 + 1/B)/(4 * (1 - cutoff + 1 / (2*B))) )
    }
}


################################################################################
## Pre-processing functions for stabsel
################################################################################

## check if folds result from subsampling with p = 0.5.
check_folds <- function(folds, B, n, sampling.type) {
    if (!is.matrix(folds) || ncol(folds) != B || nrow(folds) != n ||
        !all(folds %in% c(0, 1)))
        stop(sQuote("folds"),
             " must be a binary or logical matrix with dimension nrow(x) times B")
    if (!all(colMeans(folds) %in% c(floor(n * 0.5) / n, ceiling(n * 0.5) / n)))
        warning("Subsamples are not of size n/2; results might be wrong")
    ## use complementary pairs?
    if (sampling.type == "SS") {
        folds <- cbind(folds, rep(1, n) - folds)
    }
    folds
}

run_stabsel <- function(fitter, n, p, cutoff, q, PFER, folds, B, assumption,
                        sampling.type, papply, verbose, FWER, eval, names, ...) {

    folds <- check_folds(folds, B = B, n = n, sampling.type = sampling.type)
    pars <- stabsel_parameters(p = p, cutoff = cutoff, q = q,
                               PFER = PFER, B = B,
                               verbose = verbose, sampling.type = sampling.type,
                               assumption = assumption, FWER = FWER)
    cutoff <- pars$cutoff
    q <- pars$q
    PFER <- pars$PFER

    ## return parameter combination only if eval == FALSE
    if (!eval)
        return(pars)

    ## fit model on subsamples;
    ## Depending on papply, this is done sequentially or in parallel
    res <- matrix(nrow = ncol(folds), byrow = TRUE,
                  unlist(papply(1:ncol(folds), fitter, folds = folds, q = q, ...)))
    colnames(res) <- names

    ### TODO: Currently stability paths "phat" are missing
    ret <- list(# phat = phat,
                selected = which(colMeans(res) >= cutoff),
                max = colMeans(res), cutoff = cutoff, q = q, PFER = PFER,
                sampling.type = sampling.type, assumption = assumption)
    class(ret) <- "stabsel"
    ret
}