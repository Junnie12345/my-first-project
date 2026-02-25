廣義線性模型 (GLM; Generalized Linear Model)
 🧩 主要概念：
+ 放寬「常態分布」假設  
+ 用「連結函數 (link function)」連接預測值與期望值


1. 廣義線性模型 (Generalized Linear Models, GLM)

GLM 是現代統計建模的基石，它解決了傳統線性迴歸（Linear Regression）無法處理非常態分佈數據（如二元變項或計數資料）的限制。

1.1 核心概念

傳統線性模型（General Linear Model，如 ANOVA、T-test、Regression）其實都只是 GLM 的特例。GLM 放寬了對反應變數（Y）必須服從常態分佈的假設。

1.2 GLM 的三個組成部分

1. **隨機成分 (Random Component)：** 指定反應變數 Y 的機率分佈（來自指數族）。

    ◦ **常態 (Normal)：** 用於連續數據（傳統迴歸）。

    ◦ **二項式 (Binomial)：** 用於二元數據（如存活/死亡、是/否）。

    ◦ **卜瓦松 (Poisson) / 負二項 (Negative Binomial)：** 用於計數數據（如發病次數）。

    ◦ **Gamma：** 用於偏態且恆正的連續數據（如反應時間、費用）。

2. **系統成分 (Systematic Component)：** 線性預測變數 (Linear Predictor)，即 Xβ。

3. **連結函數 (Link Function)：** 將系統成分與隨機成分的期望值（平均數）連結起來的函數。

    ◦ _Identity Link:_ y=Xβ (用於線性迴歸)。

    ◦ _Logit Link:_ ln(p/(1−p))=Xβ (用於 Logistic 迴歸)。

    ◦ _Log Link:_ ln(λ)=Xβ (用於 Poisson 迴歸)。

1.3 限制

GLM 假設觀測值之間是 **獨立且相同分佈 (I.I.D.)** 的。若數據具有相關性（如縱向資料、家庭/學校叢集資料），GLM 會低估標準誤，導致錯誤的統計推論（Type I error 膨脹）。



**GLM = 結果分佈（exponential family） + 線性預測子（systematic component） + 連結函數（link function）**  
依據結果型態選擇分佈，就能統一用 GLM 框架建模各類資料。

│   ├─ 1️⃣ 線性模型是 GLM 的特例
│   │     link = identity, error = normal
│   │
│   ├─ 2️⃣ 常見 GLM 類型：
│   │     • Logistic regression → 二元資料 (Bernoulli)
│   │     • Poisson regression → 計數資料 (Poisson)
│   │     • Gamma regression → 正偏資料 (Gamma)
│   │     • Gamma regression → 正偏資料 (Gamma)
## 📊 GLM 結構公式總覽

GLM 通用形式：

g(E[Y])=β0+β1X1+β2X2+⋯+βpXpg(E[Y]) = \beta_0 + \beta_1 X_1 + \beta_2 X_2 + \cdots + \beta_p X_pg(E[Y])=β0​+β1​X1​+β2​X2​+⋯+βp​Xp​

- g(⋅)g(\cdot)g(⋅)：連結函數
    
- E[Y]E[Y]E[Y]：結果變項的期望值（平均）
    
- β\betaβ：迴歸係數（表示自變項對結果的影響）

glm (x~y, familly= logistic,  data = dataname)

A [GLM](https://bookdown.org/mike/data_analysis/generalized-linear-models.html#generalized-linear-models) consists of three key components:

1. **A random component**: The response variable Yi follows a distribution from the exponential family (e.g., binomial, Poisson, gamma).
2. **A systematic component**: A linear predictor ηi=x′iβ, where x′i is a vector of observed covariates (predictor variables) and β is a vector of parameters to be estimated.
3. **A link function**: A function g(⋅) that relates the expected value of the response variable, μi=E(Yi), to the linear predictor (i.e., ηi=g(μi)).
## 操作流程
1. 確定資料分布
2. 再選定適合的模式


## 🔎 深度剖析：廣義線性模型 ($\text{GLM}$) 的細節

$\text{GLM}$ 的核心思想是將一個模型的結構分解為三個相互獨立的組成部分：**隨機元件 (Random Component)**、**系統元件 (Systematic Component)**，以及將兩者連結起來的**連結函數 (Link Function)**。

### 1. 隨機元件（Random Component / 概率分佈）

隨機元件定義了模型的**因變數 ($Y$) 的概率分佈**，它不再被限定為常態分佈。所有 $\text{GLM}$ 的分佈都必須屬於**指數族分佈（Exponential Family）**。

| **分佈 (Distribution)**          | **因變數類型 (Y 數據)**  | **GLM 範例**                                  |
| ------------------------------ | ----------------- | ------------------------------------------- |
| **常態分佈 ($\text{Normal}$)**     | 連續、對稱             | **線性迴歸 ($\text{Linear Regression}$)**       |
| **伯努利分佈 ($\text{Bernoulli}$)** | 二元 (0/1)          | **邏輯斯迴歸 ($\text{Logistic Regression}$)**    |
| **泊松分佈 ($\text{Poisson}$)**    | 計數 (0, 1, 2, ...) | **泊松迴歸 ($\text{Poisson Regression}$)**      |
| **二項式分佈 ($\text{Binomial}$)**  | 比例/成功次數           | **比例迴歸 ($\text{Proportional Regression}$)** |
| **伽瑪分佈 ($\text{Gamma}$)**      | 連續、正偏、正值          | **伽瑪迴歸 ($\text{Gamma Regression}$)**        |



---

### 2. 系統元件（Systematic Component / 線性預測式）

系統元件是模型中**預測因子的線性組合**，與傳統線性迴歸完全相同。

$$\eta = \beta_0 + \beta_1 X_1 + \beta_2 X_2 + \cdots + \beta_k X_k$$

- $\eta$ ($\text{eta}$) 被稱為**線性預測式（Linear Predictor）**。
    
- $X_i$ 是自變數（預測因子）。
    
- $\beta_i$ 是迴歸係數。
    

**核心概念：** 無論因變數的分佈如何，模型的**自變數效應**永遠是以**線性的方式**組合。

### 3. 連結函數（Link Function）

連結函數 $g(\cdot)$ 是 $\text{GLM}$ 的**核心**，它負責將**因變數的期望值 $\mu$**（屬於隨機元件）連接到**線性預測式 $\eta$**（屬於系統元件）。

$$g(\mu) = \eta = \beta_0 + \beta_1 X_1 + \cdots + \beta_k X_k$$

|**GLM 類型**|**μ=E(Y) 範圍**|**連結函數 g(μ)**|**函數表達式**|**意義 (轉換結果)**|
|---|---|---|---|---|
|**線性迴歸**|$(-\infty, \infty)$|**恆等 ($\text{Identity}$)**|$g(\mu) = \mu$|$\mu$ 直接等於線性預測式|
|**Logistic**|$(0, 1)$|**對數勝算比 ($\text{Logit}$)**|$g(\mu) = \log\left(\frac{\mu}{1-\mu}\right)$|將機率 $\mu$ 轉換到 $(-\infty, \infty)$|
|**Poisson**|$(0, \infty)$|**自然對數 ($\text{Log}$)**|$g(\mu) = \log(\mu)$|將計數 $\mu$ 轉換到 $(-\infty, \infty)$|
|**Gamma**|$(0, \infty)$|**倒數 ($\text{Inverse}$)** 或 $\text{Log}$|$g(\mu) = 1/\mu$ 或 $\log(\mu)$|將正偏 $\mu$ 轉換到適合的範圍|

**核心概念：** 連結函數的目的是確保：

1. 線性預測式 $\eta$ 的範圍（通常是 $-\infty$ 到 $\infty$）與連結後的 $\mu$ 範圍**一致**。
    
2. 模型參數的估計能夠保持**最佳統計特性**（特別是使用**標準連結函數 ($\text{Canonical Link}$)** 時）。


---

### 4. 參數估計與解釋

$\text{GLM}$ 通常不使用最小平方法 ($\text{OLS}$)，而是使用**最大概似估計 ($\text{Maximum Likelihood Estimation, MLE}$)** 來找到最佳的迴歸係數 $\beta$。

|**模型類型**|**核心解釋指標**|**轉換公式**|**實際意義**|
|---|---|---|---|
|**Logistic**|**勝算比 ($\text{OR}$)**|$\text{OR} = e^{\beta}$|$X$ 增加一個單位，結果發生的勝算比變為 $\text{OR}$ 倍。|
|**Poisson**|**發生率比 ($\text{IRR}$)**|$\text{IRR} = e^{\beta}$|$X$ 增加一個單位，事件發生的**發生率**變為 $\text{IRR}$ 倍。|
|**Linear**|**平均差異**|$\text{Coefficient} = \beta$|$X$ 增加一個單位，因變項 $Y$ 的**平均值**增加 $\beta$ 個單位。|




雖然兩者都在尋找變數之間的「關聯性」，但它們有幾個關鍵的差異：

1. **方向性與預測**：相關性只是給出一個數值（例如 -1 到 1）來表示兩個變數一起變動的強度和方向，它不區分誰是因、誰是果。但 GLM 是一種「迴歸（Regression）」分析，它明確區分了「解釋變數（$X$）」和「反應變數（$Y$）」，目的是找出一個**數學方程式**，讓你能夠用 $X$ 去**預測** $Y$ 的具體數值。
2. **處理多變數與控制干擾**：相關性通常只能看兩個變數的一對一關係。而 GLM 可以同時放入多個不同的影響因子（例如：距離、溫度、性別），並評估在「控制其他條件不變」的情況下，單一因子對結果的具體影響。

---

### GLM 還可以拿來做甚麼？

因為 GLM 允許我們改變「機率分佈」和「連結函數」，它幾乎可以應用在各種不符合常態分佈的真實世界數據上。根據來源資料，GLM 常被用來解決以下幾種類型的問題：

#### 1. 預測「發生機率」或「有無」（二元資料 / 邏輯斯迴歸）

當你的結果只有「是/否」、「有/無」、「成功/失敗」時，可以使用搭配**白努利/二項分佈 (Bernoulli/Binomial distribution)** 的 GLM（即邏輯斯迴歸 Logistic Regression）。

- **醫學與公衛研究**：來源中提到一個評估心肌梗塞（心臟病發）風險的研究。GLM 被用來分析女性「是否發生心肌梗塞（1/0）」，並同時探討年齡、是否吸菸、是否使用口服避孕藥等因素的影響。
- **疾病感染預測**：預測野生野豬「是否感染結核病 (Tb)」，並發現野豬的體長越長，感染的機率呈現 S 型曲線的急劇上升。
- **計算勝算比 (Odds Ratio)**：GLM 可以精確算出風險倍數。例如上述心臟病研究中，透過模型可以算出「吸菸者」心臟病發的勝算比是不吸菸者的多少倍。

#### 2. 預測「比例」或「百分比」（比例資料）

當你的資料是某個群體中的發生比例（例如：100 隻動物中有幾隻生病）。

- **生態學群體感染率**：研究不同農場的紅鹿中，感染某種寄生蟲的「比例」是多少，並分析這個比例是否會受到農場環境（如：開放土地百分比、灌木叢百分比、是否設立圍欄）的影響。

#### 3. 預測「發生次數」（計數資料）

當結果是正整數的次數，可以使用搭配**卜瓦松 (Poisson) 或負二項分佈 (Negative Binomial)** 的 GLM。

- **臨床試驗的發作次數**：分析癲癇患者在服用新藥或安慰劑後，在一定時間內「癲癇發作的次數」，並評估新藥是否有顯著降低發作頻率的效果。
- **歷史事件分析**：歷史上著名的「馬踢死人數據」，分析普魯士軍隊在不同年份、不同軍團中，士兵被馬踢死的數量變化。

#### 4. 分析「連續但具偏態」的數值（非負連續資料）

有些連續資料（如時間、成本）永遠是正數，且數值越大時變異也越大，此時可用搭配**伽瑪分佈 (Gamma distribution)** 的 GLM。

- **反應時間測試**：來源舉例了一項血液凝固時間的研究，透過不同濃度的血漿來預測「血液凝固所需的時間（秒）」，因為時間不可能是負數且具偏態，使用 GLM 就能得到比傳統線性迴歸更好的擬合曲線。

### 總結

簡單來說，GLM 不僅僅是算相關。**它是一個強大的預測與解釋工具**。只要你能將問題量化（不管是次數、機率、比例還是偏態時間），GLM 都能幫你：

1. 找出到底哪些變數是真的有影響的（提供 p 值與信賴區間）。
2. 給出一個預測公式，讓你未來只要輸入條件（例如：50歲、吸菸、不吃藥），就能算出具體的預期結果（例如：25% 的心臟病發機率）。