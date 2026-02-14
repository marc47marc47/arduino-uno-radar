# Arduino 超音波雷達掃描器 開發文檔

> 專案狀態：**Phase 4 完成** | 最後更新：2026-02-15

## 1. 專案概述

利用 **28BYJ-48 步進馬達** 搭配 **HC-SR04 超音波感測器**，製作一個 180 度的雷達掃描器。步進馬達帶動超音波模組旋轉，每轉一步就測量一次距離，再透過 Serial 將角度與距離資料傳送到電腦端，由 **Processing** 程式繪製出雷達掃描畫面。

### 偵測規格

| 項目 | 規格 |
|------|------|
| 掃描角度 | 180 度 |
| 偵測距離 | 2 cm ~ 100 cm |
| 測量精度 | 約 3 mm（中位數濾波後更穩定） |
| 掃描方式 | 步進馬達正轉 180 度後反轉 180 度，來回掃描 |
| 掃描解析度 | 每 1 度量測一次（共 181 個量測點） |
| 單次掃描時間 | 約 15~25 秒（視環境中物體數量而定） |

---

## 2. 硬體清單

| 元件 | 型號 / 規格 | 數量 | 備註 |
|------|-------------|------|------|
| 微控制器 | Arduino UNO / Nano | 1 | 已有 |
| 步進馬達 | 28BYJ-48 (5V) | 1 | 已有 |
| 馬達驅動板 | ULN2003 | 1 | 已有 |
| 超音波感測器 | HC-SR04 | 1 | 已有 |
| 外部電源 | 5V 電源供應器 / 行動電源 | 1 | 為步進馬達供電 |
| 連接線 | 杜邦線 (公對母、公對公) | 若干 | |
| USB 線 | Type-B / Mini USB | 1 | Arduino 連接電腦用 |

---

## 3. 接線圖

### 3.1 線路示意圖

```
                    ┌─────────────┐
                    │  Arduino    │
                    │  UNO/Nano   │
                    │             │
  HC-SR04          │             │         ULN2003 驅動板
 ┌────────┐        │             │        ┌──────────────┐
 │ VCC  ──┼────────┤ 5V          │        │              │
 │ Trig ──┼────────┤ D2      D8 ├────────┤ IN1          │
 │ Echo ──┼────────┤ D3      D9 ├────────┤ IN2          │
 │ GND  ──┼────────┤ GND    D10 ├────────┤ IN3          │
 └────────┘        │        D11 ├────────┤ IN4          │
                    │             │        │          [M] ├──→ 28BYJ-48
                    │         GND ├────────┤ GND (-)      │     步進馬達
                    └─────────────┘        │ VDD (+) ─────┤──→ 外部 5V 電源
                                           └──────────────┘
```

### 3.2 接線總表

| 元件 | 元件腳位 | Arduino 腳位 | 說明 |
|------|---------|-------------|------|
| HC-SR04 | VCC | 5V | 感測器供電 |
| HC-SR04 | Trig | D2 | 觸發腳位 |
| HC-SR04 | Echo | D3 | 回波腳位 |
| HC-SR04 | GND | GND | 接地 |
| ULN2003 | IN1 | D8 | 馬達線圈控制 |
| ULN2003 | IN2 | D9 | 馬達線圈控制 |
| ULN2003 | IN3 | D10 | 馬達線圈控制 |
| ULN2003 | IN4 | D11 | 馬達線圈控制 |
| ULN2003 | GND (-) | GND | 與 Arduino 共地 |
| ULN2003 | VDD (+) | 外部 5V | 馬達獨立供電 |
| 28BYJ-48 | 5pin 插頭 | ULN2003 插座 | 直接插入驅動板 |

### 3.3 注意事項

- **共地必要**：Arduino、ULN2003、HC-SR04 三者的 GND 必須全部連接在一起
- **外部供電**：ULN2003 的 VDD 必須使用外部 5V 電源，步進馬達耗電約 240mA，超過 Arduino 5V 腳位的供電能力
- **HC-SR04 固定方式**：將超音波模組用膠或支架固定在步進馬達的轉軸上，使其隨馬達旋轉

---

## 4. 軟體需求

| 軟體 | 用途 | 下載來源 |
|------|------|---------|
| Arduino IDE | 撰寫並上傳 Arduino 程式碼 | https://www.arduino.cc/en/software |
| Processing 4.5+ | 繪製雷達掃描 GUI 畫面 | https://processing.org/download |
| Unistep2 函式庫 | 非阻塞式步進馬達控制 | Arduino IDE Library Manager |

### Processing 安裝方式

1. 從 https://processing.org/download 下載 Windows 版 `.zip`
2. 解壓縮到任意位置（例如 `C:\Processing`）
3. 雙擊 `processing.exe` 啟動（免安裝）

---

## 5. 專案檔案結構

```
step-servo01/
├── step-servo01.ino          ← Arduino 主程式（掃描 + 中位數濾波測距）
├── develop-radar.md           ← 本開發文檔
└── RadarDisplay/
    └── RadarDisplay.pde       ← Processing 雷達 GUI 程式
```

---

## 6. 開發架構

### 6.1 系統流程

```
[28BYJ-48 步進馬達] ←── 控制旋轉 ──← [Arduino]
[HC-SR04 超音波]    ──→ 距離資料 ──→ [Arduino]
                                        │
                                   Serial 9600 (USB)
                                        │
                                        ▼
                                  [Processing]
                                  繪製雷達 GUI
```

### 6.2 Arduino 端邏輯

```
初始化:
  Serial 鮑率 9600
  步進馬達: IN1~IN4 = D8~D11, 4096 步/圈, 1500μs/步
  超音波: Trig = D2, Echo = D3

主迴圈:
  1. stepper.run() 驅動馬達
  2. 馬達到位後 (stepsToGo == 0):
     a. 等待 10ms 穩定
     b. 中位數濾波測距 (取 3 次讀數的中間值)
     c. 透過 Serial 送出 "角度,距離."
     d. 計算下一個角度 (±1 度)
     e. 到達 0° 或 180° 時反轉方向
     f. 計算目標步數，驅動馬達移動
```

### 6.3 Serial 通訊格式

Arduino 透過 Serial 傳送的資料格式：

```
角度,距離.
```

- **角度**：0 ~ 180（整數，單位：度）
- **距離**：0 ~ 100（整數，單位：cm）
- 以 `.` 作為每筆資料的結尾，`\n` 換行

範例：
```
45,30.
46,32.
47,0.
```
> `0` 表示該角度未偵測到物體（超出範圍）

### 6.4 Processing 端邏輯

```
初始化:
  開啟 Serial port (COM3, 9600)
  載入中文字型 (Microsoft JhengHei)
  設定視窗 800x460

繪製迴圈 (每幀):
  1. 繪製深綠底色
  2. 繪製雷達格線 (同心圓弧 + 角度線 + 標籤)
  3. 繪製掃描區域填色 (綠色扇形漸層)
  4. 繪製物體輪廓連線 (相鄰偵測點橘色連線)
  5. 繪製偵測物體 (三層光暈紅點 + 距離標籤)
  6. 繪製掃描主線 (三層光暈綠線)
  7. 繪製中心脈衝點 (呼吸燈效果)
  8. 繪製資訊面板 (角度、距離、偵測點數、方向、狀態燈)

Serial 接收:
  bufferUntil('\n') → 解析 "角度,距離." → 更新 distances[] 與 scanTimes[]
```

---

## 7. 元件參數

### 7.1 28BYJ-48 步進馬達

| 參數 | 數值 |
|------|------|
| 工作電壓 | 5V DC |
| 相數 | 4 相 |
| 步進角 | 5.625 度 (全步) |
| 減速比 | 1:64 |
| 半步模式每圈步數 | 4096 步 |
| 全步模式每圈步數 | 2048 步 |
| 電流消耗 | 約 240 mA |

### 角度換算

掃描 180 度所需步數：
- 半步模式：4096 / 2 = **2048 步**

每步對應的角度：
- 半步模式：180 / 2048 ≈ **0.088 度/步**

每 1 度約需 **11.4 步**（實際使用精確步數計算：`角度 * 2048 / 180`）

### 7.2 HC-SR04 超音波感測器

| 參數 | 數值 |
|------|------|
| 工作電壓 | 5V DC |
| 工作電流 | 15 mA |
| 測量範圍 | 2 cm ~ 450 cm |
| 精度 | 約 3 mm |
| 測量角度 | 約 15 度錐形 |
| 觸發信號 | 10 μs 的 HIGH 脈衝 |

### 距離計算公式

```
距離 (cm) = (Echo HIGH 持續時間 μs) / 58
```

---

## 8. Phase 4 調校參數

### 8.1 Arduino 端可調參數

| 參數 | 定義位置 | 目前值 | 說明 |
|------|---------|--------|------|
| `STEP_DELAY` | step-servo01.ino:17 | 1500 μs | 馬達每步延遲，越大越慢越穩 |
| `SETTLE_MS` | step-servo01.ino:20 | 10 ms | 馬達停止後等待穩定時間 |
| `NUM_READINGS` | step-servo01.ino:21 | 3 | 中位數濾波取樣次數 |
| `READING_GAP` | step-servo01.ino:22 | 3 ms | 每次取樣之間的間隔 |

### 8.2 Processing 端可調參數

| 參數 | 定義位置 | 目前值 | 說明 |
|------|---------|--------|------|
| `FADE_MS` | RadarDisplay.pde:15 | 28000 ms | 物體淡出時間，建議接近一次掃描週期 |
| `MAX_DIST_CM` | RadarDisplay.pde:16 | 100 cm | 最大偵測距離 |
| `TRAIL_WIDTH` | RadarDisplay.pde:17 | 20 度 | 掃描線後方的拖尾寬度 |
| `Serial.list()` | RadarDisplay.pde:34 | [1] (COM3) | Serial Port 索引，依電腦環境調整 |

### 8.3 調校紀錄

| 問題 | 原因 | 解決方式 |
|------|------|---------|
| 掃描速度太快 | STEP_DELAY 過小 (1000μs) | 調整為 1500μs |
| 距離讀數不穩定 | 單次讀取容易受雜訊干擾 | 改用中位數濾波 (3 次取中間值) |
| 馬達振動影響量測 | 量測時馬達尚未完全靜止 | 加入 10ms 穩定等待 |
| Processing 中文亂碼 | 預設字型不支援中文 | 使用 createFont("Microsoft JhengHei") |
| Serial Port 連不上 | 預設選到 COM1 而非 COM3 | 改用 Serial.list()[1] |

---

## 9. 開發進度

### Phase 1：硬體驗證 ✅

- [x] 確認步進馬達正反轉正常
- [x] 接上 HC-SR04，測試超音波距離量測功能
- [x] 將 HC-SR04 固定在步進馬達轉軸上

### Phase 2：Arduino 程式開發 ✅

- [x] 整合步進馬達控制與超音波量測
- [x] 實作 180 度來回掃描邏輯
- [x] 透過 Serial 輸出 "角度,距離." 資料
- [x] 在 Serial Monitor 中驗證資料格式正確
- [x] 精確角度對位（使用步數計算避免累積誤差）

### Phase 3：Processing 雷達 GUI ✅

- [x] 建立 Processing 專案 (RadarDisplay/)
- [x] 繪製雷達底圖（同心圓弧、角度刻度線、距離標籤）
- [x] 實作 Serial 資料接收與解析
- [x] 繪製旋轉掃描線動畫
- [x] 繪製偵測到的物體標記（紅色圓點 + 時間淡出）
- [x] 顯示即時角度與距離數值
- [x] 載入中文字型解決顯示問題

### Phase 4：整合測試與調校 ✅

- [x] 調整步進馬達速度 (STEP_DELAY: 1000 → 1500 μs)
- [x] 加入中位數濾波提升測距精度 (3 次取中間值)
- [x] 加入馬達穩定等待 (10ms settle time)
- [x] 優化 Processing 顯示效果：
  - [x] 掃描區域綠色扇形填色
  - [x] 掃描線三層光暈效果
  - [x] 中心脈衝呼吸燈
  - [x] 物體輪廓橘色連線
  - [x] 物體三層光暈 + 距離標籤
  - [x] 資訊面板（偵測點數、掃描方向、閃爍狀態燈）
- [x] 實際環境測試通過

---

## 10. 使用方式

### 啟動步驟

1. 接好所有硬體線路（參照第 3 節接線圖）
2. 用 Arduino IDE 開啟 `step-servo01.ino`，上傳至 Arduino
3. **關閉** Arduino IDE 的 Serial Monitor
4. 用 Processing 開啟 `RadarDisplay/RadarDisplay.pde`
5. 按下 **▶ Play**，雷達畫面即開始運作

### 注意事項

- Arduino IDE 的 Serial Monitor 和 Processing **不能同時開啟**，兩者共用同一個 COM Port
- 如果 Processing 連不上，檢查 `Serial.list()` 索引是否正確（查看主控台輸出的 Port 列表）
- 按 Processing 的 **■ Stop** 可停止程式，Arduino 會繼續運轉直到斷電

---

## 11. 參考資源

- [Hackaday.io — Arduino Ultrasonic Radar](https://hackaday.io/project/178208-arduino-ultrasonic-radar) — 完整專案含線路圖
- [LastMinuteEngineers — 28BYJ-48 教學](https://lastminuteengineers.com/28byj48-stepper-motor-arduino-tutorial/) — 步進馬達詳細接線圖
- [ArduinoGetStarted — 28BYJ-48 + ULN2003](https://arduinogetstarted.com/tutorials/arduino-controls-28byj-48-stepper-motor-using-uln2003-driver) — 圖文接線教學
- [HackMD — Arduino 超音波 & 步進馬達講義](https://hackmd.io/@us4sw9duT5aIGbNJpCM_-Q/r1cFVAulY) — 中文教學資源
- [Random Nerd Tutorials — HC-SR04 完整指南](https://randomnerdtutorials.com/complete-guide-for-ultrasonic-sensor-hc-sr04/) — 超音波感測器教學
- [Processing 官方網站](https://processing.org/) — Processing 下載與文件
