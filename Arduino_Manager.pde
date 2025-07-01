import processing.core.PApplet;
import processing.serial.*;

// --- ARDUINO MANAGER CLASS ---
class ArduinoManager {

  /*
   *
   * This class handles all the communication with the Arduino board. It's responsible for finding the
   * correct serial port, opening the connection, and listening for incoming messages that tell the
   * simulation which factories should be active based on the physical sensors.
   *
   */

  // --- CLASS FIELDS ---
  /*
   *
   * We just need a reference to the main sketch to use its functions, and a Serial object
   * which is the actual connection to the Arduino.
   *
   */
  private PApplet parent;
  private Serial myPort;

  // --- CONSTRUCTOR ---
  ArduinoManager(PApplet p) {
    /*
     *
     * When the manager is created, it gets a list of all available serial ports. It then tries to
     * connect to the last one in the list, which is usually the correct one for an Arduino.
     * If it fails, it prints a helpful message to the console so you can see which ports are
     * available and troubleshoot the connection.
     *
     */
    this.parent = p;
    String[] portList = Serial.list();

    if (portList.length > 0) {
      // Usually the last port in the list is the Arduino
      String portName = portList[portList.length - 1];
      println("Attempting to connect to serial port: " + portName);
      try {
        myPort = new Serial(p, portName, 9600);
        myPort.bufferUntil('\n'); // Tell the port to only notify us when a full line has been sent
      } catch (Exception e) {
        println("Error opening serial port " + portName);
        e.printStackTrace();
      }
    } else {
      println("No serial ports found. Please connect your Arduino.");
    }
  }
  
  // --- DATA HANDLING ---
  void handleSerialData(Serial myPort) {
    /*
     *
     * This function is called by the main sketch's serialEvent whenever a complete message
     * arrives from the Arduino. It reads the string, cleans it up, and then updates the
     * state of the factories based on the message content.
     *
     */
     String inString = myPort.readStringUntil('\n');

     if (inString != null) {
       inString = parent.trim(inString); // Clean up any whitespace

       // We expect a string of 5 characters, like "10110"
       if (inString.length() >= 5) {
         for (int i = 0; i < 5; i++) {
           if (i < factories.size()) {
             char state = inString.charAt(i);
             boolean isActive = (state == '1');
             factories.get(i).isActive = isActive;
           }
         }
       }
     }
  }
}
