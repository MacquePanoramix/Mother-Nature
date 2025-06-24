class Factory {
    PVector location;
    int id;
    boolean isActive = true;
    ArrayList<PVector> activeEdge;
    color baseColor;
    PVector spreadDirection; 
    
    Factory(int id, float x, float y) { 
        this.id = id;
        this.location = new PVector(x, y);
        this.activeEdge = new ArrayList<PVector>();
        this.baseColor = color(80);
        
        float angle = random(TWO_PI);
        this.spreadDirection = new PVector(cos(angle), sin(angle));
    }

    void cleanupEdge() {
        ArrayList<PVector> newActiveEdge = new ArrayList<PVector>();
        for (PVector cell : this.activeEdge) {
            if (cell != null && !getAnyGrassNeighbors(cell).isEmpty()) {
                newActiveEdge.add(cell);
            }
        }
        this.activeEdge = newActiveEdge;
    }

    void repairCell() {
        ArrayList<PVector> damagedCells = new ArrayList<PVector>();
        ArrayList<Float> scores = new ArrayList<Float>();
        float totalScore = 0;

        for (int x = 0; x < gridWidth; x++) {
            for (int y = 0; y < gridHeight; y++) {
                if (grid[x][y] == this.id && overgrowthGrid[x][y] < MAX_URBAN_HEALTH) {
                    PVector cell = new PVector(x, y);
                    damagedCells.add(cell);
                    
                    float distance = dist(x, y, this.location.x, this.location.y);
                    // MODIFIED: Score is inversely proportional to the 4th power of the distance for an extremely pronounced effect.
                    float score = 1.0f / (pow(distance, 5) + 1.0f);
                    scores.add(score);
                    totalScore += score;
                }
            }
        }

        if (!damagedCells.isEmpty()) {
            float randomValue = random(totalScore);
            float currentScore = 0;

            for (int i = 0; i < damagedCells.size(); i++) {
                currentScore += scores.get(i);
                if (randomValue <= currentScore) {
                    PVector cellToRepair = damagedCells.get(i);
                    overgrowthGrid[(int)cellToRepair.x][(int)cellToRepair.y] = MAX_URBAN_HEALTH;
                    return; 
                }
            }
        }
    }
} 
