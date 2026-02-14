import processing.serial.*;

Serial myPort;
PFont font;

// === 雷達資料 ===
int currentAngle = 0;
int currentDist  = 0;
int scanDir      = 1;                 // 掃描方向: 1=正向, -1=反向
int[] distances      = new int[181];  // 每個角度的距離 (cm)
long[] scanTimes     = new long[181]; // 每個角度最後掃描時間 (ms)
int objectCount      = 0;             // 偵測到物體的角度數

// === 可調參數 ===
final int FADE_MS      = 28000;  // 物體淡出時間 (毫秒)
final int MAX_DIST_CM  = 100;    // 最大偵測距離 (cm)
final int TRAIL_WIDTH  = 20;     // 掃描線拖尾寬度 (角度)

void setup() {
  size(800, 460);
  smooth();
  background(0);

  // 載入支援中文的字型
  font = createFont("Microsoft JhengHei", 16, true);
  textFont(font);

  // 印出可用的 Serial Port
  println("=== 可用的 Serial Port ===");
  printArray(Serial.list());
  println("==========================");

  // ★ Arduino 在 COM3 → Serial.list()[1] ★
  String portName = Serial.list()[1];
  println("使用: " + portName);

  myPort = new Serial(this, portName, 9600);
  myPort.bufferUntil('\n');
}

void draw() {
  background(0, 8, 0);  // 深綠底色

  int cx = width / 2;
  int cy = height - 30;
  int r  = cy - 40;

  drawRadarGrid(cx, cy, r);
  drawScanArea(cx, cy, r);
  drawObjectOutline(cx, cy, r);
  drawObjects(cx, cy, r);
  drawScanLine(cx, cy, r);
  drawCenterDot(cx, cy);
  drawInfo();
}

// ============================================================
//  Serial 資料解析
// ============================================================
void serialEvent(Serial p) {
  String raw = p.readStringUntil('\n');
  if (raw == null) return;
  raw = raw.trim();

  if (raw.endsWith(".")) {
    raw = raw.substring(0, raw.length() - 1);
  }

  String[] parts = split(raw, ',');
  if (parts.length == 2) {
    int a = int(parts[0]);
    int d = int(parts[1]);
    if (a >= 0 && a <= 180) {
      if (a != currentAngle) {
        scanDir = (a > currentAngle) ? 1 : -1;
      }
      currentAngle = a;
      currentDist  = d;
      distances[a] = d;
      scanTimes[a] = millis();
    }
  }
}

// ============================================================
//  繪製雷達格線
// ============================================================
void drawRadarGrid(int cx, int cy, int r) {
  noFill();
  strokeWeight(1);

  // 同心圓弧 (每 25cm 一圈)
  for (int i = 1; i <= 4; i++) {
    float arcR = r * i / 4.0;
    stroke(0, 80, 0, 40);
    arc(cx, cy, arcR * 2, arcR * 2, PI, TWO_PI);
  }

  // 角度刻度線 (每 30 度)
  for (int a = 0; a <= 180; a += 30) {
    float x = cx - r * cos(radians(a));
    float y = cy - r * sin(radians(a));
    stroke(0, 80, 0, 30);
    line(cx, cy, x, y);
  }

  // 底線
  stroke(0, 100, 0, 60);
  line(cx - r - 10, cy, cx + r + 10, cy);

  // 距離標籤
  fill(0, 120, 0, 90);
  noStroke();
  textSize(10);
  textAlign(LEFT, TOP);
  for (int i = 1; i <= 4; i++) {
    float labelX = cx + r * i / 4.0 + 3;
    text(i * 25 + "cm", labelX, cy + 3);
  }

  // 角度標籤
  textAlign(CENTER, CENTER);
  for (int a = 0; a <= 180; a += 30) {
    float lx = cx - (r + 20) * cos(radians(a));
    float ly = cy - (r + 20) * sin(radians(a));
    text(a + "\u00B0", lx, ly);
  }
}

// ============================================================
//  [新] 掃描區域填色 (綠色扇形漸層)
// ============================================================
void drawScanArea(int cx, int cy, int r) {
  noStroke();
  for (int i = TRAIL_WIDTH; i >= 1; i--) {
    int a1 = currentAngle - i * scanDir;
    int a2 = currentAngle - (i - 1) * scanDir;
    if (a1 < 0 || a1 > 180 || a2 < 0 || a2 > 180) continue;

    float alpha = map(i, TRAIL_WIDTH, 1, 3, 35);
    fill(0, 255, 0, alpha);

    float x1 = cx - r * cos(radians(a1));
    float y1 = cy - r * sin(radians(a1));
    float x2 = cx - r * cos(radians(a2));
    float y2 = cy - r * sin(radians(a2));

    triangle(cx, cy, x1, y1, x2, y2);
  }
}

// ============================================================
//  繪製掃描主線 (亮綠色 + 光暈)
// ============================================================
void drawScanLine(int cx, int cy, int r) {
  float x = cx - r * cos(radians(currentAngle));
  float y = cy - r * sin(radians(currentAngle));

  // 外層光暈
  stroke(0, 255, 0, 40);
  strokeWeight(6);
  line(cx, cy, x, y);

  // 中層
  stroke(0, 255, 0, 100);
  strokeWeight(3);
  line(cx, cy, x, y);

  // 核心亮線
  stroke(0, 255, 0, 230);
  strokeWeight(1);
  line(cx, cy, x, y);
}

// ============================================================
//  [新] 中心脈衝點
// ============================================================
void drawCenterDot(int cx, int cy) {
  float pulse = sin(millis() / 300.0) * 0.3 + 0.7;  // 0.4 ~ 1.0 脈動
  noStroke();

  fill(0, 255, 0, 30 * pulse);
  ellipse(cx, cy, 20, 20);

  fill(0, 255, 0, 120 * pulse);
  ellipse(cx, cy, 8, 8);

  fill(0, 255, 0, 220);
  ellipse(cx, cy, 3, 3);
}

// ============================================================
//  [新] 物體輪廓連線 (相鄰偵測點之間畫線)
// ============================================================
void drawObjectOutline(int cx, int cy, int r) {
  long now = millis();
  int prevA = -10;  // 上一個有物體的角度
  float prevX = 0, prevY = 0;
  float prevAlpha = 0;

  for (int a = 0; a <= 180; a++) {
    int d = distances[a];
    if (d <= 0 || d > MAX_DIST_CM) continue;

    long elapsed = now - scanTimes[a];
    if (elapsed > FADE_MS) continue;

    float alpha = map(elapsed, 0, FADE_MS, 200, 0);
    float objR = map(d, 0, MAX_DIST_CM, 0, r);
    float x = cx - objR * cos(radians(a));
    float y = cy - objR * sin(radians(a));

    // 如果與上一個偵測點相距 3 度以內，畫連線
    if ((a - prevA) <= 3) {
      float lineAlpha = min(alpha, prevAlpha) * 0.6;
      stroke(255, 120, 50, lineAlpha);
      strokeWeight(1.5);
      line(prevX, prevY, x, y);
    }

    prevA = a;
    prevX = x;
    prevY = y;
    prevAlpha = alpha;
  }
}

// ============================================================
//  繪製偵測到的物體 (紅色圓點 + 光暈 + 距離標籤)
// ============================================================
void drawObjects(int cx, int cy, int r) {
  long now = millis();
  noStroke();
  objectCount = 0;

  for (int a = 0; a <= 180; a++) {
    int d = distances[a];
    if (d <= 0 || d > MAX_DIST_CM) continue;

    long elapsed = now - scanTimes[a];
    if (elapsed > FADE_MS) continue;

    objectCount++;
    float alpha = map(elapsed, 0, FADE_MS, 255, 0);
    float objR  = map(d, 0, MAX_DIST_CM, 0, r);
    float x = cx - objR * cos(radians(a));
    float y = cy - objR * sin(radians(a));

    // 外層光暈 (大)
    fill(255, 60, 60, alpha * 0.15);
    ellipse(x, y, 22, 22);

    // 中層光暈
    fill(255, 60, 60, alpha * 0.35);
    ellipse(x, y, 12, 12);

    // 核心亮點
    fill(255, 100, 80, alpha);
    ellipse(x, y, 6, 6);

    // 在掃描線附近的物體顯示距離標籤
    if (abs(a - currentAngle) <= 2 && d > 0) {
      fill(255, 255, 100, 220);
      textSize(11);
      textAlign(LEFT, BOTTOM);
      text(d + "cm", x + 10, y - 5);
    }
  }
}

// ============================================================
//  顯示資訊面板
// ============================================================
void drawInfo() {
  // 左上角 - 即時數據
  fill(0, 255, 0);
  textSize(14);
  textAlign(LEFT, TOP);
  text("角度: " + currentAngle + "\u00B0", 10, 10);
  text("距離: " + (currentDist > 0 ? currentDist + " cm" : "---"), 10, 30);
  text("偵測點: " + objectCount, 10, 50);

  // 方向指示
  fill(0, 200, 0, 150);
  textSize(11);
  text("方向: " + (scanDir > 0 ? ">>> 正掃" : "<<< 回掃"), 10, 70);

  // 右上角 - 標題
  fill(0, 255, 0);
  textAlign(RIGHT, TOP);
  textSize(16);
  text("超音波雷達掃描器", width - 10, 10);

  textSize(11);
  fill(0, 150, 0, 150);
  text("28BYJ-48 + HC-SR04", width - 10, 32);

  // 右下角 - 狀態
  fill(0, 180, 0, 120);
  textSize(10);
  textAlign(RIGHT, BOTTOM);
  text("SCANNING", width - 10, height - 5);

  // 狀態閃爍指示燈
  float blink = sin(millis() / 500.0);
  if (blink > 0) {
    noStroke();
    fill(0, 255, 0, 180);
    ellipse(width - 70, height - 10, 6, 6);
  }
}
