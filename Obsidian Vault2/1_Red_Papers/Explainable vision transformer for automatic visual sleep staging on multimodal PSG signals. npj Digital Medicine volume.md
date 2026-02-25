
Explainable vision transformer for automatic visual sleep staging on multimodal PSG signals. npj Digital Medicine volume 8, Article number: 55 (2025)

#自動判期
- _SleepXViT_ achieves superior classification performance and provides reliable confidence scores for predictions, enabling experts to thoroughly review results predicted with low confidence. This significantly increases both reliability and usability in clinical settings.
    
- _SleepXViT_ provides visual explanations through high-resolution, epoch-by-epoch heatmaps that highlight the parts of images the model focuses on for its classification predictions. It enables human experts to verify whether the model’s staging rationale can be explained using the AASM rules they employ.
    
- Additionally, it analyzes the impact of multi-epoch sequences, mirroring the way human experts consider the temporal context in their staging decisions, thus providing a more comprehensive evaluation.
    
- We assess the consistency with which the model applies its staging criteria, ensuring that the algorithm’s internal workings are clearly explainable.

## 🛠️ 方法 (Methods)

SleepXVIT 旨在模擬人類專家透過視覺評估多模態 PSG 資料來進行睡眠分期的過程 11111111。

### 1. 資料預處理與輸入格式

- **資料集：** 主要使用 **KISS** 資料集（一種標準化的影像 PSG 資料集）12以及 **SHHS** (Sleep Heart Health Study) 資料集 13。
    
- **標準化：** 採用標準化的預處理流程 14141414，將異構的原始 PSG 時序生物訊號轉換為單一的**統一影像格式**（標準化的 PSG 影像）15151515，以維持跨不同採集系統的一致性 16。
    
- **訊號包含：** 影像包含了所有多模態波形，包括 **EEG**（四個通道）、**EOG**（兩個通道）、**EMG**、**ECG**、**Flow**、**Thermister**、**Thoracic Movement**、**Abdominal Movement** 和 **Oxygen Saturation**（兩個通道），總共 **14 個通道** 17。
    
- **影像尺寸：** 影像被調整和裁剪為 $224 \times 224$ 像素 18181818。
    

### 2. SleepXVIT 架構

SleepXVIT 包含兩個 Vision Transformer (ViT) 組件，分別處理單一時程內的特徵和時程之間的連續性 1919191919：

#### A. Intra-epoch ViT (時程內 ViT)

- **功能：** 從單一 30 秒時程影像中提取特徵並進行睡眠階段分類 2020202020。
    
- **架構：** 採用 **Vision Transformer (ViT)** 架構 21212121，使用 $16 \times 16$ 的圖像塊 (patches) 大小 22。
    
- **訓練：** 使用預訓練的 ViT 權重（在 ImageNet-21k 上預訓練，並在 ImageNet-1k 上微調）23。
    

#### B. Inter-epoch ViT (時程間 ViT)

- **功能：** 處理來自 **Intra-epoch ViT** 的**連續時程特徵嵌入序列**，分析時程間的關係，以準確預測每個時程的睡眠階段 242424242424242424。
    
- **輸入：** 將多個時程的特徵嵌入 $z \in \mathbb{R}^{D}$ 編譯成序列 25。
    
- **輸入長度：** 實驗結果顯示，**10 個時程的序列長度** 達到了最高的 Macro F1 Score，因此在所有實驗中採用此長度 26262626。
    
- **訓練：** 應用多頭注意力機制，並訓練一個分類頭對序列中的每個時程進行預測 27。
    

### 3. 推理與可解釋性機制

#### A. 滑動窗口集成技術 (Sliding-Window Ensemble)

- **目的：** 在推理時使用滑動窗口方法，以**一個時程的步幅** (stride) 處理多時程序列 28282828。
    
- **過程：** 這使得目標時程的預測能夠考量到 $l$ 個相鄰時程的全面上下文 29。對於序列長度為 10 的情況，每個目標時程的預測會整合來自 **9 個先前時程和 9 個後續時程**的資訊，共 19 個時程 30。
    
- **最終預測：** 通過**加總所有預測的 Softmax 值**來聚合結果，選擇總和最高的類別作為最終預測 31。此集成效應將 Macro F1 score 提高了 1.84 個百分點 32323232。
    

#### B. 置信度分數 (Confidence Scores)

- **計算：** 使用 **Softmax 值**作為置信度指標，以簡單實用的方式評估模型的預測準確性 33。
    
- **臨床應用：** SleepXVIT 具備良好校準性 34343434，允許臨床醫生根據置信度分數來評估模型的可靠性 35353535。
    
    - 例如，如果 **Intra-epoch ViT** 的預測置信度**非常高（例如 > 0.9）**，則可繞過進一步處理以實現高效分期 36。
        
    - 如果 **Inter-epoch ViT** 的置信度**非常低（例如 < 0.8）**，則會標記出來，讓臨床醫生進行人工評估 37。
        

#### C. 視覺解釋 (Visual Explanations)

- **熱圖生成：** 採用基於 **Layer-wise Relevance Propagation (LRP)** 38為 Transformer 網絡設計的新穎方法 39。
    
- **優勢：** 這種方法提供了**高解析度熱圖**，精確地詳細說明了輸入圖像中每個像素對於最終決策的相關性（貢獻度）40404040。這與依賴較深層梯度的方法（如 Eigen-CAM）產生的粗糙熱圖不同 41。
    
- **一致性評估：** 透過對熱圖進行 K-means 聚類分析，確認了熱圖在相似輸入之間顯示出**類別特定的模式**，表明模型以一致的標準和邏輯進行解釋 42424242。
    

#### D. 多時程序列的影響 (Impact of Multi-epoch Sequences)

- **相關性分數：** 使用與生成熱圖相同的方法計算時程之間的相關性分數 43，以顯示輸入序列中其他時程對目標時程預測的影響程度 44444444。
    
- **功能：** 這項功能模仿了人類專家考慮時間上下文的行為 45，對於需要上下文判斷的階段（如 **REM** 和 **Wake/N1** 的模糊過渡）特別重要 464646464646464646。例如，**Inter-epoch ViT** 能夠透過相鄰的 REM 時程的影響，將一個最初被錯誤分類為 N2 的時程校正為 REM 47474747。