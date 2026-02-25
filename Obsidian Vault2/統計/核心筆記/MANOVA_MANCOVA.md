# 多變量變異數分析 (MANOVA / MANCOVA)

> 🔗 返回：[[2. Statistical_Models_Map]]
> 📌 相關：[[ANOVA_Family]] | [[Traditional_ANCOVA]]

---

## 一、定義

同時考量多個「高度相關的因變項」的 ANOVA / ANCOVA。

| **項目** | **MANOVA** | **MANCOVA** |
|---|---|---|
| **依變項** | **多個** (連續型) | **多個** (連續型) |
| **自變項** | 類別型 (因子 / Group) | 類別型 + 連續共變量 |
| **R 常用函數** | `manova()` | `manova()` + 共變量 |
| **核心假設** | ANOVA 假設 + **變異數-共變異數矩陣同質性** | 同 MANOVA + 迴歸斜率同質性 |
| **與迴歸關係** | 相當於對多個依變項同時執行 MLR | — |

---

## 二、適用情境

- 同時有多個相關依變項需要檢測（如：同時測量焦慮和憂鬱）
- 避免多重比較造成 Type I Error 膨脹

---

## 三、R 語言實作

```r
# MANOVA
manova_model <- manova(cbind(DV1, DV2, DV3) ~ Group, data = df)
summary(manova_model)

# 各依變項的單變量結果
summary.aov(manova_model)
```

---

## 四、注意事項

（待補充）
