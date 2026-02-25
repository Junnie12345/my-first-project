## 概念
MRI影像出來的影像是dicom檔案，內含有protocol、受試者資訊等等非常完整
4D檔案，為一個時間有很多不同切片的檔案

dicom-->Nifti
dcm2nii

# 操作順序
1. dicom轉nii檔案 (.\dcm2nii 檔名 -->即可一次轉檔)
2. CONN開啟，new project->setup
3. 輸入設定值，Repetition Time (TR)值
4. import structure : T1 or T2 (one file for one subject)
5. functional (注意不同session)
6. condition: 比如有介入不同時期-->組內比較
7. 下方preprocessing -> defult(或其他)
8. select slice order: slice time
9. 設定信賴區間(defult)
10. Map, regularization: mni
11. smoothing : 6.8... (切片厚度的兩倍:3.4X2)
12.  covariates2 ->比較不同組別加權重，比如增加設定是否為年輕人
13. Denoise->done
14. analysis
	1. ALFF 原始; fALFF 比例
15. Result: 統計分析，設定p threshold(FDR correction)


Basic的部分可以特定調整某些受試者session不同(調整數列中特定值)

# 結構影像

# fMRI影像
4D檔案，為一個時間有很多不同切片的檔案
將其轉換成一個時間一整個頭的影像(好幾個時間)才能分析
