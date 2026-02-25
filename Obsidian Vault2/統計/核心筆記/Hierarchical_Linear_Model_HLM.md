# 多層次模型 / 階層線性模型 (HLM)

> 🔗 返回：[[2. Statistical_Models_Map]]
> 📌 相關：[[LMM_Linear_Mixed_Model]]

---

## 一、定義

LMM 的另一種稱呼與應用形式。專門處理「嵌套資料 (Nested Data)」，如：學生嵌套於班級、病患嵌套於醫院。

|**項目**|**說明**|
|---|---|
|**別稱**|**分層線性模型 (Hierarchical Linear Model, HLM)**|
|**關係**|多水平模型 (MLM) 實際上是 **LMM 的一個子集或同義詞**，特別強調**巢狀結構**的應用。|
|**數據結構**|學生 (Level 1) 巢狀於 班級 (Level 2)，班級巢狀於 學校 (Level 3)。|
|**主要功能**|分析**不同層次 (Level)** 上的變異。|

---

## 二、核心概念

學生考試成績的變異可以分解為：
- 來自**學生個體**的變異 (Level 1)
- 來自**班級平均差異**的變異 (Level 2)

---

## 三、與 LMM 的關係

HLM 與 LMM 在數學上是相同的模型，差異在於應用的強調點：

- **LMM** 通常強調重複測量設計
- **HLM** 通常強調巢狀/階層結構

---

## 四、R 語言實作

```r
library(lme4)

# 二層模型：學生巢狀於班級
hlm_model <- lmer(score ~ treatment + (1 | class_id), data = df)

# 三層模型：學生巢狀於班級，班級巢狀於學校
hlm_model_3 <- lmer(score ~ treatment + (1 | school_id/class_id), data = df)

summary(hlm_model)
```
