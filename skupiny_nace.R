# Agregace sekcí CZ-NACE do skupin (tab:skupiny_nace)
# Mzda skupiny = průměr mezd sekcí vážený počtem zaměstnanců (FTE)

mzdy <- read.csv2("mzdy.csv", stringsAsFactors = FALSE)

skupiny <- c(
  A = "Zemědělství",
  B = "Průmysl", C = "Průmysl", D = "Průmysl", E = "Průmysl",
  F = "Stavebnictví",
  G = "Tržní služby", H = "Tržní služby", I = "Tržní služby",
  J = "Tržní služby", K = "Tržní služby", L = "Tržní služby",
  M = "Tržní služby", N = "Tržní služby", Q = "Tržní služby",
  O = "Netržní služby", P = "Netržní služby",
  R = "Netržní služby", S = "Netržní služby"
)

sekce <- mzdy[mzdy$sektor != "Celkem", ]
sekce$skupina <- skupiny[sekce$sektor]
stopifnot(!anyNA(sekce$skupina))

sekce$mzdovy_objem <- sekce$mzda * sekce$zamestnanci_fte

agg <- aggregate(cbind(mzdovy_objem, zamestnanci_fte) ~ obdobi + skupina,
                 data = sekce, FUN = sum)
agg$mzda <- round(agg$mzdovy_objem / agg$zamestnanci_fte)
agg <- agg[order(agg$obdobi, agg$skupina), c("obdobi", "skupina", "mzda", "zamestnanci_fte")]

write.csv2(agg, "mzdy_skupiny.csv", row.names = FALSE, fileEncoding = "UTF-8")

# Kontrola: vážený průměr přes všechny skupiny vs. řádek "Celkem"
celkem <- mzdy[mzdy$sektor == "Celkem", c("obdobi", "mzda")]
kontrola <- aggregate(cbind(mzdovy_objem, zamestnanci_fte) ~ obdobi, data = sekce, FUN = sum)
kontrola <- merge(kontrola, celkem, by = "obdobi")
kontrola$rozdil_pct <- 100 * (kontrola$mzdovy_objem / kontrola$zamestnanci_fte / kontrola$mzda - 1)
cat("Max. odchylka od 'Celkem' (%):", round(max(abs(kontrola$rozdil_pct)), 2), "\n")

print(head(agg, 10))
