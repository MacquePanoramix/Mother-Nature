import processing.core.PApplet;
import processing.core.PGraphics;
import processing.core.PVector;

// --- RENDERER CLASS ---
class Renderer
{

  /*
   *
   * This class handles all the visual part of the simulation.
   * It gets all the data from the simulation and transforms it into a final image we see in the screen as the resulting pixelated map.
   *
   */

  // --- CLASS FIELDS ---
  /*
   *
   * Simply declaring these general objects to help us draw the background.
   *
   */
  private PApplet parent;  // This just makes it so we can use the functions and everything else that is on the main sketch.
  private PGraphics backgroundBuffer;  // This optimizes the performance to render the images compared to normal processing

  // --- CONSTRUCTOR ---
  Renderer(PApplet p)
  {

    /*
     *
     * Just initializing the object that allows us to use stuff from the main sketch 'p'
     *
     */
    this.parent = p;
  }

  // --- INITIALIZATION ---
  void initializeBackground(ArrayList<Hill> hills)
  {

    /*
     *
     * We create a buffer which is like the drawing place that we can setup what we wanna draw and then call is to draw once we decide on everything to include
     * and then we call the function that sets up the background that will not change over time.
     *
     */
    this.backgroundBuffer = parent.createGraphics(parent.width, parent.height);

    renderStaticBackground(hills);
  }

  // --- MAIN DRAW METHOD ---
  void drawAll()
  {

    /*
     *
     * Okay at every frame we want to first draw the static background from the buffer, add on top of it the gravel
     * and then finally draw on top of both the city part. This layering makes sure everything looks correct.
     *
     */
    parent.image(backgroundBuffer, 0, 0);

    drawGravelOverlay();

    drawScene();
  }

  // --- PRIVATE DRAWING METHODS ---
  private void renderStaticBackground(ArrayList<Hill> hills)
  {

    /*
     *
     * So this is the function that will load up in the buffer the part of the scene that we don't want to change (apart from drawing other stuff on top of it).
     *
     * So the way it works is first for each pixel, it calculates several different noises for the textures.
     * After setting the base textures, it calculates the elevation based on a list of pre-defined hills.
     * It then compares the position of that terrain with a light source and if the terrain is facing the light is gets brighter,
     * if it's facing away it gets darker.
     *
     */
    backgroundBuffer.beginDraw();

    PVector lightDirection = new PVector(0, 1);

    lightDirection.normalize();

    backgroundBuffer.loadPixels();

    for (int y = 0; y < backgroundBuffer.height; y++)
    {

      for (int x = 0; x < backgroundBuffer.width; x++)
      {

        int loc = x + y * backgroundBuffer.width;

        int pixelColor;
        
        // --- TEXTURE GENERATION ---
        float grassNoise = parent.noise(x * GRASS_NOISE_SCALE, y * GRASS_NOISE_SCALE);

        float mossNoise = parent.noise(x * MOSS_NOISE_SCALE + 1000, y * MOSS_NOISE_SCALE + 1000); // Adding 1000 to get a different noise pattern from the grass

        float pebbleNoise = parent.noise(x * PEBBLE_NOISE_SCALE, y * PEBBLE_NOISE_SCALE);

        pixelColor = parent.lerpColor(parent.color(90, 100, 50), parent.color(60, 140, 60), grassNoise);

        if (mossNoise > MOSS_THRESHOLD)
        {

          float mossMix = parent.map(mossNoise, MOSS_THRESHOLD, 1.0f, 0, 1);

          pixelColor = parent.lerpColor(pixelColor, parent.color(40, 90, 45), mossMix);
        }
        if (pebbleNoise > PEBBLE_THRESHOLD)
        {

          float pebbleMix = parent.map(pebbleNoise, PEBBLE_THRESHOLD, 1.0f, 0, 1);

          pixelColor = parent.lerpColor(pixelColor, parent.color(140, 140, 140), pebbleMix);
        }

        // --- HILL ELEVATION & SHADING ---
        float elevation = 0;
        for(Hill h : hills) {
          float d = dist(x, y, h.location.x, h.location.y);
          if (d < h.radius) {
            // Use a cosine-based curve for a smooth, rounded hill shape
            float hillHeight = cos(map(d, 0, h.radius, 0, HALF_PI));
            elevation = max(elevation, hillHeight);
          }
        }

        // We need to calculate the normal vector based on the new elevation
        // To do this, we calculate the elevation at adjacent pixels
        float elevationRight = 0;
        for(Hill h : hills) {
          float d = dist(x + 1, y, h.location.x, h.location.y);
          if (d < h.radius) {
            float hillHeight = cos(map(d, 0, h.radius, 0, HALF_PI));
            elevationRight = max(elevationRight, hillHeight);
          }
        }
        float elevationDown = 0;
        for(Hill h : hills) {
          float d = dist(x, y + 1, h.location.x, h.location.y);
          if (d < h.radius) {
            float hillHeight = cos(map(d, 0, h.radius, 0, HALF_PI));
            elevationDown = max(elevationDown, hillHeight);
          }
        }
        
        float nx = elevation - elevationRight; // Approximation of the slope in x
        float ny = elevation - elevationDown; // Approximation of the slope in y

        PVector normal = new PVector(nx, ny);

        float shading = normal.dot(lightDirection);

        if (shading > 0)
        {

          pixelColor = parent.lerpColor(pixelColor, parent.color(255), shading * SHADING_STRENGTH * 0.5f); // Halving the highlight strength makes them less intense
        }
        else
        {

          pixelColor = parent.lerpColor(pixelColor, parent.color(0), PApplet.abs(shading) * SHADING_STRENGTH);
        }
        backgroundBuffer.pixels[loc] = pixelColor;
      }
    }
    backgroundBuffer.updatePixels();

    backgroundBuffer.endDraw();
  }

  private void drawGravelOverlay()
  {

    /*
     *
     * This function is responsible for drawing the gravel effect. It checks the gravelGrid to see how much
     * gravel (from 0 to 1) should be at each position. It then draws a rectangle with a color that mixes between
     * our two gravel colors using noise for a nice texture. The 'alpha' value is based on the gravel strength,
     * which is what makes it fade in and out smoothly.
     *
     */
    parent.noStroke();

    for (int y = 0; y < gridHeight; y++)
    {

      for (int x = 0; x < gridWidth; x++)
      {

        float gravelStrength = gravelGrid[x][y];

        if (gravelStrength > 0)
        {

          float gravelNoise = parent.noise(x * 0.5f, y * 0.5f);

          int gravelColor = parent.lerpColor(GRAVEL_COLOR_DARK, GRAVEL_COLOR_LIGHT, gravelNoise);

          float alpha = parent.map(gravelStrength, 0, 1, 0, 255);

          parent.fill(gravelColor, alpha);

          parent.rect(x * PIXEL_SCALE, y * PIXEL_SCALE, PIXEL_SCALE, PIXEL_SCALE);
        }
      }
    }
  }

  private void drawScene()
  {

    /*
     *
     * This draws the main "action" of the simulation. It goes through the grid and for every urban cell,
     * it draws the base grey color. Then, it checks if it should be a house and calls drawHouse if needed.
     * After that, it checks the cell's health in the overgrowthGrid. If it's damaged, it draws a semi-transparent
     * green/brown decay color on top. The more damage, the more visible the decay. Finally, it draws the black
     * squares for the factory origins.
     *
     */
    parent.noStroke();

    for(int x = 0; x < gridWidth; x++)
    {

      for(int y = 0; y < gridHeight; y++)
      {

        if(grid[x][y] > 0)
        {

          parent.fill(colorGrid[x][y]);

          parent.rect(x * PIXEL_SCALE, y * PIXEL_SCALE, PIXEL_SCALE, PIXEL_SCALE);

          if (houseGrid[x][y] > 0)
          {

            drawHouse(x, y, houseGrid[x][y]);
          }
          float health = overgrowthGrid[x][y];

          if (health < MAX_URBAN_HEALTH)
          {

            int naturalDecayColor = parent.color(70, 150, 70);

            int gravelDecayColor = parent.color(50, 45, 40);

            float gravelStrength = gravelGrid[x][y];

            int decayColor = parent.lerpColor(naturalDecayColor, gravelDecayColor, gravelStrength);

            float alpha = parent.map(health, MAX_URBAN_HEALTH, 0, 0, 180); // Capping the decay visibility at 180 makes it look better

            parent.fill(decayColor, alpha);

            parent.rect(x * PIXEL_SCALE, y * PIXEL_SCALE, PIXEL_SCALE, PIXEL_SCALE);
          }
        }
      }
    }
    parent.fill(0);

    parent.rectMode(PApplet.CORNER);

    for (Factory f : factories)
    {

      if (f.isActive)
      {

        parent.rect(f.location.x * PIXEL_SCALE, f.location.y * PIXEL_SCALE, PIXEL_SCALE, PIXEL_SCALE);
      }
    }
  }

  private void drawHouse(int gridX, int gridY, int houseType)
  {

    /*
     *
     * This is just a little helper function. When drawScene finds a cell that should be a house,
     * it calls this function to handle the drawing. Based on the 'houseType' number, it draws
     * a different combination of simple rectangles to create a unique house design.
     *
     */
    float x = gridX * PIXEL_SCALE;

    float y = gridY * PIXEL_SCALE;

    float ps = PIXEL_SCALE;

    parent.rectMode(PApplet.CORNER);

    parent.noStroke();

    switch(houseType)
    {

      case 1:
        parent.fill(115, 90, 85);

        parent.rect(x, y + ps*0.4f, ps, ps*0.6f);

        parent.fill(140, 75, 70);

        parent.rect(x, y, ps, ps*0.5f);

        break;

      case 2:
        parent.fill(80, 60, 50);

        parent.rect(x, y + ps*0.5f, ps, ps*0.5f);

        parent.fill(60, 40, 30);

        parent.rect(x, y + ps*0.3f, ps, ps*0.3f);

        parent.rect(x + ps*0.2f, y + ps*0.1f, ps*0.6f, ps*0.3f);

        break;

      case 3:
        parent.fill(130, 130, 125);

        parent.rect(x, y, ps, ps);

        parent.fill(110, 110, 105);

        parent.rect(x, y, ps, ps*0.3f);

        break;

      case 4:
        parent.fill(140, 135, 130);

        parent.rect(x, y + ps*0.4f, ps, ps*0.6f);

        parent.fill(80, 95, 85);

        parent.rect(x, y, ps, ps*0.5f);

        break;

      case 5:
        parent.fill(100, 100, 100);

        parent.rect(x + ps*0.15f, y, ps*0.7f, ps);

        parent.fill(80, 80, 80);

        parent.rect(x + ps*0.15f, y, ps*0.7f, ps*0.3f);

        break;
    }
  }
}
