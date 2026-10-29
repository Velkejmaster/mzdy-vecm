# VECM pro mzdy ve skupinách CZ-NACE (bez zemědělství)
# Vstup: mzdy_skupiny.csv (výstup skupiny_nace.R)

suppressPackageStartupMessages({
  library(urca)
  library(vars)
})

d <- read.csv2("mzdy_skupiny.csv", stringsAsFactors = FALSE, encoding = "UTF-8")
d <- d[d$skupina != "Zemědělství", ]

w <- reshape(d[, c("obdobi", "skupina", "mzda")], idvar = "obdobi",
             timevar = "skupina", direction = "wide")
w <- w[order(w$obdobi), ]
kratke <- c("Průmysl" = "PRU", "Stavebnictví" = "STA",
            "Tržní služby" = "TRZ", "Netržní služby" = "NET")
names(w) <- sub("^mzda\\.", "", names(w))
y <- log(as.matrix(w[, names(kratke)]))
colnames(y) <- kratke
y <- ts(y, start = c(2000, 1), frequency = 4)
# Sezónní očištění STL: sezónnost se v čase mění (pokles mezd v Q1 slábne),
# což pevné sezónní dummy nezachytí a zůstává to v autokorelaci reziduí
y_raw <- y
for (v in colnames(y)) {
  y[, v] <- y_raw[, v] - stl(y_raw[, v], s.window = 13)$time.series[, "seasonal"]
}
cat("Vzorek:", w$obdobi[1], "-", tail(w$obdobi, 1), " T =", nrow(y), "\n\n")

# --- 1. Testy jednotkového kořene ------------------------------------------
cat("=== ADF testy, sezónně očištěno (log úrovně: trend; 1. diference: drift) ===\n")
for (v in colnames(y)) {
  # deterministická sezónnost odstraněna regresí na čtvrtletní dummy
  q <- factor(cycle(y))
  ys <- residuals(lm(y[, v] ~ q))
  a1 <- ur.df(ys, type = "trend", lags = 8, selectlags = "BIC")
  a2 <- ur.df(diff(ys), type = "drift", lags = 8, selectlags = "BIC")
  cat(sprintf("%s  úroveň tau3 = %6.2f (5%% kv. %.2f) | diference tau2 = %6.2f (5%% kv. %.2f)\n",
              v, a1@teststat[1], a1@cval[1, 2], a2@teststat[1], a2@cval[1, 2]))
}

# --- 2. Deterministika: COVID + impulzy pro přesuny odměn ------------------
covid <- ts(0, start = c(2000, 1), end = end(y), frequency = 4)
window(covid, start = c(2020, 2), end = c(2020, 2)) <- 1
exo <- matrix(covid, dimnames = list(NULL, "covid"))
# Odlehlá rezidua: přesuny prémií kvůli daňovým změnám (2008 rovná daň,
# 2013 solidární přirážka), krize 2009-10 a 2021Q4
impulzy <- c("2008-Q1", "2009-Q1", "2010-Q1", "2012-Q4", "2013-Q1", "2021-Q4")
for (q in impulzy) {
  exo <- cbind(exo, as.numeric(w$obdobi == q))
  colnames(exo)[ncol(exo)] <- paste0("d", sub("-", "", q))
}

sel <- VARselect(y, lag.max = 8, type = "const", exogen = exo)
cat("\n=== Volba zpoždění VAR v úrovních ===\n"); print(sel$selection)
# K = 4 (jeden rok): nejlepší diagnostika mezi K = 2..5,
# hodnost r = 1 vychází pro všechna K stejně
K <- 4
cat("Použito K =", K, "\n")

# --- 3. Johansenův test kointegrace -----------------------------------------
# Konstanta v kointegračním vztahu (trend v CI prostoru byl nevýznamný, LR p = 0.52)
jo <- ca.jo(y, type = "trace", ecdet = "const", K = K, spec = "transitory",
            dumvar = exo)
cat("\n=== Johansen trace test ===\n")
print(cbind(stat = round(jo@teststat, 2), jo@cval))
jo_e <- ca.jo(y, type = "eigen", ecdet = "const", K = K, spec = "transitory",
              dumvar = exo)
cat("\n=== Johansen max-eigen test ===\n")
print(cbind(stat = round(jo_e@teststat, 2), jo_e@cval))

r <- sum(rev(jo@teststat) > rev(jo@cval[, "5pct"]) &
           cumprod(rev(jo@teststat) > rev(jo@cval[, "5pct"])))
if (r == 0) r <- 1
cat("\nZvolená hodnost kointegrace r =", r, "\n")

# --- 4. Dlouhodobé vazby: beta, alfa -------------------------------------
vecm <- cajorls(jo, r = r)
cat("\n=== Kointegrační vektory (beta, normalizace na PRU) ===\n")
print(round(vecm$beta, 4))
cat("\n=== Adjustační koeficienty (alfa) a krátkodobá dynamika ===\n")
sm <- summary(vecm$rlm)
for (nm in names(sm)) {
  cf <- coef(sm[[nm]])
  keep <- grepl("^ect|\\.dl", rownames(cf))
  cat("\n", nm, "\n", sep = "")
  print(round(cf[keep, c(1, 2, 4)], 4))
}

cat("\nbeta\' * alfa (rychlost návratu ECT, má být < 0):",
    round(sum(vecm$beta[1:4, 1] * coef(vecm$rlm)["ect1", ]), 4), "\n")
cat("\n=== Testy slabé exogenity (alfa_i = 0) ===\n")
for (i in seq_len(ncol(y))) {
  A <- diag(ncol(y))[, -i, drop = FALSE]
  t <- alrtest(jo, A = A, r = r)
  cat(sprintf("%s: LR = %6.2f, p = %.3f\n", colnames(y)[i],
              t@teststat, t@pval[1]))
}

if (r == 1) {
  cat("\n=== Test homogenity (součet beta mezd = 0, tj. paritní mzdy) ===\n")
  # beta = (b1,b2,b3,b4,const), restrikce b1+b2+b3+b4 = 0
  H <- rbind(c(1, 0, 0, 0), c(0, 1, 0, 0), c(0, 0, 1, 0),
             c(-1, -1, -1, 0), c(0, 0, 0, 1))
  t1 <- blrtest(jo, H = H, r = r)
  cat(sprintf("LR = %.2f, p = %.3f\n", t1@teststat, t1@pval[1]))
  cat("Restringovaný vektor:", round(t1@V[, 1] / t1@V[1, 1], 4), "\n")
}

# --- 5. Krátkodobé vazby: Grangerova kauzalita v diferencích ---------------
cat("\n=== Krátkodobá Grangerova kauzalita (Wald na zpožděných diferencích) ===\n")
m <- vecm$rlm
for (eq in colnames(y)) {
  for (src in colnames(y)) if (src != eq) {
    reg <- paste0("^", src, "\\.dl")
    idx <- grep(reg, rownames(coef(m)))
    if (!length(idx)) next
    b <- coef(m)[idx, paste0(eq, ".d")]
    V <- vcov(m)
    nm <- paste0(eq, ".d:", rownames(coef(m))[idx])
    W <- as.numeric(t(b) %*% solve(V[nm, nm, drop = FALSE]) %*% b)
    cat(sprintf("%s -> %s: Wald = %6.2f, p = %.3f\n", src, eq, W,
                pchisq(W, length(idx), lower.tail = FALSE)))
  }
}

# --- 6. Diagnostika --------------------------------------------------------
v2v <- vec2var(jo, r = r)
cat("\n=== Diagnostika rezidui ===\n")
print(serial.test(v2v, lags.pt = 12, type = "PT.adjusted"))
print(serial.test(v2v, lags.bg = 4, type = "BG"))
print(arch.test(v2v, lags.multi = 4))
print(normality.test(v2v)$jb.mul)
cat("\nJednorovnicové testy normality (JB p-hodnoty):\n")
res <- residuals(v2v)
jb <- function(e) {
  e <- e - mean(e); n <- length(e); s2 <- mean(e^2)
  S <- mean(e^3) / s2^1.5; Kt <- mean(e^4) / s2^2
  pchisq(n / 6 * (S^2 + (Kt - 3)^2 / 4), 2, lower.tail = FALSE)
}
print(round(apply(res, 2, jb), 3))

cat("\n=== Stabilita: moduly kořenů companion matice ===\n")
A <- v2v$A; kk <- length(A); n <- ncol(y)
comp <- matrix(0, n * kk, n * kk)
comp[1:n, ] <- do.call(cbind, A)
if (kk > 1) comp[(n + 1):(n * kk), 1:(n * (kk - 1))] <- diag(n * (kk - 1))
cat(round(sort(Mod(eigen(comp)$values), decreasing = TRUE), 3), "\n")
cat("(očekáváno n - r =", n - r, "jednotkových kořenů, ostatní < 1)\n")

# --- 7. Impulzní odezvy (dlouhodobé efekty šoků) -------------------------
pdf("vecm_irf.pdf", width = 9, height = 7)
plot(irf(v2v, n.ahead = 20, boot = TRUE, runs = 500, ortho = TRUE))
dev.off()
pdf("vecm_ect.pdf", width = 8, height = 4)
plot(ts(cbind(y, 1) %*% vecm$beta, start = c(2000, 1), frequency = 4),
     main = "Odchylka od dlouhodobé rovnováhy (ECT)", ylab = "")
abline(h = 0, lty = 2)
dev.off()
