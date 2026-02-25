
![[Pasted image 20251105133707.png]]

# Preprocessing
* 空間時間對位
* 提高訊躁比
![[Pasted image 20251105134100.png]]
DICOM: digital imaging and communications in medicine
NIFTI ( neuroimaging informatics technology initiative) .NII
DICOM --> NIFTI (去除病人受試者個人的資料，以及轉變成3D影像)
線上轉檔:  dcm2niix

## Realignment
* X Y Z
* Rotation: pitch, roll, yaw
定位標準通常是位移3mm或5mm以內，若位移太大可能會剔除資料
fMRI短時間的錄製中對於訊號品質的要求很高，因此只有短時間的錄製只要有大的motion，經常就是要重新掃描。

## Slice-timing
一次照影需要多時間採集因此需要對其時間序列

## Coreg (Coregistration)
對應到structure影像位置

## Segmentation
將大腦區分成: White, Gray, CSF

## Normalization
將功能性影像對到標準大腦
MNI space標準大腦
## Smoothing
* Reduce noise
* better signal, less fine detail
把雜訊稀釋掉，且雜訊很多都是高頻雜訊
salt and pepper 影像閃頻，可能是artifact
FWHM 半峰/高全寬（Full Width at Half Maximum）
決定解析度/像素量
對一個範圍做遮罩 捲積運算 (Convolution Operation)
### FWHM 半高全寬
在影像處理中，取得 FWHM 的「分佈」主要有兩種情況：**分析現有影像中的特徵**，或是**應用預先定義的高斯分佈**（例如模糊濾波器）。 

一、 分析現有影像特徵的分佈（測量 FWHM）

如果您想測量影像中某個特定亮點、邊緣或圖案的寬度（例如星點的 PSF、線條邊緣的模糊程度），您需要從影像資料中提取一個**一維的亮度或強度剖面曲線 (Profile Curve)**，然後計算該曲線的 FWHM。

取得分佈和計算 FWHM 的步驟如下：

1. **選取區域**: 在影像中找到您感興趣的特徵（例如一個光點或一條線）。
2. **提取剖面**: 沿著該特徵最寬或最強烈的方向，提取一系列像素的強度值。這會得到一個一維的數據序列（即「分佈」或曲線）。
3. **找到最大值**: 確定這個一維數據序列中的峰值（最大強度值）。
4. **計算半高**: 將最大值除以二，得到半高值。
5. **找到交叉點**: 在曲線上找到強度值等於這個「半高」值的兩個點。
6. **計算距離**: 計算這兩個點在橫軸上的距離，這個距離就是以**像素 (pixels)** 為單位的 FWHM。 

- **平滑/擬合**: 實際影像資料通常包含雜訊，曲線可能不平滑。為了獲得更準確的 FWHM，通常會使用**高斯函數擬合 (Gaussian Fitting)** 來將數據點擬合成一個理想的高斯曲線，然後從擬合出的高斯函數參數中計算 FWHM。
![[Pasted image 20251105140247.png]]



# Analysis
CONN toolbox


# Visualization

# Interpretation
