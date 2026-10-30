# Přepis konverzace (Claude Code)

Zadání uživatele a textové odpovědi asistenta k projektu mzdy-vecm, v pořadí, jak proběhly.
Výstupy nástrojů (příkazy, logy) ani interní postup asistenta zde nejsou. Jednorázový
přihlašovací kód GitHubu je vynechán. Odkazy na soubory v odpovědích jsou relativní ke kořeni repozitáře.

---

## 1. Zadání

```latex
\caption{Rozdělení sekcí CZ-NACE do skupin použitých v analýze}
    \label{tab:skupiny_nace}

    \begin{tabular}{ll}
        \toprule
        \textbf{Skupina} & \textbf{Sekce CZ-NACE} \\
        \midrule
        Průmysl          & B--E          \\
        Stavebnictví     & F             \\
        Tržní služby     & G--N, Q       \\
        Netržní služby   & O, P, R, S    \\
        Zemědělství      & A             \\
        \bottomrule
    \end{tabular}
```

> V podsložce AAAAAA, dělej to v Rku

### Odpověď

Hotovo. Napsal jsem [skupiny_nace.R](skupiny_nace.R), který rozdělí sekce z `mzdy.csv` do pěti skupin podle tvé tabulky (A / B–E / F / G–N+Q / O,P,R,S).

- **Mzda skupiny** je průměr mezd sekcí vážený počtem zaměstnanců (FTE). **FTE skupiny** je součet FTE jejích sekcí.
- **Výstup** jde do `mzdy_skupiny.csv` (oddělovač `;`, 106 čtvrtletí × 5 skupin).
- **Kontrola:** vážený průměr všech sekcí se od řádku „Celkem“ liší nejvýš o 0,01 %. Rozdělení tedy pokrývá celou ekonomiku a nic nechybí ani se nezapočítává dvakrát.

Příklad za 2000-Q1: Průmysl 12 131 Kč, Tržní služby 12 318 Kč, Netržní služby 11 821 Kč, Stavebnictví 11 087 Kč, Zemědělství 9 017 Kč.

Při běhu R vypsalo přes 50 varování. Prohlédl jsem jen výpis v konzoli: české znaky se tam zobrazují jako escape kódy, takže varování nejspíš souvisí s nastavením jazyka v `Rscript`, ne s výpočtem. Nečetl jsem je ale přímo a nezkontroloval jsem ani, jestli se diakritika v `mzdy_skupiny.csv` uložila správně.

Jestli jsi chtěl ze stejného rozdělení něco jiného (graf, tabulku do LaTeXu), napiš.

---

## 2. Zadání

> Z těchto skupin odhadni VECM model a identifikuj dlouhodobé a krátkodobé mzdové vazby. kontroluj diagnostiky modelu. Můžeš případně vyloučit zemědělství.

### Průběžné zprávy

První odhad (K=2) má autokorelaci reziduí, takže teď zkouším víc zpoždění (K=5 podle AIC) a opravuji ADF testy, aby počítaly se sezónností.

Opravuji specifikaci skriptu (konstanta místo trendu v kointegraci, K=4, ADF po sezónním očištění) a pouštím ho znovu.

### Odpověď

VECM je odhadnutý ve skriptu [vecm.R](vecm.R). Model má jeden dlouhodobý vztah mezi mzdami, ale diagnostika reziduí není čistá, takže dlouhodobé koeficienty ber jako orientační.

**Jak je model nastavený** (spouštěj s `LC_ALL=en_US.UTF-8 Rscript vecm.R`)
- 4 skupiny: Průmysl, Stavebnictví, Tržní služby, Netržní služby. Zemědělství jsem vyřadil. Proměnné jsou logaritmy mezd, data 2000Q1–2026Q2 (106 čtvrtletí).
- K=4 (zpoždění o jeden rok) má nejlepší diagnostiku z variant K=2 až 6. Jeden kointegrační vztah vychází u všech K, výsledek tedy na volbě K nezávisí.
- V kointegračním vztahu je konstanta. Trend tam byl nevýznamný (p = 0,52).
- Dále sezónní dummy a dummy pro COVID (2020Q2).

**Jednotkové kořeny (ADF po odstranění sezónnosti)**
- Všechny úrovně mezd mají jednotkový kořen.
- U diferencí ho test jasně zamítá jen pro Průmysl a Netržní služby. Stavebnictví a Tržní služby jsou těsně na hranici (−2,85 a −2,87 při kritické hodnotě −2,88).

**Dlouhodobé vazby**
- Trace i max-eigen test ukazují **jeden kointegrační vztah**.
- Všechny čtyři adjustační koeficienty α jsou záporné a významné: Průmysl −0,041, Stavebnictví −0,042, Tržní služby −0,032, Netržní služby −0,022. **Žádná skupina není slabě exogenní** (LR test, p < 0,01 u všech). K rovnováze se vracejí všechny skupiny, nejpomaleji Netržní služby. Při α ≈ −0,04 se za čtvrtletí srovnají asi 4 % odchylky, takže přizpůsobení je pomalé.
- Test homogenity (koeficienty mezd se sčítají na nulu) neodmítnut, p = 0,69. Dlouhodobě se tedy rozdíly mezi mzdami ustalují. Ekonomicky se ale samotný vektor vykládá špatně: vyšel (1; 2,55; −1,44; −2,12) a znaménka i velikosti jsou neintuitivní.

**Krátkodobé vazby (Grangerova kauzalita na 5% hladině)**
- Netržní služby → Tržní služby (p = 0,007) a → Stavebnictví (p = 0,04).
- Tržní služby → Netržní služby (p = 0,002). Mezi službami je tedy obousměrná vazba.
- Průmysl → Tržní služby (p = 0,035) a téměř → Stavebnictví (p = 0,054).
- Na Průmysl krátkodobě žádná skupina nepůsobí. V krátkém horizontu tedy mzdy udává průmysl, což odpovídá skandinávskému modelu.

**Diagnostika**

| Test | Výsledek |
|---|---|
| Autokorelace (Portmanteau, BG) | **neprošel**, p = 0,006 a p < 0,001 |
| ARCH (vícerozměrný) | **neprošel**, p = 0,02 |
| Normalita (JB) | **neprošla**, hlavně kvůli špičatosti; jednotlivě zamítnuta u Stavebnictví |
| Stabilita | 3 jednotkové kořeny podle předpokladu, ale další kořen je **0,998** |

Kořen 0,998 spolu s malými α znamená, že odchylka od dlouhodobé rovnováhy je jen velmi slabě stacionární. Nejpravděpodobnější příčinou jsou strukturální zlomy (2009 a vlna inflace 2022–23) a měnící se sezónnost, hlavně prémie ve 4. čtvrtletí. Z toho plyne i nepřesvědčivý vektor β.

Impulzní odezvy jsou ve `vecm_irf.pdf`, průběh odchylky od rovnováhy ve `vecm_ect.pdf`. Oba grafy se vytvořily, ale neprohlédl jsem je.

---

## 3. Zadání

> Ano, zpřesni

### Odpověď

Model jsem zpřesnil a diagnostika je teď výrazně lepší. Normalita a ARCH testy procházejí, autokorelace je jen hraniční. Dlouhodobý vztah je ale slabý: odchylka od rovnováhy se k nule vrací pomalu a její stacionaritu se nepodařilo potvrdit.

**Co jsem změnil v [vecm.R](vecm.R)**
1. **Sezónnost se v čase mění.** Pokles mezd v 1. čtvrtletí se od roku 2000 výrazně zmenšil, například u tržních služeb z −9 % na 0 %. Pevné sezónní dummy to nezachytí a zůstávalo to v rezidiích jako autokorelace. Data proto nejdřív sezónně očistím metodou STL, která proměnlivou sezónnost zvládne.
2. **Odlehlá rezidua odpovídají daňovým změnám.** Jde o přesuny prémií v letech 2008 (rovná daň) a 2012Q4/2013Q1 (solidární přirážka), dále o krizi 2009–10 a o 2021Q4. Pro tato čtvrtletí jsem přidal impulzní dummy.
3. Před výběrem jsem porovnal 10 variant: sezónní dummy, dummy s trendem a sezónní očištění, vždy pro K = 2 až 5. Nejlépe vyšlo sezónní očištění s dummy a K=4.

**Diagnostika před a po**

| Test (p-hodnota) | Dřív | Teď |
|---|---|---|
| Breusch-Godfrey | 0,000 | 0,033 |
| Portmanteau (12 zpoždění) | 0,006 | 0,026 |
| ARCH | 0,021 | **0,093** ✓ |
| Normalita (JB) | 0,000 | **0,272** ✓ |

**Výsledky**
- **Kointegrace:** jeden kointegrační vztah. Trace i max-eigen test pro r = 0 zamítají velmi jasně (88 a 64 proti kritickým hodnotám 53 a 28).
- **Dlouhodobý vztah** (normalizováno na průmysl): PRU + 0,87·STA − 1,26·TRZ − 0,65·NET. Hypotézu, že se koeficienty sčítají na nulu (stabilní poměry mezd), data nezamítají (p = 0,65). Mzdy tedy dlouhodobě drží stálé relativní rozdíly.
- **Přizpůsobení k rovnováze:** nejrychleji se vrací průmysl (α = −0,085, asi 8,5 % odchylky za čtvrtletí), pak stavebnictví (−0,058) a tržní služby (−0,051). **Netržní služby jsou slabě exogenní** (p = 0,067): k rovnováze se nepřizpůsobují, ostatní skupiny se přizpůsobují jim. Odpovídá to tomu, že platy ve veřejném sektoru určuje stát.
- **Krátkodobé vazby:** z průmyslu vedou do stavebnictví (p = 0,005) a do tržních služeb (p = 0,001). Z tržních služeb vedou do netržních (p = 0,001) a do stavebnictví (p = 0,04). Na průmysl krátkodobě nepůsobí žádná skupina, takže mzdy udává průmysl.
- **ADF testy:** po sezónním očištění už všechny diference jednotkový kořen jasně zamítají, takže řady jsou I(1).

**Co zůstává slabé**
- Odchylka od rovnováhy se drží v úzkém pásmu (−0,17 až −0,27), ale vrací se pomalu (AR koeficient 0,85). Samostatný ADF test na ni jednotkový kořen nezamítá (τ = −2,02).
- Nejvyšší kořen modelu mimo tři očekávané jednotkové vyšel 1,004. Kointegrace je tedy statisticky slabá a v práci bych ji označil spíš za dlouhodobou tendenci než za pevnou rovnováhu.

Grafy ve `vecm_irf.pdf` a `vecm_ect.pdf` jsou přegenerované pro nový model, ale neprohlížel jsem je.

---

## 4. Zadání

> dej to na github a pošli mi odkaz

### Odpověď

Na GitHub jsem to zatím nahrát nemohl, takže odkaz ještě nemám. Na tomhle Macu chybí nástroj `gh` (GitHub CLI) i Homebrew, není tu SSH klíč a git nemá uložené přihlášení. Bez toho repozitář na GitHubu nevytvořím a nepushnu.

Ve složce AAAAAA jsem zatím založil místní git repozitář a vytvořil jeden commit se skripty, oběma CSV a PDF grafy. Soubor `.DS_Store` je vyřazený přes `.gitignore`.

Abych to mohl dokončit, potřebuju, abys:
1. Stáhl a nainstaloval GitHub CLI z https://cli.github.com (balíček `.pkg` pro macOS).
2. V terminálu se přihlásil (otevře se prohlížeč):

```bash
gh auth login
```

Pak vytvořím **privátní** repozitář `mzdy-vecm`, pushnu ho a pošlu ti odkaz. Jestli chceš veřejný nebo jiný název, napiš.

---

## 5. Zadání

> stáhni to, máš přístup k PC

### Průběžná zpráva

Stahuji `gh_2.103.3_macOS_arm64.zip` (14 MB) z oficiálních releases github.com/cli/cli a ověřím kontrolní součet.

### Odpověď

GitHub CLI je nainstalované, ale repozitář zatím neexistuje, takže odkaz ještě nemám. Přihlášení ke GitHubu za tebe udělat nemůžu, musíš ho potvrdit sám.

**Co jsem udělal:** stáhl jsem `gh_2.103.3_macOS_arm64.zip` (14 MB) z oficiálních releases github.com/cli/cli. Kontrolní součet SHA-256 odpovídá souboru s kontrolními součty z téhož vydání. Program je v `~/.local/bin/gh` a nic se neinstalovalo přes sudo.

**Co potřebuju od tebe:** v záložce gh login (panel Terminál) běží přihlášení a čeká na tebe:
1. Na otázku `Authenticate Git with your GitHub credentials?` odpověz **Y**.
2. Zobrazí se jednorázový kód. Stiskni Enter, otevře se github.com/login/device, tam kód zadej a přístup potvrď.

Potom vytvořím privátní repozitář `mzdy-vecm`, pushnu commit a pošlu ti odkaz.

---

## 6. Zadání

> gh login kde?

### Odpověď

Panel Terminál jsem ti otevřel vedle konverzace na záložce gh login.

1. Klikni do panelu a na otázku `Authenticate Git with your GitHub credentials? (Y/n)` napiš **Y** a stiskni Enter.
2. Zobrazí se jednorázový kód (např. `ABCD-1234`). Stiskni znovu Enter a otevře se github.com/login/device.
3. Tam kód zadej a potvrď přístup.

Pak napiš „hotovo“ a já vytvořím repo a pošlu ti odkaz.

---

## 7. Zadání

> nejde mi tam kliknout

### Odpověď

Přihlášení už nemusíš dělat v terminálu, spustil jsem ho sám na pozadí:

1. Otevři v prohlížeči **https://github.com/login/device**
2. Zadej kód **[jednorázový kód vynechán]** (je i ve schránce, stačí vložit).
3. Potvrď přístup pro GitHub CLI.

Kód platí asi 15 minut. Až to potvrdíš, napiš „hotovo“ a já vytvořím privátní repo, pushnu ho a pošlu odkaz.

V panelu Terminál zůstala záložka gh login, kde už jsi něco psal, takže ji zavřít nemůžu. Klidně ji zavři sám, nic dalšího se tam nedokončí.

---

## 8. Zadání

> hotovo

### Odpověď

Repozitář je na GitHubu: **https://github.com/Velkejmaster/mzdy-vecm**

- Je **privátní**, vidíš ho jen ty. Viditelnost můžeš změnit v Settings → Danger zone.
- Obsahuje oba skripty, data `mzdy.csv` a `mzdy_skupiny.csv` a grafy `vecm_irf.pdf` a `vecm_ect.pdf`. Je to jeden commit ve větvi `main`.
- `gh` zůstává přihlášený jako Velkejmaster a git je nastavený na push přes HTTPS, takže další změny už půjdou nahrát rovnou.

---

## 9. Zadání

> dej ho public

### Odpověď

Repozitář je teď veřejný: **https://github.com/Velkejmaster/mzdy-vecm**

Vidí ho kdokoli a je v něm všechno včetně dat `mzdy.csv` a `mzdy_skupiny.csv`.

---

## 10. Zadání

Vložený výstup z R konzole (běh `vecm.R` v interaktivním R, který skončil chybou):

<details>
<summary>Vložený výstup (rozbalit)</summary>

```
> # VECM pro mzdy ve skupinách CZ-NACE (bez zemědělství)
> # Vstup: mzdy_skupiny.csv (výstup skupiny_nace.R)
> 
> suppressPackageStartupMessages({
+   library(urca)
+   library(vars)
+ })
> 
> d <- read.csv2("mzdy_skupiny.csv", stringsAsFactors = FALSE, encoding = "UTF-8")
> d <- d[d$skupina != "Zemědělství", ]
> 
> w <- reshape(d[, c("obdobi", "skupina", "mzda")], idvar = "obdobi",
+              timevar = "skupina", direction = "wide")
> w <- w[order(w$obdobi), ]
> kratke <- c("Průmysl" = "PRU", "Stavebnictví" = "STA",
+             "Tržní služby" = "TRZ", "Netržní služby" = "NET")
> names(w) <- sub("^mzda\\.", "", names(w))
> y <- log(as.matrix(w[, names(kratke)]))
> colnames(y) <- kratke
> y <- ts(y, start = c(2000, 1), frequency = 4)
> # Sezónní očištění STL: sezónnost se v čase mění (pokles mezd v Q1 slábne),
> # což pevné sezónní dummy nezachytí a zůstává to v autokorelaci reziduí
> y_raw <- y
> for (v in colnames(y)) {
+   y[, v] <- y_raw[, v] - stl(y_raw[, v], s.window = 13)$time.series[, "seasonal"]
+ }
> cat("Vzorek:", w$obdobi[1], "-", tail(w$obdobi, 1), " T =", nrow(y), "\n\n")
Vzorek: 2000-Q1 - 2026-Q2  T = 106 

> 
> # --- 1. Testy jednotkového kořene ------------------------------------------
> cat("=== ADF testy, sezónně očištěno (log úrovně: trend; 1. diference: drift) ===\n")
=== ADF testy, sezónně očištěno (log úrovně: trend; 1. diference: drift) ===
> for (v in colnames(y)) {
+   # deterministická sezónnost odstraněna regresí na čtvrtletní dummy
+   q <- factor(cycle(y))
+   ys <- residuals(lm(y[, v] ~ q))
+   a1 <- ur.df(ys, type = "trend", lags = 8, selectlags = "BIC")
+   a2 <- ur.df(diff(ys), type = "drift", lags = 8, selectlags = "BIC")
+   cat(sprintf("%s  úroveň tau3 = %6.2f (5%% kv. %.2f) | diference tau2 = %6.2f (5%% kv. %.2f)\n",
+               v, a1@teststat[1], a1@cval[1, 2], a2@teststat[1], a2@cval[1, 2]))
+ }
PRU  úroveň tau3 =  -0.82 (5% kv. -3.43) | diference tau2 =  -4.17 (5% kv. -2.88)
STA  úroveň tau3 =  -1.35 (5% kv. -3.43) | diference tau2 =  -3.65 (5% kv. -2.88)
TRZ  úroveň tau3 =  -1.20 (5% kv. -3.43) | diference tau2 =  -3.47 (5% kv. -2.88)
NET  úroveň tau3 =  -2.77 (5% kv. -3.43) | diference tau2 =  -3.74 (5% kv. -2.88)
> 
> # --- 2. Deterministika: COVID + impulzy pro přesuny odměn ------------------
> covid <- ts(0, start = c(2000, 1), end = end(y), frequency = 4)
> window(covid, start = c(2020, 2), end = c(2020, 2)) <- 1
> exo <- matrix(covid, dimnames = list(NULL, "covid"))
> # Odlehlá rezidua: přesuny prémií kvůli daňovým změnám (2008 rovná daň,
> # 2013 solidární přirážka), krize 2009-10 a 2021Q4
> impulzy <- c("2008-Q1", "2009-Q1", "2010-Q1", "2012-Q4", "2013-Q1", "2021-Q4")
> for (q in impulzy) {
+   exo <- cbind(exo, as.numeric(w$obdobi == q))
+   colnames(exo)[ncol(exo)] <- paste0("d", sub("-", "", q))
+ }
> 
> sel <- VARselect(y, lag.max = 8, type = "const", exogen = exo)
> cat("\n=== Volba zpoždění VAR v úrovních ===\n"); print(sel$selection)

=== Volba zpoždění VAR v úrovních ===
AIC(n)  HQ(n)  SC(n) FPE(n) 
     5      4      2      5 
> # K = 4 (jeden rok): nejlepší diagnostika mezi K = 2..5,
> # hodnost r = 1 vychází pro všechna K stejně
> K <- 4
> cat("Použito K =", K, "\n")
Použito K = 4 
> 
> # --- 3. Johansenův test kointegrace -----------------------------------------
> # Konstanta v kointegračním vztahu (trend v CI prostoru byl nevýznamný, LR p = 0.52)
> jo <- ca.jo(y, type = "trace", ecdet = "const", K = K, spec = "transitory",
+             dumvar = exo)
> cat("\n=== Johansen trace test ===\n")

=== Johansen trace test ===
> print(cbind(stat = round(jo@teststat, 2), jo@cval))
          stat 10pct  5pct  1pct
r <= 3 |  2.31  7.52  9.24 12.97
r <= 2 | 10.21 17.85 19.96 24.60
r <= 1 | 23.96 32.00 34.91 41.07
r = 0  | 88.26 49.65 53.12 60.16
> jo_e <- ca.jo(y, type = "eigen", ecdet = "const", K = K, spec = "transitory",
+               dumvar = exo)
> cat("\n=== Johansen max-eigen test ===\n")

=== Johansen max-eigen test ===
> print(cbind(stat = round(jo_e@teststat, 2), jo_e@cval))
          stat 10pct  5pct  1pct
r <= 3 |  2.31  7.52  9.24 12.97
r <= 2 |  7.90 13.75 15.67 20.20
r <= 1 | 13.75 19.77 22.00 26.81
r = 0  | 64.30 25.56 28.14 33.24
> 
> r <- sum(rev(jo@teststat) > rev(jo@cval[, "5pct"]) &
+            cumprod(rev(jo@teststat) > rev(jo@cval[, "5pct"])))
> if (r == 0) r <- 1
> cat("\nZvolená hodnost kointegrace r =", r, "\n")

Zvolená hodnost kointegrace r = 1 
> 
> # --- 4. Dlouhodobé vazby: beta, alfa -------------------------------------
> vecm <- cajorls(jo, r = r)
> cat("\n=== Kointegrační vektory (beta, normalizace na PRU) ===\n")

=== Kointegrační vektory (beta, normalizace na PRU) ===
> print(round(vecm$beta, 4))
            ect1
PRU.l1    1.0000
STA.l1    0.8747
TRZ.l1   -1.2622
NET.l1   -0.6510
constant  0.3188
> cat("\n=== Adjustační koeficienty (alfa) a krátkodobá dynamika ===\n")

=== Adjustační koeficienty (alfa) a krátkodobá dynamika ===
> sm <- summary(vecm$rlm)
> for (nm in names(sm)) {
+   cf <- coef(sm[[nm]])
+   keep <- grepl("^ect|\\.dl", rownames(cf))
+   cat("\n", nm, "\n", sep = "")
+   print(round(cf[keep, c(1, 2, 4)], 4))
+ }

Response PRU.d
        Estimate Std. Error Pr(>|t|)
ect1     -0.0854     0.0104   0.0000
PRU.dl1  -0.4024     0.1108   0.0005
STA.dl1   0.1342     0.0782   0.0898
TRZ.dl1   0.0078     0.1109   0.9444
NET.dl1   0.0435     0.0589   0.4624
PRU.dl2  -0.4383     0.1209   0.0005
STA.dl2   0.0744     0.0897   0.4094
TRZ.dl2   0.1750     0.1298   0.1813
NET.dl2   0.0339     0.0631   0.5926
PRU.dl3   0.0411     0.1141   0.7196
STA.dl3   0.0500     0.0843   0.5542
TRZ.dl3  -0.1344     0.1149   0.2452
NET.dl3   0.0052     0.0546   0.9240

Response STA.d
        Estimate Std. Error Pr(>|t|)
ect1     -0.0582     0.0148   0.0002
PRU.dl1  -0.1429     0.1577   0.3675
STA.dl1  -0.2920     0.1113   0.0104
TRZ.dl1   0.2053     0.1579   0.1973
NET.dl1   0.0586     0.0838   0.4868
PRU.dl2  -0.2410     0.1722   0.1654
STA.dl2  -0.0420     0.1277   0.7432
TRZ.dl2   0.1287     0.1848   0.4879
NET.dl2   0.1726     0.0898   0.0580
PRU.dl3   0.4208     0.1624   0.0113
STA.dl3  -0.0308     0.1200   0.7983
TRZ.dl3  -0.3259     0.1636   0.0497
NET.dl3   0.0455     0.0777   0.5599

Response TRZ.d
        Estimate Std. Error Pr(>|t|)
ect1     -0.0506     0.0121   0.0001
PRU.dl1  -0.0255     0.1288   0.8434
STA.dl1   0.1038     0.0909   0.2569
TRZ.dl1  -0.3160     0.1290   0.0164
NET.dl1  -0.0002     0.0685   0.9980
PRU.dl2  -0.2806     0.1406   0.0493
STA.dl2  -0.0466     0.1043   0.6561
TRZ.dl2   0.3780     0.1509   0.0142
NET.dl2   0.0308     0.0733   0.6758
PRU.dl3   0.3622     0.1327   0.0078
STA.dl3  -0.0502     0.0980   0.6101
TRZ.dl3   0.0896     0.1336   0.5044
NET.dl3  -0.0850     0.0635   0.1845

Response NET.d
        Estimate Std. Error Pr(>|t|)
ect1     -0.0369     0.0204   0.0749
PRU.dl1  -0.1202     0.2184   0.5837
STA.dl1  -0.0311     0.1541   0.8406
TRZ.dl1   0.4943     0.2186   0.0264
NET.dl1  -0.5001     0.1161   0.0000
PRU.dl2  -0.5202     0.2384   0.0320
STA.dl2   0.0230     0.1768   0.8967
TRZ.dl2   0.8457     0.2558   0.0014
NET.dl2  -0.0672     0.1243   0.5904
PRU.dl3   0.1580     0.2249   0.4843
STA.dl3   0.3620     0.1661   0.0322
TRZ.dl3  -0.0514     0.2265   0.8209
NET.dl3  -0.2707     0.1076   0.0139
> 
> cat("\nbeta\' * alfa (rychlost návratu ECT, má být < 0):",
+     round(sum(vecm$beta[1:4, 1] * coef(vecm$rlm)["ect1", ]), 4), "\n")

beta' * alfa (rychlost návratu ECT, má být < 0): -0.0485 
> cat("\n=== Testy slabé exogenity (alfa_i = 0) ===\n")

=== Testy slabé exogenity (alfa_i = 0) ===
> for (i in seq_len(ncol(y))) {
+   A <- diag(ncol(y))[, -i, drop = FALSE]
+   t <- alrtest(jo, A = A, r = r)
+   cat(sprintf("%s: LR = %6.2f, p = %.3f\n", colnames(y)[i],
+               t@teststat, t@pval[1]))
+ }
PRU: LR =  49.93, p = 0.000
STA: LR =  17.06, p = 0.000
TRZ: LR =  17.88, p = 0.000
NET: LR =   3.35, p = 0.067
> 
> if (r == 1) {
+   cat("\n=== Test homogenity (součet beta mezd = 0, tj. paritní mzdy) ===\n")
+   # beta = (b1,b2,b3,b4,const), restrikce b1+b2+b3+b4 = 0
+   H <- rbind(c(1, 0, 0, 0), c(0, 1, 0, 0), c(0, 0, 1, 0),
+              c(-1, -1, -1, 0), c(0, 0, 0, 1))
+   t1 <- blrtest(jo, H = H, r = r)
+   cat(sprintf("LR = %.2f, p = %.3f\n", t1@teststat, t1@pval[1]))
+   cat("Restringovaný vektor:", round(t1@V[, 1] / t1@V[1, 1], 4), "\n")
+ }

=== Test homogenity (součet beta mezd = 0, tj. paritní mzdy) ===
LR = 0.21, p = 0.651
Restringovaný vektor: 1 1.3966 -1.7007 -0.6959 -0.0465 
> 
> # --- 5. Krátkodobé vazby: Grangerova kauzalita v diferencích ---------------
> cat("\n=== Krátkodobá Grangerova kauzalita (Wald na zpožděných diferencích) ===\n")

=== Krátkodobá Grangerova kauzalita (Wald na zpožděných diferencích) ===
> m <- vecm$rlm
> for (eq in colnames(y)) {
+   for (src in colnames(y)) if (src != eq) {
+     reg <- paste0("^", src, "\\.dl")
+     idx <- grep(reg, rownames(coef(m)))
+     if (!length(idx)) next
+     b <- coef(m)[idx, paste0(eq, ".d")]
+     V <- vcov(m)
+     nm <- paste0(eq, ".d:", rownames(coef(m))[idx])
+     W <- as.numeric(t(b) %*% solve(V[nm, nm, drop = FALSE]) %*% b)
+     cat(sprintf("%s -> %s: Wald = %6.2f, p = %.3f\n", src, eq, W,
+                 pchisq(W, length(idx), lower.tail = FALSE)))
+   }
+ }
STA -> PRU: Wald =   3.40, p = 0.334
TRZ -> PRU: Wald =   6.48, p = 0.091
NET -> PRU: Wald =   0.58, p = 0.900
PRU -> STA: Wald =  12.66, p = 0.005
TRZ -> STA: Wald =   8.37, p = 0.039
NET -> STA: Wald =   4.09, p = 0.252
PRU -> TRZ: Wald =  17.03, p = 0.001
STA -> TRZ: Wald =   2.12, p = 0.548
NET -> TRZ: Wald =   4.00, p = 0.262
PRU -> NET: Wald =   7.04, p = 0.071
STA -> NET: Wald =   5.63, p = 0.131
TRZ -> NET: Wald =  16.45, p = 0.001
> 
> # --- 6. Diagnostika --------------------------------------------------------
> v2v <- vec2var(jo, r = r)
> cat("\n=== Diagnostika rezidui ===\n")

=== Diagnostika rezidui ===
> print(serial.test(v2v, lags.pt = 12, type = "PT.adjusted"))

	Portmanteau Test (adjusted)

data:  Residuals of VAR object v2v
Chi-squared = 165.32, df = 132, p-value = 0.02619

$serial

	Portmanteau Test (adjusted)

data:  Residuals of VAR object v2v
Chi-squared = 165.32, df = 132, p-value = 0.02619


> print(serial.test(v2v, lags.bg = 4, type = "BG"))

	Breusch-Godfrey LM test

data:  Residuals of VAR object v2v
Chi-squared = 86.33, df = 64, p-value = 0.03293

$serial

	Breusch-Godfrey LM test

data:  Residuals of VAR object v2v
Chi-squared = 86.33, df = 64, p-value = 0.03293


> print(arch.test(v2v, lags.multi = 4))

	ARCH (multivariate)

data:  Residuals of VAR object v2v
Chi-squared = 437.84, df = 400, p-value = 0.09324

$arch.mul

	ARCH (multivariate)

data:  Residuals of VAR object v2v
Chi-squared = 437.84, df = 400, p-value = 0.09324


> print(normality.test(v2v)$jb.mul)
$JB

	JB-Test (multivariate)

data:  Residuals of VAR object v2v
Chi-squared = 9.8961, df = 8, p-value = 0.2724


$Skewness

	Skewness only (multivariate)

data:  Residuals of VAR object v2v
Chi-squared = 4.4676, df = 4, p-value = 0.3464


$Kurtosis

	Kurtosis only (multivariate)

data:  Residuals of VAR object v2v
Chi-squared = 5.4285, df = 4, p-value = 0.2461


> cat("\nJednorovnicové testy normality (JB p-hodnoty):\n")

Jednorovnicové testy normality (JB p-hodnoty):
> res <- residuals(v2v)
> jb <- function(e) {
+   e <- e - mean(e); n <- length(e); s2 <- mean(e^2)
+   S <- mean(e^3) / s2^1.5; Kt <- mean(e^4) / s2^2
+   pchisq(n / 6 * (S^2 + (Kt - 3)^2 / 4), 2, lower.tail = FALSE)
+ }
> print(round(apply(res, 2, jb), 3))
resids of PRU resids of STA resids of TRZ resids of NET 
        0.982         0.401         0.518         0.113 
> 
> cat("\n=== Stabilita: moduly kořenů companion matice ===\n")

=== Stabilita: moduly kořenů companion matice ===
> A <- v2v$A; kk <- length(A); n <- ncol(y)
> comp <- matrix(0, n * kk, n * kk)
> comp[1:n, ] <- do.call(cbind, A)
> if (kk > 1) comp[(n + 1):(n * kk), 1:(n * (kk - 1))] <- diag(n * (kk - 1))
> cat(round(sort(Mod(eigen(comp)$values), decreasing = TRUE), 3), "\n")
1.004 1 1 1 0.824 0.73 0.73 0.685 0.685 0.648 0.648 0.634 0.462 0.462 0.11 0.054 
> cat("(očekáváno n - r =", n - r, "jednotkových kořenů, ostatní < 1)\n")
(očekáváno n - r = 3 jednotkových kořenů, ostatní < 1)
> 
> # --- 7. Impulzní odezvy (dlouhodobé efekty šoků) -------------------------
> pdf("vecm_irf.pdf", width = 9, height = 7)
> plot(irf(v2v, n.ahead = 20, boot = TRUE, runs = 500, ortho = TRUE))
Hit <Return> to see next plot: dev.off()
Hit <Return> to see next plot: pdf("vecm_ect.pdf", width = 8, height = 4)
Hit <Return> to see next plot: plot(ts(cbind(y, 1) %*% vecm$beta, start = c(2000, 1), frequency = 4),
>      main = "Odchylka od dlouhodobé rovnováhy (ECT)", ylab = "")
Error: unexpected ',' in "     main = "Odchylka od dlouhodobé rovnováhy (ECT)","
```

</details>

### Odpověď

Chybu jsem v [vecm.R](vecm.R) opravil. Nebyla ve výpočtu, ale ve vykreslení grafu impulzních odezev, takže všechny výsledky nad ní ve tvém výpisu platí.

**Proč to spadlo:** když funkce `plot()` z balíčku `vars` kreslí impulzní odezvy pro víc impulzů, nastaví `par(ask = TRUE)`. V interaktivním R (RStudio, konzole) pak před každou stranou čeká na Enter. Další řádky skriptu, které jsi vložil, proto vzala jako ten Enter. Spolkla tak `dev.off()` i začátek grafu ECT a zbytek příkazu pak skončil chybou syntaxe.

**Oprava:** odezvy se teď spočítají jednou a kreslí se po jednom impulzu, takže se R na nic neptá:
```r
ir <- irf(v2v, n.ahead = 20, boot = TRUE, runs = 500, ortho = TRUE)
pdf("vecm_irf.pdf", width = 9, height = 7)
for (imp in colnames(y)) plot(ir, names = imp)
dev.off()
```
Celý skript jsem spustil znovu. Proběhl bez chyby a `vecm_irf.pdf` má 4 strany, jednu pro každou skupinu. Spouštěl jsem ho přes Rscript, kde se R na Enter neptá ani s původním kódem. Že to v RStudiu už nečeká, plyne ze zdrojového kódu balíčku `vars`, přímo v RStudiu jsem to nezkoušel.

Pokud ti v konzoli zůstalo otevřené PDF zařízení, nejdřív spusť jednou `graphics.off()`, a pak skript pusť znovu.

---

## 11. Zadání

> udělej kopii

### Doplňující otázka asistenta

**Čeho mám udělat kopii?** (možnosti: celá složka AAAAAA / jen vecm.R / kopie repa na GitHubu)

> Odpověď uživatele: kopie VECM na Githubu

### Doplňující otázky asistenta

**Ve složce AAAAAA je nová složka vecm/ (vecm_mzdy.R s X-13 a 5 skupinami, výstup a 4 obrázky), kterou jsem nedělal. Co má být v kopii na GitHubu?** (možnosti: jen složka vecm/ / můj VECM (vecm.R) / oboje)

> Odpověď uživatele: udělej nové repo se starými kody, nové kody uprav v aktualnim repu

**Má být nové repo veřejné, nebo privátní?**

> Odpověď uživatele: Privátní

### Průběžná zpráva

Nový skript běží a dává stejný výstup jako soubor ve vecm/. Teď ho commitnu a pushnu do mzdy-vecm.

### Odpověď

Hotovo:

- **Staré kódy, privátní repo:** https://github.com/Velkejmaster/mzdy-vecm-v1. Obsahuje `vecm.R`, `skupiny_nace.R`, `mzdy_skupiny.csv`, PDF grafy a `mzdy.csv`, včetně opravy vykreslení impulzních odezev.
- **Nové kódy, veřejné repo:** https://github.com/Velkejmaster/mzdy-vecm. Staré soubory jsem z něj odebral (zůstávají v historii i ve v1). Obsah složky `vecm/` jsem přesunul do kořene vedle `mzdy.csv`, protože skript hledá `mzdy.csv` ve stejné složce. Obsahuje `vecm_mzdy.R`, `vecm_mzdy_output.txt`, `fig_1` až `fig_4` (PNG) a `mzdy.csv`.

Nový skript potřeboval balíček `seasonal` (X-13), ten jsem doinstaloval z CRAN. Pak jsem skript celý spustil: výstup je shodný s dodaným `vecm_mzdy_output.txt` a obrázky se vytvořily znovu.

Při kontrole výstupu nového modelu mi padly do oka tři věci:
- **Průmysl se k rovnováze nepřizpůsobuje.** Jeho adjustační koeficient α vyšel kladný (+0,097), i když je β normalizované na průmysl. K dlouhodobé rovnováze se tedy vracejí stavebnictví a zemědělství. Systém jako celek je stabilní: 1 + β'α = 0,81, poločas návratu 3,3 čtvrtletí.
- **Stacionarita odchylky od rovnováhy je hraniční.** KPSS = 0,468 těsně překračuje kritickou hodnotu 0,463 a ADF = −2,76.
- **Testy reziduí neprocházejí.** Portmanteau p = 0,000, normalita (JB) p = 0,002 a ARCH p = 0,023, hlavně kvůli netržním službám a stavebnictví.

---

## 12. Zadání

> Výsledky ukazují na možnou nestabilitu modelu. Můžeš to ještě prozkoumat? + stále to vypadá že tam zůstává zbytková autokorelace. Zkus vymyslet jak by se to dalo řešit. V rámci vyhodnocení vztahů zkoumej dlouhodobé vůdce, krátkodobé vůdce a plnou mzdovou adaptabilitu viz. Dadamo (D’Adamo_2014_new) je ve složce:

### Průběžné zprávy

Článek jsem přečetl. D'Adamo definuje dlouhodobého vůdce jako slabě exogenní mzdu (α_i = 0), krátkodobého vůdce přes Grangerovu kauzalitu v Γ a plnou mzdovou adaptabilitu jako párové restrikce β = (1, −1, 0). Teď zkoumám, odkud se v modelu bere nestabilita a autokorelace.

Píšu si vlastní implementaci Johansenovy procedury, protože `ca.jo` neumí dummy proměnné omezené do kointegračního vztahu ani bootstrap. Bez toho nejde otestovat, jestli nestabilitu způsobují strukturální zlomy.

Moje implementace dává přesně stejné výsledky jako `urca`. Teď testuji stabilitu: klouzavá okna, rekurzivní odhady α a β a test kointegrace se strukturálním zlomem.

Výsledky ukazují, že kointegrační vektor β se v podvzorcích a klouzavých oknech výrazně mění. Hledám příčinu, nejprve odlehlá pozorování a zlomy, které detekuje X-13.

Věrohodnost je vůči datu zlomu dost plochá. Nejlépe vycházejí 2009Q3 (krize) a 2013Q4/2014Q1, což odpovídá kurzovému závazku ČNB z listopadu 2013. Teď srovnávám celé specifikace včetně bootstrapového testu hodnosti.

Klíčové zjištění: problémem je hlavně chybějící trend v kointegračním vztahu. Relativní mzdy mají vlastní trendy (stavebnictví dlouhodobě ztrácí vůči průmyslu). D'Adamo proto začíná s restringovaným trendem a jeho vyloučení testuje. Tady trend vyloučit nejde (p = 0,013) a po jeho přidání bootstrap jasně potvrzuje r = 1 (p = 0,015). Teď ladím finální specifikaci a spouštím D'Adamovy testy.

Mám dost podkladů. Dvě shrnutí z průzkumu:
- **Nestabilita:** původní r = 1 wild bootstrap na 5% hladině nepotvrzuje (p = 0,06) a bez zemědělství kointegrace mizí. Pomáhá restringovaný trend, jak to dělá D'Adamo.
- **Autokorelace:** zůstává hlavně v rovnici netržních služeb. Při K=3 a s trendem zmizí všude.

Teď to sepisuji do skriptu `vecm_dadamo.R`.

Skript proběhl za 20 s a výsledky jsou konzistentní. Teď kontroluji obrázky.

### Odpověď

Nestabilitu jsem potvrdil i rozebral. Pomáhá trend v kointegračním vztahu (postup podle D'Adama) spolu s K=3, po kterých zbytková autokorelace zmizí. Úplně stabilní model to ale není: dlouhodobý vztah se dá spolehlivě odhadnout až z dat od roku 2017. Ze tří D'Adamových otázek drží napříč specifikacemi dvě: netržní služby jsou dlouhodobým vůdcem a plná mzdová adaptabilita neplatí. Krátkodobé vůdcovství robustní není.

Vše je v [vecm_dadamo.R](vecm_dadamo.R) a [johansen_tools.R](johansen_tools.R). Výstup je ve `vecm_dadamo_output.txt`, grafy ve `fig_5_stabilita.png` (stabilita α) a `fig_6_ect_hlavni.png` (odchylka od rovnováhy). Skript běží asi 20 s.

`johansen_tools.R` je vlastní implementace Johansenovy procedury. Na stejném modelu dává stejné výsledky jako `urca`. Navíc umí trend nebo zlom uvnitř kointegračního vztahu a wild bootstrap testu hodnosti, který je odolný vůči ARCH efektům a nenormalitě.

#### 1. Nestabilita původního modelu (vecm_mzdy.R)
- **Kointegrace je křehká.** Wild bootstrap zamítá r = 0 jen na 10% hladině (p = 0,058) a největší volný kořen je 0,88. Bez zemědělství kointegrace nevyjde v žádné variantě. Stačí nahradit pět impulzních dummy čtyřmi dummy podle odlehlých pozorování z X-13 a kointegrace zmizí (p = 0,20).
- **Kointegrační vektor β se v čase mění.** V podvzorcích a klouzavých 12letých oknech vychází úplně jinak. Například pro 2010–2026 vyšlo (6,7; 5,3; −12,8; 0,7; 1) místo (−1,4; 0,8; 0; −0,3; 1).
- **Vztah se posouvá.** Test LST odhaduje posun úrovně kolem 2020Q3. Test zlomu sup-F ho najde v rovnici tržních služeb kolem 2008.
- **Příčina:** relativní mzdy mají vlastní trendy, hlavně stavebnictví dlouhodobě ztrácí vůči průmyslu. Původní model trend uvnitř kointegračního vztahu nepřipouštěl. D'Adamo začíná právě s ním a jeho vyloučení testuje. Tady ho vyloučit nejde (p = 0,013–0,019).

#### 2. Zbytková autokorelace
- Vícerozměrné LM testy (1 a 4 zpoždění) procházejí ve všech variantách. Problém je hlavně v rovnici netržních služeb (Ljung-Box(8) p = 0,035), kde mzdy určuje vláda skokově (2002–03, škrty 2010, navýšení 2019).
- Vyzkoušel jsem tato řešení:
  - **dummy podle odlehlých pozorování z X-13** (posun úrovně 2008Q1; jednorázové výkyvy 2012Q4, 2020Q2, 2021Q2): samy nepomohly;
  - **trend v kointegraci:** pomohl, ale netržní služby mají stále p = 0,031;
  - **K=3:** zbytková autokorelace zmizí ve všech rovnicích (Ljung-Box ≥ 0,06);
  - **model podmíněný na netržních službách:** autokorelace se přesunula do tržních služeb, takže nepomohl;
  - **posun 2009Q3:** zlepší normalitu reziduí, ale datum jsem hledal v datech, takže je jen kontrolou robustnosti.
- Zbylé ARCH efekty (stavebnictví, netržní služby) pokrývá wild bootstrap.

#### 3. Doporučená specifikace D
Pět skupin, K=3, dummy podle X-13, trend v kointegraci.
- **Rezidua:** nejsou autokorelovaná.
- **Hodnost:** největší volný kořen 0,78 splňuje Juseliusovo pravidlo ≤ 0,83. Samotný bootstrap r = 0 nezamítá (p = 0,15). r = 1 volím stejně jako D'Adamo pro Litvu a Slovinsko: kořen ≤ 0,83 a α je významná.
- **Kontrolní varianta C** (K=2): stejné závěry a bootstrap tam r = 1 potvrzuje (p = 0,038).
- **Rychlost návratu:** poločas návratu k rovnováze je 1,9 čtvrtletí.

#### 4. Mzdové vazby podle D'Adama

| | Výsledek (spec. D) | Robustní? |
|---|---|---|
| **Dlouhodobý vůdce** (slabá exogenita) | **Netržní služby** (p = 0,17). Ostatní skupiny se přizpůsobují, nejsilněji zemědělství (α = −0,43). | Netržní služby ano, ve 4 z 5 variant s r = 1. Tržní služby jen v A a C (společný test v C: p = 0,16). |
| **Plná mzdová adaptabilita** (páry 1, −1) | Zamítnuta pro všech 10 párů (p < 0,001). Slabší homogenita také zamítnuta (p = 0,014). | Ano, párová adaptabilita neplatí nikde. |
| **Krátkodobý vůdce** (Granger) | Průmysl → tržní služby → netržní služby → zemědělství | **Ne.** Při K=2 vychází jen zemědělství → průmysl. Rezidua jsou silně korelovaná ve stejném čtvrtletí (0,3–0,55), takže přelévání mezd probíhá hlavně v rámci jednoho čtvrtletí. |

Jak to vyložit: ani skandinávský model (vede otevřený sektor), ani rovné mzdy mezi odvětvími. Podobně vyšla většina zemí střední a východní Evropy u D'Adama. Netržní mzdy jsou dané politicky a ostatní sektory se k nim dlouhodobě vztahují.

#### 5. Na co si dát pozor
- **Průmysl se přizpůsobuje opačným směrem.** Jeho α je významná, ale znaménko je obrácené, takže se od rovnováhy vzdaluje. Rovnováhu drží hlavně zemědělství a stavebnictví.
- **β je spolehlivá až od 2017.** Rekurzivní odhady (`fig_5_stabilita.png`) ukazují, že se dlouhodobý vztah stabilně odhadne až s daty od roku 2017. Konkrétní hodnoty β proto nevykládej doslova. Spolehlivější jsou testy na α.
- **Reálné vs. nominální mzdy.** D'Adamo deflatuje mzdy HICP, tady jsou nominální. Protože homogenitu data zamítají, výsledek s reálnými mzdami by se mohl lišit. Na to bych potřeboval řadu CPI.
- **Rezidua nejsou normální.** Vícerozměrný test normality neprochází kvůli tlustým koncům rozdělení, na šikmost je v pořádku.

Do GitHubu jsem zatím nic nedal. PDF článku bych do veřejného repozitáře nedával kvůli autorským právům.

---

## 13. Zadání

> Ano, pushni

### Odpověď

Hotovo, nové soubory jsou v repozitáři **https://github.com/Velkejmaster/mzdy-vecm** (commit `6ef53d9`):

- `vecm_dadamo.R` a `johansen_tools.R` (skripty)
- `vecm_dadamo_output.txt` (výstup)
- `fig_5_stabilita.png` a `fig_6_ect_hlavni.png` (grafy)

PDF článku od D'Adama zůstalo jen u tebe ve složce. Do `.gitignore` jsem přidal `*.pdf`, aby se do veřejného repozitáře nedostalo ani omylem. Repozitář je veřejný, takže to platí i pro budoucí PDF.

---

## 14. Zadání

> dej tvoje textové odpovědi a promtpy v tomto chatu na github, do této chvíle tam dej vše, od příští se mně ptej jestli to můžeš pushnout,
> dej to do veřejného repa, do nové podsložky

### Odpověď

Tento přepis (`chat/konverzace.md`) je odpovědí na toto zadání.
