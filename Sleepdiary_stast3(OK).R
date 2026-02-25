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
# === 1. 套件檢查與安裝 ===
# ==============================================================================
message(">>> [1/10] 檢查並載入套件...")
required_packages <- c(
  "data.table", "openxlsx", "lubridate", "magrittr", "dplyr", "tidyr",
  "hms", "writexl", "geepack", "emmeans", "ggplot2", "rstatix", "broom",
  "gtsummary", "afex", "gt",
  "performance", "correlation", "see", "patchwork", "lme4", "GGally",
  "MuMIn", "ggpubr", "stringr"
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
# === 2. 檔案路徑與變數設定 ===
# ==============================================================================
message(">>> [2/10] 設定路徑與參數...")

# --- 路徑設定 (請依自身環境修改此區塊) ---
base_dir <- file.path("C:", "Users", "ngps9", "OneDrive", "onedrive",
                       "桌面", "PS150_results", "2026")
input_file  <- file.path(base_dir, "Sleepdiary260117_all_clean.xlsx")
output_file <- file.path(base_dir, "Sleepdiary_stats_Full_Final_v11.xlsx")

# --- 輸入檔案存在性檢查 ---
if (!file.exists(input_file)) {
  stop("找不到輸入檔案: ", input_file,
       "\n請確認 base_dir 路徑是否正確。")
}

# --- 分析目標變數 ---
outcome_base_vars <- c(
  "TRT", "TST", "SE", "SL", "WASO", "wakefulness_day",
  "sleepiness_pre", "Alert_post", "SSS_post"
)

# --- 常數定義 ---
MIN_GEE_SAMPLES   <- 20   # GEE 分析所需最少觀測數
MIN_SHAPIRO_N      <- 3    # Shapiro-Wilk 檢定所需最少樣本數
ALPHA_NORMALITY    <- 0.05 # 常態檢定顯著水準
ALPHA_SIGNIFICANCE <- 0.05 # 繪圖標註顯著水準

# --- 統一色盤 ---
COLOR_PALETTE <- c("A" = "#31688E", "B" = "#E67E22")
SHAPE_PALETTE <- c("A" = 16, "B" = 17)

# ==============================================================================
# === 3. 資料讀取與清洗 ===
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

# 清洗 Group 欄位
long <- long %>%
  mutate(
    Group = trimws(as.character(Group)),
    Group = case_when(
      Group == "0"              ~ "A",
      Group == "1"              ~ "B",
      tolower(Group) == "control" ~ "A",
      tolower(Group) == "exp"     ~ "B",
      TRUE                      ~ Group
    ),
    Group = factor(Group, levels = c("A", "B"))
  )

# ==============================================================================
# === 4. 基礎統計 ===
# ==============================================================================
message(">>> [4/10] 執行基礎統計 (Descriptive, Normality, Correlation)...")

# A. 敘述統計
group_weekly_descriptive <- function(long_df, vars = outcome_base_vars) {
  des_list <- list()
  for (v in vars) {
    temp <- long_df %>%
      group_by(Group, week_numeric) %>%
      summarise(
        n    = sum(!is.na(.data[[v]])),
        mean = ifelse(n > 0, round(mean(.data[[v]], na.rm = TRUE), 2), NA),
        sd   = ifelse(n > 1, round(sd(.data[[v]], na.rm = TRUE), 2), NA),
        sem  = ifelse(n > 1, round(sd(.data[[v]], na.rm = TRUE) / sqrt(n), 2), NA),
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
        shapiro_p = tryCatch({
          if (n >= MIN_SHAPIRO_N && sd(.data[[v]]) > 0) {
            round(shapiro.test(.data[[v]])$p.value, 4)
          } else {
            NA
          }
        }, error = function(e) NA),
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

# C. 相關性
cor_results <- tryCatch({
  df_cor <- long %>%
    select(all_of(outcome_base_vars)) %>%
    filter(complete.cases(.))
  if (nrow(df_cor) < MIN_SHAPIRO_N) {
    NULL
  } else {
    correlation(df_cor, method = "pearson") %>% as.data.frame()
  }
}, error = function(e) NULL)

# ==============================================================================
# === 5. GEE 分析 ===
# ==============================================================================
message(">>> [5/10] 執行 GEE 分析...")

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
    error = function(e) NULL
  )
  pg <- tryCatch(
    emmeans(mod, ~ Group | week_factor) %>%
      pairs(reverse = TRUE, adjust = "none") %>%
      as.data.frame() %>%
      mutate(Variable = variable_name, Structure = corstr_label, Logic = logic_label),
    error = function(e) NULL
  )
  pt <- tryCatch(
    emmeans(mod, ~ week_factor | Group) %>%
      pairs(reverse = TRUE, adjust = "none") %>%
      as.data.frame() %>%
      mutate(Variable = variable_name, Structure = corstr_label, Logic = logic_label),
    error = function(e) NULL
  )
  list(wald = wald, group = pg, time = pt)
}

# 使用 list 收集結果，最後一次性合併 (避免逐步 bind_rows 的 O(n²) 開銷)
gee_best_wald  <- vector("list", length(outcome_base_vars))
gee_best_group <- vector("list", length(outcome_base_vars))
gee_best_time  <- vector("list", length(outcome_base_vars))
gee_spec_wald  <- vector("list", length(outcome_base_vars))
gee_spec_group <- vector("list", length(outcome_base_vars))
gee_spec_time  <- vector("list", length(outcome_base_vars))

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
      error = function(e) NULL
    )
    m_exch <- tryCatch(
      geeglm(f_gee, data = df_sub, id = ID, family = gaussian, corstr = "exchangeable"),
      error = function(e) NULL
    )

    q_ar1  <- if (!is.null(m_ar1))  QIC(m_ar1)[1]  else Inf
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
      gee_best_wald[[i]]  <- ph$wald
      gee_best_group[[i]] <- ph$group
      gee_best_time[[i]]  <- ph$time
    }

    spec_mod <- if (best_cor == "ar1" && !is.null(best_mod)) best_mod else m_ar1
    if (!is.null(spec_mod)) {
      ph_s <- calc_posthoc(spec_mod, outcome, "ar1", "Specified")
      gee_spec_wald[[i]]  <- ph_s$wald
      gee_spec_group[[i]] <- ph_s$group
      gee_spec_time[[i]]  <- ph_s$time
    }
  }
  setTxtProgressBar(pb_gee, i)
}
close(pb_gee)

# 一次性合併所有 GEE 結果
gee_best_res <- list(
  summary  = bind_rows(gee_best_wald),
  pw_group = bind_rows(gee_best_group),
  pw_time  = bind_rows(gee_best_time)
)
gee_spec_res <- list(
  summary  = bind_rows(gee_spec_wald),
  pw_group = bind_rows(gee_spec_group),
  pw_time  = bind_rows(gee_spec_time)
)

message("✅ GEE 分析完成")

# ==============================================================================
# === 6. 匯出 Excel ===
# ==============================================================================
message(">>> [6/10] 匯出 Excel 報表...")
wb <- createWorkbook()

addWorksheet(wb, "Descriptive")
writeData(wb, "Descriptive", desc_data)

addWorksheet(wb, "Normality")
writeData(wb, "Normality", norm_results)

if (!is.null(cor_results)) {
  addWorksheet(wb, "Correlation")
  writeData(wb, "Correlation", cor_results)
}

if (nrow(gee_best_res$summary) > 0) {
  addWorksheet(wb, "GEE_Best_Main")
  writeData(wb, "GEE_Best_Main", gee_best_res$summary)
  addWorksheet(wb, "GEE_Best_Group")
  writeData(wb, "GEE_Best_Group", gee_best_res$pw_group)
  addWorksheet(wb, "GEE_Best_Time")
  writeData(wb, "GEE_Best_Time", gee_best_res$pw_time)
}

if (nrow(gee_spec_res$summary) > 0) {
  addWorksheet(wb, "GEE_AR1_Main")
  writeData(wb, "GEE_AR1_Main", gee_spec_res$summary)
  addWorksheet(wb, "GEE_AR1_Group")
  writeData(wb, "GEE_AR1_Group", gee_spec_res$pw_group)
  addWorksheet(wb, "GEE_AR1_Time")
  writeData(wb, "GEE_AR1_Time", gee_spec_res$pw_time)
}

saveWorkbook(wb, output_file, overwrite = TRUE)
message("✅ Excel 匯出完成！")

# ==============================================================================
# === 7. 繪圖設定 ===
# ==============================================================================
message(">>> [7/10] 初始化繪圖設定...")
folder_date <- format(Sys.Date(), "%y%m%d")
main_plot_path   <- file.path(base_dir, paste0("Plots_Output_", folder_date))
diary_path_anno  <- file.path(main_plot_path, "SleepDiary_Annotated_AR1")
diary_path_pure  <- file.path(main_plot_path, "SleepDiary_Pure_Final")
diary_path_trend <- file.path(main_plot_path, "SleepDiary_LinearTrend")

# 一次建立所有繪圖目錄
lapply(
  c(diary_path_anno, diary_path_pure, diary_path_trend),
  dir.create, recursive = TRUE, showWarnings = FALSE
)

plot_sum <- desc_data %>% rename(measure = variable, avg = mean, se = sem)
use_ar1  <- nrow(gee_spec_res$pw_time) > 0

# ==============================================================================
# === 8. 繪圖函數定義 ===
# ==============================================================================

#' 建立基礎折線圖 (Mean ± SEM)
#'
#' @param df_s  描述統計摘要資料 (含 week_numeric, avg, se, Group)
#' @param measure_name  變數名稱 (用於標題)
#' @param y_breaks  Y 軸刻度
#' @return ggplot 物件
create_base_line_plot <- function(df_s, measure_name, y_breaks) {
  ggplot(df_s, aes(x = week_numeric, y = avg, group = Group,
                   color = Group, shape = Group)) +
    geom_line(linewidth = 1.2, alpha = 0.8) +
    geom_point(size = 4) +
    geom_errorbar(aes(ymin = avg - se, ymax = avg + se), width = 0.2) +
    scale_x_continuous(
      breaks = sort(unique(df_s$week_numeric)),
      name   = "Week",
      expand = expansion(mult = 0.1)
    ) +
    scale_y_continuous(breaks = y_breaks, limits = range(y_breaks)) +
    scale_color_manual(values = COLOR_PALETTE) +
    scale_shape_manual(values = SHAPE_PALETTE) +
    labs(title = measure_name, subtitle = "Mean ± SEM", y = "Value") +
    theme_classic() +
    theme(
      aspect.ratio    = 1,
      plot.title      = element_text(size = 22, face = "bold", hjust = 0.5),
      plot.subtitle   = element_text(size = 16, hjust = 0.5),
      axis.title      = element_text(size = 20, face = "bold"),
      axis.text       = element_text(size = 18, color = "black", face = "bold"),
      legend.position      = c(0.99, 0.99),
      legend.justification = c("right", "top"),
      legend.text     = element_text(size = 14)
    )
}

#' 加上顯著性標註的折線圖
#'
#' @param p  基礎 ggplot 折線圖
#' @param df_s  含標註欄位的資料框 (label_A, label_B, label_AB)
#' @param pmax  Y 軸上方標註位置
#' @return ggplot 物件
add_annotations <- function(p, df_s, pmax) {
  p +
    geom_text(aes(label = label_A, y = avg + se),
              vjust = -0.5, size = 7, show.legend = FALSE, na.rm = TRUE) +
    geom_text(aes(label = label_B, y = avg + se),
              vjust = -0.5, size = 6, show.legend = FALSE, na.rm = TRUE) +
    geom_text(
      data = df_s %>% filter(!is.na(label_AB)),
      aes(label = label_AB, x = week_numeric, y = pmax),
      color = "black", vjust = 1, size = 6, show.legend = FALSE, na.rm = TRUE
    ) +
    labs(subtitle = "Mean ± SEM (*:A vs Pre, #:B vs Pre, $:A vs B)")
}

#' 建立長期趨勢散佈圖 (含線性回歸)
#'
#' @param plot_df  長格式資料 (含 week_numeric, value, Group)
#' @param measure_name  變數名稱 (用於標題)
#' @param plot_top_limit  Y 軸上限
#' @return ggplot 物件
create_trend_plot <- function(plot_df, measure_name, plot_top_limit) {
  ggplot(plot_df, aes(x = week_numeric, y = value, color = Group, fill = Group)) +
    geom_point(alpha = 0.4, size = 2.5, position = position_jitter(width = 0.15)) +
    geom_smooth(method = "lm", se = TRUE, alpha = 0.15, linewidth = 1.5) +
    stat_cor(
      data   = plot_df %>% filter(Group == "A"),
      aes(label = paste("'A:'~", after_stat(r.label), "~','~", after_stat(p.label), sep = "")),
      method = "pearson", label.x.npc = 0.05, label.y.npc = 0.96,
      size = 6, geom = "label",
      fill = "white", color = "black", label.size = NA,
      alpha = 0.8, fontface = "bold", show.legend = FALSE
    ) +
    stat_cor(
      data   = plot_df %>% filter(Group == "B"),
      aes(label = paste("'B:'~", after_stat(r.label), "~','~", after_stat(p.label), sep = "")),
      method = "pearson", label.x.npc = 0.05, label.y.npc = 0.86,
      size = 6, geom = "label",
      fill = "white", color = "black", label.size = NA,
      alpha = 0.8, fontface = "bold", show.legend = FALSE
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
      y        = "Value"
    ) +
    theme_bw() +
    theme(
      aspect.ratio   = 1,
      plot.title     = element_text(size = 22, face = "bold", hjust = 0.5),
      axis.title     = element_text(size = 20, face = "bold"),
      axis.text      = element_text(size = 18, color = "black", face = "bold"),
      legend.position = "top",
      legend.text    = element_text(size = 16),
      panel.grid.minor = element_blank()
    )
}

#' 繪製並儲存 Pairplot (相關矩陣圖)
#'
#' @param data  長格式資料
#' @param vars  要繪製的變數名稱向量
#' @param title_suffix  圖表標題後綴
#' @param save_dir  儲存目錄
plot_pair <- function(data, vars, title_suffix, save_dir) {
  df_sub <- data %>%
    select(Group, all_of(vars)) %>%
    na.omit() %>%
    mutate(Group = factor(Group, levels = c("A", "B")))

  if (nrow(df_sub) == 0) return(invisible(NULL))

  p <- ggpairs(
    df_sub,
    columns = 2:ncol(df_sub),
    aes(color = Group, fill = Group, alpha = 0.6),
    diag  = list(continuous = wrap("densityDiag", alpha = 0.5)),
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
    p, width = 14, height = 12, bg = "white"
  )
}

# ==============================================================================
# === 9. 繪圖：Annotated & Pure (折線圖) ===
# ==============================================================================
message(">>> [8/10] 繪製折線圖 (Trend Plot with SEM)...")

vars_to_plot <- unique(plot_sum$measure)
pb_line <- txtProgressBar(min = 0, max = length(vars_to_plot), style = 3)

for (i in seq_along(vars_to_plot)) {
  m <- vars_to_plot[i]
  df_s <- plot_sum %>% filter(measure == m)
  if (nrow(df_s) == 0) {
    setTxtProgressBar(pb_line, i)
    next
  }

  # 初始化標註欄位
  df_s$label_A  <- NA
  df_s$label_B  <- NA
  df_s$label_AB <- NA
  base_w <- min(df_s$week_numeric, na.rm = TRUE)

  # 計算顯著性標註
  if (use_ar1) {
    stats_t <- gee_spec_res$pw_time  %>% filter(Variable == m)
    stats_g <- gee_spec_res$pw_group %>% filter(Variable == m)

    # 組內比較 (vs baseline)
    for (k in seq_len(nrow(df_s))) {
      w <- df_s$week_numeric[k]
      g <- as.character(df_s$Group[k])
      if (w > base_w) {
        res <- stats_t %>%
          filter(grepl(paste0(w), contrast) & grepl(paste0(base_w), contrast) & Group == g)
        if (nrow(res) > 0 && res$p.value[1] < ALPHA_SIGNIFICANCE) {
          if (g == "A") df_s$label_A[k] <- "*" else df_s$label_B[k] <- "#"
        }
      }
    }

    # 組間比較
    for (k in seq_len(nrow(df_s))) {
      if (as.character(df_s$Group[k]) == "A") {
        w_target <- as.character(df_s$week_numeric[k])
        res <- stats_g %>% filter(week_factor == w_target)
        if (nrow(res) > 0 && res$p.value[1] < ALPHA_SIGNIFICANCE) {
          df_s$label_AB[k] <- "$"
        }
      }
    }
  }

  # 計算 Y 軸範圍
  ymin <- min(df_s$avg - df_s$se, na.rm = TRUE)
  ymax <- max(df_s$avg + df_s$se, na.rm = TRUE)
  if (ymin == ymax) {
    ymin <- ymin - 0.1
    ymax <- ymax + 0.1
  }
  pmax_val <- ymax + (ymax - ymin) * 0.15
  brks <- pretty(c(ymin, pmax_val), n = 5)
  if (length(brks) > 6) brks <- pretty(c(ymin, pmax_val), n = 4)

  # 繪製並儲存
  p_base <- create_base_line_plot(df_s, m, brks)
  p_anno <- add_annotations(p_base, df_s, pmax_val)

  ggsave(file.path(diary_path_anno, paste0(m, "_Annotated.png")),
         p_anno, width = 8, height = 8, bg = "white")
  ggsave(file.path(diary_path_pure, paste0(m, "_Pure.png")),
         p_base, width = 8, height = 8, bg = "white")

  setTxtProgressBar(pb_line, i)
}
close(pb_line)
message("✅ 折線圖繪製完成")

# ==============================================================================
# === 10. 繪圖：Correlation Pairplots ===
# ==============================================================================
message(">>> [9/10] 繪製 Pairplots...")
diary_path_cor <- file.path(main_plot_path, "Sleepdiary_COR")
dir.create(diary_path_cor, recursive = TRUE, showWarnings = FALSE)

vars_objective  <- c("TRT", "TST", "SE", "SL", "WASO", "wakefulness_day")
vars_subjective <- c("sleepiness_pre", "Alert_post", "SSS_post", "SE")

plot_pair(long, vars_objective,  "Objective_Sleep",   diary_path_cor)
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
  y_range   <- y_max_val - y_min_val
  plot_top_limit <- y_max_val + (y_range * 0.35)

  p_trend <- create_trend_plot(plot_df, m, plot_top_limit)

  ggsave(file.path(diary_path_trend, paste0(m, "_LinearTrend.png")),
         p_trend, width = 8, height = 8, bg = "white")

  setTxtProgressBar(pb_trend, i)
}
close(pb_trend)
message("✅ 趨勢圖繪製完成")

message("\n==============================================")
message("🎉🎉🎉 全部流程執行完畢！所有圖表已生成 🎉🎉🎉")
message("==============================================")