// --- NATURE CLASS ---
class Nature
{

  /*
   *
   * The nature class is responsible for counter attacking the urban progress and trying to 
   * reclaim nature back. It can do this by applying an erosion factor into urban cells near grass cells
   * and urban cells near other damaged cells. It can also spawn vines that wiggle a bit around 
   * (although invisible) and deal some damage to the urban cells it touches. 
   *
   * Additionally nature habndles how the spread of gravel in the landscape as a result of human
   * presence is handled.
   *
   */

  // --- CLASS FIELDS ---
  /*
   *
   * The only variable nature stores are of the current vines active in the scene
   *
   */
  ArrayList<Vine> vines;

  // --- CONSTRUCTOR ---
  Nature()
  {

    /*
     *
     * Here we just initialize that vines list.
     *
     */
    this.vines = new ArrayList<Vine>();
  }

  // --- MAIN UPDATE METHOD ---
  void update(ArrayList<PVector> immuneCells) // We have immune cells in the first frame of an urban cell taking over a space so they don't imideatily disappear (That would create a sort of undesirable blinking effect).
  {

    /*
     *
     * Basically applies the damage from decay and vines to the urban cells and then updates 
     * the gravel based on the new urban/nature configuration.
     *
     */
    updateVinesAndDecay(immuneCells);

    updateGravel();
  }

  // --- GRAVEL MANAGEMENT ---
  void updateGravel()
  {

    /*
     *
     * This function first created a grid of influence in a radius around each urban cell. The influence is 1 on top of it,
     * 0 when it's more distant than the urban cell and a value in between 0 and 1 when it's inside the radius based on how close it is
     * (The closer the larger number).
     *
     * Next the function compares the current gravel grid with the ideal target gravel grid we just found. If a certain coordinate has less 
     * than the target then we add the grabvel build rate to it. If it's more than the target (if a building was just destroyed for example)
     * we subtract the gravel decay rate from it.
     *
     */
    float[][] influenceGrid = new float[gridWidth][gridHeight];

    int radius = (int)GRAVEL_AURA_RADIUS;

    for (int x = 0; x < gridWidth; x++)
    {

      for (int y = 0; y < gridHeight; y++)
      {

        if (grid[x][y] > 0)
        {

          for (int ny = -radius; ny <= radius; ny++)
          {

            for (int nx = -radius; nx <= radius; nx++)
            {

              int checkX = x + nx;

              int checkY = y + ny;

              if (checkX >= 0 && checkX < gridWidth && checkY >= 0 && checkY < gridHeight)
              {

                float distance = dist(0, 0, nx, ny);

                if (distance <= GRAVEL_AURA_RADIUS)
                {

                  float influence = 1.0f - (distance / GRAVEL_AURA_RADIUS);

                  influenceGrid[checkX][checkY] = max(influenceGrid[checkX][checkY], influence);
                }
              }
            }
          }
        }
      }
    }

    for (int x = 0; x < gridWidth; x++)
    {

      for (int y = 0; y < gridHeight; y++)
      {

        float currentGravel = gravelGrid[x][y];

        float targetGravel = influenceGrid[x][y];

        if (currentGravel < targetGravel)
        {

          gravelGrid[x][y] += GRAVEL_BUILD_RATE;
        }
        else if (currentGravel > targetGravel)
        {

          gravelGrid[x][y] -= GRAVEL_DECAY_RATE;
        }
        gravelGrid[x][y] = constrain(gravelGrid[x][y], 0, 1); 
      }
    }
  }

  // --- DECAY & OVERGROWTH ---
  void updateVinesAndDecay(ArrayList<PVector> immuneCells)
  {

    /*
     *
     * This function first calculates all the damage that needs to be applied to the current urban cells.
     * Next it applies this damage and checks which urban cells were destroyed. Finally it checks what will
     * be the new urban edge cells in contact with nature given the new configuration of the map.
     *
     */
    float[][] damageToApply = new float[gridWidth][gridHeight];

    ArrayList<PVector> currentGlobalEdge = new ArrayList<PVector>();

    for (Factory f : factories)
    {

      currentGlobalEdge.addAll(f.activeEdge); // Adds all the urban edges that were already being stored in the factories objects to this new list
    }
    
    // --- VINE SPAWNING ---
    /*
     *
     * For each urban cell that is in contact with nature, it has a chance to spawn a vine on top of it given by VINE_SPAWN_CHANCE.
     *
     */
    if (!currentGlobalEdge.isEmpty())
    {

      for (PVector cell : currentGlobalEdge)
      {

        if (random(1) < VINE_SPAWN_CHANCE)
        {
        
          vines.add(new Vine(cell));
        }
      }
    }

    // --- VINE AND DECAY UPDATES ---
    /*
     *
     * First moves the vine according to the vine logic and applies its damage to the urban cell that it's on top of.
     * Next applied damage to urban cells in contact with nature cells for each nature cell adjacent to it based on the constant DAMAGE_PER_EXPOSED_SIDE.
     *  Finally, for each urban cell that has a neighbouring urban cell, it receives damage equal to a proportion of how much health each
     * of its neighbours have lost, influenced by the constant INTERNAL_SPREAD_STRENGTH.
     */
    for (int i = vines.size() - 1; i >= 0; i--)
    {

      Vine v = vines.get(i);

      v.grow(); // Moves the vine and makes it older (relevant since vines have a set life time)

      int vx = (int)v.location.x;

      int vy = (int)v.location.y;

      if (vx >= 0 && vx < gridWidth && vy >= 0 && vy < gridHeight && grid[vx][vy] > 0)
      {

        damageToApply[vx][vy] += VINE_DAMAGE;
      }
      if (v.isDead())
      {

        vines.remove(i);
      }
    }

    if (!currentGlobalEdge.isEmpty())
    {

      for (PVector cell : currentGlobalEdge)
      {

        int x = (int)cell.x;

        int y = (int)cell.y;

        if (grid[x][y] > 0)
        {

          float damage = getAnyGrassNeighbors(cell).size() * DAMAGE_PER_EXPOSED_SIDE; 

          damageToApply[x][y] += damage;
        }
      }
    }

    for (int x = 0; x < gridWidth; x++)
    {

      for (int y = 0; y < gridHeight; y++)
      {

        if (grid[x][y] > 0 && overgrowthGrid[x][y] < MAX_URBAN_HEALTH && random(1) < INTERNAL_SPREAD_CHANCE)
        {

          float damageRatio = (MAX_URBAN_HEALTH - overgrowthGrid[x][y]) / MAX_URBAN_HEALTH; 

          float spreadPower = damageRatio * INTERNAL_SPREAD_STRENGTH;

          int[] dx = {0, 0, -1, 1};

          int[] dy = {-1, 1, 0, 0};

          for (int i = 0; i < 4; i++)
          {

            int nx = x + dx[i];

            int ny = y + dy[i];

            if (nx >= 0 && nx < gridWidth && ny >= 0 && ny < gridHeight && grid[nx][ny] > 0)
            {

              damageToApply[nx][ny] += spreadPower;
            }
          }
        }
      }
    }

    HashMap<Integer, HashSet<PVector>> newEdgeCandidates = new HashMap<Integer, HashSet<PVector>>();

    for (Factory f : factories)
    {

      newEdgeCandidates.put(f.id, new HashSet<PVector>()); 
    }

    for (int x = 0; x < gridWidth; x++)
    {

      for (int y = 0; y < gridHeight; y++)
      {

        boolean isImmune = false;

        for (PVector immuneCell : immuneCells)
        {

          if (immuneCell.x == x && immuneCell.y == y)
          {

            isImmune = true;

            break;
          }
        }
        if (isImmune)
        {

          continue;
        }
        if (damageToApply[x][y] > 0)
        {

          overgrowthGrid[x][y] -= damageToApply[x][y];  // We apply the damage to all the urban cells except the ones that are currently immune. (They are immune if they were just built).
        }
        if (grid[x][y] > 0 && overgrowthGrid[x][y] <= 0)
        {

          grid[x][y] = -1;

          houseGrid[x][y] = 0;

          int[] dx = {0, 0, -1, 1};

          int[] dy = {-1, 1, 0, 0};

          for (int j = 0; j < 4; j++)
          {

            int nx = x + dx[j];

            int ny = y + dy[j];

            if (nx >= 0 && nx < gridWidth && ny >= 0 && ny < gridHeight)
            {

              int neighborId = grid[nx][ny];

              if (neighborId > 0)
              {

                newEdgeCandidates.get(neighborId).add(new PVector(nx, ny)); // This updates the list of new urban cells with contact with nature.
              }
            }
          }
        }
      }
    }

    for (Factory f : factories)
    {

      f.activeEdge.addAll(newEdgeCandidates.get(f.id)); // Also tell the factory objects what are the new urban cells in contact with nature.
    }
  }
}
