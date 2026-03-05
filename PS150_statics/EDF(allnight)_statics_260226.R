rm(list = ls())
library(tidyverse)
library(openxlsx)
library(rstatix)
library(geepack)
library(broom)

# ==================================
# ==== 1. 設定路徑與讀取資料 ====
# ==================================

# ⚠️ 請修改你的檔案路徑
data_path <- "C:\\Users\\ngps9\\OneDrive\\onedrive\\桌面\\PS150_results\\2026\\EDF_result(allnight)_2601124_clean.xlsx"
info_path <- "C:\\Users\\ngps9\\OneDrive\\onedrive\\桌面\\PS150_results\\2026\\受試者進度紀錄與基本資料260117_shift.xlsx"
output_folder <- "C:\\Users\\ngps9\\OneDrive\\onedrive\\桌面\\PS150_results\\2026"
output_file <- file.path(output_folder, "Allnight_statics_260303.xlsx")

if (!dir.exists(output_folder)) dir.create(output_folder, recursive = TRUE)

message("正在讀取資料...")
raw_data <- read.xlsx(data_path, sheet = 1)

demographics <- NULL
if (file.exists(info_path)) {
  try(
    {
      demographics <- read.xlsx(info_path, sheet = "完整資料") %>%
        select(ID, Age, BMI) %>%
        mutate(ID = as.character(ID))
    },
    silent = TRUE
  )
}

# ==================================
# ==== 2. 資料清理 (嚴格配對邏輯) ====
# ==================================
message("正在整理資料結構...")

# 2.1 基礎清理
long_data_basic <- raw_data %>%
  mutate(
    ID = as.character(ID),
    Group = trimws(as.character(Group)),
    Group = na_if(Group, ""),
    Group = na_if(Group, "NA")
  ) %>%
  mutate(
    Group_clean = toupper(trimws(Group)),
    Group = case_when(
      Group_clean %in% c("A", "0", "CONTROL", "C", "\uff21") ~ "placebo",
      Group_clean %in% c("B", "1", "EXP", "E", "\uff22") ~ "PS150",
      TRUE ~ NA_character_
    )
  ) %>%
  select(-Group_clean) %>%
  filter(!is.na(Group)) %>%
  mutate(Group = factor(Group, levels = c("placebo", "PS150"))) %>%
  filter(Trail %in% c(1, 2)) %>%
  mutate(Trail = factor(Trail, levels = c(1, 2), labels = c("Pre", "Post"))) %>%
  pivot_longer(
    cols = -c(ID, Group, Trail),
    names_to = c("Metric", "Stage"),
    names_pattern = "(.*)_(Wake|N1|N2|N3|REM|NREM)$",
    values_to = "score"
  ) %>%
  mutate(
    score = as.numeric(score),
    measure_full = paste0(Metric, "_", Stage)
  ) %>%
  filter(!is.na(score)) %>%
  distinct(ID, Trail, measure_full, .keep_all = TRUE) # 移除重複

# 2.2 標記成對資料
valid_ids <- long_data_basic %>%
  group_by(measure_full, ID) %>%
  filter(n_distinct(Trail) == 2) %>%
  ungroup() %>%
  select(ID, measure_full) %>%
  distinct() %>%
  mutate(Is_Paired = TRUE)

long_data <- long_data_basic %>%
  left_join(valid_ids, by = c("ID", "measure_full")) %>%
  mutate(Is_Paired = replace_na(Is_Paired, FALSE))

if (!is.null(demographics)) {
  long_data <- long_data %>% left_join(demographics, by = "ID")
}

measures_list <- unique(long_data$measure_full)

# ==================================
# ==== 3. 製作 Sheet 1: 基礎統計+常態檢定 ====
# ==================================
message("計算基礎描述與常態檢定...")

desc_normality <- long_data %>%
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
  mutate(
    Is_Normal = ifelse(Shapiro_p > 0.05, "Yes", "No")
  ) %>%
  arrange(measure_full, Group, Trail)

# ==================================
# ==== 4. 製作 Sheet 2: 正規結果總表 (Pre/Post) ====
# ==================================
message("計算 Pre/Post 正規報表...")

# 4.1 計算 Mean/SEM 寬表格
stats_paper <- desc_normality %>%
  mutate(SEM = SD / sqrt(n)) %>%
  pivot_wider(
    id_cols = measure_full,
    names_from = c(Group, Trail),
    values_from = c(Mean, SEM),
    names_glue = "{Group}_{.value}_{Trail}"
  ) %>%
  select(
    measure_full,
    placebo_Mean_Pre, placebo_SEM_Pre, placebo_Mean_Post, placebo_SEM_Post,
    PS150_Mean_Pre, PS150_SEM_Pre, PS150_Mean_Post, PS150_SEM_Post
  )

# 4.2 計算 P 值
p_within <- long_data %>%
  filter(Is_Paired == TRUE) %>%
  group_by(Group, measure_full) %>%
  filter(n() > 2) %>%
  wilcox_test(score ~ Trail, paired = TRUE) %>%
  select(Group, measure_full, p) %>%
  pivot_wider(names_from = Group, values_from = p, names_prefix = "p_Within_")

p_between <- long_data %>%
  group_by(Trail, measure_full) %>%
  filter(n_distinct(Group) == 2) %>%
  wilcox_test(score ~ Group) %>%
  select(Trail, measure_full, p) %>%
  pivot_wider(names_from = Trail, values_from = p, names_prefix = "p_Between_")

sheet2_table <- stats_paper %>%
  left_join(p_within, by = "measure_full") %>%
  left_join(p_between, by = "measure_full")

# ==================================
# ==== 5. 製作 Sheet 3: 差值比較表 (Delta) - 修正命名錯誤 ====
# ==================================
message("計算差值 (Delta) 與分析...")

# 5.1 計算每個人的 Delta
delta_data <- long_data %>%
  filter(Is_Paired == TRUE) %>%
  select(ID, Group, Trail, measure_full, score) %>%
  pivot_wider(names_from = Trail, values_from = score) %>%
  mutate(Diff = Post - Pre) %>%
  filter(!is.na(Diff))

# 5.2 計算 Delta 的 Mean 和 SEM
delta_stats <- delta_data %>%
  group_by(measure_full, Group) %>%
  summarise(
    # 這裡我們先用簡單的名稱，避免 pivot 時重複前綴
    mean = mean(Diff, na.rm = TRUE),
    sd = sd(Diff, na.rm = TRUE),
    n = n(),
    sem = sd / sqrt(n),
    .groups = "drop"
  ) %>%
  # 轉寬格式
  pivot_wider(
    id_cols = measure_full,
    names_from = Group,
    values_from = c(mean, sem),
    # 🔥 關鍵修正：這裡會產生 diff_mean_A, diff_sem_A
    names_glue = "diff_{.value}_{Group}"
  ) %>%
  # 重新命名以符合大小寫要求 (sem -> SEM)
  rename_with(~ sub("diff_sem", "diff_SEM", .x), contains("diff_sem")) %>%
  # 選取並排序 (使用 any_of 避免萬一缺組時報錯)
  select(
    measure_full,
    any_of(c("diff_mean_placebo", "diff_SEM_placebo", "diff_mean_PS150", "diff_SEM_PS150"))
  )

# 5.3 差值統計檢定
delta_test <- delta_data %>%
  group_by(measure_full) %>%
  filter(n_distinct(Group) == 2) %>%
  wilcox_test(Diff ~ Group) %>%
  select(measure_full, p) %>%
  mutate(method = "Mann-Whitney U")

# 5.4 合併 Sheet 3
sheet3_table <- delta_stats %>%
  left_join(delta_test, by = "measure_full")

# ==================================
# ==== 6. 匯出 Excel ====
# ==================================
message("正在產生 Excel 報表...")

wb <- createWorkbook()
style_sig <- createStyle(bgFill = "#FFFF00")
style_warn <- createStyle(fontColour = "#FF0000", textDecoration = "bold")

# Sheet 1
addWorksheet(wb, "0_基礎描述與常態檢定")
writeData(wb, "0_基礎描述與常態檢定", desc_normality)
conditionalFormatting(wb, "0_基礎描述與常態檢定", cols = which(names(desc_normality) == "Shapiro_p"), rows = 2:5000, rule = "<0.05", style = style_warn)

# Sheet 2
addWorksheet(wb, "1_正規結果總表")
writeData(wb, "1_正規結果總表", sheet2_table)
addStyle(wb, "1_正規結果總表", createStyle(numFmt = "0.00"), rows = 2:5000, cols = 2:9, gridExpand = TRUE)
addStyle(wb, "1_正規結果總表", createStyle(numFmt = "0.000"), rows = 2:5000, cols = 10:13, gridExpand = TRUE)
p_cols_s2 <- which(grepl("p_", names(sheet2_table)))
if (length(p_cols_s2) > 0) conditionalFormatting(wb, "1_正規結果總表", cols = p_cols_s2, rows = 2:5000, rule = "<0.05", style = style_sig)

# Sheet 3
addWorksheet(wb, "2_差值比較表")
writeData(wb, "2_差值比較表", sheet3_table)
addStyle(wb, "2_差值比較表", createStyle(numFmt = "0.00"), rows = 2:5000, cols = 2:5, gridExpand = TRUE)
addStyle(wb, "2_差值比較表", createStyle(numFmt = "0.000"), rows = 2:5000, cols = 6, gridExpand = TRUE)
conditionalFormatting(wb, "2_差值比較表", cols = 6, rows = 2:5000, rule = "<0.05", style = style_sig)

saveWorkbook(wb, output_file, overwrite = TRUE)
message(paste("\n🎉 修正完成！\n📂 檔案位置：", output_file))









library(ggplot2)
library(dplyr)
library(tidyr)
library(rstatix)
library(ggplot2)
library(dplyr)
library(tidyr)
library(rstatix)

# ==================================
# ==== 6. 畫圖資料準備與路徑設定 ====
# ==================================
message("正在準備繪圖與路徑...")

# 6.0 設定路徑結構
date_str <- format(Sys.Date(), "%y%m%d")
base_plot_dir <- file.path(output_folder, paste0("Plots_Output_", date_str))

# 定義資料夾
dir_pure <- list(
  line  = file.path(base_plot_dir, "1_LinePlots_Interaction_pure"),
  pre   = file.path(base_plot_dir, "2_BarPlots_Pre_pure"),
  post  = file.path(base_plot_dir, "3_BarPlots_Post_pure"),
  delta = file.path(base_plot_dir, "4_BarPlots_Delta_pure")
)

dir_anno <- list(
  pre   = file.path(base_plot_dir, "2_BarPlots_Pre_annotated"),
  post  = file.path(base_plot_dir, "3_BarPlots_Post_annotated"),
  delta = file.path(base_plot_dir, "4_BarPlots_Delta_annotated")
)

# 建立資料夾
lapply(c(dir_pure, dir_anno), function(x) if (!dir.exists(x)) dir.create(x, recursive = TRUE))

message(paste("圖表將輸出至主目錄：", base_plot_dir))

# 6.1 資料更名 (確保名稱一致)
plot_data_source <- long_data %>%
  mutate(
    Metric = case_when(
      Metric == "a_" ~ "alpha%",
      Metric == "b_" ~ "beta%",
      Metric == "d_" ~ "delta%",
      Metric == "t_" ~ "theta%",
      Metric == "s_" ~ "sigma%",
      TRUE ~ Metric
    ),
    measure_full = paste0(Metric, "_", Stage)
  )

# Stage 順序
stage_levels <- c("Wake", "N1", "N2", "N3", "REM", "NREM")
my_colors <- c("placebo" = "#31688E", "PS150" = "#E67E22")
my_fill <- c("placebo" = "#31688E", "PS150" = "#E67E22")

# 6.2 計算 Mean/SEM (繪圖用)
plot_df_basic <- plot_data_source %>%
  mutate(Stage = factor(Stage, levels = stage_levels)) %>%
  filter(!is.na(Stage)) %>%
  group_by(Group, Trail, Metric, Stage, measure_full) %>%
  summarise(
    mean = mean(score, na.rm = TRUE),
    sd = sd(score, na.rm = TRUE),
    n = n(),
    se = sd / sqrt(n),
    .groups = "drop"
  )

# 6.3 計算 Delta 資料 (差值用)
delta_individual <- plot_data_source %>%
  filter(Is_Paired == TRUE) %>%
  select(ID, Group, Trail, Metric, Stage, score) %>%
  pivot_wider(names_from = Trail, values_from = score) %>%
  mutate(Diff = Post - Pre) %>%
  filter(!is.na(Diff))

plot_df_delta <- delta_individual %>%
  mutate(Stage = factor(Stage, levels = stage_levels)) %>%
  group_by(Group, Metric, Stage) %>%
  summarise(
    mean = mean(Diff, na.rm = TRUE),
    sd = sd(Diff, na.rm = TRUE),
    n = n(),
    se = sd / sqrt(n),
    .groups = "drop"
  )

# ==================================
# ==== 6.4 關鍵步驟：建立 P 值地圖 ====
# ==================================
message("正在計算無母數檢定 P 值 (用於標記 * # $)...")

# 建立一個空的 Data Frame 來存 P 值
p_map <- data.frame()

# 取得所有 Metric 和 Stage 的組合
combinations <- plot_data_source %>%
  select(Metric, Stage) %>%
  distinct() %>%
  filter(!is.na(Stage))

for (i in 1:nrow(combinations)) {
  m <- combinations$Metric[i]
  s <- combinations$Stage[i]

  # 篩選資料
  sub_dat <- plot_data_source %>% filter(Metric == m, Stage == s)
  sub_delta <- delta_individual %>% filter(Metric == m, Stage == s)

  # --- 計算 P 值 ---

  # 1. placebo 組內差異 (Pre vs Post) -> *
  dat_placebo <- sub_dat %>% filter(Group == "placebo", Is_Paired == TRUE)
  p_within_A <- NA
  if (nrow(dat_placebo) >= 2 && n_distinct(dat_placebo$Trail) == 2) {
    try(
      {
        p_within_A <- wilcox.test(score ~ Trail, data = dat_placebo, paired = TRUE)$p.value
      },
      silent = T
    )
  }

  # 2. PS150 組內差異 (Pre vs Post) -> #
  dat_PS150 <- sub_dat %>% filter(Group == "PS150", Is_Paired == TRUE)
  p_within_B <- NA
  if (nrow(dat_PS150) >= 2 && n_distinct(dat_PS150$Trail) == 2) {
    try(
      {
        p_within_B <- wilcox.test(score ~ Trail, data = dat_PS150, paired = TRUE)$p.value
      },
      silent = T
    )
  }

  # 3. Delta 組間差異 (Delta placebo vs Delta PS150) -> $
  p_delta_bet <- NA
  if (nrow(sub_delta) >= 2 && n_distinct(sub_delta$Group) == 2) {
    try(
      {
        p_delta_bet <- wilcox.test(Diff ~ Group, data = sub_delta)$p.value
      },
      silent = T
    )
  }

  # 4. Pre/Post 同時間點組間差異 (Pre placebo vs PS150, Post placebo vs PS150) -> $ for Pre/Post plots
  p_pre_bet <- NA
  try(
    {
      p_pre_bet <- wilcox.test(score ~ Group, data = sub_dat %>% filter(Trail == "Pre"))$p.value
    },
    silent = T
  )

  p_post_bet <- NA
  try(
    {
      p_post_bet <- wilcox.test(score ~ Group, data = sub_dat %>% filter(Trail == "Post"))$p.value
    },
    silent = T
  )

  # 存入總表
  p_map <- bind_rows(p_map, data.frame(
    Metric = m,
    Stage = s,
    p_within_A = p_within_A,
    p_within_B = p_within_B,
    p_delta_bet = p_delta_bet,
    p_pre_bet = p_pre_bet,
    p_post_bet = p_post_bet
  ))
}

# 確保 P 值表沒有 NA (避免繪圖報錯)
p_map[is.na(p_map)] <- 1

# ==================================
# ==== 函數：Y 軸單位判斷 ====
# ==================================
get_y_unit_simple <- function(metric_name) {
  clean <- gsub("_.*", "", metric_name)
  if (grepl("%", metric_name)) {
    return("(%)")
  }
  if (clean %in% c("TP", "VLF", "LF", "HF", "alleeg")) {
    return("(ms\u00B2)")
  }
  if (clean %in% c("LF_HF", "LF_HF_ratio")) {
    return("(Ratio)")
  }
  if (clean %in% c("SD", "SDNN", "RMSSD", "RR", "SDANN", "SDSD")) {
    return("(ms)")
  }
  if (clean == "MPF") {
    return("(Hz)")
  }
  if (clean == "mSpO2") {
    return("(%)")
  }
  if (clean == "n") {
    return("(Count)")
  }
  return("")
}

all_measures_full <- unique(plot_df_basic$measure_full)
all_metrics <- unique(plot_df_basic$Metric)

# ==================================
# ==== 7. 繪製折線圖 (Line Plots) ====
# ==================================
message("繪製折線圖 (Pure)...")
for (m in all_measures_full) {
  sub_data <- plot_df_basic %>% filter(measure_full == m)
  if (nrow(sub_data) == 0) next
  y_lab <- get_y_unit_simple(sub_data$Metric[1])

  p <- ggplot(sub_data, aes(x = Trail, y = mean, group = Group, color = Group)) +
    geom_line(linewidth = 1.2) +
    geom_point(size = 4) +
    geom_errorbar(aes(ymin = mean - se, ymax = mean + se), width = 0.1, linewidth = 0.8) +
    scale_color_manual(values = my_colors) +
    labs(title = m, y = y_lab, x = NULL) +
    theme_classic() +
    theme(
      plot.title = element_text(face = "bold", size = 14, hjust = 0.5), axis.text = element_text(size = 12, color = "black"),
      axis.title.y = element_text(size = 12, face = "bold"), legend.position = "top", aspect.ratio = 1.25
    ) +
    scale_x_discrete(expand = expansion(mult = 0.2)) +
    scale_y_continuous(expand = expansion(mult = c(0.2, 0.2)))

  safe_name <- gsub("%", "pct", m)
  safe_name <- gsub("[^A-Za-z0-9_]", "", safe_name)
  ggsave(filename = file.path(dir_pure$line, paste0(safe_name, ".png")), plot = p, width = 4, height = 5, dpi = 300)
}

# ==================================
# ==== 8. 繪製長條圖 (使用動態 Bar Plot Tool) ====
# ==================================
message("繪製長條圖 (Annotated Delta, Pre, Post with *, #, $)...")

# 載入我們強大的柱狀圖工具包 (請確保此路徑與檔案內容是我們剛剛最新修改的完美版)
source("C:\\github\\my-first-project\\my-first-project\\PS150_statics\\functioin\\Bar_plot_tool.R")

group_names <- levels(long_data$Group)
Group_A <- group_names[1] 
Group_B <- group_names[2]

for (metric in all_metrics) {
  safe_metric_name <- gsub("%", "pct", metric)
  safe_metric_name <- gsub("[^A-Za-z0-9_]", "", safe_metric_name)
  
  # 保留自動判斷單位的設定
  y_unit <- get_y_unit_simple(metric)
  
  # ---------------------------------------------------------
  # --- 1. Delta Plot (差值圖) ---
  # ---------------------------------------------------------
  dat_delta <- plot_df_delta %>% filter(Metric == metric)
  if (nrow(dat_delta) > 0) {
    # 合併 P 值地圖，並設定顯著性標記
    dat_p_delta <- dat_delta %>% left_join(p_map, by = c("Metric", "Stage")) %>%
      mutate(
        label_A = ifelse(Group == Group_A & p_within_A < 0.05, "*", NA),
        label_B = ifelse(Group == Group_B & p_within_B < 0.05, "#", NA),
        label_Bet = ifelse(p_delta_bet < 0.05, "$", NA)
      )
    
    # 呼叫工具包計算 Y 軸刻度
    scale_info_delta <- calc_dynamic_y_scale_bar(dat_p_delta, y_col = "mean", err_col = "se")
    
    # 繪製基礎圖 (無標記)
    p_base_delta <- create_flexible_bar_plot(
      df = dat_p_delta, x_col = "Stage", y_col = "mean", err_col = "se", group_col = "Group",
      scale_info = scale_info_delta, title_text = paste(metric, "- Difference"), 
      y_label = y_unit, x_label = "Sleep Stage", color_pal = my_fill
    )
    
    # 加上自動避讓標記 (不傳入 anno_subtitle 即可隱藏副標題)
    p_anno_delta <- add_annotations_bar(
      p = p_base_delta, df = dat_p_delta, x_col = "Stage", y_col = "mean", err_col = "se", group_col = "Group",
      scale_info = scale_info_delta, groupA_name = Group_A, groupB_name = Group_B
    )
    
    # 存檔
    ggsave(file.path(dir_pure$delta, paste0("Delta_", safe_metric_name, ".png")), p_base_delta, width = 8, height = 5, bg="white")
    ggsave(file.path(dir_anno$delta, paste0("Delta_", safe_metric_name, ".png")), p_anno_delta, width = 8, height = 5, bg="white")
  }
  
  # ---------------------------------------------------------
  # --- 2. Pre Plot (前測圖) ---
  # ---------------------------------------------------------
  dat_pre <- plot_df_basic %>% filter(Metric == metric, Trail == "Pre")
  if (nrow(dat_pre) > 0) {
    dat_p_pre <- dat_pre %>% left_join(p_map, by = c("Metric", "Stage")) %>%
      mutate(label_Bet = ifelse(p_pre_bet < 0.05, "$", NA))
    
    scale_info_pre <- calc_dynamic_y_scale_bar(dat_p_pre, y_col = "mean", err_col = "se")
    
    p_base_pre <- create_flexible_bar_plot(
      df = dat_p_pre, x_col = "Stage", y_col = "mean", err_col = "se", group_col = "Group",
      scale_info = scale_info_pre, title_text = paste(metric, "- Pre Test"), 
      y_label = y_unit, x_label = "Sleep Stage", color_pal = my_fill
    )
    
    p_anno_pre <- add_annotations_bar(
      p = p_base_pre, df = dat_p_pre, x_col = "Stage", y_col = "mean", err_col = "se", group_col = "Group",
      scale_info = scale_info_pre, groupA_name = Group_A, groupB_name = Group_B
    )
    
    ggsave(file.path(dir_pure$pre, paste0("Pre_", safe_metric_name, ".png")), p_base_pre, width = 8, height = 5, bg="white")
    ggsave(file.path(dir_anno$pre, paste0("Pre_", safe_metric_name, ".png")), p_anno_pre, width = 8, height = 5, bg="white")
  }
  
  # ---------------------------------------------------------
  # --- 3. Post Plot (後測圖) ---
  # ---------------------------------------------------------
  dat_post <- plot_df_basic %>% filter(Metric == metric, Trail == "Post")
  if (nrow(dat_post) > 0) {
    dat_p_post <- dat_post %>% left_join(p_map, by = c("Metric", "Stage")) %>%
      mutate(label_Bet = ifelse(p_post_bet < 0.05, "$", NA))
    
    scale_info_post <- calc_dynamic_y_scale_bar(dat_p_post, y_col = "mean", err_col = "se")
    
    p_base_post <- create_flexible_bar_plot(
      df = dat_p_post, x_col = "Stage", y_col = "mean", err_col = "se", group_col = "Group",
      scale_info = scale_info_post, title_text = paste(metric, "- Post Test"), 
      y_label = y_unit, x_label = "Sleep Stage", color_pal = my_fill
    )
    
    p_anno_post <- add_annotations_bar(
      p = p_base_post, df = dat_p_post, x_col = "Stage", y_col = "mean", err_col = "se", group_col = "Group",
      scale_info = scale_info_post, groupA_name = Group_A, groupB_name = Group_B
    )
    
    ggsave(file.path(dir_pure$post, paste0("Post_", safe_metric_name, ".png")), p_base_post, width = 8, height = 5, bg="white")
    ggsave(file.path(dir_anno$post, paste0("Post_", safe_metric_name, ".png")), p_anno_post, width = 8, height = 5, bg="white")
  }
}

cat("\n🎉 繪圖完成！所有 EDF 高品質長條圖已成功生成。\n")