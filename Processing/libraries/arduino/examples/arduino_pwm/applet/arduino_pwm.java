import processing.core.*; 
import processing.xml.*; 

import processing.serial.*; 
import cc.arduino.*; 

import java.applet.*; 
import java.awt.Dimension; 
import java.awt.Frame; 
import java.awt.event.MouseEvent; 
import java.awt.event.KeyEvent; 
import java.awt.event.FocusEvent; 
import java.awt.Image; 
import java.io.*; 
import java.net.*; 
import java.text.*; 
import java.util.*; 
import java.util.zip.*; 
import java.util.regex.*; 

public class arduino_pwm extends PApplet {





Arduino arduino;

public void setup() {
  size(512, 200);
  arduino = new Arduino(this, Arduino.list()[0], 57600);
}

public void draw() {
  background(constrain(mouseX / 2, 0, 255));
  arduino.analogWrite(9, constrain(mouseX / 2, 0, 255));
  arduino.analogWrite(11, constrain(255 - mouseX / 2, 0, 255));
}
  static public void main(String args[]) {
    PApplet.main(new String[] { "--bgcolor=#FFFFFF", "arduino_pwm" });
  }
}
