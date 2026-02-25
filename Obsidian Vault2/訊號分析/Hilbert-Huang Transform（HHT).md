#工程 #訊號 



HHT 的核心在於將訊號以經驗模態分解（EMD）方式分離為一組具有物理意義的 IMF，再透過希爾伯特轉換求得每一 IMF 的瞬時振幅與瞬時頻率，形成 AM-FM 分解結構。此種表示方式特別適用於非線性、非平穩訊號。
### **AM-FM 表示方式是 HHT 的核心概念之一。**

HHT 不只是做時間–頻率分析，它實際上是要把訊號表達成一組**AM-FM 成分的總和**，也就是：

x(t)=∑i=1nai(t)⋅cos⁡(θi(t))=∑i=1nai(t)⋅cos⁡(∫ωi(t)dt)x(t) = \sum_{i=1}^{n} a_i(t) \cdot \cos(\theta_i(t)) = \sum_{i=1}^{n} a_i(t) \cdot \cos\left( \int \omega_i(t) dt \right)x(t)=i=1∑n​ai​(t)⋅cos(θi​(t))=i=1∑n​ai​(t)⋅cos(∫ωi​(t)dt)

這裡：

- ai(t)a_i(t)ai​(t)：每個 IMF 的**瞬時振幅（AM）**
    
- ωi(t)\omega_i(t)ωi​(t)：**瞬時頻率（FM）**，來自於希爾伯特轉換
    
- θi(t)\theta_i(t)θi​(t)：是相位，也從希爾伯特轉換中得到



### Hilbert-Huang Transform（HHT；霍-黃轉換）

**提出者：** Norden Huang（黃鍾岳）  
**特色：** 專門為**非線性、非穩態訊號**設計（如 EEG、心跳等生理訊號）。

**流程：**

1. **EMD（經驗模態分解）**：將原始訊號分解為多個 IMF（固有模態函數），每個 IMF 對應不同頻率成分。
    
2. 對每個 IMF 做 **Hilbert Transform（希爾伯特轉換）** → 取得瞬時頻率與振幅。
    
3. 繪製 **Hilbert Spectrum**（時間-頻率-振幅三維圖）
    

📌 優點：具備時間-頻率解析，無需預設基底函數（如正弦波）  
📌 缺點：可能有模態混疊（mode mixing）問題

### 🌊 HHT（Hilbert-Huang Transform）流程圖步驟

1. **輸入信號 (Raw Signal Input)**  
    　→ 一般是一段非線性、非平穩的時間序列訊號
    
2. **進行EMD（Empirical Mode Decomposition）經驗模態分解** 　→ 將訊號分解成數個 IMF（Intrinsic Mode Functions，內涵模態函數）  
    　　- 每一個 IMF 都是局部的震盪模態
    
3. **檢查IMF特性** 　→ 確認每個 IMF 滿足兩個條件：  
    　　- 峰值與過零點數目相同或相差最多一  
    　　- 任一時間點的包絡線均值為零
    
4. **對每個 IMF 進行希爾伯特轉換 (Hilbert Transform)** 　→ 得到每一 IMF 的瞬時頻率與能量 **希爾伯特譜分析（HSA）**
    
5. **組合成時間-頻率-能量分布圖 (Hilbert Spectrum)** 　→ 可視化展示頻率隨時間變化的能量強度分布
    
6. **分析或應用** 　→ 可用於震動分析、生理訊號、地震資料等非線性訊號分析




---
### 🔹 EMD / EEMD

|方法|全名|特色與應用|
|---|---|---|
|**EMD**|Empirical Mode Decomposition|原始訊號自適應地分解成 IMF。易受噪聲影響。|
|**EEMD**|Ensemble EMD|在多次分解中加入白噪聲，平均以減少模態混疊問題。更穩定、更可靠。|
