# ==============================================================================
# === 睡眠日記統計分析腳本 (Sleep Diary Statistical Analysis)               ===
# ==============================================================================
# 說明：此腳本執行睡眠日記資料的完整分析流程，包含：
#   1. 套件載入
#   2. 路徑與參數設定
#   3. 資料讀取與清洗 (寬轉長)
#   4. 基礎統計 (描述統計、常態檢定、相關性)
#   5. GEE 分析 (Best-fit & AR1 結構)
#   6. Excel 報表匯出
#   7-10. 繪圖 (折線圖、Pairplot、趨勢圖)
# ==============================================================================

# ==============================================================================
# == 1. 套件檢查與安裝 ====
# ==============================================================================
message(">>> [1/10] 檢查並載入套件...")
required_packages <- c(
  "data.table", "openxlsx", "lubridate", "magrittr", "dplyr", "tidyr",
  "hms", "writexl", "geepack", "emmeans", "ggplot2", "rstatix", "broom",
  "gtsummary", "afex", "gt",
  "performance", "correlation", "see", "patchwork", "lme4", "GGally",
  "MuMIn", "ggpubr", "stringr", "rmcorr", "tibble"
)

for (pkg in required_packages) {
  if (!require(pkg, character.only = TRUE)) {
    message("  缺少套件: ", pkg, "，嘗試安裝...")
    install.packages(pkg, dependencies = TRUE)
    library(pkg, character.only = TRUE)
  }
}
message("✅ 套件載入完成")
# 建議：使用 renv::init() + renv::snapshot() 管理套件版本以提升可重現性

# ==============================================================================
# === 2. 檔案路徑與變數設定 ====
# ==============================================================================
message(">>> [2/10] 設定路徑與參數...")

# --- 路徑設定 (請依自身環境修改此區塊) ---
base_dir <- file.path(
  "C:", "Users", "ngps9", "OneDrive", "onedrive",
  "桌面", "PS150_results", "2026"
)
input_file <- file.path(base_dir, "Sleepdiary260117_all_clean.xlsx")
output_file <- file.path(base_dir, "Sleepdiary_stats_260302.xlsx")

# --- 輸入檔案存在性檢查 ---
if (!file.exists(input_file)) {
  stop(
    "找不到輸入檔案: ", input_file,
    "\n請確認 base_dir 路徑是否正確。"
  )
}

# --- 分析目標變數 ---
outcome_base_vars <- c(
  "TRT", "TST", "SE", "SL", "WASO", "wakefulness_day",
  "sleepiness_pre", "Alert_post", "SSS_post"
)

# --- 常數定義 ---
MIN_GEE_SAMPLES <- 20 # GEE 分析所需最少觀測數
MIN_SHAPIRO_N <- 3 # Shapiro-Wilk 檢定所需最少樣本數
ALPHA_NORMALITY <- 0.05 # 常態檢定顯著水準
ALPHA_SIGNIFICANCE <- 0.05 # 繪圖標註顯著水準

# --- 統一色盤 ---
COLOR_PALETTE <- c("placebo" = "#31688E", "PS150" = "#E67E22")
SHAPE_PALETTE <- c("placebo" = 16, "PS150" = 17)

# ==============================================================================
# === 3. 資料讀取與清洗 ====
# ==============================================================================
message(">>> [3/10] 讀取並清洗資料 (修復 Week 0)...")
raw <- read.xlsx(input_file)
names(raw) <- trimws(names(raw)) # 強力清除欄位名空白

# 寬轉長函數
wide_to_long <- function(df,
                         id_vars = c("ID", "Name", "Group"),
                         value_bases = outcome_base_vars) {
  if (!"Group" %in% names(df)) stop("錯誤：資料中找不到 'Group' 欄位")

  all_long <- list()
  for (base in value_bases) {
    cols <- grep(paste0("^", base, "_[0-9]+$"), names(df), value = TRUE)
    if (length(cols) == 0) {
      message("  [警告] 找不到變數: ", base)
      next
    }
    temp <- df %>%
      select(all_of(c(id_vars, cols))) %>%
      pivot_longer(cols = all_of(cols), names_to = "week_str", values_to = base) %>%
      mutate(week = as.numeric(str_extract(week_str, "[0-9]+$"))) %>%
      select(-week_str)
    all_long[[base]] <- temp
  }

  if (length(all_long) == 0) stop("沒有找到任何可轉換的變數")

  Reduce(
    function(x, y) full_join(x, y, by = c("ID", "Name", "Group", "week")),
    all_long
  ) %>%
    arrange(ID, week) %>%
    mutate(
      week_numeric = week,
      week_factor  = as.factor(week),
      ID           = as.factor(ID)
    )
}

long <- wide_to_long(raw)

# 檢查 Week 0
weeks_found <- sort(unique(long$week_numeric))
if (!0 %in% weeks_found) {
  warning("❌ 仍然沒有抓到 Week 0！")
} else {
  message("✅ 成功抓取 Week 0")
}

# 清洗 Group 欄位 (無死角防護網)
long <- long %>%
  mutate(
    # 1. 徹底清除前後空白，轉半形，並轉為大寫防呆
    Group_clean = toupper(trimws(as.character(Group))),
    # 2. 全面映射：涵蓋 A/B、0/1、CONTROL/EXP、C/E、全形Ａ/Ｂ
    Group = case_when(
      Group_clean %in% c("A", "0", "CONTROL", "C", "\uff21") ~ "placebo", # \uff21 = 全形Ａ
      Group_clean %in% c("B", "1", "EXP", "E", "\uff22") ~ "PS150", # \uff22 = 全形Ｂ
      TRUE ~ NA_character_ # 出現以上以外的意外值，強制轉為 NA 以利除錯
    ),
    # 3. 轉換為 Factor 並鎖定順序
    Group = factor(Group, levels = c("placebo", "PS150"))
  ) %>%
  select(-Group_clean) # 移除過渡欄位

# 安全性檢查：報告 Group 清洗結果
na_count <- sum(is.na(long$Group))
if (na_count > 0) {
  warning(sprintf("⚠️ Group 清洗後仍有 %d 筆 NA，請檢查原始資料中的 Group 欄位值！", na_count))
} else {
  message("✅ Group 欄位清洗完成，全部成功映射")
}
message("  Group 分布：", paste(capture.output(table(long$Group, useNA = "ifany")), collapse = "\n  "))

# ==============================================================================
# === 4. 基礎統計 ====
# ==============================================================================
message(">>> [4/10] 執行基礎統計 (Descriptive, Normality, Correlation)...")

# A. 敘述統計
group_weekly_descriptive <- function(long_df, vars = outcome_base_vars) {
  des_list <- list()
  for (v in vars) {
    temp <- long_df %>%
      group_by(Group, week_numeric) %>%
      summarise(
        n = sum(!is.na(.data[[v]])),
        mean = ifelse(n > 0, round(mean(.data[[v]], na.rm = TRUE), 2), NA),
        sd = ifelse(n > 1, round(sd(.data[[v]], na.rm = TRUE), 2), NA),
        sem = ifelse(n > 1, round(sd(.data[[v]], na.rm = TRUE) / sqrt(n), 2), NA),
        .groups = "drop"
      ) %>%
      mutate(variable = v) %>%
      select(variable, everything())
    des_list[[v]] <- temp
  }
  bind_rows(des_list)
}
desc_data <- group_weekly_descriptive(long)

# B. 常態檢定
normality_tests_grouped <- function(long_df,
                                    vars = outcome_base_vars,
                                    alpha = ALPHA_NORMALITY) {
  results <- list()
  for (v in vars) {
    temp <- long_df %>%
      filter(!is.na(.data[[v]])) %>%
      group_by(Group, week_numeric) %>%
      summarise(
        n = n(),
        shapiro_p = tryCatch(
          {
            if (n >= MIN_SHAPIRO_N && sd(.data[[v]]) > 0) {
              round(shapiro.test(.data[[v]])$p.value, 4)
            } else {
              NA
            }
          },
          error = function(e) NA
        ),
        .groups = "drop"
      ) %>%
      mutate(
        variable  = v,
        is_normal = ifelse(is.na(shapiro_p), NA, shapiro_p > alpha)
      )
    results[[v]] <- temp
  }
  bind_rows(results)
}
norm_results <- normality_tests_grouped(long)

# C. 合併敘述統計與常態檢定結果
desc_data <- desc_data %>%
  left_join(
    norm_results %>% select(variable, Group, week_numeric, shapiro_p, is_normal),
    by = c("variable", "Group", "week_numeric")
  )

# D. 相關性
cor_results <- tryCatch(
  {
    df_cor <- long %>%
      select(all_of(outcome_base_vars)) %>%
      filter(complete.cases(.))
    if (nrow(df_cor) < MIN_SHAPIRO_N) {
      NULL
    } else {
      correlation(df_cor, method = "pearson") %>% as.data.frame()
    }
  },
  error = function(e) NULL
)

# ==============================================================================
# === 5. GEE 分析 ====
# ==============================================================================
message(">>> [5/10] 執行 GEE 分析...")

gee_best_res <- list(summary = data.frame(), pw_group = data.frame(), pw_time = data.frame())
gee_spec_res <- list(summary = data.frame(), pw_group = data.frame(), pw_time = data.frame())
f_gee <- as.formula("score ~ Group * week_factor")

calc_posthoc <- function(mod, variable_name, corstr_label, logic_label) {
  # 注意：adjust = "none" 表示不進行多重比較校正。
  # 這是刻意的選擇，因為各時間點/組別的比較為先驗 (a priori) 假設。
  # 若需校正，可改為 adjust = "bonferroni" 或 adjust = "holm"。
  wald <- tryCatch(
    anova(mod) %>%
      as.data.frame() %>%
      mutate(Variable = variable_name, Structure = corstr_label, Logic = logic_label) %>%
      rownames_to_column("Term"),
    error = function(e) {
      message("    ⚠️ anova 失敗: ", e$message)
      NULL
    }
  )
  pg <- tryCatch(
    emmeans(mod, ~ Group | week_factor) %>%
      pairs(reverse = TRUE, adjust = "none") %>%
      as.data.frame() %>%
      mutate(Variable = variable_name, Structure = corstr_label, Logic = logic_label),
    error = function(e) {
      message("    ⚠️ emmeans(Group) 失敗: ", e$message)
      NULL
    }
  )
  pt <- tryCatch(
    emmeans(mod, ~ week_factor | Group) %>%
      pairs(reverse = TRUE, adjust = "none") %>%
      as.data.frame() %>%
      mutate(Variable = variable_name, Structure = corstr_label, Logic = logic_label),
    error = function(e) {
      message("    ⚠️ emmeans(Time) 失敗: ", e$message)
      NULL
    }
  )
  list(wald = wald, group = pg, time = pt)
}

pb_gee <- txtProgressBar(min = 0, max = length(outcome_base_vars), style = 3)
for (i in seq_along(outcome_base_vars)) {
  outcome <- outcome_base_vars[i]
  df_sub <- long %>%
    select(ID, Group, week_factor, week_numeric, score = all_of(outcome)) %>%
    filter(!is.na(score)) %>%
    arrange(ID, week_numeric)

  if (nrow(df_sub) >= MIN_GEE_SAMPLES) {
    m_ar1 <- tryCatch(
      geeglm(f_gee, data = df_sub, id = ID, family = gaussian, corstr = "ar1"),
      error = function(e) {
        message("  ⚠️ [", outcome, "] AR1 模型失敗: ", e$message)
        NULL
      }
    )
    m_exch <- tryCatch(
      geeglm(f_gee, data = df_sub, id = ID, family = gaussian, corstr = "exchangeable"),
      error = function(e) {
        message("  ⚠️ [", outcome, "] Exchangeable 模型失敗: ", e$message)
        NULL
      }
    )

    q_ar1 <- if (!is.null(m_ar1)) QIC(m_ar1)[1] else Inf
    q_exch <- if (!is.null(m_exch)) QIC(m_exch)[1] else Inf

    best_mod <- NULL
    best_cor <- "None"
    if (q_ar1 != Inf && (q_exch == Inf || q_ar1 <= q_exch)) {
      best_mod <- m_ar1
      best_cor <- "ar1"
    } else if (q_exch != Inf) {
      best_mod <- m_exch
      best_cor <- "exchangeable"
    }

    if (!is.null(best_mod)) {
      ph <- calc_posthoc(best_mod, outcome, best_cor, "Best_Fit")
      gee_best_res$summary <- bind_rows(gee_best_res$summary, ph$wald)
      gee_best_res$pw_group <- bind_rows(gee_best_res$pw_group, ph$group)
      gee_best_res$pw_time <- bind_rows(gee_best_res$pw_time, ph$time)
    } else {
      message("  ⚠️ [", outcome, "] Best-fit 模型為 NULL，跳過")
    }

    spec_mod <- if (best_cor == "ar1" && !is.null(best_mod)) best_mod else m_ar1
    if (!is.null(spec_mod)) {
      ph_s <- calc_posthoc(spec_mod, outcome, "ar1", "Specified")
      gee_spec_res$summary <- bind_rows(gee_spec_res$summary, ph_s$wald)
      gee_spec_res$pw_group <- bind_rows(gee_spec_res$pw_group, ph_s$group)
      gee_spec_res$pw_time <- bind_rows(gee_spec_res$pw_time, ph_s$time)
    } else {
      message("  ⚠️ [", outcome, "] AR1 指定模型為 NULL，跳過")
    }
  } else {
    message("  ⚠️ [", outcome, "] 觀測數不足 (n=", nrow(df_sub), " < ", MIN_GEE_SAMPLES, ")，跳過 GEE")
  }
  setTxtProgressBar(pb_gee, i)
}
close(pb_gee)

# --- GEE 診斷訊息 ---
message(
  "  📊 GEE Best-fit 結果: summary=", nrow(gee_best_res$summary),
  " rows, pw_group=", nrow(gee_best_res$pw_group),
  " rows, pw_time=", nrow(gee_best_res$pw_time), " rows"
)
message(
  "  📊 GEE AR1 結果: summary=", nrow(gee_spec_res$summary),
  " rows, pw_group=", nrow(gee_spec_res$pw_group),
  " rows, pw_time=", nrow(gee_spec_res$pw_time), " rows"
)
message("✅ GEE 分析完成")

# ==============================================================================
# === 6. 匯出 Excel ====
# ==============================================================================
message(">>> [6/10] 匯出 Excel 報表...")
wb <- createWorkbook()

# --- 合併 Descriptive + Normality 到同一個 sheet ---
addWorksheet(wb, "Desc_Normality")
writeData(wb, "Desc_Normality", desc_data)

if (!is.null(cor_results)) {
  addWorksheet(wb, "Correlation")
  writeData(wb, "Correlation", cor_results)
}

# --- GEE Best-fit 結果 (無條件建立 sheet，空結果也匯出以利除錯) ---
addWorksheet(wb, "GEE_Best_Main")
addWorksheet(wb, "GEE_Best_Group")
addWorksheet(wb, "GEE_Best_Time")
if (nrow(gee_best_res$summary) > 0) {
  writeData(wb, "GEE_Best_Main", gee_best_res$summary)
  writeData(wb, "GEE_Best_Group", gee_best_res$pw_group)
  writeData(wb, "GEE_Best_Time", gee_best_res$pw_time)
} else {
  writeData(wb, "GEE_Best_Main", data.frame(Note = "GEE Best-fit 無結果，請檢查 console 診斷訊息"))
  warning("⚠️ GEE Best-fit 結果為空，已建立空白 sheet")
}

# --- GEE AR1 指定結構結果 ---
addWorksheet(wb, "GEE_AR1_Main")
addWorksheet(wb, "GEE_AR1_Group")
addWorksheet(wb, "GEE_AR1_Time")
if (nrow(gee_spec_res$summary) > 0) {
  writeData(wb, "GEE_AR1_Main", gee_spec_res$summary)
  writeData(wb, "GEE_AR1_Group", gee_spec_res$pw_group)
  writeData(wb, "GEE_AR1_Time", gee_spec_res$pw_time)
} else {
  writeData(wb, "GEE_AR1_Main", data.frame(Note = "GEE AR1 無結果，請檢查 console 診斷訊息"))
  warning("⚠️ GEE AR1 結果為空，已建立空白 sheet")
}

saveWorkbook(wb, output_file, overwrite = TRUE)
message("✅ Excel 匯出完成！")

# ==============================================================================
# === 7. 繪圖設定 ====
# ==============================================================================
message(">>> [7/10] 初始化繪圖設定...")
folder_date <- format(Sys.Date(), "%y%m%d")
main_plot_path <- file.path(base_dir, paste0("Plots_Output_", folder_date))
diary_path_anno <- file.path(main_plot_path, "SleepDiary_Annotated_AR1")
diary_path_pure <- file.path(main_plot_path, "SleepDiary_Pure_Final")
diary_path_trend <- file.path(main_plot_path, "SleepDiary_LinearTrend")

# 一次建立所有繪圖目錄
lapply(
  c(diary_path_anno, diary_path_pure, diary_path_trend),
  dir.create,
  recursive = TRUE, showWarnings = FALSE
)

plot_sum <- desc_data %>% rename(measure = variable, avg = mean, se = sem)
use_ar1 <- nrow(gee_spec_res$pw_time) > 0


# 【關鍵新增】載入外部繪圖工具包！
source("C:\\github\\my-first-project\\my-first-project\\PS150_statics\\functioin\\Line_plot_tool.R")

# ==============================================================================
# === 8. 繪圖函數定義 (僅保留 Trend Plot 與 Pairplot) ====
# ==============================================================================
# 【新增】：動態判斷 Y 軸單位的輔助函數 (極簡版)
get_y_label <- function(measure_name) {
  if (measure_name %in% c("TST", "TRT", "WASO")) {
    return("min")            # 直接回傳 min
  } else if (measure_name == "SE") {
    return("TST/TRT(%)")     # 直接回傳 TST/TRT(%)
  } else {
    return("Score")          # 直接回傳 Score
  }
}

## 長期趨勢散佈圖 (含線性回歸)-----
create_trend_plot <- function(plot_df, measure_name, plot_top_limit) {
  pos_jitter <- position_jitter(width = 0.15, seed = 42)
  
  # 取得正確的 Y 軸單位
  dynamic_y_label <- get_y_label(measure_name)
  
  ggplot(plot_df, aes(x = week_numeric, y = value, color = Group, fill = Group)) +
    geom_point(alpha = 0.4, size = 2.5, position = pos_jitter) +
    geom_smooth(method = "lm", se = TRUE, alpha = 0.15, linewidth = 1.5) +
    
    stat_cor(
      data = plot_df %>% filter(Group == levels(plot_df$Group)[1]),
      aes(label = paste0(levels(plot_df$Group)[1], ": ", after_stat(r.label), ", ", after_stat(p.label), ifelse(after_stat(p) < 0.05, " *", ""))),
      method = "pearson", label.x.npc = 0.05, label.y.npc = 0.96,
      size = 6, geom = "label", fill = "white", color = "black",
      alpha = 0.8, fontface = "bold", show.legend = FALSE, output.type = "text"
    ) +
    stat_cor(
      data = plot_df %>% filter(Group == levels(plot_df$Group)[2]),
      aes(label = paste0(levels(plot_df$Group)[2], ": ", after_stat(r.label), ", ", after_stat(p.label), ifelse(after_stat(p) < 0.05, " *", ""))),
      method = "pearson", label.x.npc = 0.05, label.y.npc = 0.86,
      size = 6, geom = "label", fill = "white", color = "black",
      alpha = 0.8, fontface = "bold", show.legend = FALSE, output.type = "text"
    ) +
    scale_color_manual(values = COLOR_PALETTE) +
    scale_fill_manual(values = COLOR_PALETTE) +
    scale_y_continuous(limits = c(NA, plot_top_limit)) +
    scale_x_continuous(
      breaks = sort(unique(plot_df$week_numeric)),
      name   = "Week",
      expand = expansion(mult = 0.1)
    ) +
    labs(
      title    = paste0("Trend: ", measure_name),
      subtitle = "Linear Regression",
      y        = dynamic_y_label  # 【套用動態 Y 軸標籤】
    ) +
    theme_bw() +
    theme(
      aspect.ratio = 1,
      plot.title = element_text(size = 22, face = "bold", hjust = 0.5),
      axis.title = element_text(size = 20, face = "bold"),
      axis.text = element_text(size = 18, color = "black", face = "bold"),
      legend.position = "top",
      legend.text = element_text(size = 16),
      panel.grid.minor = element_blank()
    )
}

## Spaghetti 版：長期趨勢散佈圖 (加入個體連線)----
create_trend_plot_spaghetti <- function(plot_df, measure_name, plot_top_limit) {
  calc_rmcorr_label <- function(df_subset, group_name) {
    tryCatch(
      {
        df_clean <- df_subset %>% drop_na(value, week_numeric)
        res <- rmcorr::rmcorr(participant = ID, measure1 = week_numeric, measure2 = value, dataset = df_clean)
        sig_mark <- ifelse(res$p < 0.05, " *", "")
        sprintf("%s (Within): r_rm = %.3f, p = %.3f%s", group_name, res$r, res$p, sig_mark)
      },
      error = function(e) {
        paste0(group_name, " (Within): NA")
      }
    )
  }
  
  label_GroupA <- calc_rmcorr_label(plot_df %>% filter(Group == levels(plot_df$Group)[1]), levels(plot_df$Group)[1])
  label_GroupB <- calc_rmcorr_label(plot_df %>% filter(Group == levels(plot_df$Group)[2]), levels(plot_df$Group)[2])
  label_x_pos <- min(plot_df$week_numeric, na.rm = TRUE) + 0.1
  
  pos_jitter <- position_jitter(width = 0.15, seed = 42)
  
  # 取得正確的 Y 軸單位
  dynamic_y_label <- get_y_label(measure_name)
  
  ggplot(plot_df, aes(x = week_numeric, y = value, color = Group, fill = Group)) +
    geom_line(aes(group = ID), alpha = 0.2, linewidth = 0.5, position = pos_jitter) +
    geom_point(alpha = 0.4, size = 2.5, position = pos_jitter) +
    geom_smooth(method = "lm", se = TRUE, alpha = 0.15, linewidth = 1.5) +
    annotate("label",
             x = label_x_pos, y = plot_top_limit * 0.95,
             label = label_GroupA, color = COLOR_PALETTE[1], fill = "white",
             fontface = "bold", hjust = 0, size = 5
    ) +
    annotate("label",
             x = label_x_pos, y = plot_top_limit * 0.88,
             label = label_GroupB, color = COLOR_PALETTE[2], fill = "white",
             fontface = "bold", hjust = 0, size = 5
    ) +
    scale_color_manual(values = COLOR_PALETTE) +
    scale_fill_manual(values = COLOR_PALETTE) +
    scale_y_continuous(limits = c(NA, plot_top_limit)) +
    scale_x_continuous(
      breaks = sort(unique(plot_df$week_numeric)),
      name   = "Week",
      expand = expansion(mult = 0.1)
    ) +
    labs(
      title    = paste0("Trend: ", measure_name),
      subtitle = "Spaghetti Plot with Repeated Measures Correlation (rmcorr)",
      y        = dynamic_y_label  # 【套用動態 Y 軸標籤】
    ) +
    theme_bw() +
    theme(
      aspect.ratio = 1,
      plot.title = element_text(size = 22, face = "bold", hjust = 0.5),
      axis.title = element_text(size = 20, face = "bold"),
      axis.text = element_text(size = 18, color = "black", face = "bold"),
      legend.position = "top",
      legend.text = element_text(size = 16),
      panel.grid.minor = element_blank()
    )
}

## Pairplot----
plot_pair <- function(data, vars, title_suffix, save_dir) {
  df_sub <- data %>%
    select(Group, all_of(vars)) %>%
    na.omit() %>%
    mutate(Group = factor(Group, levels = levels(data$Group))) # 動態取 levels
  
  if (nrow(df_sub) == 0) {
    return(invisible(NULL))
  }
  
  p <- ggpairs(
    df_sub,
    columns = 2:ncol(df_sub),
    aes(color = Group, fill = Group, alpha = 0.6),
    diag = list(continuous = wrap("densityDiag", alpha = 0.5)),
    upper = list(continuous = wrap("cor", size = 6, fontface = "bold")),
    lower = list(continuous = wrap("points", size = 2, alpha = 0.6))
  ) +
    scale_color_manual(values = COLOR_PALETTE) +
    scale_fill_manual(values = COLOR_PALETTE) +
    labs(title = paste0("Correlation Matrix: ", title_suffix)) +
    theme_bw() +
    theme(
      axis.text  = element_text(size = 14, face = "bold", color = "black"),
      strip.text = element_text(size = 16, face = "bold", color = "black"),
      plot.title = element_text(size = 20, face = "bold", hjust = 0.5)
    )
  
  ggsave(
    file.path(save_dir, paste0("Correlation_", title_suffix, ".png")),
    p,
    width = 14, height = 12, bg = "white"
  )
}


# ==============================================================================
# === 9. 繪圖：Annotated & Pure (折線圖) - 完美對接 Line_plot_tool ====
# ==============================================================================
message(">>> [8/10] 繪製折線圖 (Trend Plot with SEM)...")

time_sig <- data.frame(Variable = character(), Group = factor(), week_numeric = numeric(), label_time = character())
group_sig <- data.frame(Variable = character(), week_numeric = numeric(), label_AB = character())

group_names <- levels(long$Group)
Group_A <- group_names[1] 
Group_B <- group_names[2]

dynamic_subtitle <- sprintf("(*: %s vs Pre, #: %s vs Pre, $: %s vs %s)", 
                            Group_A, Group_B, Group_A, Group_B)

if (use_ar1) {
  time_sig <- gee_spec_res$pw_time %>%
    mutate(
      week_1 = as.numeric(str_extract(contrast, "(?<=week_factor)\\d+(?=\\s*-)")),
      week_2 = as.numeric(str_extract(contrast, "(?<=-\\sweek_factor)\\d+"))
    ) %>%
    filter(week_1 == 0 | week_2 == 0) %>%
    mutate(
      week_numeric = ifelse(week_1 == 0, week_2, week_1),
      is_sig = p.value < ALPHA_SIGNIFICANCE,
      label_time = case_when(
        is_sig & Group == Group_A ~ "*",
        is_sig & Group == Group_B ~ "#",
        TRUE ~ NA_character_
      )
    ) %>%
    filter(!is.na(label_time)) %>%
    select(Variable, Group, week_numeric, label_time)
  
  group_sig <- gee_spec_res$pw_group %>%
    mutate(
      week_numeric = as.numeric(as.character(week_factor)),
      is_sig = p.value < ALPHA_SIGNIFICANCE,
      label_AB = case_when(is_sig ~ "$", TRUE ~ NA_character_)
    ) %>%
    filter(!is.na(label_AB)) %>%
    select(Variable, week_numeric, label_AB) %>%
    distinct()
}

vars_to_plot <- unique(plot_sum$measure)
pb_line <- txtProgressBar(min = 0, max = length(vars_to_plot), style = 3)

my_dodge_w <- 0.4

# 定義要覆寫的字體大小 (比預設大一號)
custom_text_theme <- theme(
  aspect.ratio = 1, # 1:1 正方形
  axis.title = element_text(size = 22, face = "bold"), # 軸標題放大
  axis.text  = element_text(size = 18, color = "black", face = "bold") # 軸刻度數字放大
)

for (i in seq_along(vars_to_plot)) {
  m <- vars_to_plot[i]
  df_s <- plot_sum %>% filter(measure == m)
  
  if (nrow(df_s) == 0) {
    setTxtProgressBar(pb_line, i)
    next
  }
  
  if (use_ar1) {
    sub_time <- time_sig %>% filter(Variable == m) %>% select(-Variable)
    sub_group <- group_sig %>% filter(Variable == m) %>% select(-Variable)
    
    df_s <- df_s %>%
      left_join(sub_time, by = c("Group", "week_numeric")) %>%
      left_join(sub_group, by = "week_numeric")
  }
  
  if (!"label_time" %in% names(df_s)) df_s$label_time <- NA
  if (!"label_AB" %in% names(df_s)) df_s$label_AB <- NA
  
  base_w <- min(df_s$week_numeric, na.rm = TRUE)
  df_s <- df_s %>%
    mutate(
      label_time = ifelse(week_numeric == base_w, NA, label_time),
      label_AB   = ifelse(week_numeric == base_w, NA, label_AB)
    )
  
  scale_info <- calc_dynamic_y_scale(df_s, error_ratio = 0.15)
  diary_dodge <- 0.4 
  
  # 取得當前變數的專屬 Y 軸名稱
  current_y_label <- get_y_label(m)
  
  suppressMessages(suppressWarnings({
    # [A] 有 Error Bar 版本
    p_base <- create_flexible_line_plot(
      df_s = df_s, y_breaks = scale_info$breaks, y_limits = scale_info$limits,
      title_text = m, 
      y_label = current_y_label, # 【套用動態 Y 軸標籤】
      color_pal = COLOR_PALETTE, shape_pal = SHAPE_PALETTE,
      dodge_w = diary_dodge 
    ) + custom_text_theme # 🌟【關鍵覆寫】：字體大一號 + 1:1 比例
    
    p_anno <- add_annotations_flexible(
      p = p_base, df_s = df_s, scale_info = scale_info, anno_subtitle = dynamic_subtitle,
      dodge_w = diary_dodge 
    )
    
    # [B] 無 Error Bar 版本
    p_base_no_se <- create_flexible_line_plot_no_se(
      df_s = df_s, y_breaks = scale_info$breaks, y_limits = scale_info$limits,
      title_text = m, 
      y_label = current_y_label, # 【套用動態 Y 軸標籤】
      color_pal = COLOR_PALETTE, shape_pal = SHAPE_PALETTE,
      dodge_w = diary_dodge 
    ) + custom_text_theme # 🌟【關鍵覆寫】：字體大一號 + 1:1 比例
    
    p_anno_no_se <- add_annotations_flexible(
      p = p_base_no_se, df_s = df_s, scale_info = scale_info, anno_subtitle = dynamic_subtitle,
      dodge_w = diary_dodge 
    )
  }))
  
  ggsave(file.path(diary_path_anno, paste0(m, "_Annotated.png")), p_anno, width = 8, height = 8, bg = "white")
  ggsave(file.path(diary_path_pure, paste0(m, "_Pure.png")), p_base, width = 8, height = 8, bg = "white")
  ggsave(file.path(diary_path_anno, paste0(m, "_Annotated_NoSE.png")), p_anno_no_se, width = 8, height = 8, bg = "white")
  
  setTxtProgressBar(pb_line, i)
}
close(pb_line)
message("✅ 折線圖繪製完成")



# === 10. 繪圖：Correlation Pairplots ====
# ==============================================================================
message(">>> [9/10] 繪製 Pairplots...")
diary_path_cor <- file.path(main_plot_path, "Sleepdiary_COR")
dir.create(diary_path_cor, recursive = TRUE, showWarnings = FALSE)

vars_objective <- c("TRT", "TST", "SE", "SL", "WASO", "wakefulness_day")
vars_subjective <- c("sleepiness_pre", "Alert_post", "SSS_post", "SE")

plot_pair(long, vars_objective, "Objective_Sleep", diary_path_cor)
plot_pair(long, vars_subjective, "Subjective_Feeling", diary_path_cor)
message("✅ Pairplots 繪製完成")

# ==============================================================================
# === 11. 繪圖：長期趨勢斜率圖 ===
# ==============================================================================
message(">>> [10/10] 繪製長期趨勢圖 (Long-term Trend)...")

trend_data <- long %>%
  select(ID, Group, week_numeric, all_of(outcome_base_vars)) %>%
  pivot_longer(
    cols      = all_of(outcome_base_vars),
    names_to  = "measure",
    values_to = "value"
  ) %>%
  filter(!is.na(value)) %>%
  mutate(week_numeric = as.numeric(week_numeric))

trend_vars <- unique(trend_data$measure)
pb_trend <- txtProgressBar(min = 0, max = length(trend_vars), style = 3)

for (i in seq_along(trend_vars)) {
  m <- trend_vars[i]
  plot_df <- trend_data %>% filter(measure == m)
  
  if (nrow(plot_df) < 10) {
    setTxtProgressBar(pb_trend, i)
    next
  }
  
  y_max_val <- max(plot_df$value, na.rm = TRUE)
  y_min_val <- min(plot_df$value, na.rm = TRUE)
  y_range <- y_max_val - y_min_val
  plot_top_limit <- y_max_val + (y_range * 0.35)
  
  # 原版趨勢圖
  p_trend_orig <- create_trend_plot(plot_df, m, plot_top_limit)
  ggsave(file.path(diary_path_trend, paste0(m, "_LinearTrend.png")),
         p_trend_orig, width = 8, height = 8, bg = "white"
  )
  
  # Spaghetti 版趨勢圖
  p_trend_spag <- create_trend_plot_spaghetti(plot_df, m, plot_top_limit)
  ggsave(file.path(diary_path_trend, paste0(m, "_Spaghetti.png")),
         p_trend_spag, width = 8, height = 8, bg = "white"
  )
  
  setTxtProgressBar(pb_trend, i)
}
close(pb_trend)
message("✅ 趨勢圖繪製完成")

message("\n==============================================")
message("🎉🎉🎉 全部流程執行完畢！所有圖表已生成 🎉🎉🎉")
message("==============================================")