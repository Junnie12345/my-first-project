3. 廣義估計方程式 (Generalized Estimating Equations, GEE)

廣義估計方程式 (Generalized Estimating Equations, GEE)

**理論重點：**

• **母體平均觀點 (Population-Averaged Perspective)**：GEE 是一種「邊際模型 (Marginal Model)」。它的重點在於模擬整個母體的平均反應 (mean response) 如何隨時間或協變量變化，而不是針對特定個體進行模擬,,。

• **不需要完整的機率分佈**：GEE 不需要指定資料的完整多元機率分佈（如多元常態分佈）。它僅需指定邊際分佈的前兩階動差：平均值模型 (mean model) 和變異數模型 (variance structure),。

• **工作相關矩陣 (Working Correlation Matrix)**：為了處理重複測量資料中的相依性，GEE 引入了「工作相關矩陣」（例如：可交換的/複合對稱、自迴歸 AR-1、無結構等）,。

• **穩健性 (Robustness)**：GEE 的一個核心優勢是，即使「工作相關矩陣」設定錯誤，只要樣本數 (m) 足夠大，透過「三明治估計量 (Sandwich Estimator)」或稱「穩健變異數估計量」，仍然可以得到迴歸參數 (β) 的一致估計量和有效的標準誤,,。

**應用重點：**

• **適用情境**：特別適用於非由常態分佈組成的縱向資料（如計數資料、二元資料），且主要研究興趣在於評估協變量對「整個群體平均值」的影響，而非個體差異,,。

• **參數解釋**：在非線性連結函數（如 Logistic 迴歸）中，GEE 的參數解釋為「母體平均」的變化。例如，某藥物對整個群體平均而言的勝算比 (Odds Ratio),。

• **樣本要求**：GEE 依賴大樣本理論，因此在受試者數量 (m) 較多，但每個受試者的測量次數 (n) 相對較少時表現最佳



3.1 核心定義

GEE 是 GLM 對縱向或叢集數據的延伸，由 Liang & Zeger (1986) 提出。它不試圖模擬每個個體的具體變化，而是估計**母體平均 (Population-Averaged, PA)** 的效應。

3.2 運作機制

• **將相關性視為干擾 (Nuisance)：** GEE 關注的是 X 如何影響總體 Y，而非個體內部的變化。

• **作業相關矩陣 (Working Correlation Matrix)：** 使用者需指定一個相關結構來「猜測」資料內部的關聯性。

    ◦ _Independent:_ 假設無相關。

    ◦ _Exchangeable:_ 假設群內任兩點相關性相同（適合家庭/學校資料）。

    ◦ _AR-1 (Auto-regressive):_ 距離越近相關性越高（適合時間序列）。

    ◦ _Unstructured:_ 估計所有可能的相關性（需較大樣本）。

3.3 穩健性 (Robustness)

GEE 的最大優勢在於使用 **三明治估計量 (Sandwich Estimator / Robust Standard Error)**。

• 即使你選錯了作業相關矩陣（例如假設是 Independent 但其實是 AR-1），只要平均數模型（迴歸公式）是正確的，GEE 估計出的係數 β 仍然是**一致的 (Consistent)**。

• 三明治估計量會修正標準誤，確保推論有效。

3.4 適用情境

• 流行病學研究，關注整體政策或治療對大眾的平均影響。

• 不希望依賴強烈的分布假設時。

• 需注意：GEE 需要足夠數量的群集（Cluster > 40）才能保證標準誤準確。
### 1. 模型複雜度階層

- **基本模型**: `outcome ~ week + group`
- **協變數模型**: `outcome ~ week + group + gender + age`
- **交互作用模型**: `outcome ~ week * group + gender + age` (week group主要變量可能有交互作用用*，加上協變量)
- **完整模型**: `outcome ~ week * group + week * gender + week * age` (視樣本數而定)

**星號** * 代表包含主效應與交互作用
+號為協變量
$$\text{week} * \text{group} = \text{week} + \text{group} + \text{week}:\text{group}$$
$$\text{outcome} \sim (\text{week} + \text{group} + \text{week}:\text{group}) + (\text{week} + \text{gender} + \text{week}:\text{gender}) + (\text{week} + \text{age} + \text{week}:\text{age})$$

個別去做主效應與交互作用


### 2. 協變數處理策略

**年齡處理**：

- 自動中心化 (減去平均數)
- 如果年齡跨度大，可選擇分組

**性別處理**：

- 標準化為 "female"/"male"
- 轉為因子變數

### 3. 基線特徵平衡檢查

程式會自動檢查各組的協變數分布是否平衡，這對雙盲試驗很重要。

## 實際優點

### 1. 統計精確度提升

- 控制協變數後，組別效果的估計更準確
- 減少殘差變異，提高檢定力

### 2. 偏誤控制

- 即使隨機分組，仍可能有不平衡
- 協變數調整可以控制這些潛在混淆

### 3. 結果解釋

所有的組別比較都是「調整性別和年齡後」的效果，更有說服力。

## 使用建議

### 協變數選擇原則：

1. **不宜過多**: 建議協變數數量 < 樣本數/10
2. **理論相關**: 選擇與結果變數相關的變數
3. **基線測量**: 使用基線值，而非時間變動的變數

### 常用協變數：

- 人口學: 性別、年齡、教育程度
- 基線特徵: 基線嚴重程度、BMI
- 其他: 藥物使用史、共病情況

# 模型選擇
The quasilikelihood information criterion (QIC): 用于模型擬合優度檢驗的準則，數值越小越好
## 常見的 corstr 選項 (Marix)

- **`"independence"`**
    
    - 假設同一受試者內的觀測彼此獨立。
        
    - 最簡單，但常常不合理。
        
    - 如果相關性真的存在，這會低估 SE → Type I error 上升。
        
- **`"exchangeable"`（compound symmetry）**
    
    - 假設同一受試者內所有測量都有 **相同的相關係數 ρ**。
        
    - 適合「不在乎時間順序，只認為受試者內相關性一樣」的情境。
        
    - 在睡眠研究這種 weekly measure，有時候可以接受。
        
- **`"ar1"`（first-order autoregressive）** 自回歸
    
    - 假設同一受試者內，相鄰時間點相關性最大，隨時間距離遞減。
        
    - 在時間序列或週數連續的實驗裡，這通常比較合理。
        
    - 例如 week 1 vs week 2 相關性大於 week 1 vs week 4。
        
- **`"unstructured"`（部分實作）**
    
    - 每一對時間點都有不同的相關性，最自由但參數多。
        
    - 資料量大時才建議用，小樣本會不穩定。

|**SPSS 選項**|**意義**|**R (geepack::geeglm) 對應**|**範例程式**|
|---|---|---|---|
|**依變數 (Dependent variable)**|要解釋的結果變數|`formula = y ~ ...` 左邊|`geeglm(y ~ week, ...)`|
|**尺度回應 (Scale response)**|連續資料 (常態)|`family = gaussian(link = "identity")`|`geeglm(y ~ week, ..., family = gaussian)`|
|**個數 (Poisson)**|計數資料|`family = poisson(link = "log")`|`geeglm(count ~ week, ..., family = poisson)`|
|**二元回應 (Binary)**|成功/失敗|`family = binomial(link = "logit")`|`geeglm(success ~ week, ..., family = binomial)`|
|**次序回應 (Ordinal)**|有序分類 (低/中/高)|R GEE 沒內建 → 用 `multgee::ordLORgee()`|`ordLORgee(y ~ week, id = ID, ...)`|
|**連結函數 (Link function)**|SPSS 提供 log / logit / identity|`family = ... (link = "...")`|`binomial(link = "logit")`|
|**Subjects (受試者編號)**|個體識別|`id = ID`|`geeglm(..., id = ID, ...)`|
|**Within-subject variable**|重複測量的時間/條件|自變數 (右邊公式)|`y ~ week`|
|**Correlation structure**|重複測量相關假設|`corstr = "exchangeable"` / `"ar1"` / `"independence"`|`geeglm(..., corstr = "ar1")`|
|**Factors (因子)**|類別變數|轉成 `factor()`|`geeglm(y ~ week + group, ...)`|
|**Covariates (共變量)**|連續變數|直接當數值變數|`geeglm(y ~ week + age, ...)`|
|**主效應 (Main effects)**|變數的單獨效應|模型公式|`y ~ week + group`|
|**交互作用 (Interaction)**|變數交互影響|`*` 或 `:`|`y ~ week * group`|
|**巢狀效果 (Nested effects)**|多層次結構|GEE 無法 → 改用混合模型 (lme4::lmer)|`lmer(y ~ week + (1|
|**QIC**|模型適配度指標 (類似 AIC)|`QIC(fit)`|`QIC(fit)`|


1. 連續變數 (continuous): - 保持 numeric 格式 - 考慮中心化 (age, BMI 等) - 檢查分布和極值 2. 名目變數 (nominal): - 使用 as.factor() - 設定合理的參照組 3. 順序變數 (ordinal): - 少數水準: ordered() - 多數水準: 視為 numeric - 考慮線性/二次趨勢 4. 二分變數 (binary): - 使用 as.factor() - 確保只有兩個水準