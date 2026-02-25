
# current source density (CSD)
- **Calculate the CSD:** 
    
    CSD is mathematically derived as the second spatial derivative of the measured extracellular potentials. 
    
- **Estimate current flow:** 
    
    This calculation reveals the patterns of transmembrane current flow, with negative values representing current sinks (where current flows into the neuron) and positive values representing current sources (where current flows out). 
    
- **Improve localization:** 
    
    By pinpointing the sources and sinks, CSD analysis can better define the location of active neural populations, such as those in response to a stimulus.


在這篇研究中，**CSD** 是一種用來量化大腦皮層特定區域電活動強度的指標 。而 **eLORETA** 則是一種先進的數學分析技術，用來處理頭皮腦電圖（EEG）訊號，並精確地推算出這些電活動在大腦皮質三維空間中的來源與強度（即CSD）。簡單來說，**eLORETA是「方法」，CSD是透過這個方法得到的「結果」**。

---

### **1. 電流源密度 (Current Source Density, CSD)**

#### **定義與目的**

CSD 指的是大腦皮層神經元活動所產生的電流在特定位置的密度或強度 。在腦電圖研究中，分析CSD的目的是從頭皮上測量到的混合電訊號中，反推出大腦內部特定區域的真實神經活動量，實現「功能性定位」
# exact low-resolution electromagnetic tomography (eLORETA)
The eLORETA can be used for functional localization, as in classical neuroimaging, and more importantly, it provides noninvasive intracranial recordings for the assessment of dynamic FC by evaluating connectivity between pairs of brain regions, minimally affected by volume conduction and low spatial resolution, thus revealing pure physiological connectivity.46 The eLORETA method uses a linear-type weighted minimum norm inverse solution. The eLORETA head model and electrode coordinates are based on the Montreal Neurological Institute's mean MRI brain map (MNI152), with the intracerebral volume being partitioned into 6239 voxels of 5-mm spatial resolution and restricted to cortical gray matter. Previous studies have used functional MRI,41,59 structural MRI,60 positron emission tomography,12 and intracranial EEG62 to validate eLORETA tomography

### **總結**

在這篇研究中，**CSD** 是一種用來量化大腦皮層特定區域電活動強度的指標 。而 **eLORETA** 則是一種先進的數學分析技術，用來處理頭皮腦電圖（EEG）訊號，並精確地推算出這些電活動在大腦皮質三維空間中的來源與強度（即CSD）。簡單來說，**eLORETA是「方法」，CSD是透過這個方法得到的「結果」**。
#### **定義與目的**

eLORETA (exact low-resolution electromagnetic tomography) 是一種用來解決腦電圖「逆問題（inverse problem）」的空間濾波演算法 。它的主要功能是將頭皮電極記錄到的二維電壓訊號，轉換為大腦皮層灰質的三維電流源分佈圖像 。

#### **技術特點與優勢**

- **高定位準確性**：eLORETA 即使在空間解析度較低的情況下，也能準確地定位神經活動的來源 。研究指出，與其他類似的線性逆解方案相比，eLORETA 在存在雜訊和多個訊號源的情況下，具有更佳的定位能力 。
    
- **克服容積導體效應**：傳統EEG分析容易受到「容積導體效應」（即電流在頭顱內擴散導致訊號模糊）的影響 。eLORETA 能有效地將這種影響降至最低，從而揭示更真實的生理性連結與活動來源 。
    
- **標準化與驗證**：該技術使用蒙特婁神經科學研究所（MNI）的標準大腦圖譜作為頭部模型，將大腦皮質灰質分割成6239個5mm³的立體像素（voxels）進行計算 。其準確性已透過與功能性磁振造影（fMRI）、正子斷層造影（PET）及顱內EEG等技術的比對得到驗證 。
    
- **穩健的統計方法**：在進行統計比較時，eLORETA採用非參數的隨機排列檢定（5000次數據置換），來校正多重比較問題，這種方法不依賴數據呈現高斯分佈的假設，因此統計結果更為穩健 。

# Current source density and functional connectivity extracted from resting-state electroencephalography as biomarkers for chronic low back pain

**與疼痛症狀顯著相關**：儘管組間無差異，但在CLBP患者內部，研究發現：

- 左側前額葉的 **θ波** 活性 (CSD值) 與總疼痛評分 (SF-MPQ) 呈顯著正相關 。
    
- 左側前額葉的 **δ波** 活性 (CSD值) 與當前的疼痛強度呈顯著正相關 。
    
- 這意味著，患者感受到的疼痛越強，其前額葉的慢波活動就越強烈
- 未來: 這些人可能過度敏感化，需進一部探討

![[Pasted image 20251014164619.png]]


#疼痛 #pian #EEG 