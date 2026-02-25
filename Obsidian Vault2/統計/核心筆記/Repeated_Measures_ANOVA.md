# 重複量測變異數分析 (Repeated Measures ANOVA)

> 🔗 返回：[[2. Statistical_Models_Map]]
> 📌 相關：[[ANOVA_Family]] | [[LMM_Linear_Mixed_Model]] | [[GEE_Generalized_Estimating_Equations]]

> [!WARNING]
> 現代統計學強烈建議以 [[LMM_Linear_Mixed_Model]] 或 [[GEE_Generalized_Estimating_Equations]] 取代 RM-ANOVA，以妥善處理缺失值與共變異數結構。

---

## 一、定義

早期處理重複測量資料的傳統方法。適用於同一受試者在多個時間點被重複測量的設計。

---

## 二、球形檢定 (Mauchly's Test of Sphericity)

這是**重複測量 ANOVA 專屬**的假設檢定。

### 核心概念：變異數的「公平性」

球形假設要求：**「時間點之間的差異分數」的變異數**要相等。

$$Var(T1 - T2) \approx Var(T1 - T3) \approx Var(T2 - T3)$$

### 為什麼重要？

如果不符合球形假設，原本 ANOVA 依賴的 F 分配就會失準：
- **後果：** Type I Error（型一錯誤）會暴增
- 電腦算出 p = 0.03 (顯著)，但實際上可能只有 p = 0.08 (不顯著)

### 解決方案

跑重複測量 ANOVA 時，第一步先看 **Mauchly's Test**：

1. **若 p > .05 (不顯著)：** 符合球形假設。直接看 "Sphericity Assumed" 的結果。
2. **若 p < .05 (顯著)：** 違反球形假設，必須進行**校正**。

### 校正方法

| **方法** | **特性** |
|---|---|
| **Greenhouse-Geisser (GG)** | 最常用，比較保守（懲罰比較重） |
| **Huynh-Feldt (HF)** | 比較寬鬆（懲罰比較輕） |

**實戰判斷法則：** 違反球形假設時，通常直接看 **Greenhouse-Geisser** 校正後的 p 值。

---

## 三、R 語言實作

### 使用 `afex` (推薦)
```r
library(afex)

rm_model <- aov_ez(
  id = "Subject_ID", 
  dv = "Score", 
  data = df, 
  between = "Group", 
  within = "Time"
)

# 輸出結果會跟 SPSS 一模一樣，並自動提供校正後的 p 值 (GG correction)
rm_model
```

---

## 四、為何建議改用 LMM / GEE？

| **問題** | **RM-ANOVA 的限制** | **LMM / GEE 的優勢** |
|---|---|---|
| 缺失值 | 無法處理，必須完整資料 | 可處理不完整資料 (MAR) |
| 不平衡設計 | 表現不佳 | 強大的處理能力 |
| 球形條件 | 需要額外檢定與校正 | 不需要球形假設 |
| 共變異數結構 | 僅能假設球形 | 可靈活指定結構 |
