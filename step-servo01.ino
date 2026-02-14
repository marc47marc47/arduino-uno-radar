#include <Unistep2.h>

// === 腳位定義 ===
// 步進馬達 (ULN2003 驅動板)
#define IN1 8
#define IN2 9
#define IN3 10
#define IN4 11

// 超音波感測器 (HC-SR04)
#define TRIG_PIN 2
#define ECHO_PIN 3

// === 馬達參數 ===
#define STEPS_PER_REV 4096  // 半步模式每圈步數
#define STEPS_180     2048  // 180 度所需步數
#define STEP_DELAY    1500  // 每步延遲 (微秒) — 從 1000 調慢到 1500

// === 量測參數 ===
#define SETTLE_MS     10    // 馬達停止後等待穩定的時間 (毫秒)
#define NUM_READINGS  3     // 每次取幾個讀數做中位數濾波
#define READING_GAP   3     // 每次讀數之間的間隔 (毫秒)

Unistep2 stepper(IN1, IN2, IN3, IN4, STEPS_PER_REV, STEP_DELAY);

// === 掃描狀態 ===
int currentAngle = 0;       // 目前角度 (0~180)
int direction = 1;           // 1=正轉(0→180), -1=反轉(180→0)
long currentStepPos = 0;     // 目前步數位置

// === 單次超音波測距 ===
float singleRead() {
  digitalWrite(TRIG_PIN, LOW);
  delayMicroseconds(2);
  digitalWrite(TRIG_PIN, HIGH);
  delayMicroseconds(10);
  digitalWrite(TRIG_PIN, LOW);

  long duration = pulseIn(ECHO_PIN, HIGH, 30000);  // 30ms 逾時

  if (duration == 0) return 0;
  float dist = duration / 58.0;
  if (dist > 100) return 0;
  return dist;
}

// === 中位數濾波測距 (取 3 次讀數的中間值) ===
int measureDistance() {
  float readings[NUM_READINGS];

  for (int i = 0; i < NUM_READINGS; i++) {
    readings[i] = singleRead();
    if (i < NUM_READINGS - 1) delay(READING_GAP);
  }

  // 簡易排序 (3 個元素)
  for (int i = 0; i < NUM_READINGS - 1; i++) {
    for (int j = i + 1; j < NUM_READINGS; j++) {
      if (readings[i] > readings[j]) {
        float tmp = readings[i];
        readings[i] = readings[j];
        readings[j] = tmp;
      }
    }
  }

  return (int)readings[NUM_READINGS / 2];  // 回傳中位數
}

void setup() {
  Serial.begin(9600);

  pinMode(TRIG_PIN, OUTPUT);
  pinMode(ECHO_PIN, INPUT);
}

void loop() {
  stepper.run();

  if (stepper.stepsToGo() == 0) {
    // 等待馬達振動穩定
    delay(SETTLE_MS);

    // 中位數濾波測距
    int dist = measureDistance();

    // 送出資料: "角度,距離."
    Serial.print(currentAngle);
    Serial.print(",");
    Serial.print(dist);
    Serial.println(".");

    // 計算下一個角度
    int nextAngle = currentAngle + direction;

    // 到達邊界就反轉
    if (nextAngle > 180) {
      direction = -1;
      nextAngle = currentAngle + direction;
      delay(300);
    } else if (nextAngle < 0) {
      direction = 1;
      nextAngle = currentAngle + direction;
      delay(300);
    }

    currentAngle = nextAngle;

    // 計算目標步數並移動（精確角度對位）
    long targetStepPos = (long)currentAngle * STEPS_180 / 180;
    long stepsToMove = targetStepPos - currentStepPos;
    currentStepPos = targetStepPos;
    stepper.move(stepsToMove);
  }
}
