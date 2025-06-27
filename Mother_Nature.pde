import java.util.HashSet;
import java.util.HashMap;
import processing.sound.*;

// --- CONFIGURATION ---
int PIXEL_SCALE = 5;
int ACTIONS_PER_FRAME = 5;
float REPAIR_CHANCE = 0.5f;
float HOUSE_CHANCE = 0.3f;
float MAX_URBAN_HEALTH = 255.0f;
float DAMAGE_PER_EXPOSED_SIDE = 0.5f;

// --- VINE CONFIGURATION ---
float VINE_SPAWN_CHANCE = 0.1f;
int VINE_LIFESPAN = 150;
float VINE_DAMAGE = 5.0f;
float VINE_WOBBLE = 0.6f;

// --- PROCEDURAL NATURE CONFIGURATION ---
float GRASS_NOISE_SCALE = 0.05f;
float MOSS_NOISE_SCALE = 0.02f;
float PEBBLE_NOISE_SCALE = 0.8f;

float MOSS_THRESHOLD = 0.35f;
float PEBBLE_THRESHOLD = 0.70f;

// --- DYNAMIC GRAVEL CONFIGURATION ---
float GRAVEL_AURA_RADIUS = 4.0f;      // How far (in cells) the gravel effect spreads from a building.
float GRAVEL_BUILD_RATE = 0.05f;      // How quickly gravel appears under buildings.
float GRAVEL_DECAY_RATE = 0.01f;      // How quickly gravel fades when buildings are gone.
color GRAVEL_COLOR_DARK = color(85, 80, 75);
color GRAVEL_COLOR_LIGHT = color(130, 125, 120);

// --- TOP-DOWN VARIATION CONFIGURATION (NO WATER) ---
float ELEVATION_NOISE_SCALE = 0.008f;
float SHADING_STRENGTH = 0.5f;

// --- INTERNAL SPREAD CONFIGURATION ---
float INTERNAL_SPREAD_CHANCE = 0.5f;
float INTERNAL_SPREAD_STRENGTH = 0.1f;

// --- AUDIO STATE ---
SinOsc humOscillator;      // Generates the low, continuous hum.
LowPass whistleFilter;     // Dedicated filter for the whistle.
LowPass clankFilter;       // Dedicated filter for the clank sound.

// <<< REMOVED: Whistle timer variables are no longer needed.

// --- SIMULATION STATE ---
PGraphics backgroundBuffer;
float[][] gravelGrid;
int[][] grid;
color[][] colorGrid;
int[][] houseGrid;
float[][] overgrowthGrid;
ArrayList<Factory> factories;
Nature nature;

int gridWidth;
int gridHeight;

// --- SETUP ---
void setup() {
    size(800, 600);
    gridWidth = width / PIXEL_SCALE;
    gridHeight = height / PIXEL_SCALE;

    // Initialize all the simulation state objects
    grid = new int[gridWidth][gridHeight];
    colorGrid = new color[gridWidth][gridHeight];
    houseGrid = new int[gridWidth][gridHeight];
    overgrowthGrid = new float[gridWidth][gridHeight];
    gravelGrid = new float[gridWidth][gridHeight];
    nature = new Nature();

    factories = new ArrayList<Factory>();
    factories.add(new Factory(1, 150 / PIXEL_SCALE, 150 / PIXEL_SCALE));
    factories.add(new Factory(2, 650 / PIXEL_SCALE, 150 / PIXEL_SCALE));
    factories.add(new Factory(3, 150 / PIXEL_SCALE, 450 / PIXEL_SCALE));
    factories.add(new Factory(4, 650 / PIXEL_SCALE, 450 / PIXEL_SCALE));
    factories.add(new Factory(5, 400 / PIXEL_SCALE, 150 / PIXEL_SCALE));
    factories.add(new Factory(6, 400 / PIXEL_SCALE, 450 / PIXEL_SCALE));

    // Render the static background
    backgroundBuffer = createGraphics(width, height);
    renderStaticBackground();

    // Set the initial state of the grid for the factories
    for(Factory f : factories) {
        int x = (int)f.location.x;
        int y = (int)f.location.y;
        if(x >= 0 && x < gridWidth && y >= 0 && y < gridHeight) {
            grid[x][y] = f.id;
            colorGrid[x][y] = color(80);
            overgrowthGrid[x][y] = MAX_URBAN_HEALTH;
            f.activeEdge.add(f.location);
        }
    }
    
    // --- INITIALIZE AUDIO ---
    // Setup the low hum
    humOscillator = new SinOsc(this);
    humOscillator.freq(50);
    humOscillator.amp(0);
    humOscillator.play();

    // Setup the dedicated audio effect objects.
    whistleFilter = new LowPass(this);
    clankFilter = new LowPass(this);
}

// --- DRAW ---
void draw() {
    ArrayList<PVector> newBuildingsThisFrame = new ArrayList<PVector>();

    // --- FACTORY ACTIONS (Spread and Repair) ---
    for (Factory f : factories) {
        if (!f.isActive) continue;

        for(int i = 0; i < ACTIONS_PER_FRAME; i++){
            if (random(1) < REPAIR_CHANCE) {
                f.repairCell();
            } else {
                if(f.activeEdge.isEmpty()) continue;
                PVector edgePixelToSpreadFrom = chooseEdgePixelByDistance(f);
                if (edgePixelToSpreadFrom == null) continue;
                ArrayList<PVector> neighbors = getAnyGrassNeighbors(edgePixelToSpreadFrom);
                if(!neighbors.isEmpty()){
                    PVector neighborToConvert = chooseNeighborOrganically(neighbors, edgePixelToSpreadFrom, f);
                    if (neighborToConvert == null) continue;
                    int nx = (int)neighborToConvert.x;
                    int ny = (int)neighborToConvert.y;
                    float newBrightness = 80 + random(-10, 10);
                    newBrightness = constrain(newBrightness, 70, 90);
                    grid[nx][ny] = f.id;
                    colorGrid[nx][ny] = color(newBrightness);
                    overgrowthGrid[nx][ny] = MAX_URBAN_HEALTH;
                    f.activeEdge.add(neighborToConvert);
                    if (random(1) < HOUSE_CHANCE) {
                        houseGrid[nx][ny] = (int)random(1, 6);
                    }
                    newBuildingsThisFrame.add(neighborToConvert);
                }
            }
        }
        f.cleanupEdge();
    }

    // --- NATURE ACTIONS ---
    nature.update(newBuildingsThisFrame);

    // --- AUDIO ---
    updateAudio();

    // --- RENDER ---
    image(backgroundBuffer, 0, 0);
    drawGravelOverlay();
    drawScene();
}


// --- HELPER & DRAWING FUNCTIONS ---

void updateAudio() {
  int urbanCellCount = 0;
  int activeFactories = 0;
  for (int x = 0; x < gridWidth; x++) {
    for (int y = 0; y < gridHeight; y++) {
      if (grid[x][y] > 0) {
        urbanCellCount++;
      }
    }
  }
  for (Factory f : factories) {
    if (f.isActive) {
      activeFactories++;
    }
  }

  // Control the Industrial Hum
  float targetHumVolume = map(urbanCellCount, 0, gridWidth * gridHeight / 2, 0, 0.2f);
  humOscillator.amp(targetHumVolume);
  
  // --- Trigger the Factory Whistle ---
  // <<< THIS SECTION IS REVISED ENTIRELY ---
  if (activeFactories > 0) {
    // The chance of a whistle increases significantly with the number of active factories.
    float baseWhistleChance = 0.001f;  // Chance with 1 factory
    float maxWhistleChance = 0.01f;   // Much higher chance with all factories
    float whistleChance = map(activeFactories, 1, factories.size(), baseWhistleChance, maxWhistleChance);
    
    if (random(1) < whistleChance) {
        SoundFile temporaryWhistle = new SoundFile(this, "whistle.mp3");
        // Use the dedicated whistle filter
        whistleFilter.process(temporaryWhistle);
        whistleFilter.freq(350); 
        
        // Play with a randomized pitch (rate) for variety.
        float rate = random(0.8f, 2f);
        temporaryWhistle.play(rate, 1f);
    }
  }
  
  // --- Trigger the Steampunk Clank Sound ---
  float clankChance = 0.03f;
  if (activeFactories > 0 && random(1) < clankChance) {
    // NOTE: Make sure you have a sound file named "clank.mp3" in your data folder.
    SoundFile temporaryClank = new SoundFile(this, "clank.mp3");

    // Use the dedicated clank filter
    clankFilter.process(temporaryClank);
    clankFilter.freq(100); 
    
    // Play a random snippet from the sound file.
    float duration = temporaryClank.duration();
    float startTime = random(0, duration * 0.8f); 
    temporaryClank.jump(startTime);

    // Randomize playback for variety.
    float rate = random(0.1, 0.3); // Slight pitch variation
    float amp = random(0.1, 0.1);    // Adjusted amp since filter can reduce volume

    // Play the sound directly.
    temporaryClank.play(rate, amp);
  }
}

PVector chooseEdgePixelByDistance(Factory f) {
    if (f.activeEdge.isEmpty()) {
        return null;
    }
    ArrayList<Float> scores = new ArrayList<Float>();
    float totalScore = 0;
    for (PVector cell : f.activeEdge) {
        float distance = dist(cell.x, cell.y, f.location.x, f.location.y);
        float score = 1.0f / (pow(distance, 5) + 1.0f);
        scores.add(score);
        totalScore += score;
    }
    float randomValue = random(totalScore);
    float currentScore = 0;
    for (int i = 0; i < f.activeEdge.size(); i++) {
        currentScore += scores.get(i);
        if (randomValue <= currentScore) {
            return f.activeEdge.get(i);
        }
    }
    return f.activeEdge.get(f.activeEdge.size() - 1);
}

PVector chooseNeighborOrganically(ArrayList<PVector> neighbors, PVector from, Factory factory) {
    float angle = atan2(factory.spreadDirection.y, factory.spreadDirection.x);
    angle += map(noise(from.x * 0.1f, from.y * 0.1f, frameCount * 0.01f), 0, 1, -0.5f, 0.5f);
    factory.spreadDirection.set(cos(angle), sin(angle));
    float maxScore = -1;
    PVector bestNeighbor = null;
    for (PVector neighbor : neighbors) {
        PVector directionToNeighbor = PVector.sub(neighbor, from);
        directionToNeighbor.normalize();
        float score = directionToNeighbor.dot(factory.spreadDirection);
        if (score > maxScore) {
            maxScore = score;
            bestNeighbor = neighbor;
        }
    }
    if (random(1) < 0.85f || neighbors.size() == 1) {
        return bestNeighbor;
    } else {
        return neighbors.get((int)random(neighbors.size()));
    }
}

void drawScene() {
    noStroke();
    for(int x = 0; x < gridWidth; x++){
        for(int y = 0; y < gridHeight; y++){
            if(grid[x][y] > 0){
                fill(colorGrid[x][y]);
                rect(x * PIXEL_SCALE, y * PIXEL_SCALE, PIXEL_SCALE, PIXEL_SCALE);
                if (houseGrid[x][y] > 0) {
                    drawHouse(x, y, houseGrid[x][y]);
                }
                float health = overgrowthGrid[x][y];
                if (health < MAX_URBAN_HEALTH) {
                    color naturalDecayColor = color(70, 150, 70);
                    color gravelDecayColor = color(50, 45, 40);
                    float gravelStrength = gravelGrid[x][y];
                    color decayColor = lerpColor(naturalDecayColor, gravelDecayColor, gravelStrength);
                    float alpha = map(health, MAX_URBAN_HEALTH, 0, 0, 180);
                    fill(decayColor, alpha);
                    rect(x * PIXEL_SCALE, y * PIXEL_SCALE, PIXEL_SCALE, PIXEL_SCALE);
                }
            }
        }
    }
    fill(0);
    rectMode(CORNER);
    for (Factory f : factories) {
        if (f.isActive) {
            rect(f.location.x * PIXEL_SCALE, f.location.y * PIXEL_SCALE, PIXEL_SCALE, PIXEL_SCALE);
        }
    }
}

void drawHouse(int gridX, int gridY, int houseType) {
    float x = gridX * PIXEL_SCALE;
    float y = gridY * PIXEL_SCALE;
    float ps = PIXEL_SCALE;
    rectMode(CORNER);
    noStroke();
    switch(houseType) {
        case 1:
            fill(115, 90, 85);
            rect(x, y + ps*0.4f, ps, ps*0.6f);
            fill(140, 75, 70);
            rect(x, y, ps, ps*0.5f);
            break;
        case 2:
            fill(80, 60, 50);
            rect(x, y + ps*0.5f, ps, ps*0.5f);
            fill(60, 40, 30);
            rect(x, y + ps*0.3f, ps, ps*0.3f);
            rect(x + ps*0.2f, y + ps*0.1f, ps*0.6f, ps*0.3f);
            break;
        case 3:
            fill(130, 130, 125);
            rect(x, y, ps, ps);
            fill(110, 110, 105);
            rect(x, y, ps, ps*0.3f);
            break;
        case 4:
            fill(140, 135, 130);
            rect(x, y + ps*0.4f, ps, ps*0.6f);
            fill(80, 95, 85);
            rect(x, y, ps, ps*0.5f);
            break;
        case 5:
            fill(100, 100, 100);
            rect(x + ps*0.15f, y, ps*0.7f, ps);
            fill(80, 80, 80);
            rect(x + ps*0.15f, y, ps*0.7f, ps*0.3f);
            break;
    }
}

void drawGravelOverlay() {
  noStroke();
  for (int y = 0; y < gridHeight; y++) {
    for (int x = 0; x < gridWidth; x++) {
      float gravelStrength = gravelGrid[x][y];
      if (gravelStrength > 0) {
        float gravelNoise = noise(x * 0.5, y * 0.5);
        color gravelColor = lerpColor(GRAVEL_COLOR_DARK, GRAVEL_COLOR_LIGHT, gravelNoise);
        float alpha = map(gravelStrength, 0, 1, 0, 255);
        fill(gravelColor, alpha);
        rect(x * PIXEL_SCALE, y * PIXEL_SCALE, PIXEL_SCALE, PIXEL_SCALE);
      }
    }
  }
}

void renderStaticBackground() {
  backgroundBuffer.beginDraw();
  PVector lightDirection = new PVector(-1, -1);
  lightDirection.normalize();
  backgroundBuffer.loadPixels();
  for (int y = 0; y < backgroundBuffer.height; y++) {
    for (int x = 0; x < backgroundBuffer.width; x++) {
      int loc = x + y * backgroundBuffer.width;
      color pixelColor;
      float elevation = noise(x * ELEVATION_NOISE_SCALE, y * ELEVATION_NOISE_SCALE);
      float grassNoise = noise(x * GRASS_NOISE_SCALE, y * GRASS_NOISE_SCALE);
      float mossNoise = noise(x * MOSS_NOISE_SCALE + 1000, y * MOSS_NOISE_SCALE + 1000);
      float pebbleNoise = noise(x * PEBBLE_NOISE_SCALE, y * PEBBLE_NOISE_SCALE);
      pixelColor = lerpColor(color(90, 100, 50), color(60, 140, 60), grassNoise);
      if (mossNoise > MOSS_THRESHOLD) {
        float mossMix = map(mossNoise, MOSS_THRESHOLD, 1.0, 0, 1);
        pixelColor = lerpColor(pixelColor, color(40, 90, 45), mossMix);
      }
      if (pebbleNoise > PEBBLE_THRESHOLD) {
        float pebbleMix = map(pebbleNoise, PEBBLE_THRESHOLD, 1.0, 0, 1);
        pixelColor = lerpColor(pixelColor, color(140, 140, 140), pebbleMix);
      }
      float nx = noise((x + 1) * ELEVATION_NOISE_SCALE, y * ELEVATION_NOISE_SCALE) - noise((x - 1) * ELEVATION_NOISE_SCALE, y * ELEVATION_NOISE_SCALE);
      float ny = noise(x * ELEVATION_NOISE_SCALE, (y + 1) * ELEVATION_NOISE_SCALE) - noise(x * ELEVATION_NOISE_SCALE, (y - 1) * ELEVATION_NOISE_SCALE);
      PVector normal = new PVector(nx, ny);
      float shading = normal.dot(lightDirection);
      if (shading > 0) {
        pixelColor = lerpColor(pixelColor, color(255), shading * SHADING_STRENGTH * 0.5f);
      } else {
        pixelColor = lerpColor(pixelColor, color(0), abs(shading) * SHADING_STRENGTH);
      }
      backgroundBuffer.pixels[loc] = pixelColor;
    }
  }
  backgroundBuffer.updatePixels();
  backgroundBuffer.endDraw();
}
    
ArrayList<PVector> getAnyGrassNeighbors(PVector p) {
    ArrayList<PVector> neighbors = new ArrayList<PVector>();
    int x = (int)p.x;
    int y = (int)p.y;
    int[] dx = {0, 0, -1, 1};
    int[] dy = {-1, 1, 0, 0};
    for(int i = 0; i < 4; i++){
        int nx = x + dx[i];
        int ny = y + dy[i];
        if(nx >= 0 && nx < gridWidth && ny >= 0 && ny < gridHeight){
            if(grid[nx][ny] <= 0){
                neighbors.add(new PVector(nx, ny));
            }
        }
    }
    return neighbors;
}
    
// --- KEYBOARD INPUT ---
void keyPressed() {
  switch (key) {
    case 'f':
    case 'F':
      for (Factory f : factories) {
        f.isActive = !f.isActive;
      }
      break;
    case '1':
      if (factories.size() >= 1) {
        factories.get(0).isActive = !factories.get(0).isActive;
      }
      break;
    case '2':
      if (factories.size() >= 2) {
        factories.get(1).isActive = !factories.get(1).isActive;
      }
      break;
    case '3':
      if (factories.size() >= 3) {
        factories.get(2).isActive = !factories.get(2).isActive;
      }
      break;
    case '4':
      if (factories.size() >= 4) {
        factories.get(3).isActive = !factories.get(3).isActive;
      }
      break;
    case '5':
      if (factories.size() >= 5) {
        factories.get(4).isActive = !factories.get(4).isActive;
      }
      break;
    case '6':
      if (factories.size() >= 6) {
        factories.get(5).isActive = !factories.get(5).isActive;
      }
      break;
  }
}
