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

// --- NEW INTERNAL SPREAD CONFIGURATION ---
float INTERNAL_SPREAD_CHANCE = 0.5f; // Chance for a damaged cell to attempt to spread decay each frame.
float INTERNAL_SPREAD_STRENGTH = 0.1f; // Multiplier for how much damage is spread.

// --- SIMULATION STATE ---
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
    
    grid = new int[gridWidth][gridHeight];
    colorGrid = new color[gridWidth][gridHeight];
    houseGrid = new int[gridWidth][gridHeight]; 
    overgrowthGrid = new float[gridWidth][gridHeight];
    nature = new Nature();
    
    factories = new ArrayList<Factory>();
    factories.add(new Factory(1, 150 / PIXEL_SCALE, 150 / PIXEL_SCALE));
    factories.add(new Factory(2, 650 / PIXEL_SCALE, 150 / PIXEL_SCALE));
    factories.add(new Factory(3, 150 / PIXEL_SCALE, 450 / PIXEL_SCALE));
    factories.add(new Factory(4, 650 / PIXEL_SCALE, 450 / PIXEL_SCALE));

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
    // --- FACTORY ACTIONS (Spread and Repair) ---
    for (Factory f : factories) {
        if (!f.isActive) continue; 

        for(int i = 0; i < ACTIONS_PER_FRAME; i++){
            
            // Decide whether to repair or spread
            if (random(1) < REPAIR_CHANCE) {
                // --- REPAIR ACTION ---
                f.repairCell();

            } else {
                // --- SPREAD ACTION ---
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
                }
            }
        }
        f.cleanupEdge();
    }

    // --- NATURE RECLAIMS (The "Pushback") ---
    nature.reclaim();
    
    // --- RENDER THE SCENE (The "View") ---
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
    loadPixels();
    for (int y = 0; y < height; y++) {
        for (int x = 0; x < width; x++) {
            float noiseScale = 0.05f;
            float noiseVal = noise(x * noiseScale, y * noiseScale);
            float green = map(noiseVal, 0, 1, 80, 210);
            int loc = x + y * width;
            pixels[loc] = color(70, green, 70);
        }
    }
    updatePixels();

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
                    float alpha = map(health, MAX_URBAN_HEALTH, 0, 0, 180);
                    fill(70, 150, 70, alpha);
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
    if (key == 'f' || key == 'F') {
        for (Factory f : factories) {
            f.isActive = !f.isActive;
        }
    }
}
