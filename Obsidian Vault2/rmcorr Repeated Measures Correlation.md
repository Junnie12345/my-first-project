重複測量相關 (Repeated Measures Correlation, rmcorr)

一、定義

連續因變項。探索在多個個體（participants）於兩個或多個時間點/情境下的重複測量中，兩個連續變數之間的「**共同個體內線性關聯（common within-individual association）**」,。

相較於一般多元迴歸（Y=β0​+β1​X1​+β2​X2​+⋯+βk​Xk​+ϵ），`rmcorr` 本質上是透過共變數分析（ANCOVA）來控制「個體差異」這個類別變數。其數學模型可表示為： Measure1ij​=Measure1j​+Participantj​+β(Measure2ij​−Measure2j​)+ϵij​ 其中：

- Measure1ij​ 與 Measure2ij​ 分別為第 j 個參與者在第 i 次測量時的兩個連續變數。
- Measure1j​ 與 Measure2j​ 為第 j 個參與者的個別平均值。
- Participantj​ 是代表不同參與者的虛擬變數（控制個體間變異）。
- β 是共同的迴歸斜率（整體斜率）。
- ϵij​ 為殘差。

--------------------------------------------------------------------------------

二、核心概念

- **隔離個體內變異 (Intra-individual Association)：** 傳統的 Pearson 相關或簡單線性迴歸假設觀察值必須完全獨立 (IID)；若將重複測量資料直接平均或聚合 (aggregated) 後做相關，會流失資料且可能產生偏判。`rmcorr` 透過消除「個體間 (between-participants)」的變異，專注於估計兩個變數在「個體內 (within-participants)」的共同關聯,。
- **平行斜率與變動截距 (Parallel Slopes and Varying Intercepts)：** `rmcorr` 會為每一個參與者配適一條迴歸線。這些迴歸線被假設具有**相同的斜率（平行線）**，但允許每個參與者有**不同的截距**。
- **相關係數** rrm​ **與檢定力：** `rmcorr` 的相關係數值界於 -1 到 1 之間，其正負號由共同斜率 β 決定,。計算公式為基於 ANCOVA 的離均差平方和 (SS)： rrm​=SSMeasure​+SSError​SSMeasure​​![](data:image/svg+xml;utf8,<svg%20xmlns="http://www.w3.org/2000/svg"%20width="400em"%20height="2.48em"%20viewBox="0%200%20400000%202592"%20preserveAspectRatio="xMinYMin%20slice"><path%20d="M424,2478%0Ac-1.3,-0.7,-38.5,-172,-111.5,-514c-73,-342,-109.8,-513.3,-110.5,-514%0Ac0,-2,-10.7,14.3,-32,49c-4.7,7.3,-9.8,15.7,-15.5,25c-5.7,9.3,-9.8,16,-12.5,20%0As-5,7,-5,7c-4,-3.3,-8.3,-7.7,-13,-13s-13,-13,-13,-13s76,-122,76,-122s77,-121,77,-121%0As209,968,209,968c0,-2,84.7,-361.7,254,-1079c169.3,-717.3,254.7,-1077.7,256,-1081%0Al0%20-0c4,-6.7,10,-10,18,-10%20H400000%0Av40H1014.6%0As-87.3,378.7,-272.6,1166c-185.3,787.3,-279.3,1182.3,-282,1185%0Ac-2,6,-10,9,-24,9%0Ac-8,0,-12,-0.7,-12,-2z%20M1001%2080%0Ah400000v40h-400000z"></path></svg>)​ 因為保留了同一受試者的重複測量次數，`rmcorr` 具有比單純將資料平均後做 Pearson 相關**高出許多的統計檢定力 (Statistical Power)**,。
- **自由度 (Degrees of Freedom)：** 檢定 rrm​ 顯著性的精確自由度為 N(k−1)−1（其中 N 為總參與者人數，k 為平均重複測量次數）,。
- **對線性轉換免疫：** 和 Pearson 相關一樣，對所有資料或單一個體資料進行線性轉換（加減乘除），都不會改變 rrm​ 的數值。

--------------------------------------------------------------------------------

三、R 語言實作

在 R 語言中，可以使用專門的 `rmcorr` 套件來進行運算與視覺化。

**1. 安裝與載入套件：**

```
install.packages("rmcorr")
library(rmcorr)
```

**2. 計算重複測量相關：** 使用 `rmcorr()` 函數，需指定受試者 ID 變數、兩個要測量的連續變數，以及資料集名稱。

```
# 假設 dataset 為 mydata，包含 SubjectID, VarX, VarY 三個欄位
my_rmc <- rmcorr(participant = SubjectID, measure1 = VarX, measure2 = VarY, dataset = mydata)

# 檢視結果 (包含 rmcorr 係數、自由度、95%信賴區間、p-value)
print(my_rmc)
```

**3. 視覺化 (Rmcorr Plot)：** 使用 `plot()` 函數會自動呼叫 `plot.rmc`，畫出每個受試者專屬顏色及對應的平行迴歸線。

```
plot(my_rmc, dataset = mydata, overall = FALSE, lty = 2, 
     xlab = "變數 X 名稱", ylab = "變數 Y 名稱")
# overall = TRUE 可以在圖中額外加上一條「忽略資料相依性」的簡單線性迴歸線作為對比 [13]
```

--------------------------------------------------------------------------------

四、適用情境與注意事項

- **適用情境：** 特別適合用於縱向資料 (Longitudinal data) 或受試者內設計 (Within-subjects design)，當研究問題聚焦於探討「同一個人在變數 X 改變時，變數 Y 是否會跟著改變」的共同線性趨勢時,。
- **解決「辛普森悖論 (Simpson's Paradox)」：** 有些資料在個體層次 (intra-individual) 和群體層次 (inter-individual) 會呈現完全相反的趨勢。直接把資料聚合可能得出錯誤結論，`rmcorr` 以及其散佈圖能幫助正確解讀這種非遍歷性 (non-ergodic) 資料的真實關係,,。
- **與多層次模型 (Multilevel Modeling, MLM) 的權衡：** `rmcorr` 概念上等同於一個「隨機截距但固定斜率 (Null multilevel model)」的簡單多層次模型,。
    - **優點：** 需求資料量較少、容易操作與解釋,。
    - **限制：** `rmcorr` 只能評估個體內的變異。如果研究需要同時分析個體內與個體間的變異，或者預期每個受試者的斜率差異極大而需要配適「隨機斜率 (Varying slopes)」，則 `rmcorr` 無法取代多層次模型 (MLM),。
- **基本假設：** 除了放寬了「觀察值獨立性」之外，`rmcorr` 仍須滿足一般線性模型 (GLM) 的基本假設：包含線性關係、殘差呈常態分佈且變異數同質,。此外，模型隱含了「平行斜率」的假設，如果個體間的關係異質性過大（每個人斜率方向都不同），計算出的共同效應量可能會接近於零而失去意義,。