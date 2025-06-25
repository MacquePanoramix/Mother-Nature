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

    // This is the function with the critical fix.
    void cleanupEdge() {
        ArrayList<PVector> newActiveEdge = new ArrayList<PVector>();
        for (PVector cell : this.activeEdge) {
            int cx = (int)cell.x;
            int cy = (int)cell.y;

            // THE FIX: We now check if the cell is still owned by this factory (grid[cx][cy] == this.id)
            // This prevents "zombie" cells from remaining in the active edge.
            if (cell != null && grid[cx][cy] == this.id && !getAnyGrassNeighbors(cell).isEmpty()) {
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
