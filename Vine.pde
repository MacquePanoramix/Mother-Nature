// --- VINE CLASS ---
class Vine
{

  /*
   *
   * This class defines the behavior of a single vine. A vine is an agent of nature that spawns
   * on a city edge, moves across the map for a limited time, and damages any buildings it touches.
   * It has its own lifespan and a wobbly, organic movement pattern. It's important to 
   * remember that the vine is not actually visible, we can just observe its effects.
   *
   */

  // --- CLASS FIELDS ---
  /*
   *
   * These are the properties of each vine. It has a 'location' on the grid, a 'direction'
   * it's moving in, a 'lifespan' that ticks down, and a 'noiseOffset' to make its
   * wobble unique from other vines.
   *
   */
  PVector location;
  PVector direction;
  int lifespan;
  float noiseOffset;

  // --- CONSTRUCTOR ---
  Vine(PVector startLocation)
  {

    /*
     *
     * This is called when a new vine is created. It sets the vine's starting 'location', gives it its full 'lifespan',
     * and assigns a random 'noiseOffset'. It also calculates its initial 'direction' to be generally
     * pointing away from its spawn point and towards the center of the city.
     *
     */
    this.location = startLocation.copy();

    this.lifespan = VINE_LIFESPAN;

    this.noiseOffset = random(1000); // Ensures each vine has its own unique wobble pattern

    PVector cityCenter = new PVector(gridWidth / 2, gridHeight / 2);

    this.direction = PVector.sub(cityCenter, this.location);

    this.direction.normalize();
  }

  // --- GROWTH METHOD ---
  void grow()
  {

    /*
     *
     * This function is called every frame to make the vine move and act. First, it makes the vine's
     * direction 'wobble' using Perlin noise to create an organic movement. Then, it moves the vine one
     * step in its new direction and reduces its lifespan. If the vine's new location is on top of a
     * city building, it applies damage.
     *
     */
    float angle = atan2(direction.y, direction.x);

    angle += map(noise(frameCount * 0.02f + noiseOffset), 0, 1, -VINE_WOBBLE, VINE_WOBBLE);

    direction.set(cos(angle), sin(angle));

    location.add(direction);

    lifespan--;

    int x = (int)location.x;

    int y = (int)location.y;

    if (x >= 0 && x < gridWidth && y >= 0 && y < gridHeight)
    {

      if (grid[x][y] > 0)
      {

        overgrowthGrid[x][y] -= VINE_DAMAGE;
      }
    }
  }

  // --- STATE CHECK ---
  boolean isDead()
  {

    /*
     *
     * This is a simple check that returns 'true' if the vine should be removed from the simulation.
     * This happens if its 'lifespan' has run out OR if it has moved off the edge of the map.
     *
     */
    return lifespan <= 0 ||
           location.x < 0 || location.x >= gridWidth ||
           location.y < 0 || location.y >= gridHeight;
  }
}
