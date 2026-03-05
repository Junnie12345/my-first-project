# ==============================================================================
# === Bar_plot_tool.R (高彈性柱狀圖工具包 - 終極無警告完美版) ===
# ==============================================================================
require(ggplot2)
require(dplyr)

#' 1. 動態運算 Y 軸量尺 (正負對稱置中 vs 貼地 + 刻度瘦身 + 頂端留白)
calc_dynamic_y_scale_bar <- function(df, y_col, err_col) {
  val <- df[[y_col]]
  err <- df[[err_col]]
  
  tip_high <- max(val + err, na.rm = TRUE)
  tip_low <- min(val - err, na.rm = TRUE)
  
  if (tip_low >= 0) {
    # 情況 A：全部大於 0 -> 底部貼齊 0，頂部留 35% 空間給標註
    upper_limit <- tip_high * 1.35
    if (upper_limit == 0 || is.na(upper_limit)) upper_limit <- 1
    
    my_breaks <- pretty(c(0, upper_limit), n = 4)
    if (length(my_breaks) > 5) my_breaks <- pretty(c(0, upper_limit), n = 3)
    
    final_limits <- c(0, max(my_breaks))
    expand_y <- c(0, 0)
    
  } else {
    # 情況 B：包含負值 (如 Delta) -> 上下絕對對稱置中，兩端留 35%
    max_abs <- max(abs(tip_low), abs(tip_high)) * 1.35
    if (max_abs == 0 || is.na(max_abs)) max_abs <- 1
    
    my_breaks <- pretty(c(-max_abs, max_abs), n = 4)
    if (length(my_breaks) > 5) my_breaks <- pretty(c(-max_abs, max_abs), n = 3)
    
    lim_val <- max(abs(my_breaks))
    final_limits <- c(-lim_val, lim_val)
    expand_y <- c(0, 0)
  }
  
  return(list(
    breaks = my_breaks,
    limits = final_limits,
    expand = expand_y,
    span = final_limits[2] - final_limits[1]
  ))
}

#' 2. 建立高彈性柱狀圖 (灰色虛線 + 比例自訂版)
create_flexible_bar_plot <- function(
    df, x_col, y_col, err_col, group_col,
    scale_info,
    title_text, y_label = "Value", x_label = "Time",
    color_pal,
    base_size = 14, dodge_w = 0.8,
    plot_ratio = 0.5 # 【修改 3】加入比例參數，預設 0.5，但可由主程式覆寫
) {
  pd <- position_dodge(dodge_w)
  
  ggplot(df, aes(x = .data[[x_col]], y = .data[[y_col]], fill = .data[[group_col]], color = .data[[group_col]])) +
    # 【修改 4】將基準線改為灰色虛線
    geom_hline(yintercept = 0, linetype = "dashed", color = "gray50", linewidth = 0.8) +
    
    geom_col(position = pd, width = 0.7, color = "black") +
    geom_errorbar(aes(ymin = .data[[y_col]] - .data[[err_col]], 
                      ymax = .data[[y_col]] + .data[[err_col]]), 
                  position = pd, width = 0.25, color = "black") +
    
    scale_x_discrete(expand = expansion(add = 1)) + 
    scale_y_continuous(breaks = scale_info$breaks, limits = scale_info$limits, expand = scale_info$expand) +
    coord_cartesian(ylim = scale_info$limits) + 
    
    scale_fill_manual(values = color_pal) +
    scale_color_manual(values = color_pal) +
    labs(title = title_text, x = x_label, y = y_label) +
    theme_classic() +
    theme(
      aspect.ratio = plot_ratio, # 套用外部傳入的比例
      plot.title = element_text(size = base_size + 2, face = "bold", hjust = 0.5),
      axis.title = element_text(size = base_size, face = "bold"),
      axis.text.y = element_text(size = base_size - 1, color = "black"),
      axis.text.x = element_text(size = base_size - 1, color = "black", angle = 45, hjust = 1),
      legend.position = "top",
      legend.title = element_blank(),
      legend.text = element_text(size = base_size)
    )
}

#' 3. 加上顯著性標註 (絕對座標鎖定 + 置中降高版)
add_annotations_bar <- function(
    p, df, x_col, y_col, err_col, group_col, 
    scale_info,
    groupA_name, groupB_name,
    anno_subtitle = NULL,
    dodge_w = 0.8,
    size_star = 8,      # * 字體維持
    size_pound = 6,     # # 字體維持較小
    size_dollar = 5,    # 【微調】$ 字體再縮小一號 (6 -> 5)
    y_offset_row1 = 0.05,
    y_gap_rows = 0.10   # 【微調】縮小行距，讓 $ 往下降一點 (0.15 -> 0.10)
) {
  span <- scale_info$span
  
  # 數學運算與座標鎖定
  df_pos <- df %>%
    group_by(.data[[x_col]]) %>%
    mutate(
      max_tip = max(ifelse(.data[[y_col]] >= 0, .data[[y_col]] + .data[[err_col]], 0), na.rm = TRUE),
      y_row1 = max_tip + (span * y_offset_row1),
      y_row2 = max_tip + (span * y_offset_row1) + (span * y_gap_rows)
    ) %>% 
    ungroup() %>%
    mutate(
      x_num = as.numeric(as.factor(.data[[x_col]])),
      x_exact = ifelse(.data[[group_col]] == groupA_name, x_num - (dodge_w / 4), x_num + (dodge_w / 4))
    )
  
  p_out <- p
  
  # --- 第 1 行：組內標記 (* 與 #) ---
  if ("label_A" %in% names(df_pos)) {
    df_star <- df_pos %>% filter(.data[[group_col]] == groupA_name, !is.na(label_A))
    if (nrow(df_star) > 0) {
      p_out <- p_out + geom_text(
        data = df_star, 
        aes(x = x_exact, y = y_row1, label = label_A, color = .data[[group_col]]),
        vjust = -0.1, size = size_star, fontface = "bold", show.legend = FALSE, hjust = 0.5
      )
    }
  }
  
  if ("label_B" %in% names(df_pos)) {
    df_pound <- df_pos %>% filter(.data[[group_col]] == groupB_name, !is.na(label_B))
    if (nrow(df_pound) > 0) {
      p_out <- p_out + geom_text(
        data = df_pound, 
        aes(x = x_exact, y = y_row1, label = label_B, color = .data[[group_col]]),
        vjust = 0, size = size_pound, fontface = "plain", show.legend = FALSE, hjust = 0.5
      )
    }
  }
  
  # --- 第 2 行：組間標記 ($) ---
  if ("label_Bet" %in% names(df_pos)) {
    df_Bet <- df_pos %>% filter(!is.na(label_Bet)) %>% distinct(.data[[x_col]], .keep_all = TRUE)
    if (nrow(df_Bet) > 0) {
      p_out <- p_out + geom_text(
        data = df_Bet, 
        aes(x = x_num, y = y_row2, label = label_Bet),
        inherit.aes = FALSE, color = "black", vjust = 0, size = size_dollar, fontface = "bold", hjust = 0.5
      )
    }
  }
  
  if (!is.null(anno_subtitle)) {
    p_out <- p_out + labs(subtitle = anno_subtitle)
  }
  
  return(p_out)
}