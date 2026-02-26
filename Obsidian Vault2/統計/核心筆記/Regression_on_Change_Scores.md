# 改變量迴歸 (Regression on Change Scores) 🌟

> 🔗 返回：[[2. Statistical_Models_Map]]
> 📌 相關：[[Traditional_ANCOVA]] | [[Simple_Multiple_Regression]]

---

## 一、定義

前/後測黃金標準分析法。數學上與 ANCOVA 等價。

- **依變項**為「差值 (Post - Pre)」
- 在模型中**控制前測分數**（控制基期效應）
- 可額外加入其他動態改變量（如 $\Delta MEQ$）來探討機轉

---

## 二、公式

$$\Delta Y = \beta_0 + \beta_1 \cdot \text{Group} + \beta_2 \cdot \Delta X + \beta_3 \cdot Y_{\text{pre}} + \epsilon$$

其中：
- $\Delta Y = Y_{\text{post}} - Y_{\text{pre}}$（目標量表改變量）
- $\Delta X = X_{\text{post}} - X_{\text{pre}}$（控制變項改變量）
- $Y_{\text{pre}}$（基線值，控制基期效應）

---

## 三、適用情境

- 只有兩個時間點（前測、後測）
- 想驗證組別效果是否顯著
- 想同時探討某個中介/控制變項的動態變化

---

## 四、R 語言實作

（待補充）

---

## 五、結果解讀

- 看 **Group** 的 $\beta$ 與 p-value：在控制了基線與其他改變量後，組別是否仍有顯著差異
- 看 $\Delta X$ 的 $\beta$：控制變項的變化是否與目標量表的變化相關

範例:
|Target_Outcome|Control_Variable|Formula|Term|
|PSQI|MEQ|Delta_PSQI ~ Group + Delta_MEQ + PSQI_pre|Intercept|
|PSQI|MEQ|Delta_PSQI ~ Group + Delta_MEQ + PSQI_pre|Group (B vs A)|
|PSQI|MEQ|Delta_PSQI ~ Group + Delta_MEQ + PSQI_pre|Delta_MEQ|
|PSQI|MEQ|Delta_PSQI ~ Group + Delta_MEQ + PSQI_pre|Baseline_PSQI|

### 1. Intercept (截距)
- **精確修正：** 在多元回歸中，截距的嚴格定義是 **「當模型中所有自變數都等於 0 時，依變數（$\Delta Outcome$）的預期值」**。
    
- **套用在您的數據：** 這裡的 Intercept 代表的是：如果有一個病人，他是 **Group A**（通常 A 是對照組/基準組，所以 Group=0），且他的 **$\Delta MEQ$ 是 0**（作息完全沒變），而且他的 **前測基線分數 (Baseline_pre) 也是 0**，那麼預期他的 $\Delta PSQI$ 會改變 `4.1411` 分。
    
- **臨床解讀：** 在臨床數據中，Baseline 分數為 0 通常不太可能發生（或沒有意義），因此我們通常**不會去解釋 Intercept 的 p-value 或 Estimate**。它只是數學上固定回歸線的一個錨點，您在寫 Paper 時可以直接忽略它。

### 2. Group (B vs A) (組別效應)

- **精確修正：** 這代表 **「在擁有相同前測分數，且 MEQ 改變量也相同的情況下，Group B 的 $\Delta Outcome$ 比 Group A 高/低多少」**。
    
- **套用在您的數據：** 以 PSQI 為例，Estimate 是 `0.76`，p-value 是 `0.202` (ns)。
    
- **臨床解讀：** 這表示在控制了基線分數和作息改變量之後，Group B 和 Group A 在睡眠品質的改善上**沒有統計上的顯著差異**。事實上，您這四個模型（PSQI, ISI, BDI, BAI）中，Group 的 p-value 都不顯著。

### 3. Delta_MEQ ($\Delta$ MEQ 改變量)

- **解答：** 這是您這個分析的**靈魂核心**！它代表 **「作息偏好的改變，是否能獨立預測臨床症狀的改變」**（斜率）。
    
- **套用在您的數據：**
    
    - 在 **PSQI, ISI, BAI** 模型中，Delta_MEQ 的 p-value 都不顯著 (ns)。這代表 MEQ 的改變並沒有顯著帶動這三項分數的改變。
        
    - **亮點來了！** 在 **BDI (憂鬱)** 模型中，Delta_MEQ 的 Estimate 是 `-0.2317`，p-value 是 `0.0395` (*)。
        
- **臨床解讀 (以 BDI 為例)：** 在控制了組別和前測憂鬱分數後，**病人的 $\Delta MEQ$ 每增加 1 分（可能代表越偏向某種作息，需確認您的問卷計分方向），他的 $\Delta BDI$ 就會下降 0.2317 分**。這代表作息的調整確實與憂鬱症狀的改善有顯著的線性關聯！