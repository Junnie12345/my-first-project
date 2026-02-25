統計模型 (Statistical Models)
│
├── 一、線性模型 (Linear Models)
│   │
│   ├─ 1️⃣ 簡單線性迴歸 (Simple Linear Regression)
│   │    └─ 1 個自變項、1 個連續因變項
│   │       例：Y = β0 + β1X + ε
│   │
│   ├─ 2️⃣ 多元線性迴歸 (Multiple Linear Regression)
│   │    └─ 多個自變項、連續因變項
│   │       例：Y = β0 + β1X1 + β2X2 + ... + ε
│   │
│   ├─ 3️⃣ ANOVA（變異數分析）
│   │    └─ 自變項為分類變項（組別），因變項為連續變項
│   │       例：比較三組平均數是否不同
│   │
│   └─ 4️⃣ ANCOVA（共變數分析）
│        └─ ANOVA + 一個或多個連續共變數
│           目的：控制共變數影響後比較組別效果
│           例：比較治療效果，同時控制年齡/基線值
│
├── 二、廣義線性模型 (GLM; Generalized Linear Model)
│   │
│   ├─ 🧩 主要概念：
│   │    • 放寬「常態分布」假設  
│   │    • 用「連結函數 (link function)」連接預測值與期望值
│   │
│   ├─ 1️⃣ 線性模型是 GLM 的特例
│   │     link = identity, error = normal
│   │
│   ├─ 2️⃣ 常見 GLM 類型：
│   │     • Logistic regression → 二元資料 (Bernoulli)
│   │     • Poisson regression → 計數資料 (Poisson)
│   │     • Gamma regression → 正偏資料 (Gamma)
│   │
│   └─ 3️⃣ 延伸：
│         → GEE（廣義估計方程式）
│         → GLMM（廣義線性混合模型）
│
├── 三、廣義估計方程式 (GEE; Generalized Estimating Equations)
│   │
│   ├─ 💡 概念：
│   │    • GLM 的延伸，用於「重複量測」或「群聚資料」
│   │    • 不需假設隨機效應分布，只關注「平均效應」
│   │
│   ├─ 📊 特點：
│   │    • 適合 correlated data（例如同一人多週的測量）
│   │    • 可選不同的相關結構 (exchangeable, autoregressive…)
│   │
│   └─ 🔁 對應比較：
│        - GLM → 獨立樣本
│        - GEE → 相依樣本（群內相關）
│
├── 四、混合模型 (Mixed Models)
│   │
│   ├─ 💡 兼具固定效應 (fixed) 與 隨機效應 (random)
│   │
│   ├─ 1️⃣ LMM（Linear Mixed Model）
│   │    • 適用於連續因變項 + 重複量測
│   │    • 可建模個體差異 (random intercept/slope)
│   │
│   ├─ 2️⃣ GLMM（Generalized Linear Mixed Model）
│   │    • 混合 GLM + 隨機效應
│   │    • 適用於二元、計數或比例型反應變項
│   │
│   └─ 3️⃣ 與 GEE 比較：
│        | 方法 | 關注點 | 假設 | 適用 |
│        |--------|----------|--------|--------|
│        | GEE | 平均效應 (population-level) | 關聯結構 | 大樣本重複量測 |
│        | GLMM | 個體效應 (subject-level) | 隨機效應分布 | 小樣本或個別差異 |
│
└── 五、其他延伸模型
    │
    ├─ 多層次模型 (Hierarchical Linear Model, HLM)
    │    → LMM 的一種應用形式，用於學生嵌套於班級等階層資料
    │
    ├─ 結構方程模型 (SEM)
    │    → 同時估計多個變項間的關係，含潛在變項
    │
    ├─ 生存分析 (Survival Analysis)
    │    → 處理時間到事件的資料（Cox regression 是常見模型）
    │
    ├─ MANOVA / MANCOVA
    │    → 多個因變項的 ANOVA / ANCOVA
    │
    └─ 重複量測 ANOVA
         → 最早期處理重複資料的傳統方法（後來被 LMM / GEE 取代）

