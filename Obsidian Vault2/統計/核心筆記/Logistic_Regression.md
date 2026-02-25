# 邏輯斯迴歸 (Logistic Regression)

> 🔗 返回：[[2. Statistical_Models_Map]]
> 📌 相關：[[Poisson_Gamma_Regression]]

---

## 一、基礎定義與目的

|**項目**|**說明**|
|---|---|
|**定義**|屬於**廣義線性模型 (Generalized Linear Model, GLM)** 的一種，用於估計事件發生的**機率 (Probability)**。|
|**結果變量**|必須是**類別**數據，最常見的是**二元 (Binary)**，例如：是/否、成功/失敗、得病/未得病 (通常編碼為 1/0)。|
|**輸入變量**|可以是連續、類別或兩者的組合。|
|**核心目的**|根據一組預測變量，預測特定結果事件發生的機率 $P(Y=1)$，並量化這些預測變量的**影響強度**。|

---

## 二、模型結構與核心函數

### 🌟 完整邏輯斯諦迴歸公式

$$\text{機率 } P(Y=1 | \mathbf{X}) = \frac{1}{1 + e^{-(\beta_0 + \beta_1 X_1 + \beta_2 X_2 + \dots + \beta_k X_k)}}$$

### 線性預測式 (Linear Predictor)

$$Z = \beta_0 + \beta_1 X_1 + \beta_2 X_2 + \dots + \beta_k X_k$$

$Z$ 是一種潛在得分或潛在變量，代表事件發生的對數勝算 (Log-Odds)。

### 邏輯函數 (Logit Function)

|**步驟**|**數學表達式**|**統計意義 (Link Function)**|
|---|---|---|
|**勝算 (Odds)**|$\text{Odds} = \frac{P}{1-P}$|將機率 (0 到 1) 轉換為**勝算** (0 到 $\infty$)。|
|**對數勝算 (Log-Odds)**|$\ln\left(\frac{P}{1-P}\right) = Z$|這是**連結函數 (Link Function)**，將非線性的機率與線性的預測式 $Z$ 連結起來。|
|**機率 (Probability)**|$P = \frac{1}{1 + e^{-Z}}$|這是**S型曲線 (Sigmoid Function)**，將 $Z$ 轉換回機率 $P$ (0 到 1)。|

#### 轉換步驟

|**步驟**|**說明**|**數學表達式**|**範圍**|
|---|---|---|---|
|**A. 定義機率 ($P$)**|事件發生的機率。|$P$|$[0, 1]$|
|**B. 定義勝算 (Odds)**|事件發生與不發生機率的比值。|$\text{Odds} = \frac{P}{1-P}$|$[0, \infty]$|
|**C. 定義對數勝算 (Log-Odds)**|對勝算取自然對數 ($\ln$)。|$\ln\left(\frac{P}{1-P}\right)$|$[-\infty, +\infty]$|

---

## 三、係數解釋與結果呈現

|**項目**|**數學表達式**|**實質解釋 (最重要的輸出)**|
|---|---|---|
|**迴歸係數 ($\beta_i$)**|$\beta_i$|$X_i$ 每增加一個單位，**對數勝算**改變 $\beta_i$ 個單位。|
|**勝算比 (Odds Ratio, OR)**|$\text{OR}_i = e^{\beta_i}$|$X_i$ 每增加一個單位，**事件發生的勝算**將**乘以** $\text{OR}_i$。|
|**$\text{OR} > 1$**|$e^{\beta_i} > 1$|$X_i$ 增加，事件發生的勝算**增加** (正相關)。|
|**$\text{OR} < 1$**|$e^{\beta_i} < 1$|$X_i$ 增加，事件發生的勝算**減少** (負相關)。|
|**$\text{OR} = 1$**|$e^{\beta_i} = 1$|$X_i$ 增加，對事件發生的勝算**沒有影響**。|

---

## 四、模型評估與診斷

| **評估項目**                     | **說明**                                                  | **目的**                                      |
| ---------------------------- | ------------------------------------------------------- | ------------------------------------------- |
| **Wald 檢定 (Wald Test)**      | 用於檢定單一係數 $\beta_i$ 是否顯著不為零。    | 判斷單一預測變量的貢獻是否顯著。                            |
| **擬合優度檢定 (Goodness-of-Fit)** | 常見的有**Hosmer-Lemeshow 檢定**。                             | 檢定模型是否與數據擬合良好。                              |
| **ROC 曲線**                   | 繪製**真陽性率 (Sensitivity)** 與**假陽性率 (1-Specificity)** 的曲線。 | 評估模型區分 0 和 1 兩組的能力。                |
| **AUC**                      | **曲線下面積 (Area Under the Curve)**。                       | 數值範圍 0.5 (隨機猜測) 到 1.0 (完美預測)。 |
| **最大概似法**                    | **Maximum Likelihood Estimation (MLE)**                 | 與線性迴歸使用最小平方不同，邏輯斯諦迴歸使用 MLE 來估計係數。           |

---

## 五、R 語言實作

```r
# GLM 邏輯斯迴歸
model <- glm(outcome ~ predictor1 + predictor2, 
             family = binomial(link = "logit"), 
             data = df)
summary(model)

# 計算勝算比
exp(coef(model))
exp(confint(model))
```
