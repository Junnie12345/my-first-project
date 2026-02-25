#MRI #fMRI
MRI（Magnetic Resonance Imaging）
diamagnetic 順磁性 ex: 鐵
para 反磁性(會抵抗場域磁場) ex: 水 人體大多數物質

proton 質子
計算質子旋轉

MRI: 先用一個磁場固定proton方向，再給予一個rF purse，使其旋轉，而其會產生遠離固定磁場方向的速度以及被purse影響方向的速度，而轉移過程中會因動生電，電訊號會輸入

contrast 顯影劑
# 儀器
![[Pasted image 20251029135031.png]]
### Larmor frequency
共振
![[Pasted image 20251029133143.png]]



# T1 and T2
### T1
回復到主磁場方向的速度
![[Pasted image 20251029134006.png]]
![[Pasted image 20251029134044.png]]
### T2
離開purse方向的速度
![[Pasted image 20251029133940.png]]

總結與對比 

| 特性       | T1 復原（縱向弛豫）                                                                                                                                          | T2 衰減（橫向弛豫）                                                                                                                                                       |
| -------- | ---------------------------------------------------------------------------------------------------------------------------------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| **磁化向量** | 縱向磁化向量 (<br><br>![](data:image/gif;base64,R0lGODlhAQABAIAAAP///wAAACH5BAEAAAAALAAAAAABAAEAAAICRAEAOw==)<br><br>Mzcap M sub z<br><br>𝑀𝑧<br><br>)    | 橫向磁化向量 (<br><br>![](data:image/gif;base64,R0lGODlhAQABAIAAAP///wAAACH5BAEAAAAALAAAAAABAAEAAAICRAEAOw==)<br><br>Mxycap M sub x y end-sub<br><br>𝑀𝑥𝑦<br><br>)    |
| **方向**   | 沿主磁場方向復原                                                                                                                                             | 垂直於主磁場方向衰減                                                                                                                                                        |
| **時間常數** | T1：<br><br>![](data:image/gif;base64,R0lGODlhAQABAIAAAP///wAAACH5BAEAAAAALAAAAAABAAEAAAICRAEAOw==)<br><br>Mzcap M sub z<br><br>𝑀𝑧<br><br>恢復至63%的時間 | T2：<br><br>![](data:image/gif;base64,R0lGODlhAQABAIAAAP///wAAACH5BAEAAAAALAAAAAABAAEAAAICRAEAOw==)<br><br>Mxycap M sub x y end-sub<br><br>𝑀𝑥𝑦<br><br>衰減至37%的時間 |
| **主要機制** | 能量傳遞給周圍組織（晶格）                                                                                                                                        | 質子間的磁場相互作用，導致失相                                                                                                                                                   |
| **物理過程** | 指數**成長**                                                                                                                                             | 指數**衰減**                                                                                                                                                          |
| **組織對比** | 短T1（脂肪）亮，長T1（水）暗                                                                                                                                     | 短T2（脂肪）暗，長T2（水）亮                                                                                                                                                  |
| **影像用途** | 觀察解剖結構，因為脂肪對比強                                                                                                                                       | 觀察病理變化，因為水腫病灶對比強                                                                                                                                                  |
# Gradient system
很像gradient western blot
不同區域有不同的磁場方向
在MRI中，梯度（Gradient）是指在主磁場（\(B_{0}\)）上，以可預測且線性方式增加或減少的次要磁場。這些梯度是由三個獨立的線圈所產生，分別控制空間中的三個正交方向（X、Y、Z），其主要目的是對MRI訊號進行空間編碼，讓電腦能辨識出訊號來自體內的哪個位置，進而重建出完整的影像。
三個方向的梯度 MRI掃描儀使用三組梯度線圈，負責空間編碼的三個步驟： Z梯度（\(G_{z}\)）：通常用來進行切層選擇（Slice Selection）。在縱向（Z軸，頭腳方向）產生線性變化的磁場。配合特定頻率的射頻脈衝，只有在目標切層位置、共振頻率匹配的質子才會被激發。Y梯度（\(G_{y}\)）：通常用來進行相位編碼（Phase Encoding）。在梯度開啟期間，不同位置的質子會以不同速率旋轉，導致相位產生差異。這個相位差異被記錄下來，用來辨識質子在Y方向上的位置。X梯度（\(G_{x}\)）：通常用來進行頻率編碼（Frequency Encoding），又稱讀取梯度（Readout Gradient）。在接收訊號的同時開啟，使不同位置的質子有不同的共振頻率。電腦透過分析頻率來辨識訊號在X方向上的位置。 梯度運作的示意圖 以下是一個簡化的脈衝序列圖（Pulse Sequence Diagram, PSD），描繪了梯度、射頻脈衝和接收訊號的時序關係。 時間軸 射頻脈衝（RF Pulse）Z 梯度（\(G_{z}\)）Y 梯度（\(G_{y}\)）X 梯度（\(G_{x}\)）接收訊號（Signal）激發一個短的90°脈衝。開啟一個短暫的梯度來選擇切層。相位編碼開啟一個短暫、不同強度的梯度。讀取啟動一個雙葉狀（bi-lobed）梯度。接收到回訊（echo）。示意圖說明 激發：當90°射頻脈衝發射時，\(G_{z}\)梯度同時開啟，確保只有特定切層的質子被激發。相位編碼：\(G_{y}\)梯度短暫開啟，使每個Y位置的質子產生獨特的相位偏移。讀取：\(G_{x}\)梯度開啟，質子在X方向上獲得不同的共振頻率，訊號在頻率編碼下被讀取，同時也會產生回訊（echo）。這個回訊將頻率和相位編碼資訊結合，形成原始資料（k-space），最終透過傅立葉轉換重建影像。 透過這三個獨立但協調運作的梯度，MRI掃描儀能夠精確地將人體內的每個位置進行空間編碼，進而將物理訊號轉化為具有精細解剖細節的影像。
![[Pasted image 20251029134629.png]]
![[Pasted image 20251029134637.png]]
![[Pasted image 20251029134648.png]]
![[Pasted image 20251029134654.png]]

# 參數介紹: TR, TE
### TR (repetition time)
The repetition time (_TR_) is the length of time between corresponding consecutive points on a repeating series of pulses and echoes.
### TE (Echo time)
The echo time (_TE_) represents the time from the center of the RF-pulse to the center of the echo. For pulse sequences with multiple echoes between each RF pulse, several echo times may be defined and are commonly noted _TE1_, _TE2_, _TE3_, etc.
![[Pasted image 20251029135307.png]]


不同的protocol: (不同TE TR 頻率等不同)
![[Pasted image 20251029140548.png]]


## **DTI（Diffusion Tensor Imaging）**
[[DTI 影像]]
- **原理**：MRI 的延伸，測量水分子在白質中的擴散方向性
- ### 定義：

**FA 是一個介於 0 到 1 的值，用來表示水分子擴散的方向性強弱（異向性）**。

- **FA = 0**：完全等向性（isotropic）→ 水分子擴散在各方向都一樣（像水池裡的水）。
    
- **FA 趨近 1**：高度異向性（anisotropic）→ 水分子主要朝單一方向擴散（像管道裡的水）。
- ![[Pasted image 20251029142038.png]]
## DWI 磁振擴散加權造影（Diffusion-Weighted Imaging, DWI）
#### DWI 的運作原理
DWI 的核心原理是追蹤水分子在微觀層級的移動。其脈衝序列在標準的T2加權序列上增加了兩道額外的擴散敏感梯度脈衝（diffusion-sensitizing gradient pulses），其強度與方向相等但方向相反。 
這個過程可分為以下幾個步驟：
第一次梯度脈衝：首先施加一道梯度脈衝，使所有在該方向上的質子發生失相（dephasing），導致橫向磁化訊號衰減。
分子擴散：在兩道梯度脈衝之間，組織內的水分子會因布朗運動而隨機移動。
第二次梯度脈衝：接著施加一道方向相反的梯度脈衝，試圖將所有質子重新調相（rephasing），恢復訊號。
訊號衰減：
正常組織：在正常組織中，水分子可以自由擴散，這導致它們在兩道脈衝之間改變了位置。因此，第二道梯度脈衝無法完全將所有質子調相，使得橫向磁化訊號無法完全恢復，訊號強度會降低。
病變組織：在病變組織（如急性中風）中，細胞腫脹會限制水分子的擴散。由於水分子移動距離小，第二次梯度脈衝能有效地重新調相，訊號衰減較少，因此訊號強度會維持較高。 
#### DWI 影像的特點
高訊號（高亮）： 訊號強度高的區域代表受限性擴散（Restricted diffusion），即水分子無法自由移動，通常意味著病理變化，例如急性中風、高細胞密度的腫瘤或膿腫。
低訊號（暗）： 訊號強度低的區域代表自由擴散（Free diffusion），即水分子可以自由移動，通常為正常組織或腦脊液（CSF）等水分含量高的區域

## MRA 血管攝影
耗時耗人力
![[Pasted image 20251029142502.png]]

## MRS
類似對人體做NMR核磁共振光譜學 (Nuclear magnetic resonance spectroscopy)，或是質譜儀的感覺
可以對一個區域去進行組成成分或特定標記的定量以及腫瘤評估
![[Pasted image 20251029143032.png]]


## MRE 彈性影像
使用震動器，並測量反彈強度去推測不同的結構以及軟硬情況
![[Pasted image 20251029143528.png]]


# 各類MRI主要臨床應用
![[Pasted image 20251029144108.png]]


# fMRI 資料處理
fALFF：低頻振幅分數（fractional Amplitude of Low-Frequency Fluctuation）

- **定義**：fALFF衡量的是**大腦局部自發性活動的強度**。它是計算每個腦區中，**低頻段（通常為0.01–0.08 Hz）的BOLD訊號振幅**，並將其與**整個頻率範圍內的總振幅**進行比較。
ReHo：區域同質性（Regional Homogeneity）

- **定義**：ReHo衡量的是一個**體素（voxel）及其周圍鄰近體素**在BOLD訊號上的**時間序列同步性**。它是透過計算一個體素及其周圍小範圍內的肯德爾協和係數（Kendall's coefficient of concordance）來實現的。
- **代表意義**：
    - **高 ReHo 值**：代表該腦區的鄰近體素活動具有高度同步性，反映出**局部功能連接性較強**。
    - **低 ReHo 值**：代表該腦區的活動不一致或較少同步。
RSN：靜息態網路（Resting-State Network）

- **定義**：RSN是指在靜息狀態下，**遠程但功能相關**的腦區之間，其**BOLD訊號呈現同步性波動**的空間模式。
- **代表意義**：
    - RSN代表了**大腦在靜息狀態下運作的基本功能架構**。例如，預設模式網路（Default Mode Network, DMN）就是在沒有執行任何外部任務時，表現出持續活動的一組腦區，與內部思維活動相關。
    - RSN也反映了**大腦不同區域之間的功能連接（functional connectivity）**。
![[Pasted image 20251029144400.png]]

![[Pasted image 20251029144543.png]]

![[Pasted image 20251029144827.png]]











-----











---

# Reference
https://www.radiologycafe.com/frcr-physics-notes/mr-imaging/t1-and-t2-signal/
https://mriquestions.com/what-is-t1.html
https://mriquestions.com/opposite-effects-uarrt1-uarrt2.html
https://www.imaios.com/en/e-mri/mri-instrumentation-and-mri-safety/magnetic-field-gradients
https://www.uomus.edu.iq/img/lectures21/MUCLecture_2023_1235985.pdf#:~:text=MRI%20DESIGN:%20Gradient%20Functions.%20Gradients%20are%20coils,along%20the%20gradient%20is%20known%20(Figure%2027.1).
http://www.twsrt.org.tw/twsrt/upfile/files/2016617155511.pdf   中文講義

