

### 1. 描述性統計與製表 (Descriptive Stats & Table 1)

SPSS 強項是點一下就出表格，R 的 Base R 輸出很醜，但用對套件，你可以直接產出能貼進 Word 的表格。

- **基本寫法 (Base R):** 痛苦，要自己拼湊。
    
    R
    
    ```
    summary(df)
    sapply(df, mean, na.rm=TRUE)
    ```
    
- **推薦進階 (Pro): `gtsummary`** 這是目前最強的製表神器，直接產出醫學期刊等級的 "Table 1"。
    
    R
    
    ```
    library(gtsummary)
    
    df %>%
      select(Group, Age, PS150_Score, Sleep_Hours) %>%
      tbl_summary(
        by = Group, # 依組別分欄
        statistic = all_continuous() ~ "{mean} ({sd})", # 指定顯示 Mean (SD)
        missing = "no" # 不顯示缺失值行
      ) %>%
      add_p() # 自動幫你跑 t-test 或卡方檢定算出 p value
    ```
    
```
df %>%
  tbl_summary(by = Group) %>%
  add_p(
    # 指定 PS150_Score 這一欄必須用 t-test
    test = list(PS150_Score ~ "t.test", 
                Gender ~ "chisq.test")
  )
```
**它的預設邏輯：** `add_p()` 會自動偵測你的變數長什麼樣子：

- 如果是**連續變數**（如身高、分數）：它預設跑 **Wilcoxon rank-sum test** (無母數) 或 **t-test** (如果它偵測到近似常態)。
    
- 如果是**類別變數**（如性別、有無失眠）：它預設跑 **Chi-square test** (卡方檢定) 或 **Fisher's exact test** (如果樣本數太少)。
### 2. 常態性與假設檢定 (Assumption Checks)

你之前覺得只有 Shapiro，其實是你缺了這個「健檢中心」。

- **基本寫法 (Base R):**
    
    R
    
    ```
    shapiro.test(df$Variable)
    qqnorm(df$Variable); qqline(df$Variable)
    ```
    
- **推薦進階 (Pro): `performance` (來自 `easystats` 家族)** 這是我說的「一句話做完所有檢查」。
    
    R
    
    ```
    library(performance)
    
    # 先建立一個線性模型
    model <- lm(Insomnia_Score ~ Treatment * Time, data = df)
    
    # 一次檢查：常態性、變異數同質性、共線性(VIF)、極端值
    check_model(model) 
    ```
    
    > **亮點：** 它會直接畫出一張包含 6 個子圖的診斷面板，非常直觀，比 SPSS 的文字報表強大太多。
    
如果你需要明確的數據檢定結果，`performance` 家族有另一個指令：

R

```
check_normality(model)
```

- 這個指令會輸出文字結果。
    
- **它的智慧之處：** 如果樣本數小（N < 5000），它預設跑 **Shapiro-Wilk**；如果樣本數超大，它可能會切換到 **Anderson-Darling** 或單純警告你不要過度依賴 p 值（因為樣本大時，一點點偏差都會顯著）。
### 3. T 檢定 (T-Test)

- **基本寫法 (Base R):** 輸出結果是 list，不好整理。
    
    R
    
    ```
    t.test(Score ~ Group, data = df, var.equal = TRUE)
    ```
    
- **推薦進階 (Pro): `rstatix`** 專為 `tidyverse` 設計，輸出結果是 Data Frame，方便後續畫圖。
    
    R
    
    ```
    library(rstatix)
    
    # 獨立樣本 t-test
    stat.test <- df %>% 
      t_test(Score ~ Group, var.equal = TRUE) %>%
      add_significance() # 自動幫你加星號 (*, **, ***)
    
    stat.test # 直接看結果表格
    ```
    

### 4. 變異數分析 (ANOVA) & 重複測量 (Repeated Measures)

**這是 SPSS 使用者轉 R 最容易踩雷的地方！** Base R 的 `aov` 預設是 Type I Sum of Squares，而 SPSS 是 Type III。如果樣本數不平衡，兩邊結果會不一樣，讓你懷疑人生。

- **基本寫法 (Base R):** (不建議用於學術發表，除非你很懂 SS 類型)
    
    R
    
    ```
    summary(aov(Score ~ Group * Time, data = df))
    ```
    
- **推薦進階 (Pro): `afex`** 腦科學/心理學界標準配備。它預設使用 **Type III SS**（跟 SPSS 一樣），且處理 Repeated Measures 非常簡單。
    
    R
    
    ```
    library(afex)
    
    # aov_ez 是 "Easy ANOVA" 的意思
    model_anova <- aov_ez(
      id = "Subject_ID",        # 受試者 ID (處理重複測量必備)
      dv = "PS150_Score",       # 依變項
      data = df,
      between = "Group",        # 組間因子 (實驗組 vs 對照組)
      within = "Time_Point"     # 組內因子 (前測、後測)
    )
    
    model_anova # 直接顯示標準 ANOVA 表
    ```
    
如果你想看懂 `afex` 背後在做什麼，這是用 R 模擬 Type II 和 Type III 的語法：


```
library(car) # 這裡有 Anova 指令 (注意是大寫 A)

model <- lm(Score ~ Group * Time, data = df)

# 你的疑問：Type II
# 如果你相信沒有交互作用，或者只關心主效應
Anova(model, type = 2)

# 你的標準選擇：Type III
# 這是 SPSS 的預設結果
# 注意：在 R 跑 Type III 前，必須把對比設為 sum-to-zero (這是一個數學眉角)
options(contrasts = c("contr.sum", "contr.poly")) 
Anova(model, type = 3)
```

重複測量RM ANOVA
**✅ 解決方案：** 依然是用我推薦給你的 **`afex`**。它會自動幫你處理 Type III SS **以及** 重複測量所需的球形檢定（Sphericity Test, Mauchly's Test）校正。

```
library(afex)

# 自動處理 Type III SS 和 重複測量誤差項
rm_model <- aov_ez(
  id = "Subject_ID", 
  dv = "Score", 
  data = df, 
  between = "Group", 
  within = "Time"
)

rm_model # 輸出結果會跟 SPSS 一模一樣，並自動提供校正後的 p 值 (GG correction)
```


### 5. 事後比較 (Post-hoc Tests)

如我們剛才討論的，丟掉 LSD 吧。

- **基本寫法 (Base R):**
    
    R
    
    ```
    TukeyHSD(aov_model)
    ```
    
- **推薦進階 (Pro): `emmeans`** 搭配上面的 `afex` 模型使用，完美解決交互作用的比較。
    
    R
    
    ```
    library(emmeans)
    
    # 假設 Group 和 Time 有交互作用，我們想看在 "Post-test" 時，兩組有沒有差異
    emmeans(model_anova, specs = pairwise ~ Group | Time) 
    ```

如果你還在用 `LSD.test()` 或 `TukeyHSD()`，建議升級到這個組合：

R

```
library(emmeans)
# 假設你的模型是 res_anova
# 進行 Tukey 事後比較 (最常用的，比 LSD 嚴謹)
emmeans(res_anova, list(pairwise ~ factor_name), adjust = "tukey")

# 進行 Bonferroni 修正 (比 Tukey 更嚴守型一錯誤)
emmeans(res_anova, list(pairwise ~ factor_name), adjust = "bonferroni")

# 進行 Sidak 或 Scheffe 修正 (SPSS 選單裡常看到的那些)
emmeans(res_anova, list(pairwise ~ factor_name), adjust = "scheffe")
```



### 6. 相關性分析 (Correlation)

- **基本寫法 (Base R):**
    
    R
    
    ```
    cor.test(df$Var1, df$Var2)
    ```
    
- **推薦進階 (Pro): `correlation`** 支援多變數一次跑完，還支援貝氏相關 (Bayesian) 或穩健相關 (Robust)。
    
    R
    
    ```
    library(correlation)
    
    # 一次看所有變數的相關矩陣
    df %>% 
      select(Var1, Var2, Var3) %>% 
      correlation(method = "pearson")
    ```
    

### 7. 線性混合模型 (Linear Mixed Models, LMM)

既然你是做腦科學與睡眠，這大概是你未來的神器。SPSS 跑 Mixed Model 介面很卡，R 的語法極其優雅。

- **唯一推薦: `lme4` + `lmerTest`** (`lme4` 是核心，`lmerTest` 是為了幫你算出 p-value，因為純數學家覺得 LMM 的 p-value 很難定義，但我們做實驗需要它)。
    
    R
    
    ```
    library(lme4)
    library(lmerTest)
    
    # 隨機截距模型 (考慮每個受試者的起始點不同)
    lmm_model <- lmer(PS150_Score ~ Group * Time + (1 | Subject_ID), data = df)
    
    summary(lmm_model) # 查看結果
    anova(lmm_model)   # 查看固定效應的顯著性
    ```
    

### 博士生專屬：把統計結果畫在圖上

這是 SPSS 做不到，但 R 可以讓你帥翻全場的功能。使用 `ggpubr`。

R

```
library(ggpubr)
library(ggplot2)

# 畫 Boxplot 並直接加上 p-value
ggboxplot(df, x = "Group", y = "Score", color = "Group") +
  stat_compare_means(method = "t.test") # 自動算 p 值並標在圖上
```
```
library(ggpubr)

# 指定你只想比較這兩組
my_comparisons <- list( c("Placebo", "PS150_Low"), c("Placebo", "PS150_High") )

ggboxplot(df, x = "Group", y = "Score", color = "Group") +
  stat_compare_means(
    method = "t.test",                # 強制使用 t-test
    comparisons = my_comparisons,     # 指定只比較這幾對
    label = "p.signif"                # 只顯示星號 (*, **) 而不是 p=0.012
  )
```
### 總結你的「武器庫」清單

要在實驗室推廣 R，或是讓自己用得順手，請務必安裝以下這個 **"Brain Science Starter Pack"**：

R

```
install.packages(c("tidyverse",  # 資料處理核心 (dplyr, ggplot2...)
                   "rstatix",    # 簡單好用的 T 檢定與 ANOVA
                   "afex",       # 學術級 ANOVA (對齊 SPSS)
                   "emmeans",    # 最強事後比較
                   "lme4",       # 混合模型 LMM
                   "lmerTest",   # LMM 的 p-value
                   "performance",# 模型健檢
                   "gtsummary",  # 畫 Table 1
                   "ggpubr"))    # 發表級繪圖
```


