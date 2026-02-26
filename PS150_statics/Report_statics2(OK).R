rm(list = ls())
# ==============================================================================
# ==== 0. 載入必要套件 (自動安裝缺失套件) ====
# ==============================================================================
pkg_list <- c(
  "tidyverse", "openxlsx", "readxl", "rstatix", "ez", "geepack",
  "MuMIn", "broom", "broom.mixed", "lmerTest", "car", "emmeans", "ggpubr", "scales"
)

for (pkg in pkg_list) {
  if (!requireNamespace(pkg, quietly = TRUE)) install.packages(pkg)
  library(pkg, character.only = TRUE)
}

# ==============================================================================
# ==== 1. 設定與讀取資料 ====
# ==============================================================================
# 設定路徑
data_path <- "C:\\Users\\ngps9\\OneDrive\\onedrive\\桌面\\PS150_results\\2026\\Datalist_260109_clean.xlsx"
info_path <- "C:\\Users\\ngps9\\OneDrive\\onedrive\\桌面\\PS150_results\\2026\\受試者進度紀錄與基本資料260117_clean.xlsx"
output_path <- "C:\\Users\\ngps9\\OneDrive\\onedrive\\桌面\\PS150_results\\2026"
output_file <- file.path(output_path, "Report_Stats_260203_clean.xlsx")

# 讀取資料
message("正在讀取 Excel 檔案...")
data_raw <- read.xlsx(data_path, sheet = "工作表2")
id_list <- read.xlsx(info_path, sheet = "完整資料")

# 定義分析變數
measures_to_analyze <- c(
  "TRT_min", "TST_min", "SE", "SL_min", "REML_min", "WASO_min",
  "REM%", "N1%", "N2%", "N3%", "REM_min",
  "N1_min", "N2_min", "N3_min", "ArousalIndex", "Min_O2", "AHI", "AI", "HI", "ODI",
  "NonSupine_AHI", "REM_AHI", "NREM_AHI", "Mean_HR"
)

# ==============================================================================
# ==== 2. 資料前處理 (ID 強制修復版) ====
# ==============================================================================
message("--- Step 1: 資料清理與合併 ---")

# 1. 準備名單檔
id_info <- id_list %>%
  select(ID, Group, Sex, Age, BMI, PSQI_pre) %>%
  mutate(
    ID = as.character(ID), ID = trimws(ID), ID = gsub("\\.0$", "", ID),
    Group = as.character(Group), Group = trimws(Group)
  ) %>%
  rename(PSQI_baseline = PSQI_pre)

# 2. 準備數據檔
data_clean <- data_raw %>%
  mutate(
    ID = as.character(ID), ID = trimws(ID), ID = gsub("\\.0$", "", ID),
    Trail = as.character(Trail), Trail = trimws(Trail)
  )

# 3. 合併資料
merged_data <- data_clean %>%
  left_join(id_info, by = "ID") %>%
  mutate(
    Group_clean = toupper(trimws(as.character(Group))),
    Group_Label = factor(case_when(
      Group_clean %in% c("A", "0", "CONTROL", "C", "\uff21") ~ "placebo",
      Group_clean %in% c("B", "1", "EXP", "E", "\uff22") ~ "PS150",
      TRUE ~ NA_character_
    ), levels = c("placebo", "PS150")),
    Trail_Factor = factor(case_when(
      Trail %in% c("0", "0.0", "Interview") ~ "Interview",
      Trail %in% c("1", "1.0", "Pre") ~ "Pre",
      Trail %in% c("2", "2.0", "Post") ~ "Post",
      TRUE ~ NA_character_
    ), levels = c("Interview", "Pre", "Post"))
  )

# 4. 過濾無效資料
merged_data_filtered <- merged_data %>%
  filter(!is.na(Group_Label)) %>%
  filter(!is.na(Trail_Factor))

if (nrow(merged_data_filtered) == 0) stop("❌ 錯誤：資料合併後為空，請檢查 ID/Group/Trail 對應。")

# 5. 轉換長格式
long_data <- merged_data_filtered %>%
  select(ID, Group = Group_Label, Trail = Trail_Factor, Age, BMI, PSQI_baseline, all_of(measures_to_analyze)) %>%
  pivot_longer(cols = all_of(measures_to_analyze), names_to = "measure", values_to = "score") %>%
  mutate(score = as.numeric(score)) %>%
  filter(!is.na(score))

message("✅ 資料清理完成，筆數：", nrow(long_data))

# ==============================================================================
# ==== 3. 三時點分析 (Friedman/ANOVA) ====
# ==============================================================================
message("--- Step 2: 執行三時點重複測量分析 ---")

data_3pt <- long_data %>%
  group_by(Group, measure, ID) %>%
  filter(n() == 3) %>%
  ungroup()

if (nrow(data_3pt) > 0) {
  friedman_results <- data_3pt %>%
    group_by(Group, measure) %>%
    do({
      res <- tryCatch(
        {
          friedman_test(data = ., score ~ Trail | ID)
        },
        error = function(e) NULL
      )
      if (is.null(res)) data.frame() else as.data.frame(res)
    }) %>%
    ungroup()

  anova_results <- data_3pt %>%
    group_by(Group, measure) %>%
    do({
      res <- tryCatch(
        {
          anova_test(data = ., dv = score, wid = ID, within = Trail)
        },
        error = function(e) NULL
      )
      if (is.null(res)) data.frame() else as.data.frame(res)
    }) %>%
    ungroup()

  ph_list <- list()
  for (m in unique(data_3pt$measure)) {
    for (g in unique(data_3pt$Group)) {
      sub <- data_3pt %>% filter(measure == m, Group == g)
      if (nrow(sub) >= 6 && sd(sub$score, na.rm = T) > 0) {
        res <- tryCatch(
          {
            pairwise_wilcox_test(sub, score ~ Trail, paired = T, p.adjust.method = "bonferroni") %>% mutate(measure = m, Group = g)
          },
          error = function(e) NULL
        )
        if (!is.null(res)) ph_list[[paste(m, g)]] <- res
      }
    }
  }
  posthoc_wilcox_3pt <- if (length(ph_list) > 0) bind_rows(ph_list) %>% select(measure, Group, everything()) else data.frame(measure = character())
} else {
  friedman_results <- anova_results <- posthoc_wilcox_3pt <- data.frame(Message = "No 3-point data")
}

# ==============================================================================
# ==== 4. Pre vs Post 進階比較 (建立 final_nonpara_table) ====
# ==============================================================================
message("--- Step 3: 執行 Pre vs Post 進階比較 ---")

data_2pt <- long_data %>% filter(Trail %in% c("Pre", "Post"))

# 4.1 敘述統計
desc_stats_2pt <- data_2pt %>%
  group_by(Group, Trail, measure) %>%
  summarise(
    n = n(), Mean = mean(score, na.rm = T), SEM = sd(score, na.rm = T) / sqrt(n),
    Median = median(score, na.rm = T), Shapiro_p = ifelse(n() >= 3, shapiro.test(score)$p.value, NA),
    .groups = "drop"
  )

# 4.2 Delta
delta_wide <- data_2pt %>%
  select(ID, Group, Trail, measure, score) %>%
  pivot_wider(names_from = Trail, values_from = score)
if ("Pre" %in% names(delta_wide) && "Post" %in% names(delta_wide)) {
  delta_data <- delta_wide %>%
    mutate(Diff = Post - Pre) %>%
    filter(!is.na(Diff))
  desc_delta <- delta_data %>%
    group_by(Group, measure) %>%
    summarise(n = n(), Delta_Mean = mean(Diff, na.rm = T), Delta_SEM = sd(Diff, na.rm = T) / sqrt(n), .groups = "drop")
} else {
  delta_data <- data.frame()
  desc_delta <- data.frame()
}

# 4.3 P-value Loop
p_list_np <- list()
p_list_p <- list()
for (m in unique(data_2pt$measure)) {
  sub <- data_2pt %>% filter(measure == m)
  d_sub <- if (nrow(delta_data) > 0) delta_data %>% filter(measure == m) else data.frame()

  res_np <- data.frame(measure = m, p_Within_A = NA, p_Within_B = NA, p_Bet_Pre = NA, p_Bet_Post = NA, p_Bet_Delta = NA)
  res_p <- data.frame(measure = m, p_Within_A = NA, p_Within_B = NA, p_Bet_Pre = NA, p_Bet_Post = NA, p_Bet_Delta = NA)

  # Intra
  for (g in c("placebo", "PS150")) {
    tmp <- sub %>%
      filter(Group == g) %>%
      arrange(ID, Trail)
    ids <- tmp %>%
      count(ID) %>%
      filter(n == 2) %>%
      pull(ID)
    tmp <- tmp %>% filter(ID %in% ids)
    if (length(ids) >= 2) {
      vp <- tmp$score[tmp$Trail == "Pre"]
      vt <- tmp$score[tmp$Trail == "Post"]
      try(
        {
          res_p[[paste0("p_Within_", g)]] <- t.test(vp, vt, paired = T)$p.value
        },
        silent = T
      )
      try(
        {
          res_np[[paste0("p_Within_", g)]] <- wilcox.test(vp, vt, paired = T)$p.value
        },
        silent = T
      )
    }
  }
  # Inter
  for (tm in c("Pre", "Post")) {
    dt <- sub %>% filter(Trail == tm)
    if (n_distinct(dt$Group) == 2 && min(table(dt$Group)) >= 2) {
      try(
        {
          res_p[[paste0("p_Bet_", tm)]] <- t.test(score ~ Group, data = dt)$p.value
        },
        silent = T
      )
      try(
        {
          res_np[[paste0("p_Bet_", tm)]] <- wilcox.test(score ~ Group, data = dt)$p.value
        },
        silent = T
      )
    }
  }
  # Delta
  if (nrow(d_sub) > 0 && n_distinct(d_sub$Group) == 2 && min(table(d_sub$Group)) >= 2) {
    try(
      {
        res_p$p_Bet_Delta <- t.test(Diff ~ Group, data = d_sub)$p.value
      },
      silent = T
    )
    try(
      {
        res_np$p_Bet_Delta <- wilcox.test(Diff ~ Group, data = d_sub)$p.value
      },
      silent = T
    )
  }
  p_list_np[[m]] <- res_np
  p_list_p[[m]] <- res_p
}
df_p_np <- bind_rows(p_list_np)
df_p_p <- bind_rows(p_list_p)

# 合併報表
tbl_pp <- desc_stats_2pt %>% pivot_wider(id_cols = measure, names_from = c(Group, Trail), values_from = c(Mean, SEM, Shapiro_p), names_glue = "{Group}_{.value}_{Trail}")
if (nrow(desc_delta) > 0) {
  tbl_d <- desc_delta %>% pivot_wider(id_cols = measure, names_from = Group, values_from = c(Delta_Mean, Delta_SEM), names_glue = "{.value}_{Group}")
  final_np <- tbl_pp %>%
    left_join(tbl_d, by = "measure") %>%
    left_join(df_p_np, by = "measure")
  final_p <- tbl_pp %>%
    left_join(tbl_d, by = "measure") %>%
    left_join(df_p_p, by = "measure")
} else {
  final_np <- tbl_pp %>% left_join(df_p_np, by = "measure")
  final_p <- tbl_pp %>% left_join(df_p_p, by = "measure")
}

# 確保 final_nonpara_table 存在 (關鍵!)
final_nonpara_table <- final_np
final_para_table <- final_p

# ==============================================================================
# ==== 5. GEE 與 LMM 分析 (安全版) ====
# ==============================================================================
message("--- Step 4: 執行 GEE 與 LMM ---")

gee_lmm_data <- long_data %>%
  filter(Trail %in% c("Pre", "Post")) %>%
  arrange(ID, Trail) %>%
  mutate(Trail = factor(Trail, levels = c("Pre", "Post")))

# GEE Loop
gee_res_list <- list()
for (m in measures_to_analyze) {
  tmp <- gee_lmm_data %>% filter(measure == m)
  if (nrow(tmp) < 10) next
  mod <- tryCatch(
    {
      suppressWarnings(geeglm(score ~ Group * Trail, data = tmp, id = ID, corstr = "ar1"))
    },
    error = function(e) {
      tryCatch(
        {
          suppressWarnings(geeglm(score ~ Group * Trail, data = tmp, id = ID, corstr = "exchangeable"))
        },
        error = function(e2) NULL
      )
    }
  )
  if (!is.null(mod)) {
    try(
      {
        emm <- emmeans(mod, ~ Group | Trail)
        res <- pairs(emm, reverse = TRUE) %>%
          as.data.frame() %>%
          mutate(measure = m)
        gee_res_list[[m]] <- res
      },
      silent = TRUE
    )
  }
}
df_gee_posthoc <- bind_rows(gee_res_list)

# LMM Loop (使用 broom.mixed 與手動備案)
lmm_res_list <- list()
for (m in measures_to_analyze) {
  tmp <- gee_lmm_data %>% filter(measure == m)
  if (nrow(tmp) < 10 || sd(tmp$score, na.rm = TRUE) == 0) next

  mod <- tryCatch(
    {
      suppressMessages(suppressWarnings(lmer(score ~ Group * Trail + Age + BMI + PSQI_baseline + (1 | ID), data = tmp)))
    },
    error = function(e) NULL
  )

  if (!is.null(mod)) {
    res_tidy <- tryCatch(
      {
        broom.mixed::tidy(mod, conf.int = TRUE, effects = "fixed") %>% mutate(measure = m)
      },
      error = function(e) NULL
    )
    if (is.null(res_tidy)) {
      try(
        {
          coefs <- summary(mod)$coefficients
          res_tidy <- as.data.frame(coefs) %>%
            rownames_to_column("term") %>%
            rename(estimate = Estimate, std.error = `Std. Error`, statistic = `t value`, p.value = `Pr(>|t|)`) %>%
            mutate(measure = m)
        },
        silent = TRUE
      )
    }
    if (!is.null(res_tidy)) lmm_res_list[[m]] <- res_tidy
  }
}
df_lmm_adj <- bind_rows(lmm_res_list)

# ==============================================================================
# ==== 6. 匯出 Excel ====
# ==============================================================================
message("--- Step 5: 匯出 Excel ---")
wb <- createWorkbook()
sig <- createStyle(bgFill = "#FFFF00")

addWorksheet(wb, "1_三時點_Friedman")
writeData(wb, "1_三時點_Friedman", friedman_results)
addWorksheet(wb, "1_三時點_ANOVA")
writeData(wb, "1_三時點_ANOVA", anova_results)
addWorksheet(wb, "1_三時點_Posthoc")
writeData(wb, "1_三時點_Posthoc", posthoc_wilcox_3pt)
addWorksheet(wb, "2_PrePost_有母數")
writeData(wb, "2_PrePost_有母數", final_p)
conditionalFormatting(wb, "2_PrePost_有母數", cols = which(grepl("p_", names(final_p))), rows = 2:200, rule = "<0.05", style = sig)
addWorksheet(wb, "3_PrePost_無母數")
writeData(wb, "3_PrePost_無母數", final_np)
conditionalFormatting(wb, "3_PrePost_無母數", cols = which(grepl("p_", names(final_np))), rows = 2:200, rule = "<0.05", style = sig)
addWorksheet(wb, "4_GEE_PostHoc")
if (nrow(df_gee_posthoc) > 0) writeData(wb, "4_GEE_PostHoc", df_gee_posthoc)
addWorksheet(wb, "5_LMM_Adjusted")
if (nrow(df_lmm_adj) > 0) writeData(wb, "5_LMM_Adjusted", df_lmm_adj)

saveWorkbook(wb, output_file, overwrite = TRUE)



# ==================================
# ==== 7. 繪圖 (最終定稿：灰色框線 + 虛線零軸) ====
# ==================================
message("\n--- Step 6: 產生圖表 (最終定稿：灰色框線 + 虛線零軸) ---")

# 1. 設定路徑
plot_dir <- file.path(output_path, paste0("Plots_Final_Wide_", format(Sys.Date(), "%y%m%d")))
if (!dir.exists(plot_dir)) dir.create(plot_dir)

# 2. 配色與形狀
my_colors <- c("placebo" = "#31688E", "PS150" = "#E67E22")
my_shapes <- c("placebo" = 16, "PS150" = 17)

# 3. 準備資料 (鎖定無母數分析結果)
plot_stats <- final_nonpara_table

# --- 輔助函數：自動判斷 Y 軸單位 ---
get_y_label <- function(m_name) {
  if (grepl("_min", m_name) || m_name %in% c("TRT", "TST", "SL", "WASO", "REM", "N1", "N2", "N3")) {
    return("Time (min)")
  }
  if (grepl("%", m_name) || m_name %in% c("SE")) {
    return("Percentage (%)")
  }
  if (m_name %in% c("ArousalIndex", "ODI", "AHI", "AI", "HI", "REM_AHI", "NREM_AHI", "Supine_AHI", "NonSupine_AHI")) {
    return("Frequency (times/hr)")
  }
  if (grepl("HR", m_name)) {
    return("Heart Rate (bpm)")
  }
  return("Score")
}

# --- 開始繪圖迴圈 ---
for (m in measures_to_analyze) {
  stats <- plot_stats %>% filter(measure == m)
  sum_sub <- desc_stats_2pt %>% filter(measure == m)

  if (nrow(sum_sub) == 0) next

  y_lab <- get_y_label(m)

  # =======================================================
  # [圖 1] Pre-Post 折線圖 (Trend Plot)
  # =======================================================

  anno_df <- data.frame()
  if (nrow(stats) > 0) {
    if (!is.na(stats$p_Within_A) && stats$p_Within_A < 0.05) anno_df <- rbind(anno_df, data.frame(Trail = "Post", Y = sum_sub$Mean[sum_sub$Group == "placebo" & sum_sub$Trail == "Post"] + sum_sub$SEM[sum_sub$Group == "placebo" & sum_sub$Trail == "Post"], Label = "*", Group = "placebo"))
    if (!is.na(stats$p_Within_B) && stats$p_Within_B < 0.05) anno_df <- rbind(anno_df, data.frame(Trail = "Post", Y = sum_sub$Mean[sum_sub$Group == "PS150" & sum_sub$Trail == "Post"] + sum_sub$SEM[sum_sub$Group == "PS150" & sum_sub$Trail == "Post"], Label = "#", Group = "PS150"))
    if (!is.na(stats$p_Bet_Pre) && stats$p_Bet_Pre < 0.05) anno_df <- rbind(anno_df, data.frame(Trail = "Pre", Y = max(sum_sub$Mean[sum_sub$Trail == "Pre"] + sum_sub$SEM[sum_sub$Trail == "Pre"]), Label = "$", Group = NA))
    if (!is.na(stats$p_Bet_Post) && stats$p_Bet_Post < 0.05) anno_df <- rbind(anno_df, data.frame(Trail = "Post", Y = max(sum_sub$Mean[sum_sub$Trail == "Post"] + sum_sub$SEM[sum_sub$Trail == "Post"]), Label = "$", Group = NA))
  }

  p1 <- ggplot(sum_sub, aes(x = Trail, y = Mean, group = Group, color = Group, shape = Group)) +
    geom_line(linewidth = 1.2, alpha = 0.9) +
    geom_point(size = 5) +
    geom_errorbar(aes(ymin = Mean - SEM, ymax = Mean + SEM), width = 0.15, linewidth = 1) +
    scale_color_manual(values = my_colors) +
    scale_shape_manual(values = my_shapes) +
    labs(title = m, subtitle = "Mean ± SEM (*:placebo intra, #:PS150 intra, $:Inter)", y = y_lab, x = NULL) +
    theme_classic() +
    theme(
      plot.title = element_text(size = 24, face = "bold", hjust = 0.5),
      axis.title.y = element_text(size = 16, face = "bold", margin = margin(r = 10)),
      axis.text = element_text(size = 14, color = "black", face = "bold"),

      # [修改] 圖例框線改為灰色
      legend.position = c(0.95, 0.95),
      legend.justification = c("right", "top"),
      legend.background = element_rect(fill = "white", color = "gray60", linewidth = 0.5),
      aspect.ratio = 1.25
    ) +
    scale_y_continuous(expand = expansion(mult = c(0.3, 0.3)))

  if (nrow(anno_df) > 0) {
    p1 <- p1 + geom_text(
      data = anno_df,
      aes(x = Trail, y = Y, label = Label),
      inherit.aes = FALSE,
      vjust = -0.8, hjust = 0.5, size = 7, fontface = "bold",
      position = position_nudge(x = 0.1)
    )
  }
  ggsave(file.path(plot_dir, paste0(m, "_Trend.png")), p1, width = 5, height = 6.25, bg = "white")

  # =======================================================
  # [圖 2] Delta Bar Chart (深灰虛線 + 寬 Y 軸)
  # =======================================================
  if (exists("desc_delta") && nrow(desc_delta) > 0) {
    d_sub <- desc_delta %>% filter(measure == m)
    if (nrow(d_sub) > 0) {
      max_val <- max(d_sub$Delta_Mean + d_sub$Delta_SEM, na.rm = T)
      if (max_val < 0) max_val <- 0

      p2 <- ggplot(d_sub, aes(x = Group, y = Delta_Mean, fill = Group)) +

        # [修改] 0 水平線改為：深灰色、虛線
        geom_hline(yintercept = 0, color = "gray30", linetype = "dashed", linewidth = 1.2) +
        geom_bar(stat = "identity", position = position_dodge(), width = 0.6, color = "black", alpha = 0.9) +
        geom_errorbar(aes(ymin = Delta_Mean - Delta_SEM, ymax = Delta_Mean + Delta_SEM), width = 0.2, linewidth = 1) +
        scale_fill_manual(values = my_colors) +
        labs(title = paste0(m, " (Delta)"), y = paste("Change", y_lab)) +
        theme_classic() +
        theme(
          plot.title = element_text(size = 20, face = "bold", hjust = 0.5),
          axis.title.y = element_text(size = 14, face = "bold"),
          axis.text = element_text(size = 12, color = "black", face = "bold"),
          legend.position = "none",
          aspect.ratio = 1.25
        ) +
        scale_y_continuous(expand = expansion(mult = c(0.3, 0.4)))

      if (nrow(stats) > 0 && !is.na(stats$p_Bet_Delta) && stats$p_Bet_Delta < 0.05) {
        p2 <- p2 + annotate(
          "text",
          x = 1.5, y = max_val,
          label = "$", size = 10, fontface = "bold",
          vjust = -1
        )
      }
      ggsave(file.path(plot_dir, paste0(m, "_Delta.png")), p2, width = 4, height = 5, bg = "white")
    }
  }
}

message("🎉 完美！所有分析與美化圖表已生成！")
