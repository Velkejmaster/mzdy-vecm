# =====================================================================
# Pomocné funkce: Johansenova procedura (reduced rank regression) s volnou
# deterministikou, restrikce na beta/alfa, wild bootstrap trace testu.
# Na rozdíl od urca::ca.jo umožňuje restringované dummy v kointegračním
# prostoru (zlomová konstanta) a bootstrap (Cavaliere, Rahbek, Taylor 2012).
# =====================================================================

# Y: T x n matice log mezd; K: řád VAR v úrovních
# Du: nerestringované deterministické složky (T x m, bez konstanty) - impulzy
# Dr: restringované složky v CI prostoru (T x q) - např. posunové dummy
jo_data <- function(Y, K, Du = NULL, Dr = NULL) {
  Y <- as.matrix(Y); Tt <- nrow(Y); n <- ncol(Y)
  dY <- diff(Y)
  idx <- K:(Tt - 1)                                # řádky dY použité v odhadu
  Z0 <- dY[idx, , drop = FALSE]
  Z1 <- Y[idx, , drop = FALSE]                     # Y_{t-1}
  if (!is.null(Dr)) Z1 <- cbind(Z1, as.matrix(Dr)[idx, , drop = FALSE])
  Z2 <- matrix(1, length(idx), 1, dimnames = list(NULL, "const"))
  if (K > 1) for (k in 1:(K - 1)) {
    L <- dY[idx - k, , drop = FALSE]; colnames(L) <- paste0(colnames(Y), ".dl", k)
    Z2 <- cbind(Z2, L)
  }
  if (!is.null(Du)) {
    Dz <- as.matrix(Du)[idx + 1, , drop = FALSE]
    Z2 <- cbind(Z2, Dz[, colSums(Dz != 0) > 0, drop = FALSE])   # dummy mimo vzorek vynechat
    Z2 <- Z2[, !duplicated(t(Z2)), drop = FALSE]
  }
  list(Z0 = Z0, Z1 = Z1, Z2 = Z2, n = n, K = K, Tn = length(idx),
       vn = colnames(Y), dn = if (!is.null(Dr)) colnames(Dr) else NULL)
}

.resid <- function(A, B) A - B %*% qr.solve(B, A)

# Hlavní odhad: vlastní čísla, trace statistiky, beta, alfa pro zvolené r
jo_fit <- function(d, H = NULL) {
  Z1 <- if (is.null(H)) d$Z1 else d$Z1 %*% H
  R0 <- .resid(d$Z0, d$Z2); R1 <- .resid(Z1, d$Z2); Tn <- d$Tn
  S00 <- crossprod(R0) / Tn; S11 <- crossprod(R1) / Tn; S01 <- crossprod(R0, R1) / Tn
  C <- chol(S11); Ci <- solve(C)
  M <- t(Ci) %*% t(S01) %*% solve(S00, S01) %*% Ci
  e <- eigen((M + t(M)) / 2, symmetric = TRUE)
  lam <- pmin(pmax(e$values, 0), 1 - 1e-12)
  V <- Ci %*% e$vectors                               # V' S11 V = I
  if (!is.null(H)) V <- H %*% V
  list(lambda = lam, V = V, S00 = S00, S01 = S01, S11 = S11, R0 = R0, R1 = R1, d = d,
       trace = rev(cumsum(rev(-Tn * log(1 - lam[1:d$n]))))[1:d$n])
}

# VECM pro dané r: beta (normalizované), alfa, Gamma, rezidua, std. chyby alfa
jo_vecm <- function(d, r, beta = NULL, norm = 1) {
  if (is.null(beta)) {
    f <- jo_fit(d); beta <- f$V[, 1:r, drop = FALSE]
  }
  if (!is.null(norm)) beta <- sweep(beta, 2, beta[norm, ], "/")
  rownames(beta) <- c(d$vn, d$dn)
  ect <- d$Z1 %*% beta; colnames(ect) <- paste0("ect", 1:r)
  X <- cbind(ect, d$Z2)
  fit <- lm.fit(X, d$Z0)
  B <- fit$coefficients; E <- fit$residuals
  df <- d$Tn - ncol(X); Sig <- crossprod(E) / df
  XtXi <- solve(crossprod(X))
  se <- sqrt(outer(diag(XtXi), diag(Sig)))
  dimnames(B) <- dimnames(se) <- list(colnames(X), d$vn)
  colnames(E) <- d$vn
  list(beta = beta, alpha = t(B[1:r, , drop = FALSE]), coef = B, se = se, resid = E,
       X = X, Sigma = Sig, XtXi = XtXi, df = df, r = r, d = d)
}

# LR test restrikcí beta = H phi (Johansen 1995, kap. 7) pro rank r
jo_lr_beta <- function(d, r, H) {
  f0 <- jo_fit(d); f1 <- jo_fit(d, H = H)
  LR <- d$Tn * sum(log((1 - f1$lambda[1:r]) / (1 - f0$lambda[1:r])))
  dfree <- r * (nrow(H) - r) - r * (ncol(H) - r)
  list(LR = LR, df = dfree, p = pchisq(LR, dfree, lower.tail = FALSE),
       beta = sweep(f1$V[, 1:r, drop = FALSE], 2, f1$V[1, 1:r], "/"))
}

# LR test alfa = A psi (slabá exogenita proměnných mimo sloupce A), rank r.
# Kondiciování na B'R0, B = A_perp (Johansen 1995, věta 8.1)
jo_lr_alpha <- function(d, r, A) {
  f0 <- jo_fit(d)
  Bp <- MASS::Null(A)
  d2 <- d; d2$Z0 <- d$Z0 %*% A; d2$Z2 <- cbind(d$Z2, d$Z0 %*% Bp)
  f1 <- jo_fit(d2)
  LR <- d$Tn * sum(log((1 - f1$lambda[1:r]) / (1 - f0$lambda[1:r])))
  dfree <- r * (d$n - ncol(A))
  list(LR = LR, df = dfree, p = pchisq(LR, dfree, lower.tail = FALSE))
}

# Kořeny companion matice VAR v úrovních implikovaného VECM
jo_roots <- function(v) {
  n <- v$d$n; K <- v$d$K
  Pi <- v$alpha %*% t(v$beta[1:n, , drop = FALSE])
  G <- lapply(seq_len(K - 1), function(k) t(v$coef[paste0(v$d$vn, ".dl", k), , drop = FALSE]))
  A <- vector("list", K)
  A[[1]] <- diag(n) + Pi + if (K > 1) G[[1]] else 0
  if (K > 2) for (k in 2:(K - 1)) A[[k]] <- G[[k]] - G[[k - 1]]
  if (K > 1) A[[K]] <- -G[[K - 1]]
  Cm <- matrix(0, n * K, n * K); Cm[1:n, ] <- do.call(cbind, A)
  if (K > 1) Cm[(n + 1):(n * K), 1:(n * (K - 1))] <- diag(n * (K - 1))
  sort(Mod(eigen(Cm)$values), decreasing = TRUE)
}

# --- Diagnostika reziduí VECM (stejné testy jako vars, ale pro jo_vecm) ---
# Vícerozměrný LM test autokorelace řádu h, F-verze Edgerton–Shukur (jako vars "ES")
diag_lm_es <- function(v, h) {
  U <- v$resid; X <- v$X; Tn <- nrow(U); K <- ncol(U)
  L <- do.call(cbind, lapply(1:h, function(k) rbind(matrix(0, k, K), U[1:(Tn - k), , drop = FALSE])))
  S0 <- crossprod(.resid(U, X)) / Tn
  S1 <- crossprod(.resid(U, cbind(X, L))) / Tn
  R2r <- 1 - det(S1) / det(S0)
  m <- K * h; q <- 0.5 * K * m - 1; N <- Tn - ncol(X) - m - 0.5 * (K - m + 1)
  s <- if (K^2 + m^2 - 5 > 0) sqrt((K^2 * m^2 - 4) / (K^2 + m^2 - 5)) else 1
  Fst <- ((1 - (1 - R2r)^(1 / s)) / (1 - R2r)^(1 / s)) * (N * s - q) / (K * m)
  pf(Fst, h * K^2, floor(N * s - q), lower.tail = FALSE)
}
# Vícerozměrný Jarque–Bera (Lütkepohl, standardizace Choleskyho rozkladem)
diag_jb_mult <- function(v) {
  U <- scale(v$resid, scale = FALSE); Tn <- nrow(U); K <- ncol(U)
  P <- t(chol(crossprod(U) / Tn)); W <- U %*% t(solve(P))
  s3 <- Tn * sum(colMeans(W^3)^2) / 6; s4 <- Tn * sum((colMeans(W^4) - 3)^2) / 24
  c(JB = pchisq(s3 + s4, 2 * K, lower.tail = FALSE),
    Skew = pchisq(s3, K, lower.tail = FALSE), Kurt = pchisq(s4, K, lower.tail = FALSE))
}
# Jednorovnicové testy: Ljung–Box(4, 8), JB, ARCH-LM(4)
diag_uni <- function(v) {
  sapply(colnames(v$resid), function(j) {
    x <- v$resid[, j]; z <- (x - mean(x)) / sd(x); L <- embed(x^2, 5)
    c(LB4 = Box.test(x, 4, "Ljung")$p.value, LB8 = Box.test(x, 8, "Ljung")$p.value,
      JB = pchisq(length(x) / 6 * (mean(z^3)^2 + (mean(z^4) - 3)^2 / 4), 2, lower.tail = FALSE),
      ARCH4 = pchisq(nrow(L) * summary(lm(L[, 1] ~ L[, -1]))$r.squared, 4, lower.tail = FALSE))
  })
}

# Wild bootstrap trace testu (Cavaliere, Rahbek & Taylor 2012, Econometrica):
# sekvenční test H(r) proti H(n); data generována pod H(r) s Rademacherovými
# váhami -> robustní vůči heteroskedasticitě (ARCH) a nenormalitě
jo_boot_trace <- function(Y, K, Du = NULL, Dr = NULL, B = 499, seed = 1, ranks = NULL) {
  set.seed(seed)
  Y <- as.matrix(Y); n <- ncol(Y); Tt <- nrow(Y)
  if (!is.null(Du)) {                           # stejné čištění dummy jako v jo_data
    Du <- as.matrix(Du); Dz <- Du[(K + 1):Tt, , drop = FALSE]
    Du <- Du[, colSums(Dz != 0) > 0 & !duplicated(t(Dz)), drop = FALSE]
    if (!ncol(Du)) Du <- NULL
  }
  d <- jo_data(Y, K, Du, Dr); f <- jo_fit(d)
  out <- data.frame(r = 0:(n - 1), trace = f$trace, p_boot = NA_real_)
  for (r in if (is.null(ranks)) 0:(n - 1) else ranks) {
    # odhad pod H(r)
    if (r > 0) { v <- jo_vecm(d, r, norm = NULL); E <- v$resid; Bc <- v$coef }
    else {
      fit <- lm.fit(d$Z2, d$Z0); E <- fit$residuals; Bc <- fit$coefficients
    }
    Pi <- if (r > 0) v$alpha %*% t(v$beta) else matrix(0, n, ncol(d$Z1))
    G2 <- if (r > 0) Bc[-(1:r), , drop = FALSE] else Bc
    stat <- numeric(B)
    for (b in 1:B) {
      w <- sample(c(-1, 1), nrow(E), replace = TRUE)
      Eb <- E * w
      Yb <- Y; dYb <- diff(Y)
      for (t in seq_len(nrow(E))) {
        i <- K - 1 + t                               # řádek dY
        z1 <- c(Yb[i, ], if (!is.null(Dr)) as.matrix(Dr)[i, ])
        z2 <- c(1, if (K > 1) as.vector(t(dYb[(i - 1):(i - K + 1), , drop = FALSE])), if (!is.null(Du)) as.matrix(Du)[i + 1, ])
        # pořadí zpožděných diferencí v Z2: všechny proměnné lagu 1, pak lagu 2 ...
        dYb[i, ] <- as.vector(Pi %*% z1) + as.vector(z2 %*% G2) + Eb[t, ]
        Yb[i + 1, ] <- Yb[i, ] + dYb[i, ]
      }
      db <- jo_data(Yb, K, Du, Dr)
      stat[b] <- jo_fit(db)$trace[r + 1]
    }
    out$p_boot[r + 1] <- mean(stat >= f$trace[r + 1])
  }
  out
}
