#' Pipe operator
#'
#' See \code{\link[magrittr]{\%>\%}} for more details.
#'
#' @name %>%
#' @rdname pipe
#' @keywords internal
#' @export
#' @importFrom magrittr %>%
#' @usage lhs \%>\% rhs
NULL


re_pj <- function() {
  stringr::regex(stringr::str_c(
    "S[/.]A", "LTDA", "EIRELI", " ME$", "ITAU", "FINANCEIR",
    "FINANCIAM", "SEGUR[AO]", "BANCO", "TELE[CF]O", "CARTAO", "CARTOES",
    "PETROB", "FUNDACAO", "ASSOCIACAO", "EDUCACION", "UNIMED", " SA$", "SAUDE",
    "CREDITO", "LOJAS", "CASAS BAHIA", "SANTANDER", "BRADES",
    sep = "|"), ignore_case = TRUE)
}

stat_decision <- function(x) {
  # extrai o teor da decis\u00e3o
  dct <- stringr::str_detect
  re_negaram <- "negaram|neagram|desprovido|nego prov|improced|indef[ei]r|deneg" %>%
    stringr::str_c("nega-se|mantid|n[a\u00e3]o prov|mantiveram|negado prov", sep = "|") %>%
    stringr::str_c("nega prov", sep = "|") %>%
    stringr::regex(ignore_case = TRUE)
  re_parcial <- stringr::regex("parcial|em parte", ignore_case = TRUE)
  re_deram <- stringr::regex("der[ea]m|alteraram|retific|proced|reform|acolh|provido|dar prov", ignore_case = TRUE)
  re_conhec <- stringr::regex("co?nhec", ignore_case = TRUE)
  re_dilig <- stringr::regex("dilig", ignore_case = TRUE)
  re_prejud <- stringr::regex("prejud", ignore_case = TRUE)
  re_acordo <- stringr::regex("acordo|autocom", ignore_case = TRUE)
  re_desist <- stringr::regex("desist|ren[u\u00fa]n", ignore_case = TRUE)
  re_anul <- stringr::regex("anul", ignore_case = TRUE)
  re_extin <- stringr::regex("extin|prescri", ignore_case = TRUE)
  dplyr::case_when(
    dct(x, re_parcial) ~ "parcial",
    dct(x, re_negaram) & dct(x, re_deram) ~ "parcial",
    dct(x, re_negaram) ~ "negou",
    dct(x, re_deram) ~ "aceitou",
    dct(x, re_acordo) ~ "acordo",
    dct(x, re_conhec) ~ "n\u00e3o conhecido",
    dct(x, re_dilig) ~ "dilig\u00eancia",
    dct(x, re_prejud) ~ "prejudicado",
    dct(x, re_desist) ~ "desist\u00eancia",
    dct(x, re_anul) ~ "anulado",
    dct(x, re_extin) ~ "extinto",
    TRUE ~ "outro"
  )
}
stat_decision_criminal_recursos <- function(x) {
  # extrai o teor da decis\u00e3o
  decisao <- stringi::stri_trans_tolower(x)
  decisao <- abjutils::rm_accent(decisao)
  decisao <- case_when(
    str_detect(decisao,"(prej|extin)") ~ "prejudicado/extinto",
    str_detect(decisao,"^(desp|impr)") ~ "improvido",
    str_detect(decisao,"(nao|nega\\w+)\\s+provi.*")~ "improvido",
    str_detect(decisao,"^prove\\w+") ~ "provido",
    str_detect(decisao,"^mantiveram") ~ "improvido",
    str_detect(decisao,"acolh\\w+") ~ "provido",
    str_detect(decisao,"(deram|da\\-*\\s*se|dando\\-*(se)*|comporta|dou|confere\\-se|se\\s*\\-*da|merece)") ~ "provido",
    str_detect(decisao,"parcial\\w*\\sprovi\\w+") ~ "provido",
    str_detect(decisao,"(nao\\sderam|nao\\smerece|se\\snega|nega\\-*\\s*se|negar\\-*\\s*lhe|nao\\scomporta|negram|negararam|nego|negar)") ~ "improvido",
    str_detect(decisao,"(nao\\sconhec\\w+|nao\\sse\\sconhec\\w+)") ~ "n\u00e3o conhecido",
    str_detect(decisao,"^desconh\\w+") ~ "desconhecido",
    str_detect(decisao,"nao\\s+conhec\\w+") ~ "desconhecido",
    str_detect(decisao,"(homolog|desistencia)") ~ "desist\u00eancia",
    str_detect(decisao,"(anular\\w*|nulo|nula|nulidade)") ~ "anulado",
    str_detect(decisao,"diligencia") ~ "convers\u00e3o em dilig\u00eancia",
    TRUE ~ "outro"
  )
  decisao
}
stat_decision_criminal_writ <- function(x) {
  # extrai o teor da decis\u00e3o
  decisao <- stringr::str_to_lower(abjutils::rm_accent(x))
  decisao <- dplyr::case_when(
    str_detect(decisao,"(prej|extin)") ~ "prejudicado/extinto",
    str_detect(decisao,"(indef|inder\\w+)") ~ "denegado",
    str_detect(decisao,"^defer") ~ "concedido",
    str_detect(decisao,",\\s+deferi\\w+") ~ "concedido",
    str_detect(decisao,"(desp|impr)") ~ "denegado",
    str_detect(decisao,"(nao|nega\\w+)\\s+provi.*")~ "improvido",
    str_detect(decisao,"^prov") ~ "concedido",
    str_detect(decisao,"parcial\\sprov\\w+") ~ "concedido",
    str_detect(decisao,"absolv\\w+") ~ "concedido",
    str_detect(decisao, "acolher\\w+|\\bprocedente") ~ "concedido",
    str_detect(decisao,"de*neg") ~ "denegado",
    str_detect(decisao,"^conce\\w+") ~ "concedido",
    str_detect(decisao,"^conhe\\w+") ~ "concedido",
    str_detect(decisao,"nao\\sconhec\\w+") ~ "n\u00e3o conhecido",
    str_detect(decisao,"^desconh\\w+") ~ "desconhecido",
    str_detect(decisao,"(homolog|desistencia)") ~ "desist\u00eancia",
    str_detect(decisao,"(,|e|votos)\\s+conce\\w+")~ "concedido",
    TRUE ~ "outros"
  )
  decisao
}

stat_unanime <- function(x) {
  # verifica se a decis\u00e3o \u00e9 un\u00e2nime
  dct <- stringr::str_detect
  re_unanime <- stringr::regex(
    "v *\\. *u *\\. *|un[a\u00e2]nim|v\\.? ?u$|^vu[, ]|VU\\.?$",
    ignore_case = TRUE
  )
  re_maioria <- stringr::regex("maioria|vencido", ignore_case = TRUE)
  dplyr::case_when(
    dct(x, re_unanime) ~ "unanime",
    dct(x, re_maioria) ~ "maioria",
    TRUE ~ "outro"
  )
}

clean_key <- function(key) {
  # arruma o texto dos titulos das infos basicas
  key %>%
    stringr::str_squish() %>%
    abjutils::rm_accent() %>%
    stringr::str_to_lower()
}

clean_comarca <- function(x) {
  x %>%
    stringr::str_squish() %>%
    abjutils::rm_accent() %>%
    stringr::str_to_upper()
}


parse_real <- function(x) {
  # arruma info de dinheiro
  loc <- readr::locale(decimal_mark = ",", grouping_mark = ".")
  readr::parse_number(x, locale = loc)
}

idade <- function(data_nascimento) {
  tod <- Sys.Date()
  nasc <- as.Date(as.numeric(data_nascimento), origin = "1900-01-01")
  as.numeric(tod - nasc) / 365.242
}
idade_ano <- function(data_nascimento) {
  ano <- lubridate::year(Sys.Date())
  ano - as.numeric(stringr::str_extract(data_nascimento, "[0-9]{4}"))
}
clean_nm <- function(nome) {
  nm <- nome %>%
    stringr::str_to_upper() %>%
    abjutils::rm_accent() %>%
    stringr::str_squish()
  f <- stringr::str_extract(nm, "^[A-Z]+")
  l <- stringr::str_extract(nm, "[A-Z]+$")
  paste(f, l)
}

arruma_titulo <- function(x) {
  dplyr::case_when(
    x == 'nome' ~ 'Nome',
    x == 'info_assunto' ~ 'Assunto',
    x == 'assunto' ~ 'Assunto',
    x == 'camara' ~ 'C\u00e2mara',
    x == 'area' ~ '\u00c1rea',
    x == 'faculdade' ~ 'Faculdade',
    x == 'origem' ~ 'Origem',
    x == 'idade' ~ 'Idade',
    x == 'tem_pos' ~ 'Tem p\u00f3s',
    x == 'tempo_form' ~ 'Tempo formado',
    x %in% c('tempo_', 'tempo_2inst') ~ 'Tempo tribunal',
    x == 'cidade' ~ 'Cidade origem'
  )
}

globalVariables(c('X3', 'area', 'assunto', 'assunto_filho', 'assunto_pai',
                  'ativo_adv', 'before', 'camara', 'case_when',
                  'classe', 'data', 'dec', 'decision', 'decisions',
                  'distribuicao', 'id', 'id1', 'id_lawsuit',
                  'info_comarca', 'info_cruzeiro', 'info_foro', 'info_valor',
                  'movement', 'movimento', 'movs', 'n', 'n_processo',
                  'name', 'origem', 'output', 'part', 'parts', 'passivo_adv',
                  'regime', 'relator', 'role', 'situacao', 'time',
                  'time_clean', 'time_tot', 'tipo_camara',
                  'tipo_litigio', 'tipo_parte', 'unanime', 'valor_da_acao',
                  'value'))
