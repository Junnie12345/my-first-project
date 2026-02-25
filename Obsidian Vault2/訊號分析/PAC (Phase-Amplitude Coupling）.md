得到modulation index (MI)

### PAC（Phase-Amplitude Coupling）

**用途：** 探討**不同頻率間的交互作用**，例如：

- delta波的phase 是否調控 gamma波的amplitude？
    

**應用於：**

- 睡眠研究、注意力、記憶、癲癇等神經動態分析。
    

**計算方法：**

1. 選定高頻與低頻範圍。
    
2. 對訊號做 band-pass filter。
    
3. 用 Hilbert transform 提取 phase 與 amplitude。
    
4. 計算 phase-amplitude 的耦合程度（如 modulation index）。