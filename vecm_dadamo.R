# =====================================================================
# VECM mezd podle skupin CZ-NACE: (i) nestabilita modelu z vecm_mzdy.R,
# (ii) zbytková autokorelace a její řešení, (iii) mzdové vazby podle
# D'Adamo (2014, Empir Econ 47:523–552): dlouhodobí vůdci (slabá exogenita),
# krátkodobí vůdci (Grangerova kauzalita v Gamma), plná mzdová adaptabilita
# (párové restrikce beta = (1, -1, 0, ...)).
# Vstup: mzdy.csv, johansen_tools.R. Výstupy: konzole + fig_5, fig_6 (png)
# Balíčky: urca, seasonal (X-13), strucchange, MASS
# =====================================================================
suppressMessages({library(urca); library(seasonal); library(strucchange)})
source("johansen_tools.R")
B_BOOT <- 499                                       # replikace wild bootstrapu

# ---- 1. Data: agregace + X-13 (shodně s vecm_mzdy.R) ----
m <- read.csv2("mzdy.csv", stringsAsFactors = FALSE)
skup <- c(A="ZEM", B="PRU", C="PRU", D="PRU", E="PRU", F="STA",
          G="TRZ", H="TRZ", I="TRZ", J="TRZ", K="TRZ", L="TRZ", M="TRZ", N="TRZ", Q="TRZ",
          O="NETRZ", P="NETRZ", R="NETRZ", S="NETRZ")
s <- m[m$sektor != "Celkem", ]; s$g <- skup[s$sektor]; stopifnot(!anyNA(s$g))
s$vol <- s$mzda * s$zamestnanci_fte
a <- aggregate(cbind(vol, zamestnanci_fte) ~ obdobi + g, s, sum)
a$w <- a$vol / a$zamestnanci_fte
W <- reshape(a[, c("obdobi","g","w")], idvar="obdobi", timevar="g", direction="wide")
W <- W[order(W$obdobi), ]; names(W) <- sub("^w\\.", "", names(W))
V5 <- c("PRU","STA","TRZ","NETRZ","ZEM"); tt <- W$obdobi; Tt <- length(tt)
S <- ts(sapply(V5, function(v) log(final(seas(ts(W[[v]], start=c(2000,1), frequency=4), x11=""))) ),
        start=c(2000,1), frequency=4)
colnames(S) <- V5; X <- S[, V5]

# ---- 2. Deterministické složky ----
imp <- function(q) as.numeric(tt == q)                                   # impulz
tr  <- function(q) { x <- imp(q); x[which(x == 1) + 1] <- -1; x }        # tranzitorní (+1, -1)
stp <- function(q) as.numeric(seq_len(Tt) >= which(tt == q))             # posun úrovně
DUM0 <- cbind(d08q1 = imp("2008-Q1"), d13q1 = imp("2013-Q1"), d20q2 = imp("2020-Q2"),
              d20q3 = imp("2020-Q3"), d21q2 = imp("2021-Q2"))            # původní (vecm_mzdy.R)
# Odlehlá pozorování z automatické detekce X-13: LS 2008Q1 (PRU, STA) -> impulz v diferencích;
# AO 2012Q4 (přesun odměn před solidární přirážkou), AO 2020Q2 (COVID), AO 2021Q2 (covidové
# odměny ve zdravotnictví, Q je v TRZ) -> tranzitorní dummy, protože jde o jednorázové výkyvy úrovně
DT <- cbind(dLS08 = imp("2008-Q1"), tr12q4 = tr("2012-Q4"), tr20q2 = tr("2020-Q2"), tr21q2 = tr("2021-Q2"))
TR <- cbind(trend = seq_len(Tt))                     # restringovaný trend v CI (D'Adamo, Juselius 2006)

specs <- list(
  A = list(popis = "puvodni: K=2, 5 impulzu, bez trendu",        v = V5,      K = 2, Du = DUM0, Dr = NULL),
  B = list(popis = "dummy dle X-13, bez trendu, K=2",            v = V5,      K = 2, Du = DT,   Dr = NULL),
  C = list(popis = "dummy dle X-13 + trend v CI, K=2",           v = V5,      K = 2, Du = DT,   Dr = TR),
  D = list(popis = "dummy dle X-13 + trend v CI, K=3 (HLAVNI)",  v = V5,      K = 3, Du = DT,   Dr = TR),
  E = list(popis = "jako C + posun 2009Q3 v CI",                 v = V5,      K = 2, Du = cbind(DT, i09q3 = imp("2009-Q3")),
           Dr = cbind(TR, s09q3 = stp("2009-Q3"))),
  F = list(popis = "jako D bez zemedelstvi (vymezeni D'Adamo)",  v = V5[1:4], K = 3, Du = DT,   Dr = TR))
HLAVNI <- "D"
fit_spec <- function(sp, i = 1:Tt) {
  d <- jo_data(X[i, sp$v], sp$K, sp$Du[i, , drop = FALSE], if (is.null(sp$Dr)) NULL else sp$Dr[i, , drop = FALSE])
  list(d = d, f = jo_fit(d), v = jo_vecm(d, 1))
}
# normalizace beta na proměnnou, která se nejvýznamněji přizpůsobuje (D'Adamo, Tab. 4)
normalize <- function(v) {
  t0 <- v$alpha[, 1] / v$se["ect1", ]; k <- which.max(abs(t0)); c0 <- v$beta[k, 1]
  v$beta <- v$beta / c0; v$alpha <- v$alpha * c0; v$talpha <- t0 * sign(c0); v$norm <- rownames(v$beta)[k]; v
}

# ---- 3. Nestabilita původního modelu (spec. A) ----
cat("=====================================================================\n")
cat("3. NESTABILITA PUVODNIHO MODELU (spec. A)\n")
cat("=====================================================================\n")
cat("\n-- 3a. Subvzorky: beta (normalizace ZEM = 1) a t-hodnoty alfa --\n")
for (sp_nm in c("A", HLAVNI)) for (smp in list(c("2000-Q1","2026-Q2"), c("2000-Q1","2012-Q4"), c("2000-Q1","2019-Q4"),
                                         c("2005-Q1","2026-Q2"), c("2010-Q1","2026-Q2"))) {
  i <- which(tt == smp[1]):which(tt == smp[2]); e <- fit_spec(specs[[sp_nm]], i)
  v <- jo_vecm(e$d, 1, norm = 5)
  cat(sprintf("%s %s–%s: beta = %s | t(alfa) = %s\n", sp_nm, smp[1], smp[2],
    paste(sprintf("%6.2f", v$beta[1:5, 1]), collapse = ""), paste(sprintf("%5.1f", v$alpha[, 1] / v$se["ect1", ]), collapse = "")))
}
cat("\n-- 3b. Klouzavé okno 48 čtvrtletí (spec. A): beta (ZEM = 1) --\n")
roll <- t(sapply(seq(48, Tt, by = 4), function(e) {
  ft <- fit_spec(specs$A, (e - 47):e); v <- jo_vecm(ft$d, 1, norm = 5); v$beta[1:5, 1] }))
rownames(roll) <- tt[seq(48, Tt, by = 4)]; print(round(roll, 2))
cat("\n-- 3c. Andrews sup-F: zlom v rovnicích VECM (beta pevné), p --\n")
for (sp_nm in c("A", HLAVNI)) {
  e <- fit_spec(specs[[sp_nm]]); Xr <- e$v$X[, !colnames(e$v$X) %in% c(colnames(DUM0), colnames(DT))]
  cat(sp_nm, ":", paste(sapply(V5, function(j) { fs <- Fstats(e$d$Z0[, j] ~ Xr - 1, from = 0.15)
    sprintf("%s p=%.3f (%s)", j, sctest(fs)$p.value, tt[-(1:e$d$K)][fs$breakpoint]) }), collapse = " | "), "\n")
}
cat("\n-- 3d. Lütkepohl–Saikkonen–Trenkler: kointegrace s posunem v neznámém čase --\n")
for (vv in list(V5, V5[1:4])) {
  l <- cajolst(X[, vv], trend = FALSE, K = 2, season = NULL)
  cat(paste(vv, collapse = ","), "| odhad zlomu:", tt[l@bp], "\n"); print(cbind(stat = round(l@teststat, 2), l@cval))
}

# ---- 4. Srovnání specifikací: hodnost, kořeny, diagnostika reziduí ----
cat("\n=====================================================================\n")
cat("4. SROVNANI SPECIFIKACI (wild bootstrap B =", B_BOOT, "; Cavaliere, Rahbek, Taylor 2012)\n")
cat("=====================================================================\n")
res <- list()
for (nm in names(specs)) {
  sp <- specs[[nm]]; e <- fit_spec(sp); n <- length(sp$v)
  bt <- jo_boot_trace(X[, sp$v], sp$K, sp$Du, sp$Dr, B = B_BOOT, ranks = 0:1)
  u <- diag_uni(e$v); ect <- e$d$Z1 %*% e$v$beta
  trend_p <- if (!is.null(sp$Dr)) jo_lr_beta(e$d, 1, diag(nrow(e$v$beta))[, -(n + 1), drop = FALSE])$p else NA
  res[[nm]] <- c(e, p0 = bt$p_boot[1], root = jo_roots(e$v)[n])
  cat(sprintf("\n[%s] %s  (T=%d, n=%d)\n", nm, sp$popis, e$d$Tn, n))
  cat(sprintf("  trace: r=0 %.1f (boot p=%.3f) | r<=1 %.1f (boot p=%.3f) | nejv. nerestr. kořen (r=1) = %.3f\n",
    e$f$trace[1], bt$p_boot[1], e$f$trace[2], bt$p_boot[2], jo_roots(e$v)[n]))
  cat(sprintf("  LM(1) p=%.3f  LM(4) p=%.3f  JB mult. p=%.3f  | ADF(ECT)=%.2f | trend v CI = 0: p=%s\n",
    diag_lm_es(e$v, 1), diag_lm_es(e$v, 4), diag_jb_mult(e$v)[1],
    ur.df(ect, type = "drift", lags = 4, selectlags = "BIC")@teststat[1], if (is.na(trend_p)) "-" else sprintf("%.3f", trend_p)))
  cat("  jednorovnicové p:\n"); print(round(u, 3))
}

# ---- 5. Mzdové vazby podle D'Adama (2014) ----
dadamo <- function(e) {
  d <- e$d; v <- normalize(e$v); n <- d$n; vn <- d$vn; p1 <- nrow(v$beta); K <- d$K
  we <- sapply(1:n, function(i) jo_lr_alpha(d, 1, diag(n)[, -i, drop = FALSE])$p); names(we) <- vn
  lead <- which(we > 0.05)
  joint <- if (length(lead) >= 2 && length(lead) < n) jo_lr_alpha(d, 1, diag(n)[, -lead, drop = FALSE]) else NULL
  excl <- sapply(1:n, function(i) jo_lr_beta(d, 1, diag(p1)[, -i, drop = FALSE])$p); names(excl) <- vn
  det_free <- if (p1 > n) rbind(matrix(0, n, p1 - n), diag(p1 - n)) else NULL
  fwa <- matrix(NA, n, n, dimnames = list(vn, vn))
  for (a in 1:(n - 1)) for (b in (a + 1):n) {
    h <- rep(0, n); h[c(a, b)] <- c(1, -1)
    fwa[a, b] <- fwa[b, a] <- jo_lr_beta(d, 1, cbind(c(h, rep(0, p1 - n)), det_free))$p
  }
  Hh <- rbind(sapply(2:n, function(j) { h <- rep(0, n); h[c(1, j)] <- c(1, -1); h }), matrix(0, p1 - n, n - 1))
  hom <- jo_lr_beta(d, 1, cbind(Hh, det_free))$p
  G <- matrix(NA, n, n, dimnames = list(pricina = vn, rovnice = vn))
  if (K > 1) for (j in vn) for (i in vn) if (i != j) {
    rr <- paste0(i, ".dl", 1:(K - 1)); b <- v$coef[rr, j]
    Wd <- as.numeric(t(b) %*% solve(v$Sigma[j, j] * v$XtXi[rr, rr, drop = FALSE]) %*% b)
    G[i, j] <- pchisq(Wd, K - 1, lower.tail = FALSE)
  }
  srl <- character(0)
  for (i in vn) for (j in vn) if (i != j && !is.na(G[i, j]) && G[i, j] < 0.05 && G[j, i] >= 0.05) srl <- c(srl, paste(i, "->", j))
  list(v = v, we = we, joint = joint, lead = vn[lead], excl = excl, fwa = fwa, hom = hom, G = G, srl = srl)
}
cat("\n=====================================================================\n")
cat("5. MZDOVE VAZBY PODLE D'ADAMA (2014)\n")
cat("=====================================================================\n")
DA <- lapply(res, dadamo)
for (nm in c(HLAVNI, "C")) {
  r <- DA[[nm]]; v <- r$v; n <- length(r$we)
  cat(sprintf("\n######## Specifikace %s: %s ########\n", nm, specs[[nm]]$popis))
  cat("Kointegrační vektor (normalizace na", v$norm, "= 1):\n"); print(round(v$beta[, 1], 4))
  cat("Alfa a t-hodnoty:\n"); print(round(rbind(alfa = v$alpha[, 1], t = v$talpha), 3))
  rho <- 1 + sum(v$beta[1:n, 1] * v$alpha[, 1])
  cat(sprintf("1 + beta'alfa = %.3f, poločas návratu = %.1f Q\n", rho, if (rho > 0 && rho < 1) log(.5) / log(rho) else NA))
  cat("\n(i) Dlouhodobé vůdcovství – slabá exogenita alfa_i = 0, p:\n"); print(round(r$we, 3))
  if (!is.null(r$joint)) cat(sprintf("    společně slabě exogenní {%s}: LR = %.2f, df = %d, p = %.3f\n",
                                     paste(r$lead, collapse = ", "), r$joint$LR, r$joint$df, r$joint$p))
  cat("    vyloučení z dlouhodobého vztahu beta_i = 0, p:\n"); print(round(r$excl, 3))
  cat("\n(ii) Plná mzdová adaptabilita – beta = (1, -1, 0, ...), deterministika volná, p:\n"); print(round(r$fwa, 3))
  cat(sprintf("     slabší forma – homogenita (součet beta mezd = 0): p = %.3f\n", r$hom))
  cat("\n(iii) Krátkodobé vůdcovství – Grangerova kauzalita v Gamma (Wald, řádek -> sloupec), p:\n"); print(round(r$G, 3))
  cat("     krátkodobý vůdce (i -> j a zároveň ne j -> i):", if (length(r$srl)) paste(r$srl, collapse = "; ") else "žádný", "\n")
  cat("\nKorelace reziduí (současné spillovery v rámci čtvrtletí):\n"); print(round(cor(v$resid), 2))
  Gam <- diag(n) - Reduce(`+`, lapply(1:(v$d$K - 1), function(k) t(v$coef[paste0(v$d$vn, ".dl", k), ])))
  ap <- MASS::Null(v$alpha); bp <- MASS::Null(v$beta[1:n, , drop = FALSE])
  C <- bp %*% solve(t(ap) %*% Gam %*% bp) %*% t(ap); dimnames(C) <- list(odezva = v$d$vn, sok = v$d$vn)
  cat("\nDlouhodobé dopady šoků C = beta_perp (alfa_perp' Gamma beta_perp)^-1 alfa_perp' (sloupec = šok):\n"); print(round(C, 2))
}

cat("\n-- Robustnost závěrů napříč specifikacemi --\n")
rob <- t(sapply(names(DA), function(nm) { r <- DA[[nm]]; n <- length(r$we)
  c(spec = nm, `boot p r=0` = sprintf("%.3f", res[[nm]]$p0), `koren` = sprintf("%.2f", res[[nm]]$root), `w.e. p (PRU STA TRZ NETRZ ZEM)` = paste(sprintf("%.2f", r$we), collapse = " "),
    `dlouh. vudci` = if (length(r$lead)) paste(r$lead, collapse = "+") else "-",
    `max p FWA` = sprintf("%.3f", max(r$fwa, na.rm = TRUE)), `homog. p` = sprintf("%.3f", r$hom),
    `kratk. vudci` = if (length(r$srl)) paste(r$srl, collapse = "; ") else "-") }))
print(noquote(rob), right = FALSE)
cat("Pozn.: B – r=1 nepodloženo (boot p > 0.1, kořen > 0.83). D, F – bootstrap r=0 nezamítá, ale nejv. kořen <= 0.83\n",
    "a alfa významná -> r=1 podle D'Adamova postupu (jako Litva a Slovinsko v Tab. 3). F má autokorelovaná rezidua.\n")

# ---- 6. Obrázky ----
cols <- c(PRU="#1f3b73", STA="#c0392b", TRZ="#27ae60", NETRZ="#2e86de", ZEM="#d68910")
rec_t <- function(sp) t(sapply(which(tt == "2010-Q4"):Tt, function(e) {
  ft <- fit_spec(sp, 1:e); ft$v$alpha[, 1] / ft$v$se["ect1", ] * sign(ft$v$beta[5, 1]) }))
png("fig_5_stabilita.png", 1600, 1100, res = 150); par(mfrow = c(2, 1), mar = c(3, 4, 2.5, 1))
xr <- seq(2010.75, by = 0.25, length.out = Tt - which(tt == "2010-Q4") + 1)
for (nm in c("A", HLAVNI)) {
  tv <- rec_t(specs[[nm]])
  matplot(xr, tv, type = "l", lty = 1, lwd = 1.6, col = cols[V5], ylim = range(c(tv, -3, 3)), xlab = "", ylab = "t(alfa)",
          main = sprintf("Rekurzivní t-hodnoty alfa, spec. %s (%s)", nm, specs[[nm]]$popis), cex.main = 0.9)
  abline(h = c(-1.96, 0, 1.96), lty = c(2, 3, 2), col = "grey50")
  legend("topleft", V5, col = cols[V5], lwd = 2, bty = "n", ncol = 5, cex = 0.8)
}
dev.off()
v <- res[[HLAVNI]]$v; ect <- ts(res[[HLAVNI]]$d$Z1 %*% v$beta, start = c(2000, v$d$K), frequency = 4)   # ECT_{t-1}
png("fig_6_ect_hlavni.png", 1600, 700, res = 150); par(mar = c(3, 4, 2, 1))
plot(ect - mean(ect), lwd = 1.6, col = "#1f3b73", ylab = "log",
     main = sprintf("Odchylka od dlouhodobé rovnováhy, spec. %s (trend v CI)", HLAVNI))
abline(h = 0, lty = 3); abline(v = c(2008, 2013, 2020.25), lty = 2, col = "grey60"); dev.off()
cat("\nHotovo.\n")
