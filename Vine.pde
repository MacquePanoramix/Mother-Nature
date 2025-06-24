// --- NEW VINE CLASS ---
class Vine {
  PVector location;
  PVector direction;
  int lifespan;
  float noiseOffset;

  Vine(PVector startLocation) {
    this.location = startLocation.copy();
    this.lifespan = VINE_LIFESPAN;
    this.noiseOffset = random(1000); // Unique noise offset for this vine

    // Start by growing away from the grass, into the city.
    PVector cityCenter = new PVector(gridWidth / 2, gridHeight / 2);
    this.direction = PVector.sub(cityCenter, this.location);
    this.direction.normalize();
  }

  // The main logic for the vine's behavior
  void grow() {
    // Make the direction wander organically using Perlin noise
    float angle = atan2(direction.y, direction.x);
    angle += map(noise(frameCount * 0.02f + noiseOffset), 0, 1, -VINE_WOBBLE, VINE_WOBBLE);
    direction.set(cos(angle), sin(angle));

    // Move one step in the new direction
    location.add(direction);
    lifespan--;

    int x = (int)location.x;
    int y = (int)location.y;

    // Check if the vine is still within the grid
    if (x >= 0 && x < gridWidth && y >= 0 && y < gridHeight) {
      // If the vine is over a city cell, damage it
      if (grid[x][y] > 0) {
        overgrowthGrid[x][y] -= VINE_DAMAGE;
        // Optional: Make vines die faster when they hit healthy city parts
        // lifespan -= 2;
      }
    }
  }

  // Check if the vine's life is over or it has gone off-screen
  boolean isDead() {
    return lifespan <= 0 ||
           location.x < 0 || location.x >= gridWidth ||
           location.y < 0 || location.y >= gridHeight;
  }
}
