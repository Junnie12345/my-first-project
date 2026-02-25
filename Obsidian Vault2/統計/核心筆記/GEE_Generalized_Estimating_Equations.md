# 廣義估計方程式 (GEE)

> 🔗 返回：[[2. Statistical_Models_Map]]
> 📌 相關：[[LMM_Linear_Mixed_Model]] | [[GLMM_Generalized_Linear_Mixed_Model]]

---

## 一、核心定義

GEE 是 GLM 對縱向或叢集數據的延伸，由 Liang & Zeger (1986) 提出。它不試圖模擬每個個體的具體變化，而是估計**母體平均 (Population-Averaged, PA)** 的效應。

### 理論重點

- **母體平均觀點 (Population-Averaged Perspective)**：GEE 是一種「邊際模型 (Marginal Model)」。重點在於模擬整個母體的平均反應如何隨時間或協變量變化。
- **不需要完整的機率分佈**：僅需指定邊際分佈的前兩階動差：平均值模型和變異數模型。
- **工作相關矩陣 (Working Correlation Matrix)**：處理重複測量資料中的相依性。
- **穩健性 (Robustness)**：即使「工作相關矩陣」設定錯誤，透過「三明治估計量」仍然可以得到一致估計量。

---

## 二、運作機制

- **將相關性視為干擾 (Nuisance)：** GEE 關注的是 X 如何影響總體 Y，而非個體內部的變化。
- **作業相關矩陣 (Working Correlation Matrix)：** 使用者需指定一個相關結構：

| **corstr 選項** | **假設** | **適用情境** |
|---|---|---|
| `"independence"` | 同一受試者內觀測彼此獨立 | 最簡單，但常不合理 |
| `"exchangeable"` | 群內任兩點相關性相同 ρ | 不在乎時間順序的情境 |
| `"ar1"` | 相鄰時間點相關性最大，隨距離遞減 | 時間序列或週數連續的實驗 |
| `"unstructured"` | 每一對時間點都有不同的相關性 | 資料量大時才建議 |

---

## 三、穩健性 (三明治估計量)

GEE 的最大優勢在於使用 **三明治估計量 (Sandwich Estimator / Robust Standard Error)**。

- 即使選錯了作業相關矩陣，只要平均數模型正確，GEE 估計出的係數 β 仍然是**一致的 (Consistent)**。
- 三明治估計量會修正標準誤，確保推論有效。

---

## 四、模型複雜度階層

| **模型** | **公式** |
|---|---|
| 基本模型 | `outcome ~ week + group` |
| 協變數模型 | `outcome ~ week + group + gender + age` |
| 交互作用模型 | `outcome ~ week * group + gender + age` |
| 完整模型 | `outcome ~ week * group + week * gender + week * age` |

**星號** `*` 代表包含主效應與交互作用：
$$\text{week} * \text{group} = \text{week} + \text{group} + \text{week}:\text{group}$$

---

## 五、協變數處理策略

### 年齡處理
- 自動中心化 (減去平均數)
- 如果年齡跨度大，可選擇分組

### 性別處理
- 標準化為 "female"/"male"
- 轉為因子變數

### 協變數選擇原則
1. **不宜過多**: 建議協變數數量 < 樣本數/10
2. **理論相關**: 選擇與結果變數相關的變數
3. **基線測量**: 使用基線值，而非時間變動的變數

---

## 六、模型選擇

**QIC (Quasilikelihood Information Criterion)**：用於模型擬合優度檢驗的準則，數值越小越好。

---

## 七、R 語言實作

### SPSS 對應 R 指令

|**SPSS 選項**|**R (geepack::geeglm) 對應**|**範例程式**|
|---|---|---|
|**尺度回應 (Scale response)**|`family = gaussian(link = "identity")`|`geeglm(y ~ week, ..., family = gaussian)`|
|**個數 (Poisson)**|`family = poisson(link = "log")`|`geeglm(count ~ week, ..., family = poisson)`|
|**二元回應 (Binary)**|`family = binomial(link = "logit")`|`geeglm(success ~ week, ..., family = binomial)`|
|**Subjects (受試者編號)**|`id = ID`|`geeglm(..., id = ID, ...)`|
|**Correlation structure**|`corstr = "exchangeable"` / `"ar1"`|`geeglm(..., corstr = "ar1")`|
|**QIC**|`QIC(fit)`|`QIC(fit)`|

```r
library(geepack)

# GEE 基本模型
fit <- geeglm(
  outcome ~ week * group + gender + age,
  id = ID,
  data = df_long,
  family = gaussian,
  corstr = "ar1"
)
summary(fit)
QIC(fit)
```

---

## 八、GEE vs. Mixed Models

| 方法 | 關注焦點 | 模型假設 | 適用情境 |
|------|----------|----------|----------|
| GEE | 平均效應 (Population-level) | 關聯結構 (Robust) | 大樣本、公衛政策評估 |
| LMM/GLMM | 個體效應 (Subject-specific) | 隨機效應分布 | 小樣本、精準醫療、腦科學 |

---

## 九、適用情境

- 流行病學研究，關注整體政策或治療對大眾的平均影響
- 不希望依賴強烈的分布假設時
- 需注意：GEE 需要足夠數量的群集（Cluster > 40）才能保證標準誤準確
