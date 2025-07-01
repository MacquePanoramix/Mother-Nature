import java.util.HashSet;
import java.util.HashMap;
import processing.sound.*;
import processing.serial.*; // Import the serial library

// --- CONFIGURATION ---
/*
 *
 * This part handles the general configuration of the program,
 * you can change these constant values as an easy way to 
 * change the behaviour of the program without having to modify 
 * any of the underlying systems.
 * *
 */
float PIXEL_SCALE;  // This will be calculated dynamically to fit the full screen
int ACTIONS_PER_FRAME = 5;  // How manny actions the factories get to take every frame, so increasing this would make them more efficient.
float REPAIR_CHANCE = 0.5f;  // percentage chance of a single factory action being designated to repair one of the damaged cells instead of deciding to expand more.
float HOUSE_CHANCE = 0.3f;  // Change for urban cell to have house design, it's just aesthetic.
float MAX_URBAN_HEALTH = 255.0f;  // The way nature takes over a urban cell is by reducing this health to zero.
float DAMAGE_PER_EXPOSED_SIDE = 0.5f; // Doesn't count diagonals and is applied every frame.
float VINE_SPAWN_CHANCE = 0.01f; // The chance everyframe per outter edge of the city for a vine to spawn on top of it.
int VINE_LIFESPAN = 50;  // How many frames the vine lasts.
float VINE_DAMAGE = 0.1f; // Amount of damage vine deals each frame to the urban cell on top of it.
float VINE_WOBBLE = 0.6f; // Determines how sharp the turns of the wobble would be.
float GRASS_NOISE_SCALE = 0.05f;  // Larger number means less detailed, smaller number means more detailed
float MOSS_NOISE_SCALE = 0.02f;   // Larger number means less detailed, smaller number means more detailed
float PEBBLE_NOISE_SCALE = 0.8f;  // Larger number means less detailed, smaller number means more detailed
float MOSS_THRESHOLD = 0.35f;   // How often moss will appear
float PEBBLE_THRESHOLD = 0.70f;  // How often pebbles will appear
float GRAVEL_AURA_RADIUS = 4.0f;   // Radius of the spread of gravel for a single urban cell
float GRAVEL_BUILD_RATE = 0.05f;  // Percentage of the gravel radius that is built every frame from the urban cell
float GRAVEL_DECAY_RATE = 0.01f;  // Percentage of the gravel radius cleared each frame from a empty urban cell.
color GRAVEL_COLOR_DARK = color(85, 80, 75);  // Gravel is a mix of this dark grey
color GRAVEL_COLOR_LIGHT = color(130, 125, 120);  // And this lighter grey
float SHADING_STRENGTH = 0.5f;  // How high the shadow contrast is, to give more of a sense of 3D to the hills
float INTERNAL_SPREAD_CHANCE = 0.5f; // Damaged cells have this percentage chance to spread a small percentage of it's current damage received to its neighbours.
float INTERNAL_SPREAD_STRENGTH = 0.1f; // The percentage of the amount of current damage received to spread to the neighbours.

// --- GLOBAL STATE ---
/*
 *
 * Here we declare the classes that will make up the logic of the program,
 * the grids that will store coordinates for the world, list of objects in the world
 * and the variables for grid sizes.
 *
 */
float[][] gravelGrid;  // Stores gravel coordinates
int[][] grid;  // General map coordinates
color[][] colorGrid;  // Colors in the map coordinates
int[][] houseGrid;  // Coordinates for where the houses are
float[][] overgrowthGrid;  // Grid to track the HP at every coordinate
ArrayList<Factory> factories;  // List of factories
ArrayList<Hill> hills; // List of hills for the landscape
Nature nature;  // Handles nature take over
SoundManager soundManager;  // Handles sound system
Renderer renderer;  // Handles visual system
ArduinoManager arduinoManager; // Handles communication with the Arduino
int gridWidth;  // How many grid cells for the width
int gridHeight;  // How many grid cells for the Height

// --- SETUP ---
void setup()
{

  /*
   *
   * Here we first initialize all the classes and grids and then
   * We create all the factories in the map.
   *
   */

  // --- ENVIRONMENT INITIALIZATION ---
  /*
   *
   * Setting up all the grids that will handle the dynamics of the environment.
   *
   */
  fullScreen();

  // --- DYNAMIC PIXEL SCALING ---
  /*
   *
   * This calculates the best PIXEL_SCALE to keep the simulation grid the same size
   * regardless of the user's monitor resolution.
   *
   */
  float targetGridWidth = 184.8;  // Based on the 1848px width with a scale of 10
  float targetGridHeight = 104.0; // Based on the 1040px height with a scale of 10
  
  float scaleX = width / targetGridWidth;
  float scaleY = height / targetGridHeight;
  
  PIXEL_SCALE = min(scaleX, scaleY); // Use the smaller scale to ensure the whole grid fits on screen


  gridWidth = (int)(width / PIXEL_SCALE);

  gridHeight = (int)(height / PIXEL_SCALE);

  grid = new int[gridWidth][gridHeight];

  colorGrid = new color[gridWidth][gridHeight];

  houseGrid = new int[gridWidth][gridHeight];

  overgrowthGrid = new float[gridWidth][gridHeight];

  gravelGrid = new float[gridWidth][gridHeight];

  // --- HILL & LANDSCAPE INITIALIZATION ---
  /*
   *
   * Setting up the positions and sizes of the hills based on the landscape sketch.
   *
   */
  hills = new ArrayList<Hill>();
  // These coordinates are percentages of the screen width/height. You can tweak them.
  hills.add(new Hill(new PVector(gridWidth * 0.1f, gridHeight * 0.15f), 20.0f));
  hills.add(new Hill(new PVector(gridWidth * 0.8f, gridHeight * 0.2f), 25.0f));
  hills.add(new Hill(new PVector(gridWidth * 0.2f, gridHeight * 0.8f), 30.0f));
  hills.add(new Hill(new PVector(gridWidth * 0.9f, gridHeight * 0.85f), 18.0f));
  hills.add(new Hill(new PVector(gridWidth * 0.65f, gridHeight * 0.5f), 15.0f));


  // --- MANAGER INITIALIZATION ---
  /*
   *
   * Setting up the classes that will manage the visual, sound, nature, and Arduino logic
   *
   */
  nature = new Nature();

  soundManager = new SoundManager(this);

  renderer = new Renderer(this);
  
  arduinoManager = new ArduinoManager(this);

  renderer.initializeBackground(hills);

  // --- FACTORY INITIALIZATION ---
  /*
   *
   * Setting up the factories which handle the urban takeover logic
   *
   */
  factories = new ArrayList<Factory>();

  // New factory positions based on the photo of the physical model.
  factories.add(new Factory(1, gridWidth * 0.25f, gridHeight * 0.30f));
  factories.add(new Factory(2, gridWidth * 0.75f, gridHeight * 0.65f));
  factories.add(new Factory(3, gridWidth * 0.45f, gridHeight * 0.45f));
  factories.add(new Factory(4, gridWidth * 0.35f, gridHeight * 0.65f));
  factories.add(new Factory(5, gridWidth * 0.60f, gridHeight * 0.80f));


  for(Factory f : factories)
  {

    int x = (int)f.location.x;

    int y = (int)f.location.y;

    if(x >= 0 && x < gridWidth && y >= 0 && y < gridHeight)
    {

      grid[x][y] = f.id; // Adding the factories to the grid info

      colorGrid[x][y] = color(80);

      overgrowthGrid[x][y] = MAX_URBAN_HEALTH;  // Factories spawn with max urban health

      f.activeEdge.add(f.location);
    }
  }
}

// --- MAIN LOOP ---
void draw()
{

  // --- FACTORY ACTIONS (REPAIR & SPREAD) ---
  /*
   *
   * First repairs and adds all the new urban spaces for each factory.
   * They have a bit of brightness variation and might be either an 
   * grey asphalt or represent a random house.
   *
   */
  ArrayList<PVector> newBuildingsThisFrame = new ArrayList<PVector>();  // Stores the urban cells that will spawn

  for (Factory f : factories)
  {

    if (!f.isActive) continue;

    for(int i = 0; i < ACTIONS_PER_FRAME; i++)
    {

      if (random(1) < REPAIR_CHANCE)
      {

        f.repairCell();
      }
      else
      {

        if(f.activeEdge.isEmpty()) continue;

        PVector edgePixelToSpreadFrom = chooseEdgePixelByDistance(f);

        if (edgePixelToSpreadFrom == null) continue;

        ArrayList<PVector> neighbors = getAnyGrassNeighbors(edgePixelToSpreadFrom);

        if(!neighbors.isEmpty())
        {

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

          if (random(1) < HOUSE_CHANCE)
          {

            houseGrid[nx][ny] = (int)random(1, 6);
          }
          newBuildingsThisFrame.add(neighborToConvert);
        }
      }
    }
    f.cleanupEdge();
  }

  // --- NATURE SIMULATION ---
  /*
   *
   * Simulating the nature reclamation given the factory moves.
   *
   */
  nature.update(newBuildingsThisFrame);

  // --- AUDIO UPDATE ---
  /*
   *
   * Simulates the audio part given the current urban cells, number of active factories and total size of the map.
   *
   */
  int urbanCellCount = 0;

  int activeFactories = 0;

  for (int x = 0; x < gridWidth; x++)
  {

    for (int y = 0; y < gridHeight; y++)
    {

      if (grid[x][y] > 0) urbanCellCount++;
    }
  }
  for (Factory f : factories)
  {

    if (f.isActive) activeFactories++;
  }
  soundManager.update(urbanCellCount, activeFactories, factories.size(), gridWidth, gridHeight);

  // --- RENDER ---
  /*
   *
   * Handles drawing the map visually using the info of the grids.
   *
   */
  renderer.drawAll();
}

// --- HELPER FUNCTIONS ---
PVector chooseEdgePixelByDistance(Factory f)
{

  /*
   *
   * Chooses and urban cell currently in contact with a nature cell.
   * The more far away the urban cell is from the selected factory,
   * the smaller is the chance for it to be selected.
   *
   */
  if (f.activeEdge.isEmpty())
  {

    return null;
  }
  ArrayList<Float> scores = new ArrayList<Float>();

  float totalScore = 0;

  for (PVector cell : f.activeEdge)
  {

    float distance = dist(cell.x, cell.y, f.location.x, f.location.y);

    float score = 1.0f / (pow(distance, 5) + 1.0f);  // This is what determines how likely each edge cell is to be selected relative to the other ones.

    scores.add(score);

    totalScore += score;
  }
  float randomValue = random(totalScore);

  float currentScore = 0;

  for (int i = 0; i < f.activeEdge.size(); i++)
  {

    currentScore += scores.get(i);

    if (randomValue <= currentScore)
    {

      return f.activeEdge.get(i);
    }
  }
  return f.activeEdge.get(f.activeEdge.size() - 1);
}

PVector chooseNeighborOrganically(ArrayList<PVector> neighbors, PVector from, Factory factory)
{

  /*
   *
   * First gets the general direction the factory has been spreading towards, wobbles it a bit using perlin noise
   * and then choses a neighbour to spread towards from the selected edge cell. The neighbour that matches more closely
   * the relative direction from the selected edge cell with the factory's prefered direction will be selected.
   *
   * Well almost always that is. There is a 85% chance this is the case but there is a 15% chance of just a completely random neighbour being selected also.
   *
   */
  float angle = atan2(factory.spreadDirection.y, factory.spreadDirection.x);

  angle += map(noise(from.x * 0.1f, from.y * 0.1f, frameCount * 0.01f), 0, 1, -0.5f, 0.5f);

  factory.spreadDirection.set(cos(angle), sin(angle));

  float maxScore = -1;

  PVector bestNeighbor = null;

  for (PVector neighbor : neighbors)
  {

    PVector directionToNeighbor = PVector.sub(neighbor, from);

    directionToNeighbor.normalize();

    float score = directionToNeighbor.dot(factory.spreadDirection);

    if (score > maxScore)
    {

      maxScore = score;

      bestNeighbor = neighbor;
    }
  }
  if (random(1) < 0.85f || neighbors.size() == 1)
  {

    return bestNeighbor;
  }
  else
  {

    return neighbors.get((int)random(neighbors.size()));
  }
}

ArrayList<PVector> getAnyGrassNeighbors(PVector p)  // P here means the coordinates for a certain position
{

  /*
   *
   * This function basically checks the four cells adjacent to the input cell (not checking the diagonals)
   * and gives back a list of all that are nature cells.
   *
   */
  ArrayList<PVector> neighbors = new ArrayList<PVector>();

  int x = (int)p.x;

  int y = (int)p.y;

  int[] dx = {0, 0, -1, 1};

  int[] dy = {-1, 1, 0, 0};

  for(int i = 0; i < 4; i++)
  {

    int nx = x + dx[i];

    int ny = y + dy[i];

    if(nx >= 0 && nx < gridWidth && ny >= 0 && ny < gridHeight)  // Check if it's within the borders of the map
    {

      if(grid[nx][ny] <= 0)  // A value of 0 or less in the grid is natural
      {

        neighbors.add(new PVector(nx, ny));
      }
    }
  }
  return neighbors;
}

// --- USER INPUT ---
void keyPressed()
{

  /*
   *
   * Allows the user to press 'F' to toggle all factories on/off 
   * or press keys 1-5 to toggle each of the 5 factories individually on/off.
   * This is kept as a backup for testing without the Arduino connected.
   *
   */
  switch (key)
  {

    case 'f':

    case 'F':
      for (Factory f : factories)
      {

        f.isActive = !f.isActive;
      }
      break;

    case '1':
      if (factories.size() >= 1)
      {

        factories.get(0).isActive = !factories.get(0).isActive;
      }
      break;

    case '2':
      if (factories.size() >= 2)
      {

        factories.get(1).isActive = !factories.get(1).isActive;
      }
      break;

    case '3':
      if (factories.size() >= 3)
      {

        factories.get(2).isActive = !factories.get(2).isActive;
      }
      break;

    case '4':
      if (factories.size() >= 4)
      {

        factories.get(3).isActive = !factories.get(3).isActive;
      }
      break;

    case '5':
      if (factories.size() >= 5)
      {

        factories.get(4).isActive = !factories.get(4).isActive;
      }
      break;
  }
}

// --- SERIAL EVENT HANDLER ---
void serialEvent(Serial myPort) {
  /*
   *
   * This function automatically runs whenever new data is received from the serial port.
   * It reads the incoming string until it sees a newline character, and then passes
   * the message to the arduinoManager to be processed.
   *
   */
   arduinoManager.handleSerialData(myPort);
}
