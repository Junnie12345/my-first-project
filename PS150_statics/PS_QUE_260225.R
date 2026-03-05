rm(list = ls())

# === 1. 套件載入 ===
required_packages <- c("tidyverse", "openxlsx", "writexl", "data.table", "lubridate", "rstatix", "scales", "ggpubr")
for (pkg in required_packages) {
  if (!require(pkg, character.only = TRUE)) install.packages(pkg, dependencies = TRUE)
  library(pkg, character.only = TRUE)
}

# === 2. 設定路徑與讀取資料 ===
base_dir <- "C:\\Users\\ngps9\\OneDrive\\onedrive\\桌面\\PS150_results\\2026\\"
input_file <- paste0(base_dir, "受試者進度紀錄與基本資料260117_clean.xlsx")
output_file <- paste0(base_dir, "QUE分析_Full_260303.xlsx")

# 讀取資料
message("讀取檔案: ", input_file)
data <- read.xlsx(input_file, sheet = "完整資料")

# 性別清洗與欄位名稱英文化 (維持數值化以便統計)
data <- data %>%
  mutate(
    Sex = case_when(
      Sex == "男" ~ "1", Sex == "女" ~ "2",
      Sex %in% c("1", "2") ~ as.character(Sex),
      TRUE ~ NA_character_
    ),
    Sex = as.numeric(Sex)
  ) %>%
  # 【新增】：將中文欄位名稱替換為英文縮寫，完美保留 _pre 與 _post 後綴
  rename_with(~ stringr::str_replace_all(., c(
    "日間活動失能" = "DayDys",
    "睡眠困擾" = "SlpDist",
    "睡眠效率" = "SlpEff",
    "睡眠潛伏期" = "SlpLat",
    "睡眠時長" = "SlpDur",
    "睡眠用藥" = "SlpMed",
    "睡眠評價" = "SlpQual"
  )))


# ==============================================================================
# === 3. 資料前處理 (關鍵修正：直接使用 A/B) ===
# ==============================================================================
message("--- 資料轉換中 ---")

# 1. Wide Format (統計用)
wide_data_pre_post <- data %>%
  # 轉數值
  mutate(across(.cols = contains("_pre") | contains("_post"), .fns = as.numeric)) %>%
  select(ID, Group, contains("_pre"), contains("_post")) %>%
  # [修正] 清除空白、轉大寫後精準映射 A→placebo, B→PS150
  mutate(
    Group_clean = toupper(trimws(as.character(Group))),
    Group = case_when(
      Group_clean %in% c("A", "0", "CONTROL", "C", "\uff21") ~ "placebo",
      Group_clean %in% c("B", "1", "EXP", "E", "\uff22") ~ "PS150",
      TRUE ~ NA_character_
    ),
    Group = factor(Group, levels = c("placebo", "PS150"))
  ) %>%
  select(-Group_clean) %>%
  filter(!is.na(Group))

message("寬資料 (Wide) 筆數: ", nrow(wide_data_pre_post))

# 2. Long Format (繪圖與敘述統計用)
long_data <- data %>%
  select(ID, Group, contains("_0"), contains("_pre"), contains("_post")) %>%
  mutate(across(.cols = contains("_0") | contains("_pre") | contains("_post"), .fns = as.numeric)) %>%
  pivot_longer(
    cols = contains("_0") | contains("_pre") | contains("_post"),
    names_to = c("measure", "time"), names_sep = "_", values_to = "score"
  ) %>%
  mutate(
    time = factor(case_when(
      time == "0" ~ "interview", time == "pre" ~ "Pre", time == "post" ~ "Post", TRUE ~ time
    ), levels = c("interview", "Pre", "Post")),
    Group_clean = toupper(trimws(as.character(Group))),
    Group = case_when(
      Group_clean %in% c("A", "0", "CONTROL", "C", "\uff21") ~ "placebo",
      Group_clean %in% c("B", "1", "EXP", "E", "\uff22") ~ "PS150",
      TRUE ~ NA_character_
    ),
    Group = factor(Group, levels = c("placebo", "PS150"))
  ) %>%
  select(-Group_clean) %>%
  filter(!is.na(Group)) %>%
  filter(!is.na(score))

# 為標準化分析準備欄位
long_data <- long_data %>%
  mutate(
    Trail = time,
    measure_full = measure
  )

# 標記成對資料 (同一受試者在同一量表同時有 Pre 和 Post)
valid_ids <- long_data %>%
  filter(Trail %in% c("Pre", "Post")) %>%
  group_by(measure_full, ID) %>%
  filter(n_distinct(Trail) == 2) %>%
  ungroup() %>%
  select(ID, measure_full) %>%
  distinct() %>%
  mutate(Is_Paired = TRUE)

long_data <- long_data %>%
  left_join(valid_ids, by = c("ID", "measure_full")) %>%
  mutate(Is_Paired = replace_na(Is_Paired, FALSE))

message("長資料 (Long) 筆數: ", nrow(long_data))

# ==============================================================================
# === 4. 基本資料與 Baseline (整合表格版) ====
# ==============================================================================
message("--- 計算基本資料 (整合版) ---")

# 1. 準備分析資料
data_AB <- data %>%
  mutate(
    Group_clean = toupper(trimws(as.character(Group))),
    Group = case_when(
      Group_clean %in% c("A", "0", "CONTROL", "C", "\uff21") ~ "placebo",
      Group_clean %in% c("B", "1", "EXP", "E", "\uff22") ~ "PS150",
      TRUE ~ NA_character_
    ),
    Group = factor(Group, levels = c("placebo", "PS150"))
  ) %>%
  select(-Group_clean) %>%
  filter(!is.na(Group))

# 2. 設定變數清單
continuous_vars <- c("Age", "Height", "Weight", "BMI")

# --- Part A: 連續變數處理 (T-test) ---
cont_list <- list()

for (v in continuous_vars) {
  # 檢查變數是否存在
  if (!v %in% names(data_AB)) next

  # 計算敘述統計 (Mean, SD, N)
  stats <- data_AB %>%
    group_by(Group) %>%
    summarise(
      n = n(),
      mean = mean(get(v), na.rm = TRUE),
      sd = sd(get(v), na.rm = TRUE),
      .groups = "drop"
    )

  # 分離 A/B 組數據
  stats_placebo <- stats %>% filter(Group == "placebo")
  stats_PS150 <- stats %>% filter(Group == "PS150")

  # 執行 T-test
  t_res <- tryCatch(
    {
      t_test(data_AB, as.formula(paste(v, "~ Group")))
    },
    error = function(e) NULL
  )

  p_val <- if (!is.null(t_res)) t_res$p else NA

  # 建立單列資料
  row_df <- tibble(
    Variable = v,
    placebo_n = as.character(stats_placebo$n),
    placebo_mean = round(stats_placebo$mean, 2),
    placebo_sd = round(stats_placebo$sd, 2),
    PS150_n = as.character(stats_PS150$n),
    PS150_mean = round(stats_PS150$mean, 2),
    PS150_sd = round(stats_PS150$sd, 2),
    p = round(p_val, 3),
    method = "T-test"
  )

  cont_list[[v]] <- row_df
}

# --- Part B: 性別變數處理 (Chi-square) ---
# 假設 Sex: 1=男, 2=女
n_placebo_m <- sum(data_AB$Group == "placebo" & data_AB$Sex == 1, na.rm = TRUE)
n_placebo_f <- sum(data_AB$Group == "placebo" & data_AB$Sex == 2, na.rm = TRUE)
n_PS150_m <- sum(data_AB$Group == "PS150" & data_AB$Sex == 1, na.rm = TRUE)
n_PS150_f <- sum(data_AB$Group == "PS150" & data_AB$Sex == 2, na.rm = TRUE)

# 執行 Chi-square
sex_tbl <- table(data_AB$Group, data_AB$Sex)
chisq_res <- tryCatch(chisq_test(sex_tbl), error = function(e) NULL)
p_val_sex <- if (!is.null(chisq_res)) chisq_res$p else NA

gender_row <- tibble(
  Variable = "Gender",
  placebo_n = paste0(n_placebo_m, " (", n_placebo_f, ")"), # 格式: Male (Female)
  placebo_mean = NA, placebo_sd = NA,
  PS150_n = paste0(n_PS150_m, " (", n_PS150_f, ")"),
  PS150_mean = NA, PS150_sd = NA,
  p = round(p_val_sex, 3),
  method = "Chi-square test"
)

# --- Part C: 合併表格 ---
baseline_table_final <- bind_rows(bind_rows(cont_list), gender_row)

# 敘述統計 (Survey) - 保留原本的
survey_stats <- long_data %>%
  group_by(Group, measure, time) %>%
  summarise(avg = mean(score, na.rm = TRUE), sd = sd(score, na.rm = TRUE), .groups = "drop")

# 常態檢定 (穩健版) - 保留原本的
normality_results <- long_data %>%
  group_by(Group, measure, time) %>%
  summarise(
    n = sum(!is.na(score)),
    p = tryCatch(shapiro.test(score)$p.value, error = function(e) NA),
    .groups = "drop"
  ) %>%
  filter(n >= 3)
# ==============================================================================
# === 5. 核心統計 I：組內與組間 (Raw Score) ====
# ==============================================================================
message("--- [Step 5] 執行原始分數檢定 ---")
measures_to_analyze <- c("PSQI", "ISI", "MEQ", "ESS", "BDI", "BAI", "VASGI", "diet")

intragroup_t_list <- list()
intragroup_w_list <- list()
intragroup_es_list <- list()
intergroup_t_list <- list()
intergroup_w_list <- list()

# --- A. 組內比較 ---
for (g in unique(wide_data_pre_post$Group)) { # 這裡 g 會是 "placebo" 或 "PS150"
  for (m in measures_to_analyze) {
    pre_col <- paste0(m, "_pre")
    post_col <- paste0(m, "_post")
    if (!pre_col %in% names(wide_data_pre_post)) next

    temp_df <- wide_data_pre_post[wide_data_pre_post$Group == g, c(pre_col, post_col)]
    paired_data <- temp_df[complete.cases(temp_df), ]
    if (nrow(paired_data) < 2) next

    try(
      {
        tt <- t.test(paired_data[[pre_col]], paired_data[[post_col]], paired = TRUE)
        intragroup_t_list[[paste0(g, m)]] <- tibble(Group = g, measure = m, n = nrow(paired_data), statistic = tt$statistic, p = tt$p.value, method = "Paired T-test")

        wt <- wilcox.test(paired_data[[pre_col]], paired_data[[post_col]], paired = TRUE)
        intragroup_w_list[[paste0(g, m)]] <- tibble(Group = g, measure = m, n = nrow(paired_data), statistic = wt$statistic, p = wt$p.value, method = "Paired Wilcoxon")

        long_es <- paired_data %>%
          pivot_longer(cols = everything(), names_to = "T", values_to = "S") %>%
          mutate(Time = ifelse(grepl("pre", T), "Pre", "Post"))
        es <- cohens_d(long_es, S ~ Time, paired = TRUE)
        intragroup_es_list[[paste0(g, m)]] <- tibble(Group = g, measure = m, Cohens_d = es$effsize, Magnitude = es$magnitude)
      },
      silent = TRUE
    )
  }
}

# --- B. 組間比較 ----
for (m in measures_to_analyze) {
  for (t in c("_pre", "_post")) {
    col_name <- paste0(m, t)
    if (!col_name %in% names(wide_data_pre_post)) next
    temp_data <- wide_data_pre_post %>%
      select(Group, score = all_of(col_name)) %>%
      filter(!is.na(score))
    if (length(unique(temp_data$Group)) < 2) next

    try(
      {
        tt <- t_test(data = temp_data, score ~ Group)
        intergroup_t_list[[paste0(m, t)]] <- tt %>% add_column(measure = m, time = t, .before = 1)

        wt <- wilcox_test(data = temp_data, score ~ Group)
        wt_fixed <- wt %>%
          mutate(method = "Mann-Whitney U test") %>%
          add_column(measure = m, time = t, .before = 1)
        intergroup_w_list[[paste0(m, t)]] <- wt_fixed
      },
      silent = TRUE
    )
  }
}

# 合併結果
intragroup_t_results_df <- bind_rows(intragroup_t_list)
intragroup_wilcox_results_df <- bind_rows(intragroup_w_list)
intragroup_es_results_df <- bind_rows(intragroup_es_list)
intergroup_t_results_df <- bind_rows(intergroup_t_list)
intergroup_wilcox_results_df <- bind_rows(intergroup_w_list)

message("  -> 組內 T 檢定筆數: ", nrow(intragroup_t_results_df))
message("  -> 組間 T 檢定筆數: ", nrow(intergroup_t_results_df))

# ==============================================================================
# === 6. 核心統計 II：差值分析 (Diff Analysis) ====
# ==============================================================================
message("--- [Step 6] 執行差值分析 ---")

# 1. 建立 Diff Data
diff_data_long <- data.frame()
for (m in measures_to_analyze) {
  pre_col <- paste0(m, "_pre")
  post_col <- paste0(m, "_post")
  if (!pre_col %in% names(wide_data_pre_post)) next

  temp <- wide_data_pre_post %>%
    select(ID, Group, Pre = all_of(pre_col), Post = all_of(post_col)) %>%
    mutate(Diff = Post - Pre, measure = m) %>%
    filter(!is.na(Diff))
  diff_data_long <- bind_rows(diff_data_long, temp)
}

# 2. 差值統計
diff_stats <- diff_data_long %>%
  group_by(Group, measure) %>%
  summarise(mean_diff = mean(Diff), sd_diff = sd(Diff), n = n(), se_diff = sd_diff / sqrt(n), .groups = "drop")

diff_test_t_list <- list()
diff_test_u_list <- list()

for (m in unique(diff_data_long$measure)) {
  df_sub <- diff_data_long %>% filter(measure == m)
  if (length(unique(df_sub$Group)) < 2) next

  try(
    {
      tt <- t_test(data = df_sub, Diff ~ Group)
      eff <- cohens_d(data = df_sub, Diff ~ Group)
      diff_test_t_list[[m]] <- tt %>%
        add_column(measure = m, .before = 1) %>%
        mutate(Cohens_d = eff$effsize, Magnitude = eff$magnitude)

      wt <- wilcox_test(data = df_sub, Diff ~ Group)
      diff_test_u_list[[m]] <- wt %>%
        mutate(method = "Mann-Whitney U test") %>%
        add_column(measure = m, .before = 1)
    },
    silent = TRUE
  )
}

diff_t_results_df <- bind_rows(diff_test_t_list)
diff_u_results_df <- bind_rows(diff_test_u_list)

message("  -> 差值檢定筆數: ", nrow(diff_t_results_df))

# ==============================================================================
# === 6.4 核心統計 III-A：改變量回歸分析 (無控制 Delta_MEQ) ====
# ==============================================================================
# 公式: ΔOutcome ~ Group + Outcome_pre
# 目的: 僅控制基期效應後，檢驗 Group 對各量表改變量的影響
message("--- [Step 6.4] 執行改變量回歸分析 (無控制 Delta_MEQ) ---")

# 1. 建立回歸用資料 (計算 Delta)
reg_data <- wide_data_pre_post %>%
  mutate(
    Delta_PSQI = PSQI_post - PSQI_pre,
    Delta_ISI  = ISI_post - ISI_pre,
    Delta_BDI  = BDI_post - BDI_pre,
    Delta_BAI  = BAI_post - BAI_pre,
    Delta_MEQ  = MEQ_post - MEQ_pre
  )

# 2. 設定目標量表與對應欄位
reg_targets <- list(
  list(name = "PSQI", delta = "Delta_PSQI", baseline = "PSQI_pre"),
  list(name = "ISI", delta = "Delta_ISI", baseline = "ISI_pre"),
  list(name = "BDI", delta = "Delta_BDI", baseline = "BDI_pre"),
  list(name = "BAI", delta = "Delta_BAI", baseline = "BAI_pre")
)

# 3. 逐一跑回歸並收集結果
reg_no_meq_results_list <- list()

for (tgt in reg_targets) {
  # 建立公式: Delta_X ~ Group + X_pre
  formula_str <- paste0(tgt$delta, " ~ Group + ", tgt$baseline)
  formula_obj <- as.formula(formula_str)

  # 選取完整個案
  vars_needed <- c(tgt$delta, "Group", tgt$baseline)
  reg_sub <- reg_data %>%
    select(all_of(vars_needed)) %>%
    filter(complete.cases(.))

  if (nrow(reg_sub) < 5) next

  # 執行回歸
  fit <- lm(formula_obj, data = reg_sub)
  s <- summary(fit)

  # 提取係數表
  coef_df <- as.data.frame(s$coefficients)
  coef_df$Term <- rownames(coef_df)
  rownames(coef_df) <- NULL

  # 整理 Term 名稱
  coef_df$Term <- gsub("\\(Intercept\\)", "Intercept", coef_df$Term)
  coef_df$Term <- gsub("GroupPS150", "Group (PS150 vs placebo)", coef_df$Term)
  coef_df$Term <- gsub(tgt$baseline, paste0("Baseline_", tgt$name), coef_df$Term)

  # 顯著性標記
  coef_df$Sig <- ifelse(coef_df$`Pr(>|t|)` < 0.001, "***",
    ifelse(coef_df$`Pr(>|t|)` < 0.01, "**",
      ifelse(coef_df$`Pr(>|t|)` < 0.05, "*",
        ifelse(coef_df$`Pr(>|t|)` < 0.1, ".", "ns")
      )
    )
  )

  f_stat <- s$fstatistic
  f_p <- if (!is.null(f_stat)) pf(f_stat[1], f_stat[2], f_stat[3], lower.tail = FALSE) else NA

  result_df <- tibble(
    Target_Outcome    = tgt$name,
    Control_Variable  = "None",
    Formula           = formula_str,
    Term              = coef_df$Term,
    Estimate          = round(coef_df$Estimate, 4),
    Std_Error         = round(coef_df$`Std. Error`, 4),
    t_value           = round(coef_df$`t value`, 4),
    p_value           = round(coef_df$`Pr(>|t|)`, 4),
    Sig               = coef_df$Sig,
    R_squared         = round(s$r.squared, 4),
    Adj_R_squared     = round(s$adj.r.squared, 4),
    F_statistic       = if (!is.null(f_stat)) round(f_stat[1], 4) else NA,
    F_p_value         = if (!is.na(f_p)) round(f_p, 4) else NA,
    N                 = nrow(reg_sub)
  )

  reg_no_meq_results_list[[tgt$name]] <- result_df

  message(
    "  -> ", tgt$name, " (No MEQ): N=", nrow(reg_sub),
    ", R²=", round(s$r.squared, 3),
    ", Group p=", round(coef_df$`Pr(>|t|)`[coef_df$Term == "Group (PS150 vs placebo)"], 4)
  )
}

reg_no_meq_results_df <- bind_rows(reg_no_meq_results_list)

# ==============================================================================
# === 6.5 核心統計 III-B：改變量回歸分析 (控制 Delta_MEQ) ====
# ==============================================================================
# 公式: ΔOutcome ~ Group + ΔMEQ + Outcome_pre
# 目的: 控制基期效應與 MEQ 變化量後，檢驗 Group 對各量表改變量的影響
message("--- [Step 6.5] 執行改變量回歸分析 (控制 Delta_MEQ) ---")

# 1. 之前已建立 reg_data，直接沿用即可


# 2. 設定目標量表與對應欄位
reg_targets <- list(
  list(name = "PSQI", delta = "Delta_PSQI", baseline = "PSQI_pre"),
  list(name = "ISI", delta = "Delta_ISI", baseline = "ISI_pre"),
  list(name = "BDI", delta = "Delta_BDI", baseline = "BDI_pre"),
  list(name = "BAI", delta = "Delta_BAI", baseline = "BAI_pre")
)

# 3. 逐一跑回歸並收集結果
reg_results_list <- list()

for (tgt in reg_targets) {
  # 建立公式: Delta_X ~ Group + Delta_MEQ + X_pre
  formula_str <- paste0(tgt$delta, " ~ Group + Delta_MEQ + ", tgt$baseline)
  formula_obj <- as.formula(formula_str)

  # 選取完整個案
  vars_needed <- c(tgt$delta, "Group", "Delta_MEQ", tgt$baseline)
  reg_sub <- reg_data %>%
    select(all_of(vars_needed)) %>%
    filter(complete.cases(.))

  if (nrow(reg_sub) < 5) {
    message("  [跳過] ", tgt$name, " - 有效樣本數不足 (", nrow(reg_sub), ")")
    next
  }

  # 執行回歸
  fit <- lm(formula_obj, data = reg_sub)
  s <- summary(fit)

  # 提取係數表
  coef_df <- as.data.frame(s$coefficients)
  coef_df$Term <- rownames(coef_df)
  rownames(coef_df) <- NULL

  # 整理 Term 名稱 (讓報表更易讀)
  coef_df$Term <- gsub("\\(Intercept\\)", "Intercept", coef_df$Term)
  coef_df$Term <- gsub("GroupPS150", "Group (PS150 vs placebo)", coef_df$Term)
  coef_df$Term <- gsub("Delta_MEQ", "Delta_MEQ", coef_df$Term)
  coef_df$Term <- gsub(tgt$baseline, paste0("Baseline_", tgt$name), coef_df$Term)

  # 顯著性標記
  coef_df$Sig <- ifelse(coef_df$`Pr(>|t|)` < 0.001, "***",
    ifelse(coef_df$`Pr(>|t|)` < 0.01, "**",
      ifelse(coef_df$`Pr(>|t|)` < 0.05, "*",
        ifelse(coef_df$`Pr(>|t|)` < 0.1, ".", "ns")
      )
    )
  )

  # 整體模型統計量
  f_stat <- s$fstatistic
  f_p <- if (!is.null(f_stat)) pf(f_stat[1], f_stat[2], f_stat[3], lower.tail = FALSE) else NA

  # 組裝每一列
  result_df <- tibble(
    Target_Outcome    = tgt$name,
    Control_Variable  = "MEQ",
    Formula           = formula_str,
    Term              = coef_df$Term,
    Estimate          = round(coef_df$Estimate, 4),
    Std_Error         = round(coef_df$`Std. Error`, 4),
    t_value           = round(coef_df$`t value`, 4),
    p_value           = round(coef_df$`Pr(>|t|)`, 4),
    Sig               = coef_df$Sig,
    R_squared         = round(s$r.squared, 4),
    Adj_R_squared     = round(s$adj.r.squared, 4),
    F_statistic       = if (!is.null(f_stat)) round(f_stat[1], 4) else NA,
    F_p_value         = if (!is.na(f_p)) round(f_p, 4) else NA,
    N                 = nrow(reg_sub)
  )

  reg_results_list[[tgt$name]] <- result_df

  message(
    "  -> ", tgt$name, ": N=", nrow(reg_sub),
    ", R²=", round(s$r.squared, 3),
    ", Group p=", round(coef_df$`Pr(>|t|)`[coef_df$Term == "Group (PS150 vs placebo)"], 4)
  )
}

# 4. 合併所有結果
reg_results_df <- bind_rows(reg_results_list)
message("  -> 改變量回歸分析完成，共 ", nrow(reg_results_df), " 列結果")

# ==============================================================================
# === 6.6 標準化輸出表格 ====
# ==============================================================================
message("--- [Step 6.6] 製作標準化輸出表格 ---")

# 只取 Pre/Post 資料進行分析
long_prepost <- long_data %>%
  filter(Trail %in% c("Pre", "Post")) %>%
  mutate(Trail = factor(Trail, levels = c("Pre", "Post")))

# ==================================
# ==== Sheet 1: 基礎統計+常態檢定 ====
# ==================================
message("計算基礎描述與常態檢定...")

std_desc_normality <- long_prepost %>%
  group_by(Group, Trail, measure_full) %>%
  summarise(
    n = n(),
    Mean = mean(score, na.rm = TRUE),
    SD = sd(score, na.rm = TRUE),
    Median = median(score, na.rm = TRUE),
    IQR = IQR(score, na.rm = TRUE),
    Shapiro_p = ifelse(n() >= 3, shapiro.test(score)$p.value, NA),
    .groups = "drop"
  ) %>%
  mutate(Is_Normal = ifelse(Shapiro_p > 0.05, "Yes", "No")) %>%
  arrange(measure_full, Group, Trail)

# ==================================
# ==== Sheet 2: 正規結果總表 (Pre/Post) ====
# ==================================
message("計算 Pre/Post 正規報表...")

# 2.1 Mean/SEM 寬表格
std_stats_paper <- std_desc_normality %>%
  mutate(SEM = SD / sqrt(n)) %>%
  pivot_wider(
    id_cols = measure_full,
    names_from = c(Group, Trail),
    values_from = c(Mean, SEM),
    names_glue = "{Group}_{.value}_{Trail}"
  ) %>%
  select(
    measure_full,
    any_of(c(
      "placebo_Mean_Pre", "placebo_SEM_Pre", "placebo_Mean_Post", "placebo_SEM_Post",
      "PS150_Mean_Pre", "PS150_SEM_Pre", "PS150_Mean_Post", "PS150_SEM_Post"
    ))
  )

# 2.2 無母數 P 值 (Wilcoxon within + Mann-Whitney between)
p_within_w <- long_prepost %>%
  filter(Is_Paired == TRUE) %>%
  group_by(Group, measure_full) %>%
  filter(n() > 2) %>%
  wilcox_test(score ~ Trail, paired = TRUE) %>%
  select(Group, measure_full, p) %>%
  pivot_wider(names_from = Group, values_from = p, names_prefix = "p_Within_")

p_between_w <- long_prepost %>%
  group_by(Trail, measure_full) %>%
  filter(n_distinct(Group) == 2) %>%
  wilcox_test(score ~ Group) %>%
  select(Trail, measure_full, p) %>%
  pivot_wider(names_from = Trail, values_from = p, names_prefix = "p_Between_")

std_sheet2_nonpara <- std_stats_paper %>%
  left_join(p_within_w, by = "measure_full") %>%
  left_join(p_between_w, by = "measure_full")

# 2.3 有母數 P 值 (Paired T within + Independent T between)
p_within_t <- long_prepost %>%
  filter(Is_Paired == TRUE) %>%
  group_by(Group, measure_full) %>%
  filter(n() > 2) %>%
  t_test(score ~ Trail, paired = TRUE) %>%
  select(Group, measure_full, p) %>%
  pivot_wider(names_from = Group, values_from = p, names_prefix = "p_Within_")

p_between_t <- long_prepost %>%
  group_by(Trail, measure_full) %>%
  filter(n_distinct(Group) == 2) %>%
  t_test(score ~ Group) %>%
  select(Trail, measure_full, p) %>%
  pivot_wider(names_from = Trail, values_from = p, names_prefix = "p_Between_")

std_sheet2_para <- std_stats_paper %>%
  left_join(p_within_t, by = "measure_full") %>%
  left_join(p_between_t, by = "measure_full")

# ==================================
# ==== Sheet 3: 差值比較表 (Delta) ====
# ==================================
message("計算差值 (Delta) 與分析...")

# 3.1 計算每個人的 Delta
std_delta_data <- long_prepost %>%
  filter(Is_Paired == TRUE) %>%
  select(ID, Group, Trail, measure_full, score) %>%
  pivot_wider(names_from = Trail, values_from = score) %>%
  mutate(Diff = Post - Pre) %>%
  filter(!is.na(Diff))

# 3.2 計算 Delta 的 Mean 和 SEM
std_delta_stats <- std_delta_data %>%
  group_by(measure_full, Group) %>%
  summarise(
    mean = mean(Diff, na.rm = TRUE),
    sd = sd(Diff, na.rm = TRUE),
    n = n(),
    sem = sd / sqrt(n),
    .groups = "drop"
  ) %>%
  pivot_wider(
    id_cols = measure_full,
    names_from = Group,
    values_from = c(mean, sem),
    names_glue = "diff_{.value}_{Group}"
  ) %>%
  rename_with(~ sub("diff_sem", "diff_SEM", .x), contains("diff_sem")) %>%
  select(
    measure_full,
    any_of(c("diff_mean_placebo", "diff_SEM_placebo", "diff_mean_PS150", "diff_SEM_PS150"))
  )

# 3.3 無母數差值檢定 (Mann-Whitney U)
std_delta_test_w <- std_delta_data %>%
  group_by(measure_full) %>%
  filter(n_distinct(Group) == 2) %>%
  wilcox_test(Diff ~ Group) %>%
  select(measure_full, p) %>%
  mutate(method = "Mann-Whitney U")

std_sheet3_nonpara <- std_delta_stats %>%
  left_join(std_delta_test_w, by = "measure_full")

# 3.4 有母數差值檢定 (Independent T-test)
std_delta_test_t <- std_delta_data %>%
  group_by(measure_full) %>%
  filter(n_distinct(Group) == 2) %>%
  t_test(Diff ~ Group) %>%
  select(measure_full, p) %>%
  mutate(method = "Independent T-test")

std_sheet3_para <- std_delta_stats %>%
  left_join(std_delta_test_t, by = "measure_full")

# ==============================================================================
# === 7. 匯出 Excel (標準化版) ====
# ==============================================================================
message("--- [Step 7] 匯出 Excel ---")
wb <- createWorkbook()
style_sig <- createStyle(bgFill = "#FFFF00")
style_warn <- createStyle(fontColour = "#FF0000", textDecoration = "bold")

# Baseline 表格
if (exists("baseline_table_final")) {
  addWorksheet(wb, "Baseline_Table")
  writeData(wb, "Baseline_Table", baseline_table_final)
}

# Sheet 1: 基礎描述與常態檢定 (合併 survey_stats + normality)
addWorksheet(wb, "0_基礎描述與常態檢定")
writeData(wb, "0_基礎描述與常態檢定", std_desc_normality)
conditionalFormatting(wb, "0_基礎描述與常態檢定",
  cols = which(names(std_desc_normality) == "Shapiro_p"),
  rows = 2:5000, rule = "<0.05", style = style_warn
)

# Sheet 2: 無母數結果總表 (Wilcoxon within + Mann-Whitney between)
addWorksheet(wb, "1_無母數結果總表")
writeData(wb, "1_無母數結果總表", std_sheet2_nonpara)
addStyle(wb, "1_無母數結果總表", createStyle(numFmt = "0.00"), rows = 2:5000, cols = 2:9, gridExpand = TRUE)
addStyle(wb, "1_無母數結果總表", createStyle(numFmt = "0.000"), rows = 2:5000, cols = 10:13, gridExpand = TRUE)
p_cols_np <- which(grepl("p_", names(std_sheet2_nonpara)))
if (length(p_cols_np) > 0) conditionalFormatting(wb, "1_無母數結果總表", cols = p_cols_np, rows = 2:5000, rule = "<0.05", style = style_sig)

# Sheet 3: 有母數結果總表 (Paired T within + Independent T between)
addWorksheet(wb, "2_有母數結果總表")
writeData(wb, "2_有母數結果總表", std_sheet2_para)
addStyle(wb, "2_有母數結果總表", createStyle(numFmt = "0.00"), rows = 2:5000, cols = 2:9, gridExpand = TRUE)
addStyle(wb, "2_有母數結果總表", createStyle(numFmt = "0.000"), rows = 2:5000, cols = 10:13, gridExpand = TRUE)
p_cols_p <- which(grepl("p_", names(std_sheet2_para)))
if (length(p_cols_p) > 0) conditionalFormatting(wb, "2_有母數結果總表", cols = p_cols_p, rows = 2:5000, rule = "<0.05", style = style_sig)

# Sheet 4: 無母數差值比較表
addWorksheet(wb, "3_無母數差值比較表")
writeData(wb, "3_無母數差值比較表", std_sheet3_nonpara)
addStyle(wb, "3_無母數差值比較表", createStyle(numFmt = "0.00"), rows = 2:5000, cols = 2:5, gridExpand = TRUE)
addStyle(wb, "3_無母數差值比較表", createStyle(numFmt = "0.000"), rows = 2:5000, cols = 6, gridExpand = TRUE)
conditionalFormatting(wb, "3_無母數差值比較表", cols = 6, rows = 2:5000, rule = "<0.05", style = style_sig)

# Sheet 5: 有母數差值比較表
addWorksheet(wb, "4_有母數差值比較表")
writeData(wb, "4_有母數差值比較表", std_sheet3_para)
addStyle(wb, "4_有母數差值比較表", createStyle(numFmt = "0.00"), rows = 2:5000, cols = 2:5, gridExpand = TRUE)
addStyle(wb, "4_有母數差值比較表", createStyle(numFmt = "0.000"), rows = 2:5000, cols = 6, gridExpand = TRUE)
conditionalFormatting(wb, "4_有母數差值比較表", cols = 6, rows = 2:5000, rule = "<0.05", style = style_sig)

# Effect Size (保留)
if (exists("intragroup_es_results_df") && nrow(intragroup_es_results_df) > 0) {
  addWorksheet(wb, "Intra_ES")
  writeData(wb, "Intra_ES", intragroup_es_results_df)
}

# 改變量回歸分析結果 (無控制 MEQ)
if (exists("reg_no_meq_results_df") && nrow(reg_no_meq_results_df) > 0) {
  addWorksheet(wb, "Reg_No_MEQ")
  writeData(wb, "Reg_No_MEQ", reg_no_meq_results_df)
}

# 改變量回歸分析結果 (控制 MEQ)
if (exists("reg_results_df") && nrow(reg_results_df) > 0) {
  addWorksheet(wb, "Reg_With_MEQ")
  writeData(wb, "Reg_With_MEQ", reg_results_df)
}

saveWorkbook(wb, output_file, overwrite = TRUE)
message("Excel 儲存成功！已整合為標準化格式報表。")

# ==============================================================================
# === 8. 繪圖設定 (載入強大的工具包) =====
# ==============================================================================
message("\n=== 開始繪圖流程 ===")
folder_date <- format(Sys.Date(), "%y%m%d")
plot_base_path <- file.path(base_dir, paste0("Plots_Output_", folder_date))
path_trend_anno <- file.path(plot_base_path, "Que_Annotated")
path_trend_pure <- file.path(plot_base_path, "Que_Pure")
path_diff_anno <- file.path(plot_base_path, "Que_Diff_Annotated")
path_diff_pure <- file.path(plot_base_path, "Que_Diff_Pure")

# 建立所有輸出資料夾
lapply(
  c(path_trend_anno, path_trend_pure, path_diff_anno, path_diff_pure),
  function(x) if (!dir.exists(x)) dir.create(x, recursive = TRUE)
)

# 載入我們的雙引擎工具包
source("C:\\github\\my-first-project\\my-first-project\\PS150_statics\\functioin\\Line_plot_tool.R")
source("C:\\github\\my-first-project\\my-first-project\\PS150_statics\\functioin\\Bar_plot_tool.R")

my_colors <- c("placebo" = "#31688E", "PS150" = "#E67E22")
my_shapes <- c("placebo" = 16, "PS150" = 17)

group_names <- levels(long_data$Group)
Group_A <- "placebo"
Group_B <- "PS150"

# 定義顯著性檢查函數 (維持原邏輯)
check_intra <- function(grp, msr) {
  if (!exists("intragroup_t_results_df") || nrow(intragroup_t_results_df) == 0) {
    return(FALSE)
  }
  res <- intragroup_t_results_df %>% filter(Group == grp, measure == msr)
  if (nrow(res) > 0 && !is.na(res$p) && res$p < 0.05) {
    return(TRUE)
  }
  return(FALSE)
}

check_inter <- function(msr, tm) {
  if (!exists("intergroup_t_results_df") || nrow(intergroup_t_results_df) == 0) {
    return(FALSE)
  }
  res <- intergroup_t_results_df %>% filter(measure == msr, time == tm)
  if (nrow(res) > 0 && !is.na(res$p) && res$p < 0.05) {
    return(TRUE)
  }
  return(FALSE)
}

check_diff_sig <- function(msr) {
  if (!exists("diff_t_results_df") || nrow(diff_t_results_df) == 0) {
    return(FALSE)
  }
  res <- diff_t_results_df %>% filter(measure == msr)
  if (nrow(res) > 0 && !is.na(res$p) && res$p < 0.05) {
    return(TRUE)
  }
  return(FALSE)
}

# ==============================================================================
# === 9. 繪圖：趨勢圖 (Trend Plot) - 終極穩定版 =====
# ==============================================================================
message("--- 繪製趨勢圖 (Line Plot Tool) ---")

# 設定很寬的距離讓兩組徹底分開
my_dodge_w <- 0.4

plot_summary <- long_data %>%
  filter(Group %in% c("placebo", "PS150"), time %in% c("Pre", "Post")) %>%
  group_by(Group, measure, time) %>%
  summarise(avg = mean(score, na.rm = T), sd = sd(score, na.rm = T), n = n(), se = sd / sqrt(n), .groups = "drop") %>%
  mutate(
    time = factor(time, levels = c("Pre", "Post")),
    Group = factor(Group, levels = c("placebo", "PS150")),
    week_numeric = ifelse(time == "Pre", 1, 2)
  )

for (m in unique(plot_summary$measure)) {
  df_sum <- plot_summary %>% filter(measure == m)
  if (nrow(df_sum) == 0) next

  df_sum <- df_sum %>%
    mutate(
      label_time = case_when(
        Group == Group_A & time == "Post" & check_intra(Group_A, m) ~ "*",
        Group == Group_B & time == "Post" & check_intra(Group_B, m) ~ "#",
        TRUE ~ NA_character_
      ),
      # $ 標記只放一組，避免 Bracket 重複
      label_AB = case_when(
        Group == Group_A & time == "Pre" & check_inter(m, "_pre") ~ "$",
        Group == Group_A & time == "Post" & check_inter(m, "_post") ~ "$",
        TRUE ~ NA_character_
      )
    )

  # 呼叫已經恢復 15% 比例限制的 scale 計算
  scale_info <- calc_dynamic_y_scale(df_sum, error_ratio = 0.15)

  suppressMessages(suppressWarnings({
    p_base <- create_flexible_line_plot(
      df_s = df_sum, y_breaks = scale_info$breaks, y_limits = scale_info$limits,
      title_text = m, y_label = "Score", color_pal = my_colors, shape_pal = my_shapes,
      # 傳入 0.4 寬度
      dodge_w = my_dodge_w,
      x_label = NULL # 【修正 1】: 將 x_label 設為 NULL，去除 X 軸大標題
    ) +
      scale_x_continuous(breaks = c(1, 2), labels = c("Pre", "Post"), expand = expansion(mult = 0.35))
    # 【修正 2】: 移除此處多餘的 labs(x = "Time")，否則會覆蓋 tool 中的設定

    p_anno <- add_annotations_flexible(
      p = p_base, df_s = df_sum, scale_info = scale_info,
      # 傳入相同的 0.4 寬度，數學公式會自動計算 W/4 完美鎖定
      dodge_w = my_dodge_w
      # 【修正 3】: 移除 size_star, size_pound, size_dollar, y_offset_row1, y_gap_rows 這些在 tool 裡已經有預設值的參數。
      # 這樣未來要改大小，只要去 tool.R 改一次就好，不用所有腳本都改。
    )
  }))

  ggsave(filename = file.path(path_trend_anno, paste0(m, "_Trend_Annotated.png")), plot = p_anno, width = 4, height = 5, dpi = 300, bg = "white")
  ggsave(filename = file.path(path_trend_pure, paste0(m, "_Trend_Pure.png")), plot = p_base, width = 4, height = 5, dpi = 300, bg = "white")
}
# ==============================================================================
# === 10. 差值圖 (Bar Only) - 採用 Bar Plot Tool =======
# ==============================================================================
message("--- 繪製差值圖 (Bar Plot Tool) ---")

for (m in unique(diff_stats$measure)) {
  # 1. 準備數據並轉換為 Bar Plot Tool 可讀格式
  df_bar <- diff_stats %>%
    filter(measure == m) %>%
    mutate(
      Group = factor(Group, levels = c("placebo", "PS150")),
      # 創建一個虛擬 X 軸
      Stage = "Delta",
      # 差值圖只標記組間差異，因此利用 Bar Tool 的 label_Bet 來印出 "*"
      label_Bet = ifelse(check_diff_sig(m), "*", NA)
    )

  if (nrow(df_bar) == 0) next

  # 2. 呼叫 Bar Plot Tool 運算與繪圖
  scale_info_bar <- calc_dynamic_y_scale_bar(df_bar, y_col = "mean_diff", err_col = "se_diff")

  p_base_bar <- create_flexible_bar_plot(
    df = df_bar, x_col = "Stage", y_col = "mean_diff", err_col = "se_diff", group_col = "Group",
    scale_info = scale_info_bar, title_text = paste(m, "- Difference"),
    y_label = "Difference Score", x_label = NULL, color_pal = my_colors,
    plot_ratio = 1.25 # 【關鍵修改】：Y:X = 5:4 (即 5/4 = 1.25)，讓兩根柱子看起來比例完美
  ) +
    # 隱藏虛擬的 X 軸文字 "Delta" 讓圖面更乾淨
    theme(axis.text.x = element_blank(), axis.ticks.x = element_blank())

  # 加上標註
  p_anno_bar <- add_annotations_bar(
    p = p_base_bar, df = df_bar, x_col = "Stage", y_col = "mean_diff", err_col = "se_diff", group_col = "Group",
    scale_info = scale_info_bar, groupA_name = Group_A, groupB_name = Group_B,
    size_dollar = 8, y_gap_rows = 0.08 # 因為這裡用的是 label_Bet 畫 *, 可以放大一點
  )

  # 3. 存檔
  ggsave(filename = file.path(path_diff_anno, paste0(m, "_Diff_Bar_Anno.png")), plot = p_anno_bar, width = 5, height = 6, dpi = 300, bg = "white")
  ggsave(filename = file.path(path_diff_pure, paste0(m, "_Diff_Bar_Pure.png")), plot = p_base_bar, width = 5, height = 6, dpi = 300, bg = "white")
}

message("\n🎉 所有問卷圖表繪製完成！已全面套用標準化繪圖工具！")

# View(df_sum)
