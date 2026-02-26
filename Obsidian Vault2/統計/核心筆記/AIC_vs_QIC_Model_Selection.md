# 📊 模型選擇準則：AIC vs. QIC (Model Selection Criteria)

## 📌 TL;DR (核心總結)

兩者的共同目標都是實踐「奧卡姆剃刀 (Occam's razor)」原則：在**「模型配適度 (Goodness of fit)」**與**「模型複雜度 (Model complexity)」**之間取得最佳平衡。**數值越小，代表模型越佳。**

- **用完整的機率模型 (如 [[GLM (Generalized Linear Model)]], [[LMM_Linear_Mixed_Model]], [[GLMM_Generalized_Linear_Mixed_Model]])** $\rightarrow$ 看 **AIC**。
    
- **用邊際模型/無完整概似函數 (如 [[GEE_Generalized_Estimating_Equations]])** $\rightarrow$ 看 **QIC**。
    

---

## 一、 AIC (Akaike Information Criterion, 赤池信息準則)

### 💡 核心原理

- 基於資訊理論中的「預期 Kullback-Leibler 訊息遺失量」。
    
- **數學公式：** $AIC = -2 \times \ln(L) + 2k$
    
    - $L$ (Likelihood): 最大對數概似值（衡量配適度）。
        
    - $k$ (Parameters): 參數數量（作為複雜度的懲罰項 Penalty，避免 Overfitting）。
        

### ✅ 優勢 (Pros)

1. **廣泛且通用：** 適用於各種具備完整機率分佈假設的模型，且不要求模型之間必須是巢狀關係 (Non-nested models) 即可比較。
    
2. **軟體支援度極高：** R (`AIC()` 函數)、SAS、SPSS 等主流軟體皆內建，隨插即用。
    
3. **多模型推論 (Multimodel Inference)：** 可計算 Akaike Weights，量化各模型的相對支持機率，進而進行「多模型平均 (Model Averaging)」，在處理模型不確定性時非常強大。
    

### ❌ 劣勢與陷阱 (Cons)

1. **致命傷：依賴「真實概似函數 (True Likelihood)」**。若模型沒有完整機率分佈假設（如準卜瓦松模型 Quasi-Poisson 或 [[GEE_Generalized_Estimating_Equations]]），就無法計算傳統 AIC。
    
2. **⚠️ 混合模型的 ML vs. REML 陷阱：** 在 [[LMM]] 中，若要比較「不同固定效應 (Fixed effects)」的模型，**絕對不能**使用預設的 REML 算出的 AIC 互比，必須改用 ML (Maximum Likelihood) 重新配適後才能比較。
    

---

## 二、 QIC (Quasi-likelihood under the Independence model Criterion)

### 💡 核心原理

- 由 Pan (2001) 專為 [[GEE]] (廣義估計方程式) 量身打造的改良版 AIC。
    
- 因為 GEE 不是 Likelihood-based，QIC 改用**「獨立工作相關矩陣假設下的準概似函數 (Quasi-likelihood under the independence 'working' correlation assumption)」** 來估算 KL 差異，並同樣加上參數懲罰項。
    

### ✅ 優勢 (Pros)

1. **拯救 GEE 模型的救星：** 填補了 GEE 無法使用傳統訊息準則進行模型比較的學術空白。
    
2. **「雙重選擇」超能力：** QIC 允許研究者在 GEE 中**同時決定**兩件事：
    
    - 最佳的解釋變數組合 (Covariates)。
        
    - 最佳的「工作相關矩陣結構 (Working Correlation Structure)」（例如：該用 AR-1 還是 Unstructured）。
        

### ❌ 劣勢 (Cons)

1. **結構區別力有限：** 研究顯示，QIC 在區分「獨立 (Independent)」與「可交換 (Exchangeable)」相關結構時表現較遲鈍，有時不同結構會得出相同的迴歸參數估計值。
    
2. **對平均值結構過度敏感：** 單純只想挑選「相關矩陣結構」時，QIC 容易受到平均值結構干擾。此時改看 **CIC (Correlation Information Criterion)** 會更精確。
    
3. **軟體普及度較低：** R 的 `geepack` 預設不輸出 QIC，通常需要額外安裝套件（如 `MuMIn::QIC` 或自行寫 code）才能呼叫出來；且部分較傳統的 Reviewer 可能對 QIC 較不熟悉。
    

---

## 🎯 實戰決策指南 (Decision Matrix)

| **模型類型**                | **機率分佈假設**              | **估計方法**               | **該看哪個指標？** | **R 語言常用套件/語法**           |
| ----------------------- | ----------------------- | ---------------------- | ----------- | ------------------------- |
| **一般線性模型 ([[GLM]])**    | 完整 (如 Normal, Binomial) | ML                     | **AIC**     | `AIC(model)`              |
| **線性混合模型 ([[LMM]])**    | 完整                      | ML / REML              | **AIC**     | `lme4::lmer`, `nlme::lme` |
| **廣義線性混合模型 ([[GLMM]])** | 完整                      | ML/ Laplace            | **AIC**     | `lme4::glmer`             |
| **廣義估計方程式 ([[GEE]])**   | **無 (僅給定均值與變異數關係)**     | 準概似 (Quasi-likelihood) | **QIC**     | `MuMIn::QIC(model)`       |