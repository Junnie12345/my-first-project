# 廣義線性混合模型 (GLMM)

> 🔗 返回：[[2. Statistical_Models_Map]]
> 📌 相關：[[LMM_Linear_Mixed_Model]] | [[GEE_Generalized_Estimating_Equations]]

---

## 一、定義

混合 GLM + 隨機效應。適用於二元、計數等非常態分布的重複量測資料。

|**項目**|**說明**|
|---|---|
|**LMM**|連續因變項 + 重複量測（常態分布）|
|**GLMM**|非常態因變項（二元、計數、比例）+ 重複量測|

---

## 二、核心概念

GLMM = GLM（處理非常態分布）+ Random Effects（處理重複測量/巢狀結構）

$$g(E[Y_{ij}]) = \mathbf{X}_{ij}\boldsymbol{\beta} + \mathbf{Z}_{ij}\mathbf{u}_i$$

- $g(\cdot)$：連結函數（如 logit、log）
- $\mathbf{u}_i$：個體隨機效應

---

## 三、常見 GLMM 類型

| **因變項類型** | **分佈** | **連結函數** | **範例** |
|---|---|---|---|
| 二元 (0/1) | Binomial | Logit | 是否失眠 |
| 計數 | Poisson | Log | 每晚驚醒次數 |
| 比例 | Binomial | Logit | 治療改善比例 |

---

## 四、GEE vs. GLMM 決策指南

| 方法 | 關注焦點 | 模型假設 | 適用情境 |
|------|----------|----------|----------|
| GEE | 平均效應 (Population-level) | 關聯結構 (Robust) | 大樣本、公衛政策評估 |
| GLMM | 個體效應 (Subject-specific) | 隨機效應分布 | 小樣本、精準醫療、腦科學 |

---

## 五、R 語言實作

```r
library(lme4)

# 二元結果的 GLMM
glmm_model <- glmer(
  outcome ~ Group * Time + (1 | Subject_ID),
  data = df,
  family = binomial(link = "logit")
)

summary(glmm_model)
```

---

## 六、注意事項

- 計算複雜，可能遇到收斂問題 (Convergence issues)
- 需假設隨機效應服從常態分佈
- 對插補較敏感
