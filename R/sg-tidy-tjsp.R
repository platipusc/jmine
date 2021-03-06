tidy_tjsp_cposg_data <- function(cposg) {
  re_coma <- "(?<=Comarca de ).*"
  cposg_data <- cposg %>%
    dplyr::filter(return != "error") %>%
    tidyr::unnest(output) %>%
    dplyr::select(id1, file, data) %>%
    tidyr::unnest() %>%
    dplyr::mutate(data = clean_key(data)) %>%
    dplyr::group_by(data) %>%
    dplyr::filter(n() > 1) %>%
    dplyr::group_by(id1, file, data) %>%
    dplyr::summarise(value = paste(unique(value), collapse = "@")) %>%
    dplyr::ungroup() %>%
    tidyr::spread(data, value) %>%
    janitor::clean_names() %>%
    dplyr::rename(n_processo = id1) %>%
    # arrumar
    dplyr::mutate(
      camara = stringr::str_extract(distribuicao, "[0-9]+"),
      camara = stringr::str_pad(camara, 2, "left", "0"),
      tipo_camara = dplyr::case_when(
        stringr::str_detect(distribuicao, "Criminal") ~ "Criminal",
        stringr::str_detect(distribuicao, "Privado") ~ "Privado",
        stringr::str_detect(distribuicao, "Empresarial") ~ "Empresarial",
        stringr::str_detect(distribuicao, "P[u\u00fa]blico") ~ "P\u00fablico",
        stringr::str_detect(distribuicao, "Ambien") ~ "Ambiental",
        stringr::str_detect(distribuicao, "Recup") ~ "Fal\u00eancia e Recupera\u00e7\u00e3o",
        TRUE ~ NA_character_
      ),
      regime = dplyr::case_when(
        stringr::str_detect(distribuicao, "Extraordin") ~ "Extraordin\u00e1ria",
        stringr::str_detect(distribuicao, "\u00aa C\u00e2mara (Reservada )?de.*[^A-Z]$") ~ "Ordin\u00e1ria",
        TRUE ~ "Outro"
      )
    ) %>%
    dplyr::mutate(
      area = dplyr::if_else(area == "Criminal", "Criminal", "Privado")
    ) %>%
    # arrumar
    dplyr::mutate(area = dplyr::case_when(
      area == "Privado" & camara %in% sprintf("%02d", 1:10) ~ "Fam\u00edlia",
      area == "Privado" & camara %in% sprintf("%02d", c(11:24, 37:38)) ~ "Contratos",
      area == "Privado" & camara %in% sprintf("%02d", 25:36) ~ "Imobili\u00e1rio",
      area == "Criminal" ~ "Criminal"
    )) %>%
    tidyr::separate(origem, c("info_comarca", "info_foro", "info_vara"),
                    sep = " / ", extra = "merge", fill = "right") %>%
    dplyr::mutate(
      info_comarca = stringr::str_extract(info_comarca, re_coma),
      info_comarca = clean_comarca(info_comarca),
      info_comarca = dplyr::case_when(
        info_comarca == "S.JOSE DO RIO PARDO" ~ "SAO JOSE DO RIO PARDO",
        info_comarca == "S.P./VIC.CARVALHO/GUARUJA" ~ "GUARUJA",
        info_comarca == 'IPAUCU' ~ 'IPAUSSU',
        info_comarca == 'MOGI-GUACU' ~ 'MOGI GUACU',
        info_comarca == 'MOGI-MIRIM' ~ 'MOGI MIRIM',
        info_comarca == 'SANTA BARBARA D OESTE' ~ "SANTA BARBARA D'OESTE",
        info_comarca == 'FORO DE OUROESTE' ~ 'OUROESTE',
        info_comarca == 'ESTRELA D OESTE' ~ 'ESTRELA DOESTE',
        info_comarca == 'PALMEIRA D OESTE' ~ "PALMEIRA D'OESTE",
        info_comarca == 'SAO LUIZ DO PARAITINGA' ~ 'SAO LUIS DO PARAITINGA',
        TRUE ~ info_comarca
      )
    ) %>%
    tidyr::separate(assunto, c("assunto_pai", "assunto_filho"),
                    sep = " ?- ?", remove = FALSE, extra = "merge",
                    fill = "right") %>%
    dplyr::mutate(info_cruzeiro = stringr::str_detect(valor_da_acao, "[cC]"),
                  info_valor = parse_real(valor_da_acao))

  cposg_data %>%
    dplyr::select(
      n_processo,
      file,
      info_area = area,
      info_classe = classe,
      info_assunto_full = assunto,
      info_assunto_pai = assunto_pai,
      info_assunto_filho = assunto_filho,
      info_camara_nm = distribuicao,
      info_camara_num = camara,
      info_camara_tipo = tipo_camara,
      info_camara_regime = regime,
      info_relator = relator,
      info_comarca,
      info_foro,
      info_status = situacao,
      info_cruzeiro,
      info_valor
    )
}

tidy_tjsp_cposg_parts <- function(cposg) {
  passivo <- c(
    "apelado", "agravado",
    "apelada", "recorrido", #"apdaapte", "apdoapte",
    "ru", "r", "sucitado", "recorrida", "reclamado", "requerido"
  )
  ativo <- c(
    "apelante", "agravante", #"apteapdo", "apteapda",
    "recorrente", "impetrante", "autor", "autora",
    "suscitante", "requerente", "reclamante", "impette/pacient"
  )
  adv <- c("advogado", "advogada")

  cposg_parts <- cposg %>%
    dplyr::filter(return != "error") %>%
    tidyr::unnest(output) %>%
    dplyr::select(id1, file, parts) %>%
    tidyr::unnest() %>%
    dplyr::mutate(
      role = tolower(role),
      part = tolower(part),
      tipo_parte = dplyr::case_when(
        role %in% ativo ~ "ativo",
        role %in% passivo ~ "passivo",
        role %in% adv & part %in% passivo ~ "passivo_adv",
        role %in% adv & part %in% ativo ~ "ativo_adv",
        TRUE ~ "outro"
      )
    ) %>%
    dplyr::group_by(id1, file, tipo_parte) %>%
    dplyr::summarise(name = paste(name, collapse = "\n")) %>%
    dplyr::ungroup() %>%
    tidyr::spread(tipo_parte, name) %>%
    dplyr::mutate(
      ativo_pj = is_pj(ativo),
      passivo_pj = is_pj(passivo),
      tipo_litigio = dplyr::case_when(
        ativo_pj & passivo_pj ~ "nPF-nPF",
        ativo_pj & !passivo_pj ~ "nPF-PF",
        !ativo_pj & passivo_pj ~ "PF-nPF",
        !ativo_pj & !passivo_pj ~ "PF-PF"
      ),
      ativo = clean_part(ativo),
      passivo = clean_part(passivo)
    )

  cposg_parts %>%
    dplyr::select(
      n_processo = id1, file,
      part_ativo = ativo,
      part_ativo_adv = ativo_adv,
      part_passivo = passivo,
      part_passivo_adv = passivo_adv,
      part_tipo_litigio = tipo_litigio
    )
}

tidy_tjsp_cposg_movs <- function(cposg, cut_time = 3) {
  cposg_movs <- cposg %>%
    dplyr::filter(return != "error") %>%
    tidyr::unnest(output) %>%
    dplyr::select(id1, file, movs) %>%
    tidyr::unnest() %>%
    dplyr::filter(movement > "2000-01-01") %>%
    dplyr::arrange(id1, file, movement) %>%
    dplyr::group_by(id1, file) %>%
    dplyr::mutate(before = dplyr::lag(movement, default = 0),
                  time = as.numeric(movement - before)) %>%
    dplyr::summarise(time_tot = as.numeric(diff(range(movement))),
                     # soma todos os tempos menores de cut_time anos
                     time_clean = sum(time[time < 365 * cut_time])) %>%
    dplyr::ungroup() %>%
    dplyr::select(n_processo = id1, file, time_tot, time_clean)
  cposg_movs
}

tidy_tjsp_cposg_dec <- function(cposg) {
  re_adeq <- stringr::regex("ADEQUA", ignore_case = TRUE)
  re_retir <- stringr::regex("RETIRADO DE PAUTA", ignore_case = TRUE)
  re_embargo <- stringr::regex("EMBARGO", ignore_case = TRUE)

  cposg_dec <- cposg %>%
    dplyr::filter(return != "error") %>%
    tidyr::unnest(output) %>%
    dplyr::select(id1, file, decisions) %>%
    tidyr::unnest() %>%
    dplyr::filter(!is.na(decision),
                  !stringr::str_detect(decision, re_adeq),
                  !stringr::str_detect(decision, re_retir),
                  !stringr::str_detect(decision, re_embargo)) %>%
    dplyr::mutate(dec = stat_decision(decision),
                  unanime = stat_unanime(decision)) %>%
    dplyr::arrange(dplyr::desc(date)) %>%
    dplyr::distinct(id1, file, .keep_all = TRUE) %>%
    dplyr::select(n_processo = id1, file,
                  dec_date = date,
                  dec_val = dec,
                  decision,
                  dec_unanime = unanime)
}


#' Tidy TJSP
#'
#' @param path folder that contains cpopg.rds file
#'
#' @export
tidy_tjsp_cposg <- function(path) {

  classes_writ <- c("Mandado de Seguran\u00e7a", "Habeas Corpus", "Revis\u00e3o Criminal")
  classes_recurso <- c("Apela\u00e7\u00e3o", "Agravo de Execu\u00e7\u00e3o Penal", "Recurso em Sentido Estrito")

  cposg <- readr::read_rds(paste0(path, "/cposg.rds"))
  cposg_data <- tidy_tjsp_cposg_data(cposg)
  cposg_parts <- tidy_tjsp_cposg_parts(cposg)
  cposg_movs <- tidy_tjsp_cposg_movs(cposg)
  cposg_dec <- tidy_tjsp_cposg_dec(cposg)

  cposg_data %>%
    dplyr::inner_join(cposg_parts, c("n_processo", "file")) %>%
    dplyr::inner_join(cposg_movs, c("n_processo", "file")) %>%
    dplyr::left_join(cposg_dec, c("n_processo", "file")) %>%
    dplyr::mutate(info_classe_crim = dplyr::case_when(
      info_area == "Criminal" & info_classe %in% classes_writ ~ "Writ",
      info_area == "Criminal" & info_classe %in% classes_recurso ~ "Recurso",
      TRUE ~ "N\u00e3o \u00e9 criminal"
    ))
}
