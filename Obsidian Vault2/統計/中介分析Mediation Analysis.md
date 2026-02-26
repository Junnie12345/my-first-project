![[Pasted image 20260225191531.png]]
### 第一部分：理論核心 —— 打開「黑盒子」

傳統的回歸分析或 ANOVA 只關心一件事：**X (介入) 是否影響了 Y (結果)？** 這就像一個黑盒子，我們知道吃藥病會好，但不知道為什麼。

中介分析就是要打開這個黑盒子，引入第三個變數 **M (中介變項)**：

我們想證明：**X 其實是先改變了 M，然後 M 的改變才導致了 Y 的改變。**

在標準的中介模型中，有幾條您必須認識的「神聖路徑 (Paths)」：

1. **路徑 $c$ (總效應 Total Effect)：** 不管任何中間過程，X 對 Y 的總體影響力。（例如：您的治療組對比對照組，整體睡眠改善了多少）。
    
2. **路徑 $a$：** X 對 M 的影響。（例如：您的治療組，是否真的顯著改變了病人的作息 $\Delta MEQ$）。
    
3. **路徑 $b$：** 在控制了 X 的情況下，M 對 Y 的影響。（例如：作息改變 $\Delta MEQ$ 本身，是否能預測睡眠品質 $\Delta PSQI$ 的改善）。
    
4. **路徑 $c'$ (直接效應 Direct Effect)：** 當我們把 M (作息改變) 的功勞「扣除」之後，X 對 Y 還剩下多少影響力？
    

**🔥 中介分析的終極目標：**

證明 **間接效應 (Indirect Effect)** 是存在的。

數學上，間接效應大小 $= a \times b$ 或者 $= c - c'$。

---

### 第二部分：檢定方法的演進 (舊觀念 vs. 新黃金標準)

這部分非常重要，因為很多老教授還停留在舊觀念，但 SCI 期刊現在要求的是新標準。

#### ❌ 舊標準：Baron & Kenny 四步驟法則 (1986)

以前的人認為，要做中介分析，**路徑 $c$ (總效應) 必須先顯著！** 如果介入對結果沒有整體效果，就不准做中介。這也是為什麼我之前說您的數據可能做不了中介，因為您的 Group 對 $\Delta PSQI$ 不顯著。

#### ✅ 新黃金標準：拔靴法 (Bootstrapping) (Hayes, 2009 起)

現在的統計學家發現，有時候 $X$ 對 $Y$ 會有兩個互相抵銷的路徑（例如：藥物一方面改善睡眠，一方面又引發腸胃不適導致失眠），這會讓總效應 $c$ 看起來不顯著。

因此，現在的 SCI 期刊**不再強求總效應 $c$ 必須顯著**。

現在的唯一標準是：**只要證明 $a \times b$ (間接效應) 顯著不等於 0 即可。**

我們透過一種叫 **Bootstrapping (拔靴法/自助重抽法)** 的電腦模擬技術，隨機抽樣您的數據 5000 次，來算出 $a \times b$ 的 95% 信賴區間 (CI)。**只要這個 CI 沒有跨過 0，中介效應就成立！**

---

### 第三部分：應用端 —— 在 R 語言中如何執行？

在 R 裡面執行中介分析出乎意料地簡單。主流有兩個套件：`lavaan` (結構方程式) 和 `mediation`。對於您的臨床數據，我強烈推薦使用 **`mediation` 套件**，語法極度直觀。

**步驟示範 (以您的猜想為例)：**

- $X$ = `Group` (介入)
    
- $M$ = `Delta_MEQ` (作息改變)
    
- $Y$ = `Delta_PSQI` (睡眠改善)
    

R

```
# 安裝並載入套件
# install.packages("mediation")
library(mediation)

# 第一步：建立 路徑 a 的回歸模型 (X 預測 M)
# 這裡要放 Baseline_MEQ 來控制前測
fit.mediator <- lm(Delta_MEQ ~ Group + Baseline_MEQ, data = your_data)

# 第二步：建立 路徑 b 和 c' 的回歸模型 (X 和 M 一起預測 Y)
# 這裡要放 Baseline_PSQI 來控制前測
fit.dv <- lm(Delta_PSQI ~ Group + Delta_MEQ + Baseline_PSQI, data = your_data)

# 第三步：將兩個模型放入 mediate() 函數，並設定 boot = TRUE (啟用拔靴法)
results <- mediate(fit.mediator, fit.dv, treat = "Group", mediator = "Delta_MEQ", boot = TRUE, sims = 5000)

# 查看結果報表
summary(results)
```

**報表怎麼看？**

跑完 `summary(results)` 後，您只需要看四行核心數據：

1. **ACME (Average Causal Mediation Effects)：** 這就是間接效應 ($a \times b$)。看它的 p-value 是否小於 0.05。
    
2. **ADE (Average Direct Effects)：** 這就是直接效應 ($c'$路徑)。
    
3. **Total Effect：** 這就是總效應 ($c$路徑)。
    
4. **Prop. Mediated：** 這非常酷！它會告訴您「Y 的改善中，有百分之幾 (%) 是歸功於 M 的改變」。
    

---

### 💡 理論與應用的總結

中介分析的核心精神，就是回答**「Why it works (為什麼有效)」**。 即使您的整體治療效果 (Group) 在某些指標上看起來不顯著，但如果您能透過中介分析證明：「那些**成功被改變作息**的病人，他們的睡眠確實得到了顯著改善」，這依然是一個非常強大且具有臨床價值的發現！