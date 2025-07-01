// --- HILL CLASS ---
/*
 *
 * A simple class to hold the data for a single hill in the landscape.
 *
 */
class Hill {
  PVector location;
  float radius;

  Hill(PVector loc, float r) {
    location = loc;
    radius = r;
  }
}
