https://pmc.ncbi.nlm.nih.gov/articles/PMC5804982/

### 🧠 **Arousal Threshold 的定義**

- **Arousal threshold**（覺醒閾值）指的是：  
    ➤「引發睡眠者從睡眠中覺醒所需的呼吸驅動強度（即氣道塌陷後，胸腔內負壓的強度）」。
    
- 換句話說，就是當睡眠中上呼吸道塌陷時，**需要多大的吸氣努力（negative esophageal pressure）**才會導致大腦覺醒。
    

---

### ⚙️ **在臨床多導睡眠檢查（PSG）中的估算方法**

由於臨床上通常不會直接測量食道壓力（Pes），Eckert 團隊發展出一種**間接估算法**，透過 PSG 資料來推算 arousal threshold：

1. **利用呼吸事件（apneas/hypopneas）中最後一口呼吸的氣流形態與血氧變化**：
    
    - 在覺醒（EEG arousal）前的最後幾個呼吸週期中，
        
        - 若氣流波形持續降低、胸腹運動變大但仍未覺醒，代表閾值較高；
            
        - 若輕微塌陷就導致覺醒，代表閾值較低。
            
2. **Eckert 等人（2011, 2015）的模型公式**：  
    研究團隊建立了一個以臨床變項為基礎的迴歸模型，用來預測個體的「arousal threshold」類型（高或低）。主要指標包括：
    
    |項目|生理意義|
    |---|---|
    |**最低 SpO₂**|反映呼吸事件的嚴重程度|
    |**AHI（呼吸中止指數）**|事件頻率|
    |**Nadir SpO₂ ≤ 82.5%**、**AHI ≤ 30**、**% hypopneas > 58.3%**|這三項組合常被用來預測低覺醒閾值（Low arousal threshold）患者|
    |**機率模型公式（Eckert et al., 2015）**：||
    |P(Low Threshold)=11+e−(−2.65+0.07×%hypopneas+0.03×minSpO2−0.05×AHI)P(Low\ Threshold) = \frac{1}{1+e^{-(-2.65 + 0.07 \times \%hypopneas + 0.03 \times minSpO₂ - 0.05 \times AHI)}}P(Low Threshold)=1+e−(−2.65+0.07×%hypopneas+0.03×minSpO2​−0.05×AHI)1​||
    
    - 當機率 **> 0.3** 時，通常歸類為 **低 arousal threshold (low AT)**。
        

---

### 🧩 **Physiological interpretation**

- **Low arousal threshold (低覺醒閾值)**：稍微氣道阻力上升就會覺醒 → 導致睡眠片段化、但氣體交換尚可。
    
- **High arousal threshold (高覺醒閾值)**：需更強烈的呼吸驅動才會覺醒 → 雖然睡眠較穩定，但易有血氧下降與高 CO₂ 累積。
    



![[Pasted image 20251028160927.png]]
---
![[Pasted image 20251028161006.png]]
### 📚 參考文獻

- Eckert DJ et al. _Quantitative phenotyping of obstructive sleep apnea patients using polysomnography data._ **Sleep** 2015;38(2):261–269.
    
- Younes M et al. _Mechanisms of arousals from sleep in obstructive sleep apnea._ **Sleep** 2012;35(3):361–374.

