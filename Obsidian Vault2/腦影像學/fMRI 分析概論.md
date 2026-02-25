
## 🧠 一、BOLD signal 是什麼？

**BOLD（Blood Oxygen Level–Dependent）signal**  
是 fMRI（功能性磁振造影）量測到的信號變化，反映**神經活動引起的血流與氧合變化**。

### 🔬 生理原理簡述：

- 當神經元活動上升 → 該區代謝需求增加
    
- 腦血流 (CBF) 上升以供應氧氣 → 血中 **氧合血紅素 (HbO)** 增加、**去氧血紅素 (HbR)** 減少
    
- 因為 **去氧血紅素具磁性**，會影響 MRI 的 T2* 信號 → 當 HbR 減少時，T2* 增強 → 產生 **BOLD signal 上升**
    

🧩 所以：

> BOLD signal 是「神經活動 → 血流反應 → 氧合變化 → 磁信號變化」的間接指標。

## 🕒 二、BOLD signal 的範圍（frequency & spatial scale）

### 1️⃣ **時間頻率範圍**

BOLD signal 的「低頻波動」是靜息態分析的核心。  
研究發現神經自發活動主要在 **0.01–0.1 Hz**（即 10–100 秒週期）之間震盪。

|頻率範圍|種類|主要用途|
|---|---|---|
|0–0.01 Hz|超低頻（ultra-slow）|可能與儀器漂移、血流動力學基線變化有關（通常過濾掉）|
|**0.01–0.1 Hz**|**低頻（neurophysiological range）**|神經活動相關，為 ALFF / ReHo / FC 的主分析範圍|
|>0.1 Hz|高頻|主要反映生理噪音（心跳、呼吸）或隨機誤差|


---

### 2️⃣ **空間範圍**

BOLD signal 可從不同層級觀察：

| 層級             | 分析單位         | 常見方法               |
| -------------- | ------------ | ------------------ |
| voxel（毫米等級）    | 每個立方體像素的時間序列 | ALFF / ReHo        |
| ROI（數個 voxel）  | 腦區平均信號       | Seed-based FC      |
| network（多腦區組合） | 整體連結模式       | ICA / Graph theory |
## ✅ 總覽簡介

### 依據分析焦點分為三大類

| 分析類型        | 重點        | 常見指標                                    |
| ----------- | --------- | --------------------------------------- |
| **活動強度分析**  | 單一腦區的活性變化 | ALFF / fALFF                            |
| **區域一致性分析** | 腦區內部的同步性  | ReHo                                    |
| **功能連結分析**  | 腦區間的關聯性   | FC、seed-to-voxel、ICA                    |
| **全腦網絡分析**  | 整體網絡特性    | Graph theory、small-worldness、modularity |
### 指標比較整理表

| 指標                     | 對應問題   | 計算對象        | 優點     | 缺點       |
| ---------------------- | ------ | ----------- | ------ | -------- |
| **ALFF/fALFF**         | 活動強度   | 單一 voxel    | 直觀、易計算 | 噪音敏感、無連結 |
| **ReHo**               | 區域同步性  | voxel 與鄰近區域 | 局部整合敏感 | 僅限局部     |
| **FC (seed-to-voxel)** | 區域間同步  | 腦區之間        | 解釋性高   | 需指定種子    |
| **ICA**                | 探索內在網絡 | 全腦          | 無需先驗假設 | 成分需人工解釋  |
| **Graph analysis**     | 全腦網絡特性 | 腦區連結圖       | 整體視角   | 複雜、需建模知識 |

---

### 🎯 選擇建議

|研究目的|建議使用|
|---|---|
|測量腦區是否活動強|ALFF / fALFF|
|觀察局部同步性變化|ReHo|
|想知道兩個腦區是否連動|FC（seed-based 或 ROI-to-ROI）|
|無先驗假設，想看全腦功能網絡|ICA|
|想從網絡角度了解腦組織|Graph 理論分析|

---

### 📌 舉例應用情境（假設研究主題：失眠）

| 問題                            | 可用參數           |
| ----------------------------- | -------------- |
| 失眠者腦中哪裡活動比較少？                 | ALFF / fALFF   |
| 他們的局部神經同步是否異常？                | ReHo           |
| default mode network 有沒有連結異常？ | FC、ICA         |
| 整體網絡效率是否下降？                   | Graph analysis |


## 依照分析模式 運算比較方式可以分成這幾種
### 1. **Seed-to-Voxel Analysis**

- 又稱 **ROI-to-voxel** 分析，是 resting-state fMRI 中最常見的功能連結分析方法之一。
    

**步驟：**

1. 定義一個種子區域（seed），如 PCC、amygdala、dlPFC 等。
    
2. 提取該區時間序列。
    
3. 與整個大腦中每個 voxel 的時間序列進行相關（Pearson correlation）。
    
4. 得到一張「與 seed 區域功能相關的全腦 map」。
    

**優點：**

- 簡單易解釋，具生理意義。
    
- 可聚焦於特定假設。
    

**缺點：**

- 結果受 seed 選擇影響大。
    
- 不對稱（seed→voxel，但非 voxel→seed）。
    

---

### 2. **Voxel-wise Analysis**

- 指針對每個 voxel 做統計檢定，常見於任務式分析或 group comparison。
    
- 又稱 **whole-brain analysis**，是最細緻的空間層級分析。
    

**常見應用：**

- 比較兩組在整個腦區的活化差異。
    
- 用於 machine learning 或 multivariate pattern analysis（MVPA）。
    

**處理方式：**

- 需考慮多重比較問題（如使用 FWE 或 FDR 修正）。
    
- 常用統計方法：t-test、ANOVA、回歸分析等。
    

**優點：**

- 可探索全腦範圍的變化，無偏見。
    
- 能發現 seed 未涵蓋到的關鍵區域。
    

**缺點：**

- 計算量大。
    
- 容易因多重比較造成假陽性。
    

---

### 3. **ROI-to-ROI Analysis**

- 將腦分為多個區域（ROIs），對每對 ROI 計算時間序列相關性，產生一個矩陣（connectivity matrix）。
    
- 常用於 network-level 分析，如 default mode network、salience network 等。
    

---

### 4. **Independent Component Analysis (ICA)**

- 無需指定 seed，藉由數學分解將全腦訊號拆成數個獨立空間模式（components）。
    
- 常用於發現靜息態功能網絡（如 default mode network, DMN）。
    

---

### 5. **Dynamic Functional Connectivity（dFC）**

- 傳統 FC 假設連結隨時間穩定，dFC 則探討「連結變動性」。
    
- 常用 sliding window 法觀察時間段內的連結模式變化。
    
- 適合研究失眠、精神疾病等腦網路不穩定的情況。
    

---

### 6. **Graph Theory Analysis（圖論分析）**

- 將大腦視為網路（node = brain region；edge = connectivity）。
    
- 分析全腦網絡的拓樸特性，如：
    
    - degree centrality（節點連線數）
        
    - clustering coefficient（區域性聚集性）
        
    - path length（訊息傳遞距離）
        
    - modularity（模組化程度）
    



---
# fMRI 參數介紹

## 1. ALFF （Amplitude of Low Frequency Fluctuation）
- **原理**：計算每個 voxel 在 0.01–0.08 Hz 的低頻 BOLD 波動強度（功率）
    
- **反映**：自發神經活動的強度（特別是靜息狀態下）
    
- **適合用途**：比較群體或狀態間自發活性差異（如疾病 vs 健康）
    
- **優點**：直觀、容易計算
    
- **缺點**：受全腦 noise 影響大
    
- **變體**：
    
    - **fALFF**：fractional ALFF，將 ALFF 除以全頻功率，提升特異性，抑制非神經性雜訊
    -
## 2. ReHo（Regional Homogeneity）
- **原理**：評估一個 voxel 與鄰近 voxel 的 BOLD 波動一致性（通常與26個鄰居比較）
    
- **反映**：局部神經元活動的同步性
    
- **適合用途**：探索局部網絡整合、早期疾病特徵
    
- **優點**：敏感度高，可用於早期變化偵測
    
- **缺點**：僅限於局部、無法反映跨腦區網絡
## 3. FC（Functional Connectivity）
- **原理**：計算不同腦區之間的 BOLD 訊號時間序列相關性（通常用皮爾森相關）
    
- **形式**：
    
    - **Seed-based FC（seed-to-voxel）**：預設一個感興趣腦區（ROI），看它與全腦其他 voxel 的連結性
        
    - **ROI-to-ROI FC**：分析多個指定腦區間的關聯矩陣
        
    - **Whole-brain FC**：建立全腦 voxel 間的關聯網絡
        
- **反映**：區域間同步活動，揭示功能性網絡
    
- **適合用途**：探索 default mode network、salience network 等內在網絡，以及疾病連結異常
    
- **優點**：解釋性強、與症狀連結廣泛
    
- **缺點**：需預設 seed，結果依賴 ROI 定義；不代表因果（只顯示同步）
## 4. ICA（Independent Component Analysis)
- **原理**：無須指定 ROI，將 fMRI 訊號拆解為數個彼此統計獨立的成分（component）
    
- **反映**：腦內獨立網絡的活動模式（如 DMN、視覺網絡等）
    
- **適合用途**：探索未知網絡、消除噪音、比較網絡強度差異
    
- **優點**：資料驅動，不需假設；適合探索研究
    
- **缺點**：成分解釋困難、需要經驗判讀
## 5. Functional Network Connectivity / Graph theory analysis
- **原理**：以腦區為節點、功能連結為邊，建立整體腦網絡圖
    
- **指標範例**：
    
    - **Degree**：節點與幾個腦區有連結
        
    - **Clustering coefficient**：局部網絡聚合程度
        
    - **Small-worldness**：腦網路的效率特徵
        
- **適合用途**：系統性比較腦網絡組織結構，如精神疾病、老化、IQ 差異
    
- **優點**：整體性高、可量化複雜腦連結
    
- **缺點**：解釋性依賴理論背景、需較高技術能力

# 6 **Lesion network mapping**
[[Lesion network symptom mapping]]
