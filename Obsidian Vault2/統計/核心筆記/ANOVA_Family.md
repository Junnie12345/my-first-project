# 變異數分析 (ANOVA Family)

> 🔗 返回：[[2. Statistical_Models_Map]]
> 📌 相關：[[Traditional_ANCOVA]] | [[MANOVA_MANCOVA]] | [[Repeated_Measures_ANOVA]]

---

## 一、ANOVA / ANCOVA / MANOVA 比較總覽

| **模型名稱 (R 函數)**     | **變異數分析 (ANOVA)**                                | **共變數分析 (ANCOVA)**                           | **多變量變異數分析 (MANOVA)**                           |
| ------------------- | ------------------------------------------------ | -------------------------------------------- | ----------------------------------------------- |
| **定義 (目標)**         | 檢測**單個**或**多個**類別自變項 (因子/組別) 對**單個**連續依變項平均數的影響。 | 在 ANOVA 的基礎上，加入**連續共變量**來控制混淆變數的影響，以提高統計檢定力。 | 檢測**單個**或**多個**類別自變項對**多個**連續依變項**整體組合**平均數的影響。 |
| **依變項數量**           | **單個** (連續型)                                     | **單個** (連續型)                                 | **多個** (連續型)                                    |
| **自變項類型**           | 類別型 (因子 / Group)                                 | 類別型 (因子 / Group)                             | 類別型 (因子 / Group)                                |
| **共變量 (Covariate)** | **無**                                            | **有** (連續型，用來調整)                             | **無** (若有，則為 MANCOVA)                           |
| **R 常用函數**          | `aov()` 或 `lm()`                                 | `lm()`                                       | `manova()`                                      |
| **核心假設**            | 殘差常態分佈、變異數同質性 (Homogeneity of Variance)。         | 除了 ANOVA 假設，還需要**迴歸斜率同質性**。                  | 除了 ANOVA 假設，還需要**變異數-共變異數矩陣同質性**。               |
| **與迴歸關係**           | 是 **GLM (Gaussian Family)** 的特例。                 | 是 **多元線性迴歸 (MLR)** 的特例。                      | 相當於對多個依變項同時執行 MLR。                              |

---

## 二、ANOVA 的本質（訊號雜訊比）

**「我們觀察到的數據差異（Total Variance），有多少是因為我們的實驗操弄（Effect/Signal），又有多少只是隨機誤差（Error/Noise）？」**

1. **SST (Total Sum of Squares - 總變異):** 數據裡的總波動。
2. **SSB (Between-group - 組間變異):** 「實驗組」跟「對照組」的差別。這是你要的 **Signal**。
3. **SSW (Within-group - 組內變異):** 同一組受試者內部每個人的差異。這是你無法控制的 **Noise**。

**F 值 (F-ratio) 就是訊號雜訊比：**

$$F = \frac{\text{Signal (組間差異)}}{\text{Noise (組內差異)}}$$

- 如果 F 很大，代表實驗操弄的效果蓋過了隨機雜訊 -> **顯著**。
- 如果 F 很小，代表你的操弄效果被淹沒在個體差異的雜訊裡了 -> **不顯著**。

---

## 三、Type I / II / III Sum of Squares

### 檢定類型總覽

|**檢定類型**|**變異歸屬原則**|**適用情境**|**R 程式碼 (套件)**|
|---|---|---|---|
|**Type I (順序/階層)**|檢測某項時，**不控制**其在公式中**之後**的變數，但控制**之前**的變數。 (順序性貢獻)|僅適用於：1. **平衡設計** (所有 Type 相同)。2. **單純迴歸** 或**有明確理論順序**的模型。|`anova(lm(...))` (R 內建)|
|**Type II (階層/主效應)**|檢測某項主效應時，**控制**所有**其他主效應**，但**不控制**該項的**高階交互作用項**。 (假設無交互作用)|適用於：1. **無顯著交互作用**的 ANOVA/ANCOVA 模型。2. **只有主效應**的模型。|`Anova(..., type = "II")` (`car` 套件)|
|**Type III (邊緣/獨特)**|檢測某項時，**控制**模型中**所有其他項** (包括所有交互作用)。 (獨特邊緣貢獻)|**適用於：** 1. **ANCOVA** (確保共變量被調整)。2. 存在**顯著交互作用**的模型。3. **不平衡設計**。|`Anova(..., type = "III")` (`car` 套件)|

### 圖解比喻：聚光燈下的舞台

想像舞台上有兩個演員 A 和 B，以及一盞聚光燈（總變異量）。

- **Type I (偏心導演):** 導演喊「A 先來！」，A 的影子連同重疊部分都算 A 的。B 只能算剩下沒重疊的影子。
- **Type II (和平主義者):** 導演說「你們只比誰的主體影子大，重疊的部分先不管，假設你們沒有互動（交互作用）。」
- **Type III (嚴格裁判 - SPSS):** 導演說「重疊的通通不算！A 只能算完全乾淨的 A 影子，B 只能算完全乾淨的 B 影子。」

### 何時分別使用？

#### Type I SS：用於「階層迴歸」或「多項式分析」

當變數進入模型的**順序具有強烈的理論意義**時，必須用 Type I。

- **情境 A：多項式回歸** — 模型 `y ~ x + x^2 + x^3`，順序不能動。
- **情境 B：控制變項的階層分析** — 先讓「年齡」把變異量吃光，剩下的殘渣如果「新療法」還能顯著，那才是真的厲害。

#### Type II SS：用於「模型篩選」或「檢定力最佳化」

如果你跑了 Type III，發現交互作用項的 p 值是 0.85（超級不顯著），Type II 對主效應的檢定力比 Type III 更強。

#### Type III SS：社科與生醫領域的「預設值」

最保守，不管順序怎麼放，結果都一樣。SPSS、SAS、Stata 預設使用。

---

## 四、R 語言實作

### 基本 ANOVA (Base R)
```r
summary(aov(Score ~ Group * Time, data = df))
```

### 進階 ANOVA：`afex` (推薦)
```r
library(afex)

model_anova <- aov_ez(
  id = "Subject_ID",
  dv = "PS150_Score",
  data = df,
  between = "Group",
  within = "Time_Point"
)

model_anova
```

### Type II / III (使用 `car` 套件)
```r
library(car)
model <- lm(Score ~ Group * Time, data = df)

# Type II
Anova(model, type = 2)

# Type III (需先設定對比)
options(contrasts = c("contr.sum", "contr.poly")) 
Anova(model, type = 3)
```

### 事後比較：`emmeans`
```r
library(emmeans)
emmeans(model_anova, specs = pairwise ~ Group | Time)
emmeans(model_anova, list(pairwise ~ factor_name), adjust = "tukey")
```

---

## 五、參考連結

- [[Traditional_ANCOVA]] — ANCOVA 詳細說明
- [[MANOVA_MANCOVA]] — 多變量變異數分析
- [[Repeated_Measures_ANOVA]] — 重複測量 ANOVA 與球形檢定
