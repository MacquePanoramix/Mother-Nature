class Nature {
    ArrayList<Vine> vines;

    Nature() {
        this.vines = new ArrayList<Vine>();
    }

    void reclaim() {
        // --- This buffer is for the NEW internal spread logic ---
        float[][] damageToApply = new float[gridWidth][gridHeight];

        // --- 1. EXISTING VINE LOGIC (No changes here) ---
        ArrayList<PVector> currentGlobalEdge = new ArrayList<PVector>();
        for (Factory f : factories) {
            currentGlobalEdge.addAll(f.activeEdge);
        }

        if (!currentGlobalEdge.isEmpty() && random(1) < VINE_SPAWN_CHANCE) {
            PVector spawnPoint = currentGlobalEdge.get((int)random(currentGlobalEdge.size()));
            vines.add(new Vine(spawnPoint));
        }

        for (int i = vines.size() - 1; i >= 0; i--) {
            Vine v = vines.get(i);
            v.grow();
            if (v.isDead()) {
                vines.remove(i);
            }
        }

        // --- 2. EXISTING EDGE EROSION LOGIC (No changes here) ---
        HashMap<Integer, HashSet<PVector>> newEdgeCandidates = new HashMap<Integer, HashSet<PVector>>();
        for (Factory f : factories) {
            newEdgeCandidates.put(f.id, new HashSet<PVector>());
        }

        if (!currentGlobalEdge.isEmpty()) {
            for (PVector cell : currentGlobalEdge) {
                int x = (int)cell.x;
                int y = (int)cell.y;
                if (grid[x][y] > 0) { // Check if it hasn't been destroyed by a vine this frame
                    float damage = getAnyGrassNeighbors(cell).size() * DAMAGE_PER_EXPOSED_SIDE;
                    overgrowthGrid[x][y] -= damage;
                }
            }
        }
        
        // --- 3. NEW: INTERNAL DECAY SPREAD LOGIC ---
        for (int x = 0; x < gridWidth; x++) {
            for (int y = 0; y < gridHeight; y++) {
                // Check if this is a damaged urban cell that passes the random chance
                if (grid[x][y] > 0 && overgrowthGrid[x][y] < MAX_URBAN_HEALTH && random(1) < INTERNAL_SPREAD_CHANCE) {
                    
                    // Calculate how damaged this cell is (0.0 to 1.0)
                    float damageRatio = (MAX_URBAN_HEALTH - overgrowthGrid[x][y]) / MAX_URBAN_HEALTH;
                    float spreadPower = damageRatio * INTERNAL_SPREAD_STRENGTH;

                    // Look at its neighbors
                    int[] dx = {0, 0, -1, 1};
                    int[] dy = {-1, 1, 0, 0};
                    for (int i = 0; i < 4; i++) {
                        int nx = x + dx[i];
                        int ny = y + dy[i];

                        // If the neighbor is a valid urban cell, queue up damage for it
                        if (nx >= 0 && nx < gridWidth && ny >= 0 && ny < gridHeight && grid[nx][ny] > 0) {
                            damageToApply[nx][ny] += spreadPower;
                        }
                    }
                }
            }
        }

        // --- 4. APPLY ALL CALCULATED DAMAGE (from internal spread) and CHECK FOR NEWLY DESTROYED CELLS ---
        for (int x = 0; x < gridWidth; x++) {
            for (int y = 0; y < gridHeight; y++) {
                // Apply the buffered internal spread damage
                if (damageToApply[x][y] > 0) {
                    overgrowthGrid[x][y] -= damageToApply[x][y];
                }

                // Check if any cell (from any damage source) has been destroyed in this frame
                if (grid[x][y] > 0 && overgrowthGrid[x][y] <= 0) {
                    grid[x][y] = -1;
                    houseGrid[x][y] = 0;

                    // Find neighbors of the just-destroyed cell to form the new edge
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

        // --- 5. FINAL EDGE CLEANUP (No changes here) ---
        for (Factory f : factories) {
            f.activeEdge.addAll(newEdgeCandidates.get(f.id));
        }
    }
}
