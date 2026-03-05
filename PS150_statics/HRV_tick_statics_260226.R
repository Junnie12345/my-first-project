rm(list = ls())
library(tidyverse)
library(openxlsx)
library(rstatix)
library(ggplot2)
library(geepack)
library(broom)
library(emmeans)

# ==================================
# ==== 1. 設定路徑與讀取資料 ====
# ==================================
# ⚠️ 請確認您的檔案路徑
data_path <- "C:\\Users\\ngps9\\OneDrive\\onedrive\\桌面\\PS150_results\\2026\\HRV_result_0128.xlsx"
output_folder <- "C:\\Users\\ngps9\\OneDrive\\onedrive\\桌面\\PS150_results\\2026"
output_file <- file.path(output_folder, "HRV_ticks_Stats_260303.xlsx")

if (!dir.exists(output_folder)) dir.create(output_folder, recursive = TRUE)

message("正在讀取資料...")
raw_data <- read.xlsx(data_path, sheet = "HRV_result")

# 定義時間點與順序
timing_map <- c(
  "T0" = "Pre_SO", "T1" = "Post_SO",
  "T2" = "Pre_SO_stb", "T3" = "Post_SO_stb",
  "T4" = "N2_1", "T5" = "N3_1", "T6" = "pre_REM_1", "T7" = "REM_1",
  "T8" = "N2_2", "T9" = "N3_2", "T10" = "pre_REM_2", "T11" = "REM_2"
)

time_levels <- c(
  "Pre_SO", "Post_SO", "Pre_SO_stb", "Post_SO_stb",
  "N2_1", "N3_1", "pre_REM_1", "REM_1",
  "N2_2", "N3_2", "pre_REM_2", "REM_2"
)

hrv_metrics <- c("RRI", "HR", "SDNN", "VLF", "LF", "HF", "TP", "Var", "LF%", "HF%", "LF/HF", "n")

# ==================================
# ==== 2. 資料清理 (確保欄位存在) ====
# ==================================
message("Step 1: 資料清理...")

clean_data <- raw_data %>%
  mutate(
    ID = trimws(as.character(ID)),
    Group = trimws(as.character(Group)),
    Timing = trimws(as.character(Timing))
  ) %>%
  mutate(
    Group_clean = toupper(Group),
    Group = case_when(
      Group_clean %in% c("A", "0", "CONTROL", "C", "\uff21") ~ "placebo",
      Group_clean %in% c("B", "1", "EXP", "E", "\uff22") ~ "PS150",
      TRUE ~ NA_character_
    )
  ) %>%
  select(-Group_clean) %>%
  filter(!is.na(Group)) %>%
  mutate(Group = factor(Group, levels = c("placebo", "PS150"))) %>%
  mutate(Trail = factor(Trail, levels = c(0, 1, 2), labels = c("Interview", "Pre", "Post"))) %>%
  filter(Trail %in% c("Pre", "Post")) %>%
  mutate(Stage = timing_map[Timing]) %>%
  filter(!is.na(Stage)) %>%
  mutate(Stage = factor(Stage, levels = time_levels)) %>%
  pivot_longer(cols = any_of(hrv_metrics), names_to = "Metric", values_to = "score") %>%
  mutate(score = as.numeric(score)) %>%
  filter(!is.na(score)) %>%
  mutate(measure_full = paste0(Metric, "_", Stage)) # 用於 GEE 識別

# 標記成對資料
valid_ids <- clean_data %>%
  group_by(Metric, Stage, ID) %>%
  filter(n_distinct(Trail) == 2) %>%
  ungroup() %>%
  select(ID, Metric, Stage) %>%
  distinct() %>%
  mutate(Is_Paired = TRUE)

clean_data <- clean_data %>%
  left_join(valid_ids, by = c("ID", "Metric", "Stage")) %>%
  mutate(Is_Paired = replace_na(Is_Paired, FALSE))

# 準備 Delta 資料
delta_data <- clean_data %>%
  filter(Is_Paired == TRUE) %>%
  select(ID, Group, Trail, Metric, Stage, score, measure_full) %>%
  pivot_wider(names_from = Trail, values_from = score) %>%
  mutate(Diff = Post - Pre) %>%
  filter(!is.na(Diff))

# ==================================
# ==== 3. 統計分析 (有母數 vs 無母數) ====
# ==================================
message("Step 2: 執行統計分析 (Parametric & Non-Parametric)...")

# --- A. 基礎敘述統計 (Pre/Post) ---
desc_stats <- clean_data %>%
  group_by(Group, Trail, Metric, Stage) %>%
  summarise(
    n = n(),
    Mean = mean(score, na.rm = T),
    SEM = sd(score, na.rm = T) / sqrt(n),
    Median = median(score, na.rm = T),
    IQR = IQR(score, na.rm = T),
    Shapiro_p = ifelse(n() >= 3, shapiro.test(score)$p.value, NA),
    .groups = "drop"
  ) %>%
  mutate(Is_Normal = ifelse(Shapiro_p > 0.05, "Yes", "No"))

# --- B. 基礎敘述統計 (Delta) ---
desc_delta <- delta_data %>%
  group_by(Group, Metric, Stage) %>%
  summarise(
    n = n(),
    Delta_Mean = mean(Diff, na.rm = T),
    Delta_SEM = sd(Diff, na.rm = T) / sqrt(n),
    Delta_Median = median(Diff, na.rm = T),
    .groups = "drop"
  )

# --- C. 統計檢定迴圈 ---
res_para_list <- list()
res_nonpara_list <- list()

combos <- clean_data %>%
  select(Metric, Stage) %>%
  distinct()

for (i in 1:nrow(combos)) {
  m <- combos$Metric[i]
  s <- combos$Stage[i]

  dat_sub <- clean_data %>% filter(Metric == m, Stage == s)
  delta_sub <- delta_data %>% filter(Metric == m, Stage == s)

  # 1. 組內比較 (Pre vs Post)
  # placebo組
  dat_placebo <- dat_sub %>%
    filter(Group == "placebo", Is_Paired) %>%
    arrange(ID, Trail)
  p_within_A_para <- NA
  p_within_A_non <- NA
  if (nrow(dat_placebo) > 0 && n_distinct(dat_placebo$Trail) == 2) {
    # 改用向量輸入避免公式錯誤
    vec_pre <- dat_placebo$score[dat_placebo$Trail == "Pre"]
    vec_post <- dat_placebo$score[dat_placebo$Trail == "Post"]
    if (length(vec_pre) == length(vec_post) && length(vec_pre) > 1) {
      try(
        {
          p_within_A_para <- t.test(vec_pre, vec_post, paired = T)$p.value
        },
        silent = T
      )
      try(
        {
          p_within_A_non <- wilcox.test(vec_pre, vec_post, paired = T)$p.value
        },
        silent = T
      )
    }
  }

  # PS150組
  dat_PS150 <- dat_sub %>%
    filter(Group == "PS150", Is_Paired) %>%
    arrange(ID, Trail)
  p_within_B_para <- NA
  p_within_B_non <- NA
  if (nrow(dat_PS150) > 0 && n_distinct(dat_PS150$Trail) == 2) {
    vec_pre <- dat_PS150$score[dat_PS150$Trail == "Pre"]
    vec_post <- dat_PS150$score[dat_PS150$Trail == "Post"]
    if (length(vec_pre) == length(vec_post) && length(vec_pre) > 1) {
      try(
        {
          p_within_B_para <- t.test(vec_pre, vec_post, paired = T)$p.value
        },
        silent = T
      )
      try(
        {
          p_within_B_non <- wilcox.test(vec_pre, vec_post, paired = T)$p.value
        },
        silent = T
      )
    }
  }

  # 2. 組間比較 (A vs B)
  # Pre
  dat_pre <- dat_sub %>% filter(Trail == "Pre")
  p_bet_pre_para <- NA
  p_bet_pre_non <- NA
  if (n_distinct(dat_pre$Group) == 2 && nrow(dat_pre) > 2) {
    try(
      {
        p_bet_pre_para <- t.test(score ~ Group, data = dat_pre, var.equal = F)$p.value
      },
      silent = T
    )
    try(
      {
        p_bet_pre_non <- wilcox.test(score ~ Group, data = dat_pre)$p.value
      },
      silent = T
    )
  }

  # Post
  dat_post <- dat_sub %>% filter(Trail == "Post")
  p_bet_post_para <- NA
  p_bet_post_non <- NA
  if (n_distinct(dat_post$Group) == 2 && nrow(dat_post) > 2) {
    try(
      {
        p_bet_post_para <- t.test(score ~ Group, data = dat_post, var.equal = F)$p.value
      },
      silent = T
    )
    try(
      {
        p_bet_post_non <- wilcox.test(score ~ Group, data = dat_post)$p.value
      },
      silent = T
    )
  }

  # Delta
  p_delta_para <- NA
  p_delta_non <- NA
  if (n_distinct(delta_sub$Group) == 2 && nrow(delta_sub) > 2) {
    try(
      {
        p_delta_para <- t.test(Diff ~ Group, data = delta_sub, var.equal = F)$p.value
      },
      silent = T
    )
    try(
      {
        p_delta_non <- wilcox.test(Diff ~ Group, data = delta_sub)$p.value
      },
      silent = T
    )
  }

  base_info <- data.frame(Metric = m, Stage = s)

  res_para_list[[i]] <- bind_cols(base_info, data.frame(
    p_Within_A = p_within_A_para, p_Within_B = p_within_B_para,
    p_Bet_Pre = p_bet_pre_para, p_Bet_Post = p_bet_post_para, p_Bet_Delta = p_delta_para
  ))

  res_nonpara_list[[i]] <- bind_cols(base_info, data.frame(
    p_Within_A = p_within_A_non, p_Within_B = p_within_B_non,
    p_Bet_Pre = p_bet_pre_non, p_Bet_Post = p_bet_post_non, p_Bet_Delta = p_delta_non
  ))
}

df_p_para <- bind_rows(res_para_list)
df_p_nonpara <- bind_rows(res_nonpara_list)

# ==================================
# ==== 4. GEE Post-hoc 分析 ====
# ==================================
message("Step 3: GEE Post-hoc (Time & Group)...")

gee_results_list <- list()

for (m_full in unique(clean_data$measure_full)) {
  dat <- clean_data %>%
    filter(measure_full == m_full) %>%
    arrange(ID, Trail) %>%
    droplevels()
  if (nrow(dat) < 10) next

  mod <- tryCatch(
    {
      geeglm(score ~ Group * Trail, data = dat, id = ID, corstr = "ar1")
    },
    error = function(e) {
      tryCatch(
        {
          geeglm(score ~ Group * Trail, data = dat, id = ID, corstr = "independence")
        },
        error = function(e2) NULL
      )
    }
  )

  if (!is.null(mod)) {
    emm <- emmeans(mod, ~ Group * Trail)

    # Time Effect
    res_time <- contrast(emm, method = "pairwise", simple = "Trail") %>%
      tidy() %>%
      select(Group, contrast, estimate, p.value) %>%
      mutate(Type = "Time_Effect")

    # Group Effect
    res_group <- contrast(emm, method = "pairwise", simple = "Group") %>%
      tidy() %>%
      select(Trail, contrast, estimate, p.value) %>%
      mutate(Type = "Group_Effect")

    # Interaction P
    anova_res <- anova(mod)
    p_inter <- tryCatch(anova_res["Group:Trail", "Pr(>Chi)"], error = function(e) NA)

    combined <- bind_rows(
      res_time %>% rename(Factor = Group),
      res_group %>% rename(Factor = Trail)
    ) %>% mutate(measure_full = m_full, Interaction_p = p_inter)

    gee_results_list[[m_full]] <- combined
  }
}
df_gee_posthoc <- bind_rows(gee_results_list)

# ==================================
# ==== 5. 彙整報表 (修正 ERROR 處) ====
# ==================================
message("Step 4: 彙整報表...")

# 5.1 整理 Mean/SEM 寬表格 (Pre/Post)
# 🔥 修正: 加入 names_glue 確保欄位名稱為 A_Mean_Pre 格式
table_prepost <- desc_stats %>%
  pivot_wider(
    id_cols = c(Metric, Stage),
    names_from = c(Group, Trail),
    values_from = c(Mean, SEM),
    names_glue = "{Group}_{.value}_{Trail}" # 自動生成 A_Mean_Pre
  ) %>%
  select(
    Metric, Stage,
    placebo_Mean_Pre, placebo_SEM_Pre, placebo_Mean_Post, placebo_SEM_Post,
    PS150_Mean_Pre, PS150_SEM_Pre, PS150_Mean_Post, PS150_SEM_Post
  )

# 5.2 整理 Delta 寬表格
table_delta <- desc_delta %>%
  pivot_wider(
    id_cols = c(Metric, Stage),
    names_from = Group,
    values_from = c(Delta_Mean, Delta_SEM),
    names_glue = "{.value}_{Group}" # 生成 Delta_Mean_A
  ) %>%
  select(Metric, Stage, Delta_Mean_placebo, Delta_SEM_placebo, Delta_Mean_PS150, Delta_SEM_PS150)

# 5.3 組合 - 有母數報表
final_para <- table_prepost %>%
  left_join(table_delta, by = c("Metric", "Stage")) %>%
  left_join(df_p_para, by = c("Metric", "Stage"))

# 5.4 組合 - 無母數報表
final_nonpara <- table_prepost %>%
  left_join(table_delta, by = c("Metric", "Stage")) %>%
  left_join(df_p_nonpara, by = c("Metric", "Stage"))

# ==================================
# ==== 6. 匯出 Excel ====
# ==================================
message("Step 5: 匯出 Excel...")
wb <- createWorkbook()
style_sig <- createStyle(bgFill = "#FFFF00")

# Sheet 1: 基礎統計
addWorksheet(wb, "0_基礎描述")
writeData(wb, "0_基礎描述", desc_stats)
conditionalFormatting(wb, "0_基礎描述", cols = which(names(desc_stats) == "Shapiro_p"), rows = 2:5000, rule = "<0.05", style = createStyle(fontColour = "#FF0000", textDecoration = "bold"))

# Sheet 2: 有母數結果
addWorksheet(wb, "1_有母數分析(Parametric)")
writeData(wb, "1_有母數分析(Parametric)", final_para)
p_cols_para <- which(grepl("p_", names(final_para)))
conditionalFormatting(wb, "1_有母數分析(Parametric)", cols = p_cols_para, rows = 2:5000, rule = "<0.05", style = style_sig)

# Sheet 3: 無母數結果
addWorksheet(wb, "2_無母數分析(Non-Para)")
writeData(wb, "2_無母數分析(Non-Para)", final_nonpara)
p_cols_non <- which(grepl("p_", names(final_nonpara)))
conditionalFormatting(wb, "2_無母數分析(Non-Para)", cols = p_cols_non, rows = 2:5000, rule = "<0.05", style = style_sig)

# Sheet 4: GEE Post-hoc
addWorksheet(wb, "3_GEE_PostHoc")
if (nrow(df_gee_posthoc) > 0) {
  writeData(wb, "3_GEE_PostHoc", df_gee_posthoc)
  conditionalFormatting(wb, "3_GEE_PostHoc", cols = which(names(df_gee_posthoc) == "p.value"), rows = 2:5000, rule = "<0.05", style = style_sig)
}

saveWorkbook(wb, output_file, overwrite = TRUE)


# ==================================
# ==== 7. 繪圖 (使用動態 Bar Plot Tool) ====
# ==================================
message("Step 6: 開始繪圖...")

# 載入我們強大的柱狀圖工具包
source("C:\\github\\my-first-project\\my-first-project\\PS150_statics\\functioin\\Bar_plot_tool.R")

date_str <- format(Sys.Date(), "%y%m%d")
base_plot_dir <- file.path(output_folder, paste0("HRV_Plots_", date_str))

dir_pure <- list(pre = file.path(base_plot_dir, "Pre_pure"), post = file.path(base_plot_dir, "Post_pure"), delta = file.path(base_plot_dir, "Delta_pure"))
dir_anno <- list(pre = file.path(base_plot_dir, "Pre_annotated"), post = file.path(base_plot_dir, "Post_annotated"), delta = file.path(base_plot_dir, "Delta_annotated"))
lapply(c(dir_pure, dir_anno), function(x) if (!dir.exists(x)) dir.create(x, recursive = TRUE))

p_map <- final_nonpara %>%
  select(Metric, Stage, p_Within_A, p_Within_B, p_Bet_Pre, p_Bet_Post, p_Bet_Delta) %>%
  mutate(across(starts_with("p_"), ~ replace_na(., 1)))

get_hrv_unit <- function(metric_name) {
  if (metric_name %in% c("TP", "VLF", "LF", "HF", "Var")) return("(ms\u00B2)")
  if (metric_name %in% c("LF/HF")) return("(Ratio)")
  if (metric_name %in% c("SDNN", "RRI")) return("(ms)")
  if (metric_name %in% c("HR")) return("(bpm)")
  if (grepl("%", metric_name)) return("(%)")
  if (metric_name == "n") return("(count)")
  return("")
}

my_fill <- c("placebo" = "#31688E", "PS150" = "#E67E22")
group_names <- levels(clean_data$Group)
Group_A <- group_names[1] 
Group_B <- group_names[2]

# 【已將副標題變數安全移除】

for (metric in unique(clean_data$Metric)) {
  safe_name <- gsub("%", "pct", metric); safe_name <- gsub("/", "div", safe_name); safe_name <- gsub("[^A-Za-z0-9_]", "", safe_name)
  unit_lab <- get_hrv_unit(metric)
  
  # --- 1. Delta Plot ---
  dat_d <- desc_delta %>% filter(Metric == metric)
  if (nrow(dat_d) > 0) {
    dat_p <- dat_d %>% left_join(p_map, by = c("Metric", "Stage")) %>%
      mutate(
        label_A = ifelse(Group == Group_A & p_Within_A < 0.05, "*", NA),
        label_B = ifelse(Group == Group_B & p_Within_B < 0.05, "#", NA),
        label_Bet = ifelse(p_Bet_Delta < 0.05, "$", NA)
      )
    
    scale_info <- calc_dynamic_y_scale_bar(dat_p, "Delta_Mean", "Delta_SEM")
    
    p_base <- create_flexible_bar_plot(
      df = dat_p, x_col = "Stage", y_col = "Delta_Mean", err_col = "Delta_SEM", group_col = "Group",
      scale_info = scale_info, title_text = paste0(metric, " - Difference"), y_label = unit_lab, color_pal = my_fill
    )
    # 【關鍵修正】：直接不傳入 anno_subtitle，函數預設就會使用 NULL，不畫副標題！
    p_anno <- add_annotations_bar(
      p = p_base, df = dat_p, x_col = "Stage", y_col = "Delta_Mean", err_col = "Delta_SEM", group_col = "Group",
      scale_info = scale_info, groupA_name = Group_A, groupB_name = Group_B
    )
    
    ggsave(file.path(dir_pure$delta, paste0("Delta_", safe_name, ".png")), p_base, width = 8, height = 5, bg="white")
    ggsave(file.path(dir_anno$delta, paste0("Delta_", safe_name, ".png")), p_anno, width = 8, height = 5, bg="white")
  }
  
  # --- 2. Pre Plot ---
  dat_pre <- desc_stats %>% filter(Metric == metric, Trail == "Pre")
  if (nrow(dat_pre) > 0) {
    dat_p_pre <- dat_pre %>% left_join(p_map, by = c("Metric", "Stage")) %>%
      mutate(label_Bet = ifelse(p_Bet_Pre < 0.05, "$", NA))
    
    scale_info_pre <- calc_dynamic_y_scale_bar(dat_p_pre, "Mean", "SEM")
    
    p_base_pre <- create_flexible_bar_plot(
      df = dat_p_pre, x_col = "Stage", y_col = "Mean", err_col = "SEM", group_col = "Group",
      scale_info = scale_info_pre, title_text = paste0(metric, " - Pre Test"), y_label = unit_lab, color_pal = my_fill
    )
    # 【關鍵修正】：移除 anno_subtitle
    p_anno_pre <- add_annotations_bar(
      p = p_base_pre, df = dat_p_pre, x_col = "Stage", y_col = "Mean", err_col = "SEM", group_col = "Group",
      scale_info = scale_info_pre, groupA_name = Group_A, groupB_name = Group_B
    )
    
    ggsave(file.path(dir_pure$pre, paste0("Pre_", safe_name, ".png")), p_base_pre, width = 8, height = 5, bg="white")
    ggsave(file.path(dir_anno$pre, paste0("Pre_", safe_name, ".png")), p_anno_pre, width = 8, height = 5, bg="white")
  }
  
  # --- 3. Post Plot ---
  dat_post <- desc_stats %>% filter(Metric == metric, Trail == "Post")
  if (nrow(dat_post) > 0) {
    dat_p_post <- dat_post %>% left_join(p_map, by = c("Metric", "Stage")) %>%
      mutate(label_Bet = ifelse(p_Bet_Post < 0.05, "$", NA))
    
    scale_info_post <- calc_dynamic_y_scale_bar(dat_p_post, "Mean", "SEM")
    
    p_base_post <- create_flexible_bar_plot(
      df = dat_p_post, x_col = "Stage", y_col = "Mean", err_col = "SEM", group_col = "Group",
      scale_info = scale_info_post, title_text = paste0(metric, " - Post Test"), y_label = unit_lab, color_pal = my_fill
    )
    # 【關鍵修正】：移除 anno_subtitle
    p_anno_post <- add_annotations_bar(
      p = p_base_post, df = dat_p_post, x_col = "Stage", y_col = "Mean", err_col = "SEM", group_col = "Group",
      scale_info = scale_info_post, groupA_name = Group_A, groupB_name = Group_B
    )
    
    ggsave(file.path(dir_pure$post, paste0("Post_", safe_name, ".png")), p_base_post, width = 8, height = 5, bg="white")
    ggsave(file.path(dir_anno$post, paste0("Post_", safe_name, ".png")), p_anno_post, width = 8, height = 5, bg="white")
  }
}

message("🎉 任務完成！所有高品質柱狀圖已生成。")