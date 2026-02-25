# 卜瓦松迴歸與伽瑪迴歸 (Poisson & Gamma Regression)

> 🔗 返回：[[2. Statistical_Models_Map]]
> 📌 相關：[[Logistic_Regression]]

---

## 一、卜瓦松迴歸 (Poisson Regression)

處理「計數資料」(Poisson 分布)，如：每晚驚醒次數、住院天數。

**定義：** 在某一時間區域內，某一事件的發生次數。

$$\log(\lambda) = \beta_0 + \beta_1 X_1 + \cdots + \beta_k X_k$$

- 連結函數：Log link
- 參數解釋：$\exp(\beta_1)$ 為率比 (Rate Ratio)，表示事件率變化倍數

### R 語言實作
```r
model <- glm(count ~ predictor, family = poisson(link = "log"), data = df)
summary(model)
```

---

## 二、伽瑪迴歸 (Gamma Regression)

處理「正偏態資料」(Gamma 分布)，如：醫療花費、反應時間。

$$g(\mu) = \beta_0 + \beta_1 X_1 + \cdots + \beta_k X_k$$

- 連結函數：Inverse 或 Log
- 適用於連續、正值、右偏的資料

### R 語言實作
```r
model <- glm(response_time ~ predictor, family = Gamma(link = "log"), data = df)
summary(model)
```

---

## 三、適用情境比較

| **分佈** | **因變數類型** | **連結函數** | **參數意義** |
|---|---|---|---|
| Poisson | 計數 (0, 1, 2, ...) | Log | $\exp(\beta_1)$ 為率比 |
| Gamma | 連續、正偏、正值 | Inverse 或 Log | 適用於反比關係 |
| 負二項 (NB) | 過度離散計數資料 | Log | 考慮額外散布參數 |
