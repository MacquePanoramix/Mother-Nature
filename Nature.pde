class Nature {
    ArrayList<Vine> vines;

    Nature() {
        this.vines = new ArrayList<Vine>();
    }

    // MODIFIED: This method now accepts a list of "immune" cells (the ones built this frame)
    // and passes it along to the decay function.
    void update(ArrayList<PVector> immuneCells) {
        updateVinesAndDecay(immuneCells);
        updateGravel();
    }

    // This function handles the dynamic growth and decay of the gravel overlay.
    void updateGravel() {
        float[][] influenceGrid = new float[gridWidth][gridHeight];
        int radius = (int)GRAVEL_AURA_RADIUS;

        // Step 1: Calculate the "civilization pressure" from all buildings
        for (int x = 0; x < gridWidth; x++) {
            for (int y = 0; y < gridHeight; y++) {
                if (grid[x][y] > 0) { // If there is a building here
                    // Spread influence to the surrounding area
                    for (int ny = -radius; ny <= radius; ny++) {
                        for (int nx = -radius; nx <= radius; nx++) {
                            int checkX = x + nx;
                            int checkY = y + ny;

                            if (checkX >= 0 && checkX < gridWidth && checkY >= 0 && checkY < gridHeight) {
                                float distance = dist(0, 0, nx, ny);
                                if (distance <= GRAVEL_AURA_RADIUS) {
                                    float influence = 1.0f - (distance / GRAVEL_AURA_RADIUS);
                                    influenceGrid[checkX][checkY] = max(influenceGrid[checkX][checkY], influence);
                                }
                            }
                        }
                    }
                }
            }
        }
        
        // Step 2: Evolve the main gravelGrid towards the influence grid
        for (int x = 0; x < gridWidth; x++) {
            for (int y = 0; y < gridHeight; y++) {
                float currentGravel = gravelGrid[x][y];
                float targetGravel = influenceGrid[x][y];

                if (currentGravel < targetGravel) {
                    gravelGrid[x][y] += GRAVEL_BUILD_RATE;
                } else if (currentGravel > targetGravel) {
                    gravelGrid[x][y] -= GRAVEL_DECAY_RATE;
                }
                gravelGrid[x][y] = constrain(gravelGrid[x][y], 0, 1);
            }
        }
    }

    // MODIFIED: This function now accepts the list of immune cells and uses it to prevent
    // new buildings from taking damage in the frame they are created.
    void updateVinesAndDecay(ArrayList<PVector> immuneCells) {
        // A fresh buffer to store all damage calculated this frame.
        float[][] damageToApply = new float[gridWidth][gridHeight];

        // --- Step 1: CALCULATE ALL DAMAGE AND ADD IT TO THE BUFFER ---

        // A. Calculate Vine Damage
        for (int i = vines.size() - 1; i >= 0; i--) {
            Vine v = vines.get(i);
            v.grow();
            int vx = (int)v.location.x;
            int vy = (int)v.location.y;
            if (vx >= 0 && vx < gridWidth && vy >= 0 && vy < gridHeight && grid[vx][vy] > 0) {
                damageToApply[vx][vy] += VINE_DAMAGE;
            }
            if (v.isDead()) {
                vines.remove(i);
            }
        }

        // B. Calculate Edge Erosion Damage
        ArrayList<PVector> currentGlobalEdge = new ArrayList<PVector>();
        for (Factory f : factories) {
            currentGlobalEdge.addAll(f.activeEdge);
        }
        if (!currentGlobalEdge.isEmpty()) {
            for (PVector cell : currentGlobalEdge) {
                int x = (int)cell.x;
                int y = (int)cell.y;
                if (grid[x][y] > 0) {
                    float damage = getAnyGrassNeighbors(cell).size() * DAMAGE_PER_EXPOSED_SIDE;
                    damageToApply[x][y] += damage;
                }
            }
        }

        // C. Calculate Internal Spread Damage
        for (int x = 0; x < gridWidth; x++) {
            for (int y = 0; y < gridHeight; y++) {
                if (grid[x][y] > 0 && overgrowthGrid[x][y] < MAX_URBAN_HEALTH && random(1) < INTERNAL_SPREAD_CHANCE) {
                    float damageRatio = (MAX_URBAN_HEALTH - overgrowthGrid[x][y]) / MAX_URBAN_HEALTH;
                    float spreadPower = damageRatio * INTERNAL_SPREAD_STRENGTH;
                    int[] dx = {0, 0, -1, 1};
                    int[] dy = {-1, 1, 0, 0};
                    for (int i = 0; i < 4; i++) {
                        int nx = x + dx[i];
                        int ny = y + dy[i];
                        if (nx >= 0 && nx < gridWidth && ny >= 0 && ny < gridHeight && grid[nx][ny] > 0) {
                            damageToApply[nx][ny] += spreadPower;
                        }
                    }
                }
            }
        }

        // --- Step 2: APPLY ALL ACCUMULATED DAMAGE AND UPDATE THE GRID ---
        HashMap<Integer, HashSet<PVector>> newEdgeCandidates = new HashMap<Integer, HashSet<PVector>>();
        for (Factory f : factories) {
            newEdgeCandidates.put(f.id, new HashSet<PVector>());
        }

        for (int x = 0; x < gridWidth; x++) {
            for (int y = 0; y < gridHeight; y++) {
                
                // NEW "GRACE PERIOD" IMMUNITY LOGIC
                boolean isImmune = false;
                for (PVector immuneCell : immuneCells) {
                    if (immuneCell.x == x && immuneCell.y == y) {
                        isImmune = true;
                        break;
                    }
                }
                if (isImmune) {
                    continue; // Skip all damage and death checks for this new building this frame.
                }

                // Apply the total calculated damage from the buffer
                if (damageToApply[x][y] > 0) {
                    overgrowthGrid[x][y] -= damageToApply[x][y];
                }

                // Now check if the cell has been destroyed
                if (grid[x][y] > 0 && overgrowthGrid[x][y] <= 0) {
                    grid[x][y] = -1;
                    houseGrid[x][y] = 0;

                    // If it was destroyed, its neighbors might now be part of the new edge
                    int[] dx = {0, 0, -1, 1};
                    int[] dy = {-1, 1, 0, 0};
                    for (int j = 0; j < 4; j++) {
                        int nx = x + dx[j];
                        int ny = y + dy[j];
                        if (nx >= 0 && nx < gridWidth && ny >= 0 && ny < gridHeight) {
                            int neighborId = grid[nx][ny];
                            if (neighborId > 0) {
                                newEdgeCandidates.get(neighborId).add(new PVector(nx, ny));
                            }
                        }
                    }
                }
            }
        }

        // Add the newly exposed cells to the active edges of their respective factories
        for (Factory f : factories) {
            f.activeEdge.addAll(newEdgeCandidates.get(f.id));
        }
    }
}
