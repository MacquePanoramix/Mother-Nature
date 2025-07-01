// --- FACTORY CLASS ---
class Factory
{

  /*
   *
   * The factory class is respomnsible for managing the factories that control the urban expansion.
   * This includes the logic and parameters for expanding into new spaces, repairing damaged urban cells
   * and handling the list of current spaces that it might possibly want to expand to next.
   *
   */

  // --- CLASS FIELDS ---
  /*
   *
   * A factory has a location, an id, it can be either on or off, it has a color and a current direction of spread.
   *
   */
  PVector location;
  int id;
  boolean isActive = true;
  ArrayList<PVector> activeEdge;
  color baseColor;
  PVector spreadDirection;

  // --- CONSTRUCTOR ---
  Factory(int id, float x, float y)
  {

    /*
     *
     * We give an initial ID and position to each factory. 
     * It also starts with a random angle to be the spread direction.
     *
     */
    this.id = id;

    this.location = new PVector(x, y);

    this.activeEdge = new ArrayList<PVector>();

    this.baseColor = color(80);

    float angle = random(TWO_PI);

    this.spreadDirection = new PVector(cos(angle), sin(angle));
  }

  // --- EDGE MANAGEMENT ---
  void cleanupEdge()
  {

    /*
     *
     * For each active edge cell, check if it is still an urban cell and still has grass neighbours, if not remove it from the list.
     * This makes sure the active edge continues being correct given changes in the simulation.
     *
     */
    ArrayList<PVector> newActiveEdge = new ArrayList<PVector>();

    for (PVector cell : this.activeEdge)
    {

      int cx = (int)cell.x;

      int cy = (int)cell.y;

      if (cell != null && grid[cx][cy] == this.id && !getAnyGrassNeighbors(cell).isEmpty())
      {

        newActiveEdge.add(cell);
      }
    }
    this.activeEdge = newActiveEdge;
  }

  // --- REPAIR MECHANISM ---
  void repairCell()
  {

    /*
     *
     * First gets all the urban cells belonging to this factory and that don~t have full health.
     * It then gives each one a priority score based on how close they are.
     * One of them is then selected (the closer they are the higher chance to be selected) and restores it's health to full.
     *
     */
    ArrayList<PVector> damagedCells = new ArrayList<PVector>();

    ArrayList<Float> scores = new ArrayList<Float>();

    float totalScore = 0;

    for (int x = 0; x < gridWidth; x++)
    {

      for (int y = 0; y < gridHeight; y++)
      {

        if (grid[x][y] == this.id && overgrowthGrid[x][y] < MAX_URBAN_HEALTH)  // Only select the urban cells that have been damaged
        {

          PVector cell = new PVector(x, y);

          damagedCells.add(cell);

          float distance = dist(x, y, this.location.x, this.location.y);

          float score = 1.0f / (pow(distance, 5) + 1.0f);  // The more far away the lower the priority score

          scores.add(score);

          totalScore += score;
        }
      }
    }

    if (!damagedCells.isEmpty())
    {

      float randomValue = random(totalScore);

      float currentScore = 0;

      for (int i = 0; i < damagedCells.size(); i++)
      {

        currentScore += scores.get(i);

        if (randomValue <= currentScore)
        {

          PVector cellToRepair = damagedCells.get(i);

          overgrowthGrid[(int)cellToRepair.x][(int)cellToRepair.y] = MAX_URBAN_HEALTH;

          return;
        }
      }
    }
  }
}
