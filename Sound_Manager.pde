import processing.core.PApplet;
import processing.sound.*;
import java.util.ArrayList;

// --- SOUND MANAGER CLASS ---
class SoundManager
{

  /*
   *
   * This class handles everything related to sound in the simulation. It manages the ambient background
   * sounds like wind and birds, the industrial hum of the city, and all the random, event-based sounds
   * like whistles and clanks. It adjusts the volume of these sounds based on the state of the simulation.
   *
   */

  // --- CLASS FIELDS ---
  PApplet parent;
  SinOsc humOscillator;
  SoundFile windSound;
  SoundFile birdsSound;
  ArrayList<SoundFile> activeWhistles;
  int lastIndustrialSoundTime;
  final int BIRD_FADE_IN_TIME = 10000;
  final float MAX_BIRD_VOLUME = 0.8f;
  final int MAX_SIMULTANEOUS_WHISTLES = 3;

  // --- CONSTRUCTOR ---
  SoundManager(PApplet p)
  {

    /*
     *
     * This is where we load up all the sound files and set up the sound objects when the program starts.
     * It gets the wind and bird sounds looping and creates the hum oscillator, but keeps their volumes at
     * zero initially. It also sets up the timers and lists needed to manage the event sounds.
     *
     */
    this.parent = p;

    humOscillator = new SinOsc(p);

    humOscillator.freq(50);

    humOscillator.amp(0);

    humOscillator.play();

    windSound = new SoundFile(p, "wind.mp3");

    windSound.loop();

    birdsSound = new SoundFile(p, "birds.mp3");

    birdsSound.loop();

    activeWhistles = new ArrayList<SoundFile>();

    lastIndustrialSoundTime = parent.millis();
  }

  // --- CLASS METHODS ---
  void update(int urbanCellCount, int activeFactories, int totalFactories, float gridWidth, float gridHeight)
  {

    /*
     *
     * This function is called every frame to update the soundscape based on what's happening in the simulation.
     * First, it adjusts the ambient sounds (wind and industrial hum) based on how much of the map is covered by the city.
     * Next, it calculates the volume for the bird sounds, which depend on both the amount of nature and how long it's been
     * since an industrial sound has played. Finally, it handles the random, event-based sounds like whistles and clanks.
     *
     */
    float totalCells = gridWidth * gridHeight;

    float maxUrbanForFade = totalCells / 2;

    float windVolume = parent.map(urbanCellCount, 0, maxUrbanForFade, 1f, 0);

    windVolume = PApplet.constrain(windVolume, 0, 1f);

    windSound.amp(windVolume);

    float targetHumVolume = parent.map(urbanCellCount, 0, totalCells / 2, 0, 0.2f);

    humOscillator.amp(targetHumVolume);

    float naturePresenceVolume = parent.map(urbanCellCount, 0, maxUrbanForFade, MAX_BIRD_VOLUME, 0);

    naturePresenceVolume = PApplet.constrain(naturePresenceVolume, 0, MAX_BIRD_VOLUME);

    long timeSinceIndustrial = parent.millis() - lastIndustrialSoundTime;

    float silenceFadeIn = parent.map(timeSinceIndustrial, 1000, BIRD_FADE_IN_TIME, 0, 1.0f);

    silenceFadeIn = PApplet.constrain(silenceFadeIn, 0, 1.0f);

    float birdVolume = naturePresenceVolume * silenceFadeIn;

    birdsSound.amp(birdVolume);

    for (int i = activeWhistles.size() - 1; i >= 0; i--)
    {

      SoundFile whistle = activeWhistles.get(i);

      if (!whistle.isPlaying())
      {

        activeWhistles.remove(i);
      }
    }

    if (activeFactories > 0 && activeWhistles.size() < MAX_SIMULTANEOUS_WHISTLES)
    {

      float baseWhistleChance = 0.001f;

      float maxWhistleChance = 0.01f;

      float whistleChance = parent.map(activeFactories, 1, totalFactories, baseWhistleChance, maxWhistleChance);

      if (parent.random(1) < whistleChance)
      {

        SoundFile temporaryWhistle = new SoundFile(parent, "whistle.mp3");

        LowPass temporaryFilter = new LowPass(parent);

        temporaryFilter.process(temporaryWhistle);

        temporaryFilter.freq(350);

        float rate = parent.random(0.8f, 2f);

        temporaryWhistle.play(rate, 1f);

        activeWhistles.add(temporaryWhistle);

        lastIndustrialSoundTime = parent.millis();
      }
    }

    float clankChance = 0.03f;

    if (activeFactories > 0 && parent.random(1) < clankChance)
    {

      SoundFile temporaryClank = new SoundFile(parent, "clank.mp3");

      LowPass temporaryClankFilter = new LowPass(parent);

      temporaryClankFilter.process(temporaryClank);

      temporaryClankFilter.freq(100);

      float duration = temporaryClank.duration();

      float startTime = parent.random(0, duration * 0.8f);

      temporaryClank.jump(startTime);

      float rate = parent.random(0.1, 0.3);

      float amp = parent.random(0.1, 0.1);

      temporaryClank.play(rate, amp);

      lastIndustrialSoundTime = parent.millis();
    }
  }
}
