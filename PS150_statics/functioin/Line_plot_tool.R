# ==============================================================================
# === Line_plot_tool.R (獨立高度修正 + 預設 0.2 保護兩點專案 + 含 No_SE) ===
# ==============================================================================
require(ggplot2)
require(dplyr)
if (!requireNamespace("ggsignif", quietly = TRUE)) install.packages("ggsignif")
require(ggsignif)

#' 0. 動態運算 Y 軸量尺 (回歸 15% Error Bar 限制 + 頂端留白)
calc_dynamic_y_scale <- function(df_s, error_ratio = 0.15) {
  true_y_min <- min(df_s$avg - df_s$se, na.rm = TRUE)
  true_y_max <- max(df_s$avg + df_s$se, na.rm = TRUE)
  mid_y <- (true_y_max + true_y_min) / 2
  
  max_error_len <- max(2 * df_s$se, na.rm = TRUE)
  if (is.na(max_error_len) || max_error_len == 0) max_error_len <- 1 
  
  target_span <- max_error_len / error_ratio 
  y_low_zoom <- mid_y - (target_span / 2)
  y_high_zoom <- mid_y + (target_span / 2)
  y_high_zoom <- y_high_zoom + (target_span * 0.15)
  
  my_breaks <- pretty(c(y_low_zoom, y_high_zoom), n = 4)
  if (length(my_breaks) > 5) {
    my_breaks <- pretty(c(y_low_zoom, y_high_zoom), n = 3)
  }
  
  final_limits <- range(my_breaks)
  if(final_limits[2] < y_high_zoom) final_limits[2] <- y_high_zoom
  
  return(list(breaks = my_breaks, limits = final_limits, span = final_limits[2] - final_limits[1]))
}

#' 1. 建立高彈性折線圖
create_flexible_line_plot <- function(
    df_s, y_breaks, y_limits, 
    title_text, 
    x_label = "Week", y_label = "Value", 
    color_pal, shape_pal,
    base_size = 14, 
    dodge_w = 0.4 # ⚠️安全預設
) {
  pd <- position_dodge(dodge_w)
  
  ggplot(df_s, aes(x = week_numeric, y = avg, group = Group, color = Group, shape = Group)) +
    geom_line(linewidth = 1.2, alpha = 0.8, position = pd) +
    geom_point(size = 4, position = pd) +
    geom_errorbar(aes(ymin = avg - se, ymax = avg + se), width = 0.1, position = pd) +
    
    scale_x_continuous(breaks = sort(unique(df_s$week_numeric)), name = x_label, expand = expansion(mult = 0.15)) +
    scale_y_continuous(breaks = y_breaks, limits = y_limits, expand = c(0, 0)) +
    coord_cartesian(ylim = y_limits) + 
    
    scale_color_manual(values = color_pal) +
    scale_shape_manual(values = shape_pal) +
    labs(title = title_text, x = x_label, y = y_label) +
    
    theme_classic() +
    theme(
      aspect.ratio = 1.25,
      plot.title = element_text(size = base_size + 8, face = "bold", hjust = 0.5),
      axis.title = element_text(size = base_size + 4, face = "bold"),
      axis.text  = element_text(size = base_size + 2, color = "black"),
      legend.position = c(0.99, 0.99),
      legend.justification = c("right", "top"),
      legend.text = element_text(size = base_size),
      legend.title = element_blank()
    )
}

#' 2. 建立高彈性折線圖 (無 Error bar 版) ⚠️【幫你補回這個函數了】
create_flexible_line_plot_no_se <- function(
    df_s, y_breaks, y_limits, 
    title_text, 
    x_label = "Week", y_label = "Value", 
    color_pal, shape_pal,
    base_size = 14, 
    dodge_w = 0.4 # ⚠️【安全預設】
) {
  pd <- position_dodge(dodge_w)
  
  ggplot(df_s, aes(x = week_numeric, y = avg, group = Group, color = Group, shape = Group)) +
    geom_line(linewidth = 1.2, alpha = 0.8, position = pd) +
    geom_point(size = 4, position = pd) +
    
    scale_x_continuous(breaks = sort(unique(df_s$week_numeric)), name = x_label, expand = expansion(mult = 0.15)) +
    scale_y_continuous(breaks = y_breaks, limits = y_limits, expand = c(0, 0)) +
    coord_cartesian(ylim = y_limits) + 
    
    scale_color_manual(values = color_pal) +
    scale_shape_manual(values = shape_pal) +
    labs(title = title_text, x = x_label, y = y_label) +
    
    theme_classic() +
    theme(
      aspect.ratio = 1.25,
      plot.title = element_text(size = base_size + 8, face = "bold", hjust = 0.5),
      axis.title = element_text(size = base_size + 4, face = "bold"),
      axis.text  = element_text(size = base_size + 2, color = "black"),
      legend.position = c(0.99, 0.99),
      legend.justification = c("right", "top"),
      legend.text = element_text(size = base_size),
      legend.title = element_blank()
    )
}

#' 3. 加上顯著性標註 (獨立高度修正版)
add_annotations_flexible <- function(
    p, df_s, scale_info,
    dodge_w = 0.4, # ⚠️【安全預設】
    anno_subtitle = NULL,
    size_star = 8,
    size_pound = 5,
    size_dollar = 4,
    y_offset_row1 = 0.03, #組內顯著標記與error bar 距離
    y_gap_rows = 0.07     #組間顯著標記與error bar 距離
) {
  span <- scale_info$span
  offset_x <- dodge_w / 4
  
  # === 核心邏輯區 ===
  df_s_anno <- df_s %>%
    mutate(
      my_tip = avg + se, 
      y_row1 = my_tip + (span * y_offset_row1) 
    )
  
  df_bracket <- df_s_anno %>%
    group_by(week_numeric) %>%
    mutate(
      week_max_tip = max(my_tip, na.rm = TRUE),
      y_row2 = week_max_tip + (span * y_offset_row1) + (span * y_gap_rows)
    ) %>% ungroup()
  
  df_row1_placebo <- df_s_anno %>% filter(Group == "placebo" & label_time == "*")
  df_row1_PS150 <- df_s_anno %>% filter(Group == "PS150" & label_time == "#")
  
  p_out <- p
  
  if (nrow(df_row1_placebo) > 0) {
    p_out <- p_out + geom_text(
      data = df_row1_placebo,
      aes(label = label_time, x = week_numeric - offset_x, y = y_row1), 
      inherit.aes = FALSE, color = "#31688E", 
      vjust = 0, hjust = 0.5, size = size_star, fontface = "bold"
    )
  }
  
  if (nrow(df_row1_PS150) > 0) {
    p_out <- p_out + geom_text(
      data = df_row1_PS150,
      aes(label = label_time, x = week_numeric + offset_x, y = y_row1), 
      inherit.aes = FALSE, color = "#E67E22", 
      vjust = 0, hjust = 0.5, size = size_pound, fontface = "bold"
    )
  }
  
  df_row2 <- df_bracket %>% filter(!is.na(label_AB)) %>% distinct(week_numeric, .keep_all = TRUE)
  if (nrow(df_row2) > 0) {
    for (i in 1:nrow(df_row2)) {
      row_p <- df_row2[i, ]
      p_out <- p_out + geom_signif(
        xmin = row_p$week_numeric - offset_x, 
        xmax = row_p$week_numeric + offset_x, 
        y_position = row_p$y_row2,
        vjust = -0.2, 
        annotations = "$",  
        size = 0.6, color = "black", textsize = size_dollar, tip_length = 0.02
      )
    }
  }
  
  return(p_out)
}