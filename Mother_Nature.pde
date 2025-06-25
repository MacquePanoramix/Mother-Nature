import java.util.HashSet;
import java.util.HashMap;

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
float GRAVEL_AURA_RADIUS = 4.0f;     // How far (in cells) the gravel effect spreads from a building.
float GRAVEL_BUILD_RATE = 0.05f;     // How quickly gravel appears under buildings.
float GRAVEL_DECAY_RATE = 0.01f;     // How quickly gravel fades when buildings are gone.
color GRAVEL_COLOR_DARK = color(85, 80, 75);
color GRAVEL_COLOR_LIGHT = color(130, 125, 120);

// --- TOP-DOWN VARIATION CONFIGURATION (NO WATER) ---
float ELEVATION_NOISE_SCALE = 0.008f;
float SHADING_STRENGTH = 0.5f;

// --- INTERNAL SPREAD CONFIGURATION ---
float INTERNAL_SPREAD_CHANCE = 0.5f;
float INTERNAL_SPREAD_STRENGTH = 0.1f;

// --- SIMULATION STATE ---
PGraphics backgroundBuffer; // NEW: An off-screen buffer for the static background
float[][] gravelGrid; // NEW: Tracks the strength of gravel at each cell
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
    gravelGrid = new float[gridWidth][gridHeight]; // Initialize the new grid
    nature = new Nature();

    factories = new ArrayList<Factory>();
    factories.add(new Factory(1, 150 / PIXEL_SCALE, 150 / PIXEL_SCALE));
    factories.add(new Factory(2, 650 / PIXEL_SCALE, 150 / PIXEL_SCALE));
    factories.add(new Factory(3, 150 / PIXEL_SCALE, 450 / PIXEL_SCALE));
    factories.add(new Factory(4, 650 / PIXEL_SCALE, 450 / PIXEL_SCALE));

    // Render the static background (now without any gravel)
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
}

// --- DRAW ---
void draw() {
    // 1. Create a temporary list to hold buildings created this frame.
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
                    // 2. Add the newly created building to our temporary list.
                    newBuildingsThisFrame.add(neighborToConvert);
                }
            }
        }
        f.cleanupEdge();
    }

    // --- NATURE ACTIONS (Decay, Vines, and Gravel) ---
    // 3. Pass the list of new buildings to the nature update method.
    nature.update(newBuildingsThisFrame);

    // --- RENDER THE SCENE in layers ---
    // 1. Draw the pre-rendered static background
    image(backgroundBuffer, 0, 0);

    // 2. Draw the dynamic gravel overlay
    drawGravelOverlay();

    // 3. Draw the dynamic city elements on top
    drawScene();
}

// Helper function to select an edge pixel, weighted by distance from the factory.
PVector chooseEdgePixelByDistance(Factory f) {
    if (f.activeEdge.isEmpty()) {
        return null;
    }

    ArrayList<Float> scores = new ArrayList<Float>();
    float totalScore = 0;

    for (PVector cell : f.activeEdge) {
        float distance = dist(cell.x, cell.y, f.location.x, f.location.y);
        // MODIFIED: Score is inversely proportional to the 4th power of the distance for an extremely pronounced effect.
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

    return f.activeEdge.get(f.activeEdge.size() - 1); // Fallback
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
    // This function now only draws the dynamic city elements on top of the pre-rendered background.
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
                    
                    // --- NEW DYNAMIC DECAY LOGIC ---
                    
                    // 1. Define the two possible decay colors.
                    color naturalDecayColor = color(70, 150, 70); // The green overgrowth color
                    color gravelDecayColor = color(50, 45, 40);   // A dark, gritty "urban decay" color
                    
                    // 2. Check the gravel strength underneath this building.
                    float gravelStrength = gravelGrid[x][y];
                    
                    // 3. Blend between the two colors based on the gravel strength.
                    color decayColor = lerpColor(naturalDecayColor, gravelDecayColor, gravelStrength);

                    // 4. Calculate the alpha (transparency) based on the building's health.
                    float alpha = map(health, MAX_URBAN_HEALTH, 0, 0, 180);

                    // 5. Apply the final dynamic color and alpha.
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



// --- NEW HELPER FUNCTION to draw the dynamic gravel layer ---
void drawGravelOverlay() {
  noStroke();
  for (int y = 0; y < gridHeight; y++) {
    for (int x = 0; x < gridWidth; x++) {
      float gravelStrength = gravelGrid[x][y];
      if (gravelStrength > 0) {
        // Use noise to give the gravel some texture
        float gravelNoise = noise(x * 0.5, y * 0.5);
        color gravelColor = lerpColor(GRAVEL_COLOR_DARK, GRAVEL_COLOR_LIGHT, gravelNoise);
        
        // The alpha is determined by the gravel's strength
        float alpha = map(gravelStrength, 0, 1, 0, 255);
        fill(gravelColor, alpha);
        rect(x * PIXEL_SCALE, y * PIXEL_SCALE, PIXEL_SCALE, PIXEL_SCALE);
      }
    }
  }
}

// --- MODIFIED HELPER FUNCTION to render the background once to a buffer ---
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
    
// --- HELPER FUNCTIONS ---
    
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
      // Toggle all factories on/off at once
      for (Factory f : factories) {
        f.isActive = !f.isActive;
      }
      break;

    case '1':
      // Toggle Factory 1 (at index 0)
      if (factories.size() >= 1) {
        factories.get(0).isActive = !factories.get(0).isActive;
      }
      break;

    case '2':
      // Toggle Factory 2 (at index 1)
      if (factories.size() >= 2) {
        factories.get(1).isActive = !factories.get(1).isActive;
      }
      break;

    case '3':
      // Toggle Factory 3 (at index 2)
      if (factories.size() >= 3) {
        factories.get(2).isActive = !factories.get(2).isActive;
      }
      break;

    case '4':
      // Toggle Factory 4 (at index 3)
      if (factories.size() >= 4) {
        factories.get(3).isActive = !factories.get(3).isActive;
      }
      break;
  }
}
