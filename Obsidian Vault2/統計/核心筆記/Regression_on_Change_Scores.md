# 改變量迴歸 (Regression on Change Scores) 🌟

> 🔗 返回：[[2. Statistical_Models_Map]]
> 📌 相關：[[Traditional_ANCOVA]] | [[Simple_Multiple_Regression]]

---

## 一、定義

前/後測黃金標準分析法。數學上與 ANCOVA 等價。

- **依變項**為「差值 (Post - Pre)」
- 在模型中**控制前測分數**（控制基期效應）
- 可額外加入其他動態改變量（如 $\Delta MEQ$）來探討機轉

---

## 二、公式

$$\Delta Y = \beta_0 + \beta_1 \cdot \text{Group} + \beta_2 \cdot \Delta X + \beta_3 \cdot Y_{\text{pre}} + \epsilon$$

其中：
- $\Delta Y = Y_{\text{post}} - Y_{\text{pre}}$（目標量表改變量）
- $\Delta X = X_{\text{post}} - X_{\text{pre}}$（控制變項改變量）
- $Y_{\text{pre}}$（基線值，控制基期效應）

---

## 三、適用情境

- 只有兩個時間點（前測、後測）
- 想驗證組別效果是否顯著
- 想同時探討某個中介/控制變項的動態變化

---

## 四、R 語言實作

（待補充）

---

## 五、結果解讀

- 看 **Group** 的 $\beta$ 與 p-value：在控制了基線與其他改變量後，組別是否仍有顯著差異
- 看 $\Delta X$ 的 $\beta$：控制變項的變化是否與目標量表的變化相關
