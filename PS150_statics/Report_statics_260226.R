rm(list = ls())
library(tidyverse)
library(openxlsx)
library(writexl)
library(data.table)
library(lubridate)
library(tidyverse)
library(tidyverse)
library(rstatix)
library(ez)
data <- read.xlsx("C:\\Users\\ngps9\\OneDrive\\onedrive\\桌面\\PS150_results\\2026\\Datalist_260109_clean.xlsx",
  sheet = "工作表2"
)
# 基本資訊與分組來源
ID_list <- read.xlsx("C:\\Users\\ngps9\\OneDrive\\onedrive\\桌面\\PS150_results\\2026\\受試者進度紀錄與基本資料260117_clean.xlsx",
  sheet = "完整資料"
)
# 設定檔案匯出路徑與名稱
output_file <- "C:\\Users\\ngps9\\OneDrive\\onedrive\\桌面\\PS150_results\\2026\\report_stats_260305_clean.xlsx"
output_path <- "C:\\Users\\ngps9\\OneDrive\\onedrive\\桌面\\PS150_results\\2026"

# 定義所有 PSG 生理指標
measures_to_analyze <- c(
  "TRT_min", "TST_min", "SE", "SL_min", "REML_min", "WASO_min",
  "REM%", "N1%", "N2%", "N3%", "REM_min",
  "N1_min", "N2_min", "N3_min", "ArousalIndex", "Min_O2", "AHI", "AI", "HI", "ODI",
  "NonSupine_AHI", "REM_AHI", "NREM_AHI", "Mean_HR"
)

# 全部數值
# measures_to_analyze <- c(
#   "AHI", "TRT_min", "TST_min", "SE", "SL_min", "REML_min", "WASO_min",
#   "Snore_pct", "PLMS", "ODI", "REM%", "N1%", "N2%", "N3%", "REM_min",
#   "N1_min", "N2_min", "N3_min", "ArousalIndex", "Min_O2", "AI", "HI",
#   "Supine_AHI", "NonSupine_AHI", "REM_AHI", "NREM_AHI", "Mean_HR",
#   "Max_HR_TRT", "Min_HR_TST", "Max_HR_TST"
# )


# ==================================
# ==== 2. 資料清理與合併 ====
# ==================================

# 整理基本資訊並與生理數據合併
id_info <- ID_list %>%
  select(ID, Group, Sex, Age, BMI) %>%
  mutate(ID = as.character(ID))

merged_data <- data %>%
  mutate(ID = as.character(ID)) %>%
  left_join(id_info, by = "ID") %>%
  mutate(
    Trail = factor(Trail, levels = c(0, 1, 2), labels = c("Interview", "Pre", "Post")),
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

# 轉換為長格式 (Long Format)
long_measures <- merged_data %>%
  select(ID, Group, Trail, all_of(measures_to_analyze)) %>%
  pivot_longer(cols = all_of(measures_to_analyze), names_to = "measure", values_to = "score") %>%
  mutate(score = as.numeric(score)) %>%
  filter(!is.na(score))

# ==================================
# ==== 3. 描述統計與常態檢定 ====
# ==================================
# A. 描述統計 (手動計算以包含 Mean, SD, 與 SEM)
desc_stats <- long_measures %>%
  group_by(Group, Trail, measure) %>%
  summarise(
    n = n(),
    mean = mean(score, na.rm = TRUE),
    sd = sd(score, na.rm = TRUE),
    # 計算 SEM: 標準差 / 樣本數的平方根
    sem = sd / sqrt(n),
    .groups = "drop"
  )
# B. 常態檢定
normality_results <- long_measures %>%
  group_by(Group, Trail, measure) %>%
  filter(n() >= 3, sd(score) > 0) %>%
  shapiro_test(score)

# ==================================
# ==== 4. 組內 3 時間點重複測量分析 ====
# ==================================
# A. 無母數 (Friedman Test)
friedman_results <- long_measures %>%
  group_by(Group, measure, ID) %>%
  filter(n() == 3) %>%
  ungroup() %>%
  group_by(Group, measure) %>%
  do({
    temp <- .
    res <- tryCatch(
      {
        friedman_test(data = temp, score ~ Trail | ID)
      },
      error = function(e) NULL
    )
    if (is.null(res)) data.frame() else as.data.frame(res)
  }) %>%
  ungroup() %>%
  add_significance()

# B. 有母數 (One-way RM ANOVA)
oneway_rm_anova_results <- long_measures %>%
  group_by(Group, measure, ID) %>%
  filter(n() == 3) %>%
  ungroup() %>%
  group_by(Group, measure) %>%
  do({
    temp <- .
    res <- tryCatch(
      {
        anova_test(data = temp, dv = score, wid = ID, within = Trail)
      },
      error = function(e) NULL
    )
    if (is.null(res)) data.frame() else as.data.frame(res)
  }) %>%
  ungroup() %>%
  add_significance()

# C. 事後比較 (Post-hoc) - 包含有母數與無母數
posthoc_wilcox <- long_measures %>%
  group_by(Group, measure, ID) %>%
  filter(n() == 3) %>%
  ungroup() %>%
  group_by(Group, measure) %>%
  pairwise_wilcox_test(score ~ Trail, paired = TRUE, p.adjust.method = "bonferroni")

posthoc_t <- long_measures %>%
  group_by(Group, measure, ID) %>%
  filter(n() == 3) %>%
  ungroup() %>%
  group_by(Group, measure) %>%
  pairwise_t_test(score ~ Trail, paired = TRUE, p.adjust.method = "bonferroni")

# ==================================
# ==== 5. Pre vs Post 專項成對分析 ====
# ==================================
pre_post_clean <- long_measures %>%
  filter(Trail %in% c("Pre", "Post")) %>%
  group_by(ID, measure) %>%
  filter(n() == 2) %>%
  ungroup()

# 無母數 (Wilcoxon)
paired_w_results <- pre_post_clean %>%
  group_by(Group, measure) %>%
  wilcox_test(score ~ Trail, paired = TRUE) %>%
  add_significance()

# 有母數 (Paired T-test)
paired_t_results <- pre_post_clean %>%
  group_by(Group, measure) %>%
  t_test(score ~ Trail, paired = TRUE) %>%
  add_significance()

# ==================================
# ==== 5.1 (新增) 組間無母數檢定 (Mann-Whitney U) ====
# ==================================
message("--- 執行組間無母數檢定 (placebo vs PS150 at Pre/Post) ---")

# 針對 Pre 和 Post 分別做 placebo vs PS150 的比較
intergroup_wilcox_results_df <- long_measures %>%
  filter(Trail %in% c("Pre", "Post")) %>%
  group_by(measure, Trail) %>%
  wilcox_test(score ~ Group) %>%
  add_significance() %>%
  # 【關鍵】新增 time 欄位以符合繪圖程式的偵測邏輯 (_pre, _post)
  mutate(
    time = case_when(
      Trail == "Pre" ~ "_pre",
      Trail == "Post" ~ "_post",
      TRUE ~ NA_character_
    )
  )

# 檢查一下結果
print(head(intergroup_wilcox_results_df))


# ==============================================================================
# ==== 6. 報表資料整併 (參照新版優化邏輯) ====
# ==============================================================================
message("\n--- 正在整併報表資料 ---")

# 6.1 製作 Sheet 1: 基礎統計+常態檢定合併表
desc_normality <- desc_stats %>%
  left_join(
    normality_results %>% select(Group, Trail, measure, Shapiro_p = p),
    by = c("Group", "Trail", "measure")
  ) %>%
  mutate(
    Is_Normal = ifelse(Shapiro_p > 0.05, "Yes", "No")
  ) %>%
  arrange(measure, Group, Trail)

# 6.2 製作 Sheet 2: 正規結果總表 (Pre/Post 組內與組間合併)
stats_paper <- desc_normality %>%
  filter(Trail %in% c("Pre", "Post")) %>%
  pivot_wider(
    id_cols = measure,
    names_from = c(Group, Trail),
    values_from = c(mean, sem),
    names_glue = "{Group}_{.value}_{Trail}"
  ) %>%
  select(
    measure,
    placebo_mean_Pre, placebo_sem_Pre, placebo_mean_Post, placebo_sem_Post,
    PS150_mean_Pre, PS150_sem_Pre, PS150_mean_Post, PS150_sem_Post
  )

# 擷取組內 p 值 (Wilcoxon)
p_within <- paired_w_results %>%
  select(Group, measure, p) %>%
  pivot_wider(names_from = Group, values_from = p, names_prefix = "p_Within_")

# 擷取組間 p 值 (Mann-Whitney)
p_between <- intergroup_wilcox_results_df %>%
  select(Trail, measure, p) %>%
  pivot_wider(names_from = Trail, values_from = p, names_prefix = "p_Between_")

# 合併為總表
sheet2_table <- stats_paper %>%
  left_join(p_within, by = "measure") %>%
  left_join(p_between, by = "measure")

# 6.3 製作 Sheet 3: 差值比較表 (Delta)
delta_data <- long_measures %>%
  filter(Trail %in% c("Pre", "Post")) %>%
  group_by(ID, measure) %>%
  filter(n_distinct(Trail) == 2) %>% # 確保有配對
  ungroup() %>%
  select(ID, Group, Trail, measure, score) %>%
  pivot_wider(names_from = Trail, values_from = score) %>%
  mutate(Diff = Post - Pre) %>%
  filter(!is.na(Diff))

delta_stats <- delta_data %>%
  group_by(measure, Group) %>%
  summarise(
    mean = mean(Diff, na.rm = TRUE),
    sd = sd(Diff, na.rm = TRUE),
    n = n(),
    sem = sd / sqrt(n),
    .groups = "drop"
  ) %>%
  pivot_wider(
    id_cols = measure,
    names_from = Group,
    values_from = c(mean, sem),
    names_glue = "diff_{.value}_{Group}"
  ) %>%
  rename_with(~ sub("diff_sem", "diff_SEM", .x), contains("diff_sem")) %>%
  select(
    measure,
    any_of(c("diff_mean_placebo", "diff_SEM_placebo", "diff_mean_PS150", "diff_SEM_PS150"))
  )

delta_test <- delta_data %>%
  group_by(measure) %>%
  filter(n_distinct(Group) == 2) %>%
  wilcox_test(Diff ~ Group) %>%
  select(measure, p) %>%
  mutate(method = "Mann-Whitney U")

sheet3_table <- delta_stats %>%
  left_join(delta_test, by = "measure")

library(geepack)
library(MuMIn)
library(broom)
library(tidyverse)
# ==================================
# ==== 1. 建立 GEE 專用資料集 (修正合併邏輯) ====
# ==================================

# A. 準備乾淨的基礎資訊 (ID, Group, Sex, Age, BMI)
id_info_clean <- ID_list %>%
  select(ID, Group, Sex, Age, BMI) %>%
  mutate(ID = as.character(ID))

# B. 準備問卷基準值
survey_baseline_clean <- ID_list %>%
  select(ID, PSQI_baseline = PSQI_pre) %>%
  mutate(ID = as.character(ID))

# C. 重新建立 gee_data
gee_data <- long_measures %>%
  mutate(ID = as.character(ID)) %>%
  # 移除 long_measures 裡可能殘留的 Group 欄位，避免 join 後產生 Group.x/y
  select(-any_of("Group")) %>%
  filter(Trail %in% c("Pre", "Post")) %>%
  # 重新併入完整資訊
  left_join(id_info_clean, by = "ID") %>%
  left_join(survey_baseline_clean, by = "ID") %>%
  # 清理 Factor 層級
  droplevels() %>%
  mutate(
    ID = as.factor(ID),
    Group = as.factor(Group), # 現在保證能找到 Group 了
    Trail = factor(Trail, levels = c("Pre", "Post"))
  ) %>%
  # GEE 必須排序
  arrange(ID, Trail)

# ==============================================================================
# ==== 2. 執行 GEE 分析 (雙軌：Best Fit & Specified AR1) ====
# ==============================================================================
library(geepack)
library(MuMIn)
library(broom)
library(emmeans)
library(dplyr)

message("\n=== 開始執行 GEE 分析 (雙軌制) ===")

# --- 定義公式 (直接作為公式物件，而非字串) ---
formula_unadj <- as.formula("score ~ Group * Trail")
formula_adj <- as.formula("score ~ Group * Trail + Age + BMI + PSQI_baseline")

# --- 定義儲存容器 ---
# 1. Best Fit (自動選 QIC 最小)
gee_best_unadj_list <- list()
gee_best_adj_list <- list()
gee_best_posthoc_list <- list()

# 2. Specified (強制 AR1)
gee_spec_unadj_list <- list()
gee_spec_adj_list <- list()
gee_spec_posthoc_list <- list()

# --- 輔助函數：計算 Post-hoc ---
calc_posthoc <- function(model, m_name, cor_name, type_name) {
  # 1. 組別在各時間點的差異
  emm1 <- emmeans(model, ~ Group | Trail)
  ph1 <- pairs(emm1, reverse = TRUE, adjust = "none") %>%
    as.data.frame() %>%
    mutate(measure = m_name, Model_Type = type_name, Comparison = "Group_Diff")

  # 2. 時間在各組別的差異
  emm2 <- emmeans(model, ~ Trail | Group)
  ph2 <- pairs(emm2, reverse = TRUE, adjust = "none") %>%
    as.data.frame() %>%
    mutate(measure = m_name, Model_Type = type_name, Comparison = "Time_Diff")

  return(bind_rows(ph1, ph2))
}

# --- 開始迴圈 ---
for (m in measures_to_analyze) {
  # 準備資料
  temp_data <- gee_data %>%
    filter(measure == m, !is.na(Group)) %>%
    arrange(ID, Trail)

  if (nrow(temp_data) < 4) next

  # =========================================================
  # Part A: Best Fit (自動比較 AR1 vs Exchangeable)
  # =========================================================

  # 1. Unadjusted
  m_ar1 <- tryCatch(
    {
      geeglm(formula_unadj, data = temp_data, id = ID, corstr = "ar1")
    },
    error = function(e) NULL
  )
  m_exch <- tryCatch(
    {
      geeglm(formula_unadj, data = temp_data, id = ID, corstr = "exchangeable")
    },
    error = function(e) NULL
  )

  best_mod_unadj <- NULL
  best_cor_unadj <- NA

  if (!is.null(m_ar1) && !is.null(m_exch)) {
    if (QIC(m_ar1) <= QIC(m_exch)) {
      best_mod_unadj <- m_ar1
      best_cor_unadj <- "ar1"
    } else {
      best_mod_unadj <- m_exch
      best_cor_unadj <- "exchangeable"
    }
  } else if (!is.null(m_ar1)) {
    best_mod_unadj <- m_ar1
    best_cor_unadj <- "ar1"
  } else if (!is.null(m_exch)) {
    best_mod_unadj <- m_exch
    best_cor_unadj <- "exchangeable"
  }

  if (!is.null(best_mod_unadj)) {
    gee_best_unadj_list[[m]] <- tidy(best_mod_unadj) %>% mutate(measure = m, corstr = best_cor_unadj, QIC = QIC(best_mod_unadj))
  }

  # 2. Adjusted
  m_ar1_adj <- tryCatch(
    {
      geeglm(formula_adj, data = temp_data, id = ID, corstr = "ar1")
    },
    error = function(e) NULL
  )
  m_exch_adj <- tryCatch(
    {
      geeglm(formula_adj, data = temp_data, id = ID, corstr = "exchangeable")
    },
    error = function(e) NULL
  )

  best_mod_adj <- NULL
  best_cor_adj <- NA

  if (!is.null(m_ar1_adj) && !is.null(m_exch_adj)) {
    if (QIC(m_ar1_adj) <= QIC(m_exch_adj)) {
      best_mod_adj <- m_ar1_adj
      best_cor_adj <- "ar1"
    } else {
      best_mod_adj <- m_exch_adj
      best_cor_adj <- "exchangeable"
    }
  } else if (!is.null(m_ar1_adj)) {
    best_mod_adj <- m_ar1_adj
    best_cor_adj <- "ar1"
  } else if (!is.null(m_exch_adj)) {
    best_mod_adj <- m_exch_adj
    best_cor_adj <- "exchangeable"
  }

  if (!is.null(best_mod_adj)) {
    gee_best_adj_list[[m]] <- tidy(best_mod_adj) %>% mutate(measure = m, corstr = best_cor_adj, QIC = QIC(best_mod_adj))
    # Post-hoc for Best Adjusted
    gee_best_posthoc_list[[m]] <- calc_posthoc(best_mod_adj, m, best_cor_adj, "Best_Fit")
  }

  # =========================================================
  # Part B: Specified (強制 AR1)
  # =========================================================

  # 1. Unadjusted (AR1)
  # 判斷是否可以直接沿用 Best Model (如果 Best 剛好是 AR1)
  spec_mod_unadj <- NULL
  if (!is.na(best_cor_unadj) && best_cor_unadj == "ar1" && !is.null(best_mod_unadj)) {
    spec_mod_unadj <- best_mod_unadj
  } else {
    spec_mod_unadj <- tryCatch(
      {
        geeglm(formula_unadj, data = temp_data, id = ID, corstr = "ar1")
      },
      error = function(e) NULL
    )
  }

  if (!is.null(spec_mod_unadj)) {
    gee_spec_unadj_list[[m]] <- tidy(spec_mod_unadj) %>% mutate(measure = m, corstr = "ar1", QIC = QIC(spec_mod_unadj))
  }

  # 2. Adjusted (AR1)
  spec_mod_adj <- NULL
  if (!is.na(best_cor_adj) && best_cor_adj == "ar1" && !is.null(best_mod_adj)) {
    spec_mod_adj <- best_mod_adj
  } else {
    spec_mod_adj <- tryCatch(
      {
        geeglm(formula_adj, data = temp_data, id = ID, corstr = "ar1")
      },
      error = function(e) NULL
    )
  }

  if (!is.null(spec_mod_adj)) {
    gee_spec_adj_list[[m]] <- tidy(spec_mod_adj) %>% mutate(measure = m, corstr = "ar1", QIC = QIC(spec_mod_adj))
    # Post-hoc for Specified Adjusted
    gee_spec_posthoc_list[[m]] <- calc_posthoc(spec_mod_adj, m, "ar1", "Specified")
  }
}

# --- 整理結果表格 ---
df_gee_best_unadj <- bind_rows(gee_best_unadj_list)
df_gee_best_adj <- bind_rows(gee_best_adj_list)
df_gee_best_ph <- bind_rows(gee_best_posthoc_list)

df_gee_spec_unadj <- bind_rows(gee_spec_unadj_list)
df_gee_spec_adj <- bind_rows(gee_spec_adj_list)
df_gee_spec_ph <- bind_rows(gee_spec_posthoc_list)

message("GEE 分析完成！")


# mix model------------
library(broom.mixed) # 關鍵：解決 tidy method 找不到的問題
library(lmerTest)
library(car)

# ==== 1. 資料前處理：建立分析母檔 (Master Data) ====

# 整理問卷 Baseline 資料 (只拿 PSQI 作為調整用)
survey_baseline <- ID_list %>%
  select(ID, PSQI_pre) %>%
  mutate(ID = as.character(ID)) %>%
  rename(PSQI_baseline = PSQI_pre)

# 整理人口統計與分組
id_master <- ID_list %>%
  select(ID, Group, Sex, Age, BMI) %>%
  mutate(ID = as.character(ID)) %>%
  left_join(survey_baseline, by = "ID")

# 建立核心合併資料 (生理 + 人口 + 問卷基準)
master_data <- data %>%
  mutate(ID = as.character(ID)) %>%
  left_join(id_master, by = "ID") %>%
  mutate(
    Trail = factor(Trail, levels = c(0, 1, 2), labels = c("Interview", "Pre", "Post")),
    Group_clean = toupper(trimws(as.character(Group))),
    Group = case_when(
      Group_clean %in% c("A", "0", "CONTROL", "C", "\uff21") ~ "placebo",
      Group_clean %in% c("B", "1", "EXP", "E", "\uff22") ~ "PS150",
      TRUE ~ NA_character_
    ),
    Group = factor(Group, levels = c("placebo", "PS150"))
  ) %>%
  select(-Group_clean)

# 建立長格式生理資料
long_measures <- master_data %>%
  select(ID, Group, Trail, Age, BMI, PSQI_baseline, all_of(measures_to_analyze)) %>%
  pivot_longer(cols = all_of(measures_to_analyze), names_to = "measure", values_to = "score") %>%
  mutate(score = as.numeric(score)) %>%
  filter(!is.na(score))

# ==== 2. 混合模型分析 (LMM) ====

# 僅針對 Pre & Post 分析
final_analysis_df <- long_measures %>% filter(Trail %in% c("Pre", "Post"))

# --- A. Unadjusted LMM ---
results_unadjusted <- list()
for (m in measures_to_analyze) {
  temp <- final_analysis_df %>% filter(measure == m)
  if (nrow(temp) < 4) next
  mod <- tryCatch(
    {
      lmer(score ~ Group * Trail + (1 | ID), data = temp)
    },
    error = function(e) NULL
  )
  if (!is.null(mod)) {
    results_unadjusted[[m]] <- tidy(mod, conf.int = TRUE) %>%
      filter(effect == "fixed") %>%
      mutate(measure = m)
  }
}
df_unadjusted <- bind_rows(results_unadjusted)

# --- B. Adjusted LMM (控制 Age, BMI, PSQI) ---
results_adjusted <- list()
vif_report <- NULL
for (m in measures_to_analyze) {
  temp <- final_analysis_df %>% filter(measure == m)
  if (nrow(temp) < 4) next
  mod_adj <- tryCatch(
    {
      lmer(score ~ Group * Trail + Age + BMI + PSQI_baseline + (1 | ID), data = temp)
    },
    error = function(e) NULL
  )

  if (!is.null(mod_adj)) {
    if (is.null(vif_report)) { # 只做一次 VIF 檢查
      vif_mod <- lm(score ~ Group + Trail + Age + BMI + PSQI_baseline, data = temp)
      vif_report <- as.data.frame(vif(vif_mod))
    }
    results_adjusted[[m]] <- tidy(mod_adj, conf.int = TRUE) %>%
      filter(effect == "fixed") %>%
      mutate(measure = m)
  }
}
df_adjusted <- bind_rows(results_adjusted)


# 建立 Excel 活頁簿
# ==============================================================================
# ==== 7. 建立專業統計報表 (格式化 Excel 匯出) ====
# ==============================================================================
message("正在產生格式化 Excel 報表...")

wb <- createWorkbook()

# 定義條件格式 Style
style_sig <- createStyle(bgFill = "#FFFF00") # 黃底：顯著
style_warn <- createStyle(fontColour = "#FF0000", textDecoration = "bold") # 紅字粗體：非常態

# --- 階段 A: 基礎與總表 (套用條件格式) ---

# Sheet 1: 基礎描述與常態檢定
addWorksheet(wb, "0_基礎描述與常態檢定")
writeData(wb, "0_基礎描述與常態檢定", desc_normality)
conditionalFormatting(wb, "0_基礎描述與常態檢定", cols = which(names(desc_normality) == "Shapiro_p"), rows = 2:5000, rule = "<0.05", style = style_warn)

# Sheet 2: 正規結果總表
addWorksheet(wb, "1_正規結果總表")
writeData(wb, "1_正規結果總表", sheet2_table)
# 小數點格式化
addStyle(wb, "1_正規結果總表", createStyle(numFmt = "0.00"), rows = 2:5000, cols = 2:9, gridExpand = TRUE)
addStyle(wb, "1_正規結果總表", createStyle(numFmt = "0.000"), rows = 2:5000, cols = 10:13, gridExpand = TRUE)
# 標記顯著 P 值
p_cols_s2 <- which(grepl("p_", names(sheet2_table)))
if (length(p_cols_s2) > 0) {
  conditionalFormatting(wb, "1_正規結果總表", cols = p_cols_s2, rows = 2:5000, rule = "<0.05", style = style_sig)
}

# Sheet 3: 差值比較表
addWorksheet(wb, "2_差值比較表")
writeData(wb, "2_差值比較表", sheet3_table)
addStyle(wb, "2_差值比較表", createStyle(numFmt = "0.00"), rows = 2:5000, cols = 2:5, gridExpand = TRUE)
addStyle(wb, "2_差值比較表", createStyle(numFmt = "0.000"), rows = 2:5000, cols = 6, gridExpand = TRUE)
conditionalFormatting(wb, "2_差值比較表", cols = 6, rows = 2:5000, rule = "<0.05", style = style_sig)


# --- 階段 B: 傳統三時點組內分析 (Friedman/ANOVA) ---
addWorksheet(wb, "3_三時點_無母數(Friedman)")
writeData(wb, "3_三時點_無母數(Friedman)", friedman_results)

addWorksheet(wb, "4_三時點_有母數(ANOVA)")
writeData(wb, "4_三時點_有母數(ANOVA)", oneway_rm_anova_results)

addWorksheet(wb, "5_三時點_事後比較(Wilcox)")
writeData(wb, "5_三時點_事後比較(Wilcox)", posthoc_wilcox)


# --- 階段 C: GEE (原樣保留) ---
addWorksheet(wb, "6a_GEE_Best_Unadj")
writeData(wb, "6a_GEE_Best_Unadj", df_gee_best_unadj)

addWorksheet(wb, "7a_GEE_Best_Adj")
writeData(wb, "7a_GEE_Best_Adj", df_gee_best_adj)

addWorksheet(wb, "7a_GEE_Best_PostHoc")
writeData(wb, "7a_GEE_Best_PostHoc", df_gee_best_ph)

addWorksheet(wb, "6b_GEE_AR1_Unadj")
writeData(wb, "6b_GEE_AR1_Unadj", df_gee_spec_unadj)

addWorksheet(wb, "7b_GEE_AR1_Adj")
writeData(wb, "7b_GEE_AR1_Adj", df_gee_spec_adj)

addWorksheet(wb, "7b_GEE_AR1_PostHoc")
writeData(wb, "7b_GEE_AR1_PostHoc", df_gee_spec_ph)


# --- 階段 D: LMM (原樣保留) ---
addWorksheet(wb, "8_LMM_原始模型")
writeData(wb, "8_LMM_原始模型", df_unadjusted)

addWorksheet(wb, "9_LMM_調整模型")
writeData(wb, "9_LMM_調整模型", df_adjusted)

addWorksheet(wb, "10_共線性檢查(VIF)")
if (!is.null(vif_report)) {
  writeData(wb, "10_共線性檢查(VIF)", vif_report, rowNames = TRUE)
}

# 儲存檔案
saveWorkbook(wb, output_file, overwrite = TRUE)

cat("\n🎉 統計分析報告已更新並格式化完成！\n📂 儲存路徑：", output_file, "\n")



#--畫圖-----
# ==============================================================================
# ==== 繪圖總控制區 (使用統一引擎 + 終極防撞 Bracket 版) ======
# ==============================================================================
library(ggplot2)
library(tidyverse)
library(scales)
library(ggpubr)
# ⚠️ 新增：畫組間橫線 (Bracket) 必備的套件
if (!require(ggsignif)) install.packages("ggsignif")
library(ggsignif)

message("\n=== 開始繪圖流程 ===")

# 1. 再次檢查必要物件
if (!exists("paired_w_results")) warning("❌ 缺少 paired_w_results (組內)")
if (!exists("intergroup_wilcox_results_df")) warning("❌ 缺少 intergroup_wilcox_results_df (組間)")
if (!exists("df_gee_best_ph")) warning("❌ 缺少 df_gee_best_ph (GEE)")

# 2. 路徑設定
folder_date <- format(Sys.Date(), "%y%m%d")
plot_base_path <- file.path(output_path, paste0("Plots_Output_", folder_date))

path_pure <- file.path(plot_base_path, "Report_pure")
path_annotated <- file.path(plot_base_path, "Report_annotated")
path_3point <- file.path(plot_base_path, "Report_3point_annotated")
path_diff_bar <- file.path(plot_base_path, "Report_Delta_Bar") 

for (p in c(path_pure, path_annotated, path_3point, path_diff_bar)) {
  if (!dir.exists(p)) dir.create(p, recursive = TRUE)
}

# 3. 載入統一繪圖工具包
source("C:\\github\\my-first-project\\my-first-project\\PS150_statics\\functioin\\Line_plot_tool.R")
source("C:\\github\\my-first-project\\my-first-project\\PS150_statics\\functioin\\Bar_plot_tool.R")

# 顏色與形狀
my_colors <- c("placebo" = "#31688E", "PS150" = "#E67E22")
my_shapes <- c("placebo" = 16, "PS150" = 17)
Group_A <- "placebo"
Group_B <- "PS150"

# 【關鍵設定】：統一設定折線圖的 Error Bar 閃避寬度，0.35 足以讓兩組徹底分開
my_dodge_w <- 0.35 

# 4. 準備繪圖數據
plot_data_full <- long_measures %>%
  mutate(
    Group_clean = toupper(trimws(as.character(Group))),
    Group = case_when(
      Group_clean %in% c("A", "0", "CONTROL", "C", "\uff21") ~ "placebo",
      Group_clean %in% c("B", "1", "EXP", "E", "\uff22") ~ "PS150",
      Group_clean %in% c("PLACEBO") ~ "placebo",
      Group_clean %in% c("PS150") ~ "PS150",
      TRUE ~ NA_character_
    )
  ) %>%
  select(-Group_clean) %>%
  filter(!is.na(Group)) %>%
  group_by(Group, measure, Trail) %>%
  summarise(
    avg = mean(score, na.rm = TRUE),
    sd = sd(score, na.rm = TRUE),
    n = n(),
    se = sd / sqrt(n),
    .groups = "drop"
  ) %>%
  mutate(Group = factor(Group, levels = c("placebo", "PS150")))

# ==============================================================================
# ==== PART 1: 兩點趨勢圖 (Pre-Post) ====
# ==============================================================================
message("--- 繪製兩點圖 (Annotated 包含組間 Bracket) ---")

plot_data_2pt <- plot_data_full %>%
  filter(Trail %in% c("Pre", "Post")) %>%
  mutate(week_numeric = ifelse(Trail == "Pre", 1, 2))

for (m in unique(plot_data_2pt$measure)) {
  df_sum <- plot_data_2pt %>% filter(measure == m)
  if (nrow(df_sum) == 0) next
  
  df_sum$label_time <- NA
  df_sum$label_AB <- NA
  
  # 組內比較
  if (exists("paired_w_results")) {
    res_placebo <- paired_w_results %>% filter(measure == m, Group == "placebo")
    if (nrow(res_placebo) > 0 && !is.na(res_placebo$p) && res_placebo$p < 0.05) {
      df_sum$label_time[df_sum$Group == "placebo" & df_sum$Trail == "Post"] <- "*"
    }
    res_PS150 <- paired_w_results %>% filter(measure == m, Group == "PS150")
    if (nrow(res_PS150) > 0 && !is.na(res_PS150$p) && res_PS150$p < 0.05) {
      df_sum$label_time[df_sum$Group == "PS150" & df_sum$Trail == "Post"] <- "#"
    }
  }
  
  # 組間比較 -> 標記在 Group_A 防止 Bracket 重複繪製
  if (exists("intergroup_wilcox_results_df")) {
    res_pre <- intergroup_wilcox_results_df %>% filter(measure == m, Trail == "Pre")
    if (nrow(res_pre) > 0 && !is.na(res_pre$p) && res_pre$p < 0.05) {
      df_sum$label_AB[df_sum$Group == "placebo" & df_sum$Trail == "Pre"] <- "$"
    }
    res_post <- intergroup_wilcox_results_df %>% filter(measure == m, Trail == "Post")
    if (nrow(res_post) > 0 && !is.na(res_post$p) && res_post$p < 0.05) {
      df_sum$label_AB[df_sum$Group == "placebo" & df_sum$Trail == "Post"] <- "$"
    }
  }
  
  scale_info <- calc_dynamic_y_scale(df_sum, error_ratio = 0.15)
  
  suppressMessages(suppressWarnings({
    p_base <- create_flexible_line_plot(
      df_s = df_sum, y_breaks = scale_info$breaks, y_limits = scale_info$limits,
      title_text = m, y_label = "Score", x_label = "Time",
      color_pal = my_colors, shape_pal = my_shapes, 
      dodge_w = my_dodge_w 
    ) + 
      scale_x_continuous(breaks = c(1, 2), labels = c("Pre", "Post"), expand = expansion(mult = 0.35))
    
    p_anno <- add_annotations_flexible(
      p = p_base, df_s = df_sum, scale_info = scale_info, 
      dodge_w = my_dodge_w, 
      # 【修正這裡】：拆成 size_star 和 size_pound
      size_star = 8, 
      size_pound = 6, 
      size_dollar = 6, 
      y_gap_rows = 0.05
    )
  }))
  
  safe_name <- gsub("%", "pct", m)
  ggsave(file.path(path_annotated, paste0(safe_name, "_Trend_Annotated.png")), p_anno, width = 4, height = 5, dpi = 300, bg = "white")
  ggsave(file.path(path_pure, paste0(safe_name, "_Trend_Pure.png")), p_base, width = 4, height = 5, dpi = 300, bg = "white")
}


# ==============================================================================
# ==== PART 2: 三點趨勢圖 (GEE Annotated) ====
# ==============================================================================
message("\n--- 繪製三點圖 (GEE Annotated 包含組間 Bracket) ---")

plot_data_3pt <- plot_data_full %>%
  mutate(
    week_numeric = case_when(
      Trail == "Interview" ~ 1,
      Trail == "Pre" ~ 2,
      Trail == "Post" ~ 3
    )
  )

check_gee_intra <- function(msr, grp, tm) {
  if (!exists("df_gee_best_ph")) return(FALSE)
  res <- df_gee_best_ph %>%
    filter(measure == msr, Comparison == "Time_Diff", Group == grp) %>%
    filter(grepl("Interview", contrast) & grepl(tm, contrast))
  if (nrow(res) > 0 && !is.na(res$p.value) && res$p.value < 0.05) return(TRUE)
  return(FALSE)
}

check_gee_inter <- function(msr, tm) {
  if (!exists("df_gee_best_ph")) return(FALSE)
  res <- df_gee_best_ph %>% filter(measure == msr, Comparison == "Group_Diff", Trail == tm)
  if (nrow(res) > 0 && !is.na(res$p.value) && res$p.value < 0.05) return(TRUE)
  return(FALSE)
}

for (m in unique(plot_data_3pt$measure)) {
  df_sum <- plot_data_3pt %>% filter(measure == m)
  if (nrow(df_sum) == 0) next
  
  df_sum$label_time <- NA
  df_sum$label_AB <- NA
  
  if (check_gee_intra(m, "placebo", "Pre")) df_sum$label_time[df_sum$Group == "placebo" & df_sum$Trail == "Pre"] <- "*"
  if (check_gee_intra(m, "placebo", "Post")) df_sum$label_time[df_sum$Group == "placebo" & df_sum$Trail == "Post"] <- "*"
  if (check_gee_intra(m, "PS150", "Pre")) df_sum$label_time[df_sum$Group == "PS150" & df_sum$Trail == "Pre"] <- "#"
  if (check_gee_intra(m, "PS150", "Post")) df_sum$label_time[df_sum$Group == "PS150" & df_sum$Trail == "Post"] <- "#"
  
  if (check_gee_inter(m, "Interview")) df_sum$label_AB[df_sum$Group == "placebo" & df_sum$Trail == "Interview"] <- "$"
  if (check_gee_inter(m, "Pre")) df_sum$label_AB[df_sum$Group == "placebo" & df_sum$Trail == "Pre"] <- "$"
  if (check_gee_inter(m, "Post")) df_sum$label_AB[df_sum$Group == "placebo" & df_sum$Trail == "Post"] <- "$"
  
  scale_info <- calc_dynamic_y_scale(df_sum, error_ratio = 0.15)
  
  suppressMessages(suppressWarnings({
    p_3pt <- create_flexible_line_plot(
      df_s = df_sum, y_breaks = scale_info$breaks, y_limits = scale_info$limits,
      title_text = m, y_label = "Score", x_label = "Time",
      color_pal = my_colors, shape_pal = my_shapes, 
      dodge_w = my_dodge_w
    ) + 
      scale_x_continuous(breaks = c(1, 2, 3), labels = c("Interview", "Pre", "Post"), expand = expansion(mult = 0.15))
    
    p_3pt_anno <- add_annotations_flexible(
      p = p_3pt, df_s = df_sum, scale_info = scale_info, 
      dodge_w = my_dodge_w, 
      # 【修正這裡】：拆成 size_star 和 size_pound
      size_star = 8, 
      size_pound = 6, 
      size_dollar = 6, 
      y_gap_rows = 0.05
    )
  }))
  
  safe_name <- gsub("%", "pct", m)
  ggsave(file.path(path_3point, paste0(safe_name, "_Trend_3pt.png")), p_3pt_anno, width = 5, height = 5, dpi = 300, bg = "white")
}

# ==============================================================================
# ==== PART 3: 差值圖 (Delta Bar Plot) ====
# ==============================================================================
message("\n--- 計算並繪製差值圖 (Bar Plot Tool) ---")

delta_individual <- long_measures %>%
  filter(Trail %in% c("Pre", "Post")) %>%
  select(ID, Group, measure, Trail, score) %>%
  pivot_wider(names_from = Trail, values_from = score) %>%
  mutate(Diff = Post - Pre) %>%
  filter(!is.na(Diff))

delta_summary <- delta_individual %>%
  group_by(Group, measure) %>%
  summarise(
    avg = mean(Diff, na.rm = TRUE),
    sd = sd(Diff, na.rm = TRUE),
    n = n(),
    se = sd / sqrt(n),
    .groups = "drop"
  ) %>%
  mutate(Group = factor(Group, levels = c("placebo", "PS150")))

for (m in unique(delta_summary$measure)) {
  df_bar <- delta_summary %>%
    filter(measure == m) %>%
    mutate(Stage = "Delta") 
  
  if (nrow(df_bar) == 0) next
  
  sub_delta <- delta_individual %>% filter(measure == m)
  p_val <- NA
  if (nrow(sub_delta) >= 2 && n_distinct(sub_delta$Group) == 2) {
    p_val <- tryCatch(wilcox.test(Diff ~ Group, data = sub_delta)$p.value, error = function(e) NA)
  }
  
  df_bar <- df_bar %>% mutate(label_Bet = ifelse(!is.na(p_val) && p_val < 0.05, "*", NA))
  
  scale_info_bar <- calc_dynamic_y_scale_bar(df_bar, y_col = "avg", err_col = "se")
  
  suppressWarnings({
    p_base_bar <- create_flexible_bar_plot(
      df = df_bar, x_col = "Stage", y_col = "avg", err_col = "se", group_col = "Group",
      scale_info = scale_info_bar, title_text = paste(m, "- Change"), 
      y_label = "Difference Score", x_label = NULL, color_pal = my_colors,
      plot_ratio = 1.25 
    ) + theme(axis.text.x = element_blank(), axis.ticks.x = element_blank())
    
    p_anno_bar <- add_annotations_bar(
      p = p_base_bar, df = df_bar, x_col = "Stage", y_col = "avg", err_col = "se", group_col = "Group",
      scale_info = scale_info_bar, groupA_name = Group_A, groupB_name = Group_B,
      dodge_w = 0.8,
      size_dollar = 8, y_gap_rows = 0.08
    )
  })
  
  safe_name <- gsub("%", "pct", m)
  ggsave(filename = file.path(path_diff_bar, paste0(safe_name, "_Diff_Bar_Anno.png")), plot = p_anno_bar, width = 5, height = 6, dpi = 300, bg = "white")
}

cat("\n🎉 所有圖表與報表更新完成！已全面套用標準化繪圖工具！\n")