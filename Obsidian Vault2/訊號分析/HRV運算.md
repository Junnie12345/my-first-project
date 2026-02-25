1. 抓R pick
2. 計算 R-R interval
3. 去除spike (與前面三者差異過大的，可以使用斜率法，差值法)
4. 去除3倍標準差外的數值
5. 得到N-N
6. 計算 時域數值
7. 設定window length (60s/30s)
8. resample 到68.5  (因傅立葉轉換需要是2的N次方)
9. haming window
10. FFT
11. 計算PSD