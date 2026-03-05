# 🚀 R 語言自動化科學繪圖：核心邏輯與架構筆記

## 1. 基礎架構：三階段接力賽

這套繪圖系統之所以強大，是因為它將「算統計」跟「畫圖」完全分開。整套流程分為三個階段：

- **第一階段：資料端 (Main Script)**
    
    - **任務**：計算敘述統計（平均數、標準誤）與 P 值。
        
    - **關鍵輸出**：建立帶有 `label_time` (`*`, `#`) 與 `label_AB` (`$`) 的資料表。
        
    - **思維**：在這裡，統計顯著性還只是一串「字元」，還不是圖形。
        
- **第二階段：工具端 (`tool.R`)**
    
    - **任務**：包含三個 Function，負責「數學運算」與「視覺渲染」。
        
        1. `calc_dynamic_y_scale`：算出最完美的 Y 軸上下限。
            
        2. `create_flexible_line_plot`：畫出底圖（線、點、誤差棒）。
            
        3. `add_annotations_flexible`：精確計算座標，把 `*`, `#`, `$` 畫上去。
            
- **第三階段：執行端 (Main Script 的迴圈)**
    
    - **任務**：把第一階段的資料，餵給第二階段的工具，然後存檔 (`ggsave`)。
        

---

## 2. 圖層排序：ggplot2 的「千層派」邏輯

R 繪圖的核心概念是圖層疊加（就像畫布一樣，越後面寫的程式碼，會蓋在越上層）。在 `create_flexible_line_plot` 中，順序非常重要：

1. **底層畫布**：`ggplot(...)` 設定資料來源與 X/Y 軸映射。
    
2. **幾何圖形 (Geoms)**：
    
    - 先畫線 `geom_line()`（在最下面）
        
    - 再畫點 `geom_point()`（蓋在線上）
        
    - 最後畫誤差棒 `geom_errorbar()`（蓋在最上面，保持清晰）
        
3. **座標軸與比例 (Scales)**：`scale_x_continuous()`, `scale_y_continuous()` 決定刻度與邊界。
    
4. **美化與主題 (Theme)**：`theme_classic()` 加上 `theme(...)` 決定字體大小、圖例位置。
    

---

## 3. Function 設計哲學：預設值 vs. 覆寫 (Override)

這是妳今天學到最重要的一課：**「預設值寫在工具裡，例外才寫在主程式。」**

### 📍 預設值 (Defaults) 在哪裡？

在 `tool.R` 建立 Function 時，括號裡寫的等於是「出廠設定」。

R

```
# tool.R 裡面的定義
add_annotations_flexible <- function(
    size_star = 8,        # 出廠設定星星大小為 8
    y_offset_row1 = 0.04  # 出廠設定星星高度為 4%
)
```

### 📍 什麼時候該在主程式添加設定？

如果妳 100 張圖有 99 張都要用 8 號星星，主程式呼叫時就**不要寫**這個參數。只有當某一張圖（或某個特定腳本）需要「特別待遇」時，才在主程式加上去覆寫它。

**正確的簡化寫法：**

R

```
# 主程式呼叫時，讓它保持乾淨，依賴 tool.R 的預設值
p_anno <- add_annotations_flexible(
  p = p_base, 
  df_s = df_sum, 
  scale_info = scale_info, 
  dodge_w = my_dodge_w
)
```

**如果某天教授說「所有圖」的星星都要變大：** 去改 `tool.R` 的預設值。 **如果教授說「只有問卷」的圖，X 軸標題不要顯示：** 在問卷主程式傳入 `x_label = NULL` 覆寫它。

---

## 4. 細節修正導航指南 (Where to adjust what)

未來如果看到圖面上有不滿意的地方，請對照以下指南去尋找修改點：

### 🛠️ 問題 A：顯著性標記 (`*`, `#`) 飄太高或撞到 Error Bar

- **修改位置**：`tool.R` -> `add_annotations_flexible` 裡的預設值 `y_offset_row1`。
    
- **邏輯**：它是看該組 Error Bar 最高點 (`my_tip`) 往上加多少百分比（例如 0.04 就是 4%）。數字調大就會飛更高。
    
- **對齊關鍵**：確保 `geom_text()` 裡面設定了 `vjust = 0`，這代表以字體的「底部」作為基準線，才不會忽高忽低。
    

### 🛠️ 問題 B：組間標記 (`$`, Bracket) 位置不對

- **修改位置**：`tool.R` -> `add_annotations_flexible` 裡的預設值 `y_gap_rows`。
    
- **邏輯**：Bracket 的高度是由「全場最高點」+ `y_offset_row1` + `y_gap_rows` 決定的。
    

### 🛠️ 問題 C：兩組的線與點靠太近（或離太遠）

- **修改位置**：Main Script（主程式）裡的 `my_dodge_w <- 0.4`。
    
- **邏輯**：這個數值控制兩組在 X 軸上「閃避」的距離。預設 0.4 夠寬；如果設為 0，兩組的點會完全重疊在一條垂直線上。
    

### 🛠️ 問題 D：想更改標題、移除 X/Y 軸名稱

- **修改位置**：Main Script（主程式）呼叫 `create_flexible_line_plot` 時傳入的參數。
    
- **範例**：加上 `x_label = NULL` 就能把 X 軸下方的大標題拿掉；加上 `title_text = "新標題"` 就能改圖名。