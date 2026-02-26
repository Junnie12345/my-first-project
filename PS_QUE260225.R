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
output_file <- paste0(base_dir, "QUE分析_Full_260130.xlsx") # v6

# 讀取資料
message("讀取檔案: ", input_file)
data <- read.xlsx(input_file, sheet = "完整資料")

# 性別清洗 (維持數值化以便統計)
data <- data %>%
  mutate(
    Sex = case_when(
      Sex == "男" ~ "1", Sex == "女" ~ "2",
      Sex %in% c("1", "2") ~ as.character(Sex),
      TRUE ~ NA_character_
    ),
    Sex = as.numeric(Sex)
  )

# ==============================================================================
# === 3. 資料前處理 (關鍵修正：直接使用 A/B) ===
# ==============================================================================
message("--- 資料轉換中 ---")

# 1. Wide Format (統計用)
wide_data_pre_post <- data %>%
  # 轉數值
  mutate(across(.cols = contains("_pre") | contains("_post"), .fns = as.numeric)) %>%
  select(ID, Group, contains("_pre"), contains("_post")) %>%
  # [修正] 直接去空白並保留 A/B
  mutate(Group = trimws(as.character(Group))) %>%
  filter(Group %in% c("A", "B"))

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
    Group = trimws(as.character(Group)) # [修正] 直接使用 A/B
  ) %>%
  filter(Group %in% c("A", "B")) %>%
  filter(!is.na(score))

message("長資料 (Long) 筆數: ", nrow(long_data))

# ==============================================================================
# === 4. 基本資料與 Baseline (整合表格版) ====
# ==============================================================================
message("--- 計算基本資料 (整合版) ---")

# 1. 準備分析資料
data_AB <- data %>%
  mutate(Group = trimws(as.character(Group))) %>%
  filter(Group %in% c("A", "B"))

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
  stats_A <- stats %>% filter(Group == "A")
  stats_B <- stats %>% filter(Group == "B")

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
    A_n = as.character(stats_A$n),
    A_mean = round(stats_A$mean, 2),
    A_sd = round(stats_A$sd, 2),
    B_n = as.character(stats_B$n),
    B_mean = round(stats_B$mean, 2),
    B_sd = round(stats_B$sd, 2),
    p = round(p_val, 3),
    method = "T-test"
  )

  cont_list[[v]] <- row_df
}

# --- Part B: 性別變數處理 (Chi-square) ---
# 假設 Sex: 1=男, 2=女
n_A_m <- sum(data_AB$Group == "A" & data_AB$Sex == 1, na.rm = TRUE)
n_A_f <- sum(data_AB$Group == "A" & data_AB$Sex == 2, na.rm = TRUE)
n_B_m <- sum(data_AB$Group == "B" & data_AB$Sex == 1, na.rm = TRUE)
n_B_f <- sum(data_AB$Group == "B" & data_AB$Sex == 2, na.rm = TRUE)

# 執行 Chi-square
sex_tbl <- table(data_AB$Group, data_AB$Sex)
chisq_res <- tryCatch(chisq_test(sex_tbl), error = function(e) NULL)
p_val_sex <- if (!is.null(chisq_res)) chisq_res$p else NA

gender_row <- tibble(
  Variable = "Gender",
  A_n = paste0(n_A_m, " (", n_A_f, ")"), # 格式: Male (Female)
  A_mean = NA, A_sd = NA,
  B_n = paste0(n_B_m, " (", n_B_f, ")"),
  B_mean = NA, B_sd = NA,
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
for (g in unique(wide_data_pre_post$Group)) { # 這裡 g 會是 "A" 或 "B"
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
  coef_df$Term <- gsub("GroupB", "Group (B vs A)", coef_df$Term)
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
    ", Group p=", round(coef_df$`Pr(>|t|)`[coef_df$Term == "Group (B vs A)"], 4)
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
  coef_df$Term <- gsub("GroupB", "Group (B vs A)", coef_df$Term)
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
    ", Group p=", round(coef_df$`Pr(>|t|)`[coef_df$Term == "Group (B vs A)"], 4)
  )
}

# 4. 合併所有結果
reg_results_df <- bind_rows(reg_results_list)
message("  -> 改變量回歸分析完成，共 ", nrow(reg_results_df), " 列結果")

# ==============================================================================
# === 7. 匯出 Excel (更新版) ====
# ==============================================================================
message("--- [Step 7] 匯出 Excel ---")
wb <- createWorkbook()

# 新增整合後的 Baseline 表格 (取代原本零散的 sheet)
if (exists("baseline_table_final")) {
  addWorksheet(wb, "Baseline_Table")
  writeData(wb, "Baseline_Table", baseline_table_final)
}

# 其他原本的 Sheet 保持不變
if (exists("survey_stats")) {
  addWorksheet(wb, "Survey_Stats")
  writeData(wb, "Survey_Stats", survey_stats)
}
if (exists("normality_results")) {
  addWorksheet(wb, "Normality")
  writeData(wb, "Normality", normality_results)
}

if (nrow(intragroup_t_results_df) > 0) {
  addWorksheet(wb, "Intra_T")
  writeData(wb, "Intra_T", intragroup_t_results_df)
}
if (nrow(intragroup_wilcox_results_df) > 0) {
  addWorksheet(wb, "Intra_Wilcoxon")
  writeData(wb, "Intra_Wilcoxon", intragroup_wilcox_results_df)
}
if (nrow(intragroup_es_results_df) > 0) {
  addWorksheet(wb, "Intra_ES")
  writeData(wb, "Intra_ES", intragroup_es_results_df)
}
if (nrow(intergroup_t_results_df) > 0) {
  addWorksheet(wb, "Inter_T")
  writeData(wb, "Inter_T", intergroup_t_results_df)
}
if (nrow(intergroup_wilcox_results_df) > 0) {
  addWorksheet(wb, "Inter_U")
  writeData(wb, "Inter_U", intergroup_wilcox_results_df)
}

if (nrow(diff_stats) > 0) {
  addWorksheet(wb, "Diff_Stats")
  writeData(wb, "Diff_Stats", diff_stats)
}
if (nrow(diff_t_results_df) > 0) {
  addWorksheet(wb, "Diff_T_ES")
  writeData(wb, "Diff_T_ES", diff_t_results_df)
}
if (nrow(diff_u_results_df) > 0) {
  addWorksheet(wb, "Diff_U")
  writeData(wb, "Diff_U", diff_u_results_df)
}

# 改變量回歸分析結果 (無 控制 MEQ)
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
message("Excel 儲存成功！Baseline 表格已整合至 'Baseline_Table' 分頁。")

# ==============================================================================
# === 8. 繪圖設定 =====
# ==============================================================================
message("\n=== 開始繪圖流程 ===")
folder_date <- format(Sys.Date(), "%y%m%d")
plot_base_path <- file.path(base_dir, paste0("Plots_Output_", folder_date))
path_trend_anno <- file.path(plot_base_path, "Que_Annotated")
path_trend_pure <- file.path(plot_base_path, "Que_Pure")
path_diff <- file.path(plot_base_path, "Que_Diff")

if (!dir.exists(path_trend_anno)) dir.create(path_trend_anno, recursive = TRUE)
if (!dir.exists(path_trend_pure)) dir.create(path_trend_pure, recursive = TRUE)
if (!dir.exists(path_diff)) dir.create(path_diff, recursive = TRUE)

my_colors <- c("A" = "#31688E", "B" = "#E67E22")
my_shapes <- c("A" = 16, "B" = 17)

# ==============================================================================
# === 9. 繪圖：趨勢圖 (Trend Plot) - 視覺優化版 =====
# ==============================================================================
message("--- 繪製趨勢圖 (直式 5:4 | 優化字體與 ErrorBar) ---")

# 準備繪圖數據
plot_summary <- long_data %>%
  filter(Group %in% c("A", "B"), time %in% c("Pre", "Post")) %>%
  group_by(Group, measure, time) %>%
  summarise(avg = mean(score, na.rm = T), sd = sd(score, na.rm = T), n = n(), se = sd / sqrt(n), .groups = "drop") %>%
  mutate(time = factor(time, levels = c("Pre", "Post")), Group = factor(Group, levels = c("A", "B")))

# 定義顯著性檢查函數 (連接 Step 5 的 T-test 結果)
check_intra <- function(grp, msr) {
  # 防呆：確保結果表格存在且有內容
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

# 開始繪圖迴圈
for (m in unique(plot_summary$measure)) {
  df_sum <- plot_summary %>% filter(measure == m)
  if (nrow(df_sum) == 0) next

  # 1. 填寫顯著性標籤 (*, #, $)
  df_sum$label_A <- NA
  df_sum$label_B <- NA
  df_sum$label_AB <- NA

  # A 組組內 (Post)
  if (check_intra("A", m)) df_sum$label_A[df_sum$Group == "A" & df_sum$time == "Post"] <- "*"
  # B 組組內 (Post)
  if (check_intra("B", m)) df_sum$label_B[df_sum$Group == "B" & df_sum$time == "Post"] <- "#"
  # 組間 (Pre / Post)
  if (check_inter(m, "_pre")) df_sum$label_AB[df_sum$Group == "A" & df_sum$time == "Pre"] <- "$"
  if (check_inter(m, "_post")) df_sum$label_AB[df_sum$Group == "A" & df_sum$time == "Post"] <- "$"

  # 2. Y 軸範圍與刻度計算
  raw_min <- min(df_sum$avg - df_sum$se, na.rm = T)
  raw_max <- max(df_sum$avg + df_sum$se, na.rm = T)

  # 避免最大最小相同導致報錯
  if (raw_min == raw_max) {
    raw_min <- raw_min - 0.1
    raw_max <- raw_max + 0.1
  }

  # 設定上方顯著性符號的位置 (比最高點再高 15%)
  plot_max <- raw_max + (raw_max - raw_min) * 0.15

  # 自動產生漂亮的刻度
  breaks_seq <- pretty(c(raw_min, plot_max), n = 5)
  if (length(breaks_seq) > 6) breaks_seq <- pretty(c(raw_min, plot_max), n = 4)

  # --- 3. 繪圖核心 ---
  p_base <- ggplot(df_sum, aes(x = time, y = avg, group = Group, color = Group, shape = Group)) +
    # 線條
    geom_line(linewidth = 1.2, alpha = 0.9) +
    # 點
    geom_point(size = 4.5) +
    # 【修改 1】Error Bar 寬度縮小 (width = 0.08)
    geom_errorbar(aes(ymin = avg - se, ymax = avg + se), width = 0.08, linewidth = 0.8) +

    # X 軸擠壓 (維持 5:4 視覺感)
    scale_x_discrete(expand = expansion(mult = c(0.35, 0.35))) +

    # 【修改 2】Y 軸上方留白增加到 30% (mult = 0.30)，防止星星被切掉
    scale_y_continuous(breaks = breaks_seq, limits = range(breaks_seq), expand = expansion(mult = c(0.05, 0.30))) +
    scale_color_manual(values = my_colors, labels = c("A" = "Group A", "B" = "Group B")) +
    scale_shape_manual(values = my_shapes, labels = c("A" = "Group A", "B" = "Group B")) +
    labs(title = m, subtitle = "Mean ± SEM", x = NULL, y = "Score") +
    theme_classic() +
    theme(
      # 標題
      plot.title = element_text(size = 20, face = "bold", hjust = 0.5),
      plot.subtitle = element_text(size = 12, color = "gray30"),

      # 【修改 3】XY軸文字放大兩號
      axis.title.y = element_text(size = 18, face = "bold", margin = margin(r = 10)), # Y軸標題
      axis.text = element_text(size = 16, color = "black", face = "bold"), # 刻度文字(Pre/Post & 數字)

      # 圖例
      legend.position = c(0.95, 0.98),
      legend.justification = c("right", "top"),
      legend.background = element_rect(fill = "white", color = "black", linewidth = 0.2),
      legend.title = element_blank(),
      legend.text = element_text(size = 14) # 圖例文字也稍微放大
    )

  # 4. 加入顯著性標記
  # 注意：這裡使用 vjust = -1 讓符號離 Error Bar 遠一點點，避免重疊
  p_anno <- p_base +
    geom_text(aes(label = label_A, y = avg + se), vjust = -1, size = 8, fontface = "bold", show.legend = FALSE, na.rm = TRUE) +
    geom_text(aes(label = label_B, y = avg + se), vjust = -1, size = 7, fontface = "bold", show.legend = FALSE, na.rm = TRUE) +
    geom_text(data = df_sum %>% filter(!is.na(label_AB)), aes(label = label_AB, x = time, y = plot_max), color = "black", vjust = 1, size = 6, show.legend = FALSE, na.rm = TRUE) +
    labs(subtitle = "Mean ± SEM (*:A intra, #:B intra, $:A vs B)")

  # 5. 存檔 (直式 4:5)
  ggsave(filename = file.path(path_trend_anno, paste0(m, "_Trend_Annotated.png")), plot = p_anno, width = 4, height = 5, dpi = 300, bg = "white")
  ggsave(filename = file.path(path_trend_pure, paste0(m, "_Trend_Pure.png")), plot = p_base, width = 4, height = 5, dpi = 300, bg = "white")
}

message("繪圖完成！請檢查輸出資料夾。")


# ==============================================================================
# === 10. 差值圖 (Bar Only) - Annotated & Pure 版本 =======
# ==============================================================================
message("--- 繪製差值圖 (Annotated & Pure) ---")

# 1. 設定並建立新資料夾
path_diff_anno <- file.path(plot_base_path, "Que_Diff_Annotated")
path_diff_pure <- file.path(plot_base_path, "Que_Diff_Pure")

if (!dir.exists(path_diff_anno)) dir.create(path_diff_anno, recursive = TRUE)
if (!dir.exists(path_diff_pure)) dir.create(path_diff_pure, recursive = TRUE)

# 2. 定義顯著性檢查函數 (使用 diff_t_results_df)
check_diff_sig <- function(msr) {
  if (!exists("diff_t_results_df") || nrow(diff_t_results_df) == 0) {
    return(FALSE)
  }
  res <- diff_t_results_df %>% filter(measure == msr)
  # 若 p < 0.05 回傳 TRUE
  if (nrow(res) > 0 && !is.na(res$p) && res$p < 0.05) {
    return(TRUE)
  }
  return(FALSE)
}

# 3. 開始繪圖迴圈
for (m in unique(diff_stats$measure)) {
  # 準備數據
  df_bar <- diff_stats %>%
    filter(measure == m) %>%
    mutate(Group = factor(Group, levels = c("A", "B")))

  if (nrow(df_bar) == 0) next

  # 顯著性判斷
  is_sig <- check_diff_sig(m)

  # 計算 Y 軸範圍 (包含正負 Error Bar)
  vals <- c(df_bar$mean_diff + df_bar$se_diff, df_bar$mean_diff - df_bar$se_diff)
  raw_max <- max(vals, na.rm = TRUE)
  raw_min <- min(vals, na.rm = TRUE)

  # 為了畫 "ㄇ" 型標記線，需要找出兩組 Bar 的最高點
  top_y <- max(df_bar$mean_diff + df_bar$se_diff, na.rm = TRUE)
  # 若所有數值都小於 0，基準線設為 0
  if (top_y < 0) top_y <- 0

  # 設定標記線的高度 (比最高點再高 10%)
  bracket_y <- top_y + (abs(raw_max - raw_min) * 0.1)
  # 若數據變異太小，給個基本高度
  if (bracket_y == top_y) bracket_y <- top_y + 0.5

  # 星號高度 (比標記線再高一點)
  star_y <- bracket_y + (abs(raw_max - raw_min) * 0.05)

  # --- [共用基底圖層] ---
  p_base <- ggplot(df_bar, aes(x = Group, y = mean_diff, fill = Group)) +
    # Y=0 參考虛線
    geom_hline(yintercept = 0, linetype = "dashed", color = "gray30", linewidth = 1) +

    # Bar 本體
    geom_bar(stat = "identity", width = 0.6, alpha = 0.85, color = "black") +

    # Error Bar
    geom_errorbar(aes(ymin = mean_diff - se_diff, ymax = mean_diff + se_diff),
      width = 0.2, linewidth = 0.8
    ) +
    scale_fill_manual(values = my_colors) +
    scale_y_continuous(expand = expansion(mult = c(0.1, 0.2))) + # 上下留白

    theme_classic() +
    theme(
      plot.title = element_text(size = 18, face = "bold", hjust = 0.5),
      plot.subtitle = element_text(size = 12, color = "gray30", hjust = 0.5),
      axis.title.y = element_text(size = 16, face = "bold", margin = margin(r = 10)),
      axis.text = element_text(size = 14, color = "black", face = "bold"),
      legend.position = "none" # 差值圖不需要圖例，X軸已經有 A/B
    )

  # --- [A. Annotated 版本] (加上顯著性標記) ---
  p_anno <- p_base +
    labs(
      title = paste0(m, " - Change"),
      subtitle = "Mean ± SEM | *: Sig Diff (p<0.05)",
      y = "Difference Score", x = NULL
    )

  # 若顯著，畫上 "ㄇ" 型線與星星
  if (is_sig) {
    p_anno <- p_anno +
      # 橫線
      geom_segment(aes(x = 1, xend = 2, y = bracket_y, yend = bracket_y),
        color = "black", linewidth = 0.8
      ) +
      # 星號 (置中)
      annotate("text",
        x = 1.5, y = star_y, label = "*",
        size = 8, fontface = "bold"
      )
  }

  ggsave(
    filename = file.path(path_diff_anno, paste0(m, "_Diff_Bar_Anno.png")),
    plot = p_anno, width = 5, height = 6, dpi = 300, bg = "white"
  )

  # --- [B. Pure 版本] (無標記) ---
  p_pure <- p_base +
    labs(title = m, subtitle = NULL, y = "Difference Score", x = NULL)

  ggsave(
    filename = file.path(path_diff_pure, paste0(m, "_Diff_Bar_Pure.png")),
    plot = p_pure, width = 5, height = 6, dpi = 300, bg = "white"
  )
}

message("差值圖繪製完成！\n路徑 1: ", path_diff_anno, "\n路徑 2: ", path_diff_pure)
