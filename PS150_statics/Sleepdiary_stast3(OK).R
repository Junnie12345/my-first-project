rm(list = ls())

# ==============================================================================
# === 1. 套件檢查與安裝 ===
# ==============================================================================
message(">>> [1/10] 檢查並載入套件...")
required_packages <- c(
  "data.table", "openxlsx", "lubridate", "magrittr", "dplyr", "tidyr",
  "hms", "writexl", "geepack", "emmeans", "ggplot2", "rstatix", "broom",
  "gtsummary", "afex", "gt",
  "performance", "correlation", "see", "patchwork", "lme4", "GGally", "MuMIn", "ggpubr", "stringr"
)

for (pkg in required_packages) {
  if (!require(pkg, character.only = TRUE)) {
    install.packages(pkg, dependencies = TRUE)
    library(pkg, character.only = TRUE)
  }
}
message("✅ 套件載入完成")

# ==============================================================================
# === 2. 檔案路徑與變數設定 ===
# ==============================================================================
message(">>> [2/10] 設定路徑與參數...")
base_dir <- "C:\\Users\\ngps9\\OneDrive\\onedrive\\桌面\\PS150_results\\2026\\"
input_file <- paste0(base_dir, "Sleepdiary260117_all_clean.xlsx")
output_file <- paste0(base_dir, "Sleepdiary_stats_Full_Final_v11.xlsx")

outcome_base_vars <- c(
  "TRT", "TST", "SE", "SL", "WASO", "wakefulness_day",
  "sleepiness_pre", "Alert_post", "SSS_post"
)

# ==============================================================================
# === 3. 資料讀取與清洗 ===
# ==============================================================================
message(">>> [3/10] 讀取並清洗資料 (修復 Week 0)...")
raw <- read.xlsx(input_file)
names(raw) <- trimws(names(raw)) # 強力清除空白

# 寬轉長函數
wide_to_long <- function(df, id_vars = c("ID", "Name", "Group"), value_bases = outcome_base_vars) {
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
  if (length(all_long) > 0) {
    Reduce(function(x, y) full_join(x, y, by = c("ID", "Name", "Group", "week")), all_long) %>%
      arrange(ID, week) %>%
      mutate(week_numeric = week, week_factor = as.factor(week), ID = as.factor(ID))
  } else {
    stop("沒有找到任何可轉換的變數")
  }
}

long <- wide_to_long(raw)

# 檢查 Week 0
weeks_found <- sort(unique(long$week_numeric))
if (!0 %in% weeks_found) warning("❌ 仍然沒有抓到 Week 0！") else message("✅ 成功抓取 Week 0")

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
# === 4. 基礎統計 ===
# ==============================================================================
message(">>> [4/10] 執行基礎統計 (Descriptive, Normality, Correlation)...")

# A. 敘述統計
group_weekly_descriptive <- function(long_df, vars = outcome_base_vars) {
  des_list <- list()
  for (v in vars) {
    temp <- long_df %>%
      group_by(Group, week_numeric) %>%
      summarise(n = sum(!is.na(.data[[v]])), mean = ifelse(n > 0, round(mean(.data[[v]], na.rm = T), 2), NA), sd = ifelse(n > 1, round(sd(.data[[v]], na.rm = T), 2), NA), sem = ifelse(n > 1, round(sd(.data[[v]], na.rm = T) / sqrt(n), 2), NA), .groups = "drop") %>%
      mutate(variable = v) %>%
      select(variable, everything())
    des_list[[v]] <- temp
  }
  bind_rows(des_list)
}
desc_data <- group_weekly_descriptive(long)

# B. 常態檢定
normality_tests_grouped <- function(long_df, vars = outcome_base_vars, alpha = 0.05) {
  results <- data.frame()
  for (v in vars) {
    temp <- long_df %>%
      filter(!is.na(.data[[v]])) %>%
      group_by(Group, week_numeric) %>%
      summarise(n = n(), shapiro_p = tryCatch(
        {
          if (n >= 3 && sd(.data[[v]]) > 0) round(shapiro.test(.data[[v]])$p.value, 4) else NA
        },
        error = function(e) NA
      ), .groups = "drop") %>%
      mutate(variable = v, is_normal = ifelse(is.na(shapiro_p), NA, shapiro_p > alpha))
    results <- bind_rows(results, temp)
  }
  return(results)
}
norm_results <- normality_tests_grouped(long)

# C. 相關性
cor_results <- tryCatch(
  {
    df_cor <- long %>%
      select(all_of(outcome_base_vars)) %>%
      filter(complete.cases(.))
    if (nrow(df_cor) < 3) NULL else correlation(df_cor, method = "pearson") %>% as.data.frame()
  },
  error = function(e) NULL
)

# ==============================================================================
# === 5. GEE 分析 ===
# ==============================================================================
message(">>> [5/10] 執行 GEE 分析...")

gee_best_res <- list(summary = data.frame(), pw_group = data.frame(), pw_time = data.frame())
gee_spec_res <- list(summary = data.frame(), pw_group = data.frame(), pw_time = data.frame())
f_gee <- as.formula("score ~ Group * week_factor")

calc_posthoc <- function(mod, m, c, type) {
  wald <- tryCatch(anova(mod) %>% as.data.frame() %>% mutate(Variable = m, Structure = c, Logic = type) %>% rownames_to_column("Term"), error = function(e) NULL)
  pg <- tryCatch(emmeans(mod, ~ Group | week_factor) %>% pairs(reverse = T, adjust = "none") %>% as.data.frame() %>% mutate(Variable = m, Structure = c, Logic = type), error = function(e) NULL)
  pt <- tryCatch(emmeans(mod, ~ week_factor | Group) %>% pairs(reverse = T, adjust = "none") %>% as.data.frame() %>% mutate(Variable = m, Structure = c, Logic = type), error = function(e) NULL)
  list(wald = wald, group = pg, time = pt)
}

pb_gee <- txtProgressBar(min = 0, max = length(outcome_base_vars), style = 3)
for (i in seq_along(outcome_base_vars)) {
  outcome <- outcome_base_vars[i]
  df_sub <- long %>%
    select(ID, Group, week_factor, week_numeric, score = all_of(outcome)) %>%
    filter(!is.na(score)) %>%
    arrange(ID, week_numeric)

  if (nrow(df_sub) >= 20) {
    m_ar1 <- tryCatch(
      {
        geeglm(f_gee, data = df_sub, id = ID, family = gaussian, corstr = "ar1")
      },
      error = function(e) NULL
    )
    m_exch <- tryCatch(
      {
        geeglm(f_gee, data = df_sub, id = ID, family = gaussian, corstr = "exchangeable")
      },
      error = function(e) NULL
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
    }

    spec_mod <- if (best_cor == "ar1" && !is.null(best_mod)) best_mod else m_ar1
    if (!is.null(spec_mod)) {
      ph_s <- calc_posthoc(spec_mod, outcome, "ar1", "Specified")
      gee_spec_res$summary <- bind_rows(gee_spec_res$summary, ph_s$wald)
      gee_spec_res$pw_group <- bind_rows(gee_spec_res$pw_group, ph_s$group)
      gee_spec_res$pw_time <- bind_rows(gee_spec_res$pw_time, ph_s$time)
    }
  }
  setTxtProgressBar(pb_gee, i)
}
close(pb_gee)
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
main_plot_path <- file.path(base_dir, paste0("Plots_Output_", folder_date))
diary_path_anno <- file.path(main_plot_path, "SleepDiary_Annotated_AR1")
diary_path_pure <- file.path(main_plot_path, "SleepDiary_Pure_Final")
diary_path_trend <- file.path(main_plot_path, "SleepDiary_LinearTrend")

if (!dir.exists(diary_path_anno)) dir.create(diary_path_anno, recursive = TRUE)
if (!dir.exists(diary_path_pure)) dir.create(diary_path_pure, recursive = TRUE)
if (!dir.exists(diary_path_trend)) dir.create(diary_path_trend, recursive = TRUE)

plot_sum <- desc_data %>% rename(measure = variable, avg = mean, se = sem)
my_colors <- c("placebo" = "#31688E", "PS150" = "#E67E22")
my_shapes <- c("placebo" = 16, "PS150" = 17)
use_ar1 <- nrow(gee_spec_res$pw_time) > 0

# ==============================================================================
# === 8. 繪圖：Annotated & Pure (折線圖) ===
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

  df_s$label_placebo <- NA
  df_s$label_PS150 <- NA
  df_s$label_AB <- NA
  base_w <- min(df_s$week_numeric, na.rm = T)

  if (use_ar1) {
    stats_t <- gee_spec_res$pw_time %>% filter(Variable == m)
    stats_g <- gee_spec_res$pw_group %>% filter(Variable == m)
    # Intra
    for (k in 1:nrow(df_s)) {
      w <- df_s$week_numeric[k]
      g <- as.character(df_s$Group[k])
      if (w > base_w) {
        res <- stats_t %>% filter(grepl(paste0(w), contrast) & grepl(paste0(base_w), contrast) & Group == g)
        if (nrow(res) > 0 && res$p.value[1] < 0.05) {
          if (g == "placebo") df_s$label_placebo[k] <- "*" else df_s$label_PS150[k] <- "#"
        }
      }
    }
    # Inter
    for (k in 1:nrow(df_s)) {
      if (as.character(df_s$Group[k]) == "placebo") {
        w_target <- as.character(df_s$week_numeric[k])
        res <- stats_g %>% filter(week_factor == w_target)
        if (nrow(res) > 0 && res$p.value[1] < 0.05) df_s$label_AB[k] <- "$"
      }
    }
  }

  ymin <- min(df_s$avg - df_s$se, na.rm = T)
  ymax <- max(df_s$avg + df_s$se, na.rm = T)
  if (ymin == ymax) {
    ymin <- ymin - 0.1
    ymax <- ymax + 0.1
  }
  pmax <- ymax + (ymax - ymin) * 0.15
  brks <- pretty(c(ymin, pmax), n = 5)
  if (length(brks) > 6) brks <- pretty(c(ymin, pmax), n = 4)

  p <- ggplot(df_s, aes(x = week_numeric, y = avg, group = Group, color = Group, shape = Group)) +
    geom_line(linewidth = 1.2, alpha = 0.8) +
    geom_point(size = 4) +
    geom_errorbar(aes(ymin = avg - se, ymax = avg + se), width = 0.2) +
    scale_x_continuous(breaks = sort(unique(df_s$week_numeric)), name = "Week", expand = expansion(mult = 0.1)) +
    scale_y_continuous(breaks = brks, limits = range(brks)) +
    scale_color_manual(values = my_colors) +
    scale_shape_manual(values = my_shapes) +
    labs(title = m, subtitle = "Mean ± SEM", y = "Value") +
    theme_classic() +
    theme(
      aspect.ratio = 1,
      plot.title = element_text(size = 22, face = "bold", hjust = 0.5),
      plot.subtitle = element_text(size = 16, hjust = 0.5),
      axis.title = element_text(size = 20, face = "bold"),
      axis.text = element_text(size = 18, color = "black", face = "bold"),
      legend.position = c(0.99, 0.99), legend.justification = c("right", "top"),
      legend.text = element_text(size = 14)
    )

  p_anno <- p +
    geom_text(aes(label = label_placebo, y = avg + se), vjust = -0.5, size = 7, show.legend = F, na.rm = T) +
    geom_text(aes(label = label_PS150, y = avg + se), vjust = -0.5, size = 6, show.legend = F, na.rm = T) +
    geom_text(data = df_s %>% filter(!is.na(label_AB)), aes(label = label_AB, x = week_numeric, y = pmax), color = "black", vjust = 1, size = 6, show.legend = F, na.rm = T) +
    labs(subtitle = "Mean ± SEM (*:placebo vs Pre, #:PS150 vs Pre, $:placebo vs PS150)")

  ggsave(file.path(diary_path_anno, paste0(m, "_Annotated.png")), p_anno, width = 8, height = 8, bg = "white")
  ggsave(file.path(diary_path_pure, paste0(m, "_Pure.png")), p, width = 8, height = 8, bg = "white")

  setTxtProgressBar(pb_line, i)
}
close(pb_line)
message("✅ 折線圖繪製完成")

# ==============================================================================
# === 9. 繪圖：Correlation Pairplots ===
# ==============================================================================
message(">>> [9/10] 繪製 Pairplots...")
diary_path_cor <- file.path(main_plot_path, "Sleepdiary_COR")
if (!dir.exists(diary_path_cor)) dir.create(diary_path_cor, recursive = TRUE)

vars_objective <- c("TRT", "TST", "SE", "SL", "WASO", "wakefulness_day")
vars_subjective <- c("sleepiness_pre", "Alert_post", "SSS_post", "SE")

plot_pair <- function(data, vars, title_suffix) {
  df_sub <- data %>%
    select(Group, all_of(vars)) %>%
    na.omit() %>%
    mutate(Group = factor(Group, levels = c("placebo", "PS150")))
  if (nrow(df_sub) > 0) {
    my_colors_pair <- c("#00BFC4", "#F8766D")
    p <- ggpairs(
      df_sub,
      columns = 2:ncol(df_sub),
      aes(color = Group, fill = Group, alpha = 0.6),
      diag = list(continuous = wrap("densityDiag", alpha = 0.5)),
      upper = list(continuous = wrap("cor", size = 6, fontface = "bold")),
      lower = list(continuous = wrap("points", size = 2, alpha = 0.6))
    ) +
      scale_color_manual(values = my_colors_pair) + scale_fill_manual(values = my_colors_pair) +
      labs(title = paste0("Correlation Matrix: ", title_suffix)) +
      theme_bw() +
      theme(
        axis.text = element_text(size = 14, face = "bold", color = "black"),
        strip.text = element_text(size = 16, face = "bold", color = "black"),
        plot.title = element_text(size = 20, face = "bold", hjust = 0.5)
      )
    ggsave(file.path(diary_path_cor, paste0("Correlation_", title_suffix, ".png")), p, width = 14, height = 12, bg = "white")
  }
}

plot_pair(long, vars_objective, "Objective_Sleep")
plot_pair(long, vars_subjective, "Subjective_Feeling")
message("✅ Pairplots 繪製完成")

# ==============================================================================
# === 10. 繪圖：長期趨勢斜率圖 ===
# ==============================================================================
message(">>> [10/10] 繪製長期趨勢圖 (Long-term Trend)...")

trend_data <- long %>%
  select(ID, Group, week_numeric, all_of(outcome_base_vars)) %>%
  pivot_longer(cols = all_of(outcome_base_vars), names_to = "measure", values_to = "value") %>%
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

  p_trend <- ggplot(plot_df, aes(x = week_numeric, y = value, color = Group, fill = Group)) +
    geom_point(alpha = 0.4, size = 2.5, position = position_jitter(width = 0.15)) +
    geom_smooth(method = "lm", se = TRUE, alpha = 0.15, linewidth = 1.5) +
    stat_cor(
      data = plot_df %>% filter(Group == "placebo"),
      aes(label = paste("'placebo:'~", after_stat(r.label), "~','~", after_stat(p.label), sep = "")),
      method = "pearson", label.x.npc = 0.05, label.y.npc = 0.96, size = 6, geom = "label",
      fill = "white", color = "black", label.size = NA, alpha = 0.8, fontface = "bold", show.legend = FALSE
    ) +
    stat_cor(
      data = plot_df %>% filter(Group == "PS150"),
      aes(label = paste("'PS150:'~", after_stat(r.label), "~','~", after_stat(p.label), sep = "")),
      method = "pearson", label.x.npc = 0.05, label.y.npc = 0.86, size = 6, geom = "label",
      fill = "white", color = "black", label.size = NA, alpha = 0.8, fontface = "bold", show.legend = FALSE
    ) +
    scale_color_manual(values = c("placebo" = "#00BFC4", "PS150" = "#F8766D")) +
    scale_fill_manual(values = c("placebo" = "#00BFC4", "PS150" = "#F8766D")) +
    scale_y_continuous(limits = c(NA, plot_top_limit)) +
    scale_x_continuous(breaks = sort(unique(plot_df$week_numeric)), name = "Week", expand = expansion(mult = 0.1)) +
    labs(title = paste0("Trend: ", m), subtitle = "Linear Regression", y = "Value") +
    theme_bw() +
    theme(
      aspect.ratio = 1,
      plot.title = element_text(size = 22, face = "bold", hjust = 0.5),
      axis.title = element_text(size = 20, face = "bold"),
      axis.text = element_text(size = 18, color = "black", face = "bold"),
      legend.position = "top", legend.text = element_text(size = 16),
      panel.grid.minor = element_blank()
    )

  ggsave(file.path(diary_path_trend, paste0(m, "_LinearTrend.png")), p_trend, width = 8, height = 8, bg = "white")
  setTxtProgressBar(pb_trend, i)
}
close(pb_trend)
message("✅ 趨勢圖繪製完成")

message("\n==============================================")
message("🎉🎉🎉 全部流程執行完畢！所有圖表已生成 🎉🎉🎉")
message("==============================================")
