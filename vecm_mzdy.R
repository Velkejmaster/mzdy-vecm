# =====================================================================
# VECM mezd podle skupin odvětví CZ-NACE (2000Q1–2026Q2)
# Vstup: mzdy.csv (sekce A–S + Celkem). Výstupy: konzole + obrázky fig_*.png
# Balíčky: urca, vars, seasonal (X-13), strucchange
# =====================================================================
suppressMessages({library(urca); library(vars); library(seasonal); library(strucchange)})

# ---- 1. Agregace do skupin (stejně jako skupiny_nace.R, ASCII kódy) ----
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

# ---- 2. Sezónní očištění X-13 (residuální sezónnost v NSA datech rozbíjí rezidua VECM) ----
S <- ts(sapply(V5, function(v) log(final(seas(ts(W[[v]], start=c(2000,1), frequency=4), x11=""))) ),
        start=c(2000,1), frequency=4)
colnames(S) <- V5

# ---- 3. Jednotkové kořeny ----
cat("== ADF (trend) / ADF diference (drift) / KPSS ==\n")
print(round(t(sapply(V5, function(v) c(
  ADF_lvl  = ur.df(S[,v], type="trend", lags=6, selectlags="BIC")@teststat[1],
  ADF_diff = ur.df(diff(S[,v]), type="drift", lags=6, selectlags="BIC")@teststat[1],
  KPSS_lvl = ur.kpss(S[,v], type="tau", lags="short")@teststat,
  KPSS_dif = ur.kpss(diff(S[,v]), type="mu", lags="short")@teststat))), 2))
cat("cv5: -3.43 / -2.88 / 0.146 / 0.463\n")

# ---- 4. Impulsní dummy (nerestringované) ----
imp <- function(q) as.numeric(tt == q)
DUM <- cbind(d08q1 = imp("2008-Q1"),   # přesun odměn z 12/2007 do 2008 (rovná daň)
             d13q1 = imp("2013-Q1"),   # přesun odměn do 12/2012 (solidární přirážka od 2013)
             d20q2 = imp("2020-Q2"), d20q3 = imp("2020-Q3"),   # COVID, Antivirus
             d21q2 = imp("2021-Q2"))   # covidové odměny ve zdravotnictví (Q je v TRZ)

# ---- 5. Rank test ----
X <- S[, V5]
print(VARselect(X, lag.max=8, type="const", exogen=DUM)$selection)
K <- 2
jo <- ca.jo(X, type="trace", ecdet="none", K=K, spec="transitory", dumvar=DUM)
je <- ca.jo(X, type="eigen", ecdet="none", K=K, spec="transitory", dumvar=DUM)
n <- 5; Tn <- Tt - K
cat("\n== Johansen, 5 skupin, K=2, neomezená konstanta ==\n")
print(data.frame(H0=paste0("r<=",0:4), lambda=round(jo@lambda[1:5],3),
  trace=round(rev(jo@teststat),2), trace_RA=round(rev(jo@teststat)*(Tn-n*K)/Tn,2), cv5=rev(jo@cval[,2]),
  maxeig=round(rev(je@teststat),2), cv5_me=rev(je@cval[,2])), row.names=FALSE)
j4 <- ca.jo(X[,1:4], type="trace", ecdet="none", K=K, spec="transitory", dumvar=DUM)
cat("\nBez zemědělství: trace", round(rev(j4@teststat),2), " cv5", rev(j4@cval[,2]), "\n")

# ---- 6. Restrikce na beta a alpha ----
cat("\n== LR testy (r=1) ==\n")
for (i in 1:5) cat(sprintf("beta_%-6s = 0: p=%.3f | alpha_%-6s = 0: p=%.3f\n", V5[i],
  blrtest(jo, H=diag(5)[,-i], r=1)@pval[1], V5[i], alrtest(jo, A=diag(5)[,-i], r=1)@pval[1]))
H_hom <- cbind(c(1,-1,0,0,0), c(1,0,-1,0,0), c(1,0,0,-1,0), c(1,0,0,0,-1))
cat(sprintf("homogenita sum(beta)=0: p=%.3f\n", blrtest(jo, H=H_hom, r=1)@pval[1]))
H3 <- cbind(c(1,0,0,0,-1), c(0,1,0,0,-1), c(0,0,0,1,-1))          # beta_TRZ=0 + homogenita
A3 <- diag(5)[, c(1,2,5)]                                          # TRZ, NETRZ slabě exogenní
tb <- blrtest(jo, H=H3, r=1); tab <- ablrtest(jo, H=H3, A=A3, r=1)
cat(sprintf("beta_TRZ=0 & homogenita: LR=%.2f, df=2, p=%.3f\n", tb@teststat, tb@pval[1]))
cat(sprintf("+ alpha_TRZ=alpha_NETRZ=0: LR=%.2f, df=4, p=%.3f\n", tab@teststat, tab@pval[1]))

# ---- 7. Finální (restringovaný) VECM ----
vr <- cajorls(tb, r=1); sm <- summary(vr$rlm); beta <- vr$beta[,1]
cat("\nbeta:", round(beta, 3), "\n")
al <- t(sapply(sm, function(x) coef(x)["ect1", ])); print(round(al, 4))
rho <- 1 + sum(beta * al[,1]); cat(sprintf("1+beta'alpha = %.3f, poločas = %.1f Q\n", rho, log(.5)/log(rho)))
for (nm in names(sm)) { cat("\n--", nm, "--\n"); print(round(coef(sm[[nm]]), 4)) }
ect <- ts(X %*% beta, start=c(2000,1), frequency=4)
cat(sprintf("\nECT: ADF=%.2f, KPSS=%.3f\n", ur.df(ect, type="drift", lags=4, selectlags="BIC")@teststat[1],
            ur.kpss(ect, type="mu", lags="short")@teststat))

# ---- 8. Diagnostika ----
vv <- vec2var(jo, r=1)   # úrovňový VAR (vec2var neumí restringované beta; beta jsou téměř shodná)
cat("\n== Multivariátní diagnostika (p) ==\n")
print(round(c(PT12 = serial.test(vv, lags.pt=12, type="PT.adjusted")$serial$p.value,
  LM1 = serial.test(vv, lags.bg=1, type="ES")$serial$p.value,
  LM4 = serial.test(vv, lags.bg=4, type="ES")$serial$p.value,
  JB = normality.test(vv)$jb.mul$JB$p.value, Skew = normality.test(vv)$jb.mul$Skewness$p.value,
  Kurt = normality.test(vv)$jb.mul$Kurtosis$p.value, ARCH4 = arch.test(vv, lags.multi=4)$arch.mul$p.value), 3))
R <- residuals(vr$rlm); colnames(R) <- V5
cat("\n== Univariátní diagnostika restringovaného VECM (p) ==\n")
print(round(sapply(V5, function(v) { x <- R[,v]; z <- (x-mean(x))/sd(x); L <- embed(x^2, 5)
  c(LB4 = Box.test(x, 4, "Ljung")$p.value, LB12 = Box.test(x, 12, "Ljung")$p.value,
    JB = 1-pchisq(length(x)/6*(mean(z^3)^2+(mean(z^4)-3)^2/4), 2), exKurt = mean(z^4)-3,
    ARCH4 = 1-pchisq(nrow(L)*summary(lm(L[,1]~L[,-1]))$r.squared, 4)) }), 3))
A <- vv$A; p <- length(A); Cm <- matrix(0, n*p, n*p); Cm[1:n,] <- do.call(cbind, A); Cm[(n+1):(n*p), 1:(n*(p-1))] <- diag(n*(p-1))
cat("\nModuly kořenů:", round(sort(Mod(eigen(Cm)$values), decreasing=TRUE), 3), "\n")
Yd <- vr$rlm$model[[1]]; Xd <- vr$rlm$model[[2]]
cat("OLS-CUSUM p:", sapply(1:5, function(j) round(sctest(efp(Yd[,j] ~ Xd - 1, type="OLS-CUSUM"))$p.value, 3)), "\n")

st0 <- which(tt == "2010-Q4")
rec <- t(sapply(st0:Tt, function(e) {
  D <- DUM[1:e, colSums(DUM[1:e,,drop=FALSE]) > 0, drop=FALSE]
  j <- ca.jo(X[1:e,], type="trace", ecdet="none", K=K, spec="transitory", dumvar=D)
  r3 <- blrtest(j, H=H3, r=1); b3 <- r3@V[,1]/r3@V[1,1]
  c(tr0 = unname(rev(j@teststat)[1]), cv0 = unname(rev(j@cval[,2])[1]), STA = unname(b3[2]), NETRZ = unname(b3[4]), ZEM = unname(b3[5]), p_beta = unname(r3@pval[1])) }))

# ---- 9. Krátkodobé vazby ----
G <- matrix(NA, 5, 5, dimnames=list(cause=V5, eq=V5))
for (i in 1:5) for (j in 1:5) G[j,i] <- coef(sm[[i]])[paste0(V5[j], ".dl1"), 4]
cat("\nKrátkodobá Grangerova kauzalita (p, Δx_j,t-1 v rovnici i):\n"); print(round(G, 3))
cat("\nKorelace reziduí:\n"); print(round(cor(R), 2))
ord <- c("PRU","STA","TRZ","ZEM","NETRZ")
vvO <- vec2var(ca.jo(X[, ord], type="trace", ecdet="none", K=K, spec="transitory", dumvar=DUM), r=1)
set.seed(42)
ir <- irf(vvO, n.ahead=20, ortho=TRUE, boot=TRUE, runs=1000, ci=0.9)
fe <- fevd(vvO, n.ahead=20)
cat("\nFEVD h=20 (%):\n"); print(round(100*t(sapply(ord, function(v) fe[[v]][20,])), 1))

# ---- 10. Obrázky ----
cols <- c(PRU="#1f3b73", STA="#c0392b", TRZ="#27ae60", NETRZ="#2e86de", ZEM="#d68910")
png("fig_1_mzdy.png", 1600, 1000, res=150); par(mfrow=c(2,1), mar=c(3,4,2,1))
ts.plot(S, col=cols[V5], lwd=1.6, main="Log mezd podle skupin (X-13 SA)", ylab="log Kč")
legend("topleft", V5, col=cols[V5], lwd=2, bty="n", ncol=5)
ts.plot(S[,-1] - S[,1], col=cols[V5[-1]], lwd=1.6, main="Relativní mzda vůči průmyslu (log rozdíl)", ylab="")
abline(h=0, lty=3); dev.off()

png("fig_2_ect.png", 1600, 700, res=150); par(mar=c(3,4,2,1))
plot(ect - mean(ect), lwd=1.6, col="#1f3b73", main="Odchylka od dlouhodobé rovnováhy (ECT, demeaned)", ylab="log")
abline(h=0, lty=3); abline(v=c(2008, 2013, 2020.25), lty=2, col="grey60"); dev.off()

png("fig_3_rekurze.png", 1600, 1000, res=150); par(mfrow=c(2,1), mar=c(3,4,2,1))
xr <- seq(2010.75, by=0.25, length.out=nrow(rec))
plot(xr, rec[,"tr0"], type="l", lwd=1.6, ylim=range(rec[,1:2]), main="Rekurzivní trace statistika (H0: r=0)", ylab="", xlab="")
lines(xr, rec[,"cv0"], lty=2, col="red")
k14 <- xr >= 2014
matplot(xr[k14], rec[k14, c("STA","NETRZ","ZEM")], type="l", lty=1, lwd=1.6, col=cols[c("STA","NETRZ","ZEM")],
        ylim=c(-1.5, 1), main="Rekurzivní beta od 2014 (beta_PRU = 1, beta_TRZ = 0, homogenita; dříve neidentifikováno)", ylab="", xlab="")
abline(h=0, lty=3); legend("bottomleft", c("STA","NETRZ","ZEM"), col=cols[c("STA","NETRZ","ZEM")], lwd=2, bty="n", ncol=3)
dev.off()

png("fig_4_irf.png", 2000, 1700, res=150); par(mfrow=c(5,5), mar=c(2,2.5,2,0.5), oma=c(0,2,2,0))
for (rsp in ord) for (sh in ord) {
  y <- 100*cbind(ir$irf[[sh]][,rsp], ir$Lower[[sh]][,rsp], ir$Upper[[sh]][,rsp])
  matplot(0:20, y, type="l", lty=c(1,2,2), col=c(cols[sh], "grey50", "grey50"), lwd=c(1.8,1,1),
          main=paste(sh, "→", rsp), cex.main=0.9, ylab="", xlab=""); abline(h=0, lty=3) }
mtext("Ortogonální IRF (Cholesky PRU→STA→TRZ→ZEM→NETRZ), %, 90% bootstrap CI", outer=TRUE, cex=0.9)
dev.off()
cat("\nHotovo.\n")
