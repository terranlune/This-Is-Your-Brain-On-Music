/**
Some comment
*/

import processing.serial.*;
import cc.arduino.*;
Arduino arduino;

import ddf.minim.analysis.*;
import ddf.minim.*;

Minim minim;
AudioInput in;
FFT fft;

// Visualizer efaults
float valScale = 1.0;
float maxVisible = 10.0;
float beatThreshold = 0.25;
float colorOffset = 30;
float autoColorOffset = 0.01;

// Show text if recently adjusted
boolean showscale = false;
boolean showBeatThreshold = false;
boolean showHelp = false;

float beatH = 0;
float beatS = 0;
float beatB = 0;
float arduinoBeatB = 0;

float[] lastY;
float[] lastVal;

int buffer_size = 1024;  // also sets FFT size (frequency resolution)
float sample_rate = 44100;

int redPin = 5;
int greenPin = 6;
int bluePin = 3;

boolean fullscreen = false;
int lastWidth = 0;
int lastHeight = 0;

boolean arduinoConnected = false;
int arduinoIndex = 0;
String arduinoMessage = "";

void setup() {

  size(500, 300);
  frame.setResizable(true);
  
  background(0);
  
  minim = new Minim(this);
  in = minim.getLineIn(Minim.MONO,buffer_size,sample_rate);
  
  fft = new FFT(in.bufferSize(), in.sampleRate());
  fft.logAverages(16, 2);
  fft.window(FFT.HAMMING);
  
  lastY = new float[fft.avgSize()];
  lastVal = new float[fft.avgSize()];
  initLasts();
  
  initArduino();
  
  textSize(10);
  
  frame.setAlwaysOnTop(true);
}

int leftBorder()   { return int(.05 * width); }
int rightBorder()  { return int(.05 * width); }
int bottomBorder() { return int(.05 * width); }
int topBorder()    { return int(.05 * width); }

void initArduino()
{
  String[] serialPorts;
  try {
    serialPorts = Arduino.list();
    arduinoIndex %= serialPorts.length;
  }
  catch (Exception e)
  {
    arduinoConnected = false;
    arduinoMessage = "Unable to list serial ports";
    println(e);
    return;
  }
  
  if(arduino != null)
  {
    arduino.dispose();
  }
  
  try {
    arduino = new Arduino(this, serialPorts[arduinoIndex], 57600);
    arduino.pinMode(redPin, Arduino.OUTPUT);
    arduino.pinMode(greenPin, Arduino.OUTPUT);
    arduino.pinMode(bluePin, Arduino.OUTPUT);
    arduinoConnected = true;
    arduinoMessage = "Connected on " +arduinoIndex + ":" + serialPorts[arduinoIndex];
    println(arduinoMessage);
  }
  catch (Exception e) {
    arduinoConnected = false;
    arduinoMessage = "Unable to connect on " +arduinoIndex + ":"+
      serialPorts[arduinoIndex] + "\nPress TAB to try a different port.";
    println(e);
  }
}

void initLasts()
{
  
  for(int i = 0; i < fft.avgSize(); i++) {
    lastY[i] = height - bottomBorder();
    lastVal[i] = 0;
  }
  
}

void draw() {
   
    colorMode(RGB);
  
    // Detect resizes
    if(width != lastWidth || height != lastHeight)
    {
      lastWidth = width;
      lastHeight = height;
      background(0);
      initLasts();
      println("resized");
    }
  
    // Slowly erase the screen
    fill(0,10 * 60/frameRate); // Based on 60fps
    rect(0,0,width,height - 0.8*bottomBorder());
  
    colorMode(HSB, 100);
  
    fft.forward(in.mix);
    smooth();
    noStroke();
    
    
    int iCount = fft.avgSize();
    float barHeight =  0.03*(height-topBorder()-bottomBorder());
    float barWidth = (width-leftBorder()-rightBorder())/iCount;
    
    float biggestValChange = 0;
    
    for(int i = 0; i < iCount; i++) {
      
      float iPercent = 1.0*i/iCount;
      
      float highFreqscale = 1.0 + pow(iPercent, 4) * 2.0;
      
      float val = sqrt(fft.getAvg(i)) * valScale * highFreqscale / maxVisible;
      
      float y = height - bottomBorder() - val * (height - bottomBorder() - topBorder());
      float x = leftBorder() + iPercent * (width - leftBorder() - rightBorder()) ;
      
      float h = 100 - (100.0 * iPercent + colorOffset) % 100;
      float s = 70 - pow(val, 3) * 70;
      float b = 100;
      
      fill(h, s, b);
      textAlign(CENTER, BOTTOM);
      text(nf(int(100*val),2), x+barWidth/2, y);
           
      rectMode(CORNERS);
      rect(x, y+barHeight/2, x+barWidth, lastY[i]+barHeight/2);
      
      float valDiff = val-lastVal[i];
      if(valDiff > beatThreshold && valDiff > biggestValChange)
      {
        biggestValChange = valDiff;
        beatH = h;
        beatS = s;
        beatB = b;
      }
      
      lastY[i] = y;
      lastVal[i] = val;

    }
    
    // If we've hit a beat, bring the brightness of the bar up to full
    if(biggestValChange > beatThreshold)
    {
      arduinoBeatB = 100;
    }  
    
    // calculate the arduino beat color
    color c_hsb = color(beatH, 90, constrain(arduinoBeatB, 1, 100));
    
    int r = int(red(c_hsb) / 100 * 255);
    int g = int(green(c_hsb) / 100 * 255);
    int b = int(blue(c_hsb) / 100 * 255);
   
    // clear out the message area
    fill(0);
    rect(0, height - 0.8*bottomBorder(), width, height);
    
    // draw the beat bar
    colorMode(RGB, 255);
    fill(r, g, b);
    rect(leftBorder(), height - 0.8*bottomBorder(), width-rightBorder(), height - .5*bottomBorder());

    // Tell the arduino to draw
    if (arduinoConnected)
    {
      try
      {
        arduino.analogWrite(redPin, r);
        arduino.analogWrite(greenPin, g);
        arduino.analogWrite(bluePin, b);
        fill(16,16,16);
        textAlign(CENTER, BOTTOM);
        text(arduinoMessage, width/2, height);
      }
      catch (Exception e) {
        arduinoConnected = false;
        arduinoMessage = "Lost connection!  Press TAB to reconnect.";
        arduinoIndex--; // Pressing TAB advances, but we want to retry the same index
        println(e);
      }
    }
    else
    {
      fill(16);
      rect(0, topBorder()-15, width, topBorder()+15);
      
      fill(255,64,64);
      textAlign(CENTER, CENTER);
      text("Arduino error: " + arduinoMessage, width/2, topBorder());
    }

    // Decay the arduino beat brightness (based on 60 fps)
    arduinoBeatB *= 1.0 - 0.10 * 60/frameRate;
    
    // Automatically advance the color
    colorOffset += autoColorOffset;
    colorOffset %= 100;

    // Show the scale if it was adjusted recently
    if(showscale)
    {
      fill(255,255,255);
      textAlign(RIGHT, TOP);
      text("scale:"+nf(valScale,1,1), width-rightBorder(), topBorder());
      showscale=false;
    }
    
    // Show the beat threshold if it was adjusted recently
    if(showBeatThreshold)
    {
      fill(255,255,255);
      textAlign(RIGHT, TOP);
      text("beat threshold:"+nf(beatThreshold,1,2), width-rightBorder(), topBorder());
      showBeatThreshold=false;
    }
     
    // Show the help
    if(showHelp)
    {
      fill(255,255,255);
      textAlign(RIGHT, TOP);
      text("Help:\nUP/DOWN arrows = Scale Visualizer\n" + 
           "LEFT/RIGHT arrows = Temporarily shift colors\n" + 
           "+/- = Beat Detection Sensitivity\n" + 
           "TAB = Use Next Arduino Port\n" + 
           "SPACE = Toggle full-screen\n" + 
           "Anything Else = Show this help", width-rightBorder(), topBorder());
      showHelp=false;
    }
     
    // Display the frame rate
    fill(16, 16, 16);
    textAlign(RIGHT, BOTTOM);
    text(nf(frameRate,2,1) + " fps", width - rightBorder(), topBorder());
    if(!fullscreen)
    {
    frame.setTitle("This Is Your Brain On Music ("+nf(frameRate,2,1)+" fps)");
    }

}

void keyReleased()
{
  if (key == CODED)
  {
   if (keyCode == UP)
   {
     valScale += 0.1;
     showscale=true;
   }
   else if (keyCode == DOWN)
   {
     valScale -= 0.1;
     showscale = true;
   }
   else if (keyCode == RIGHT)
   {
     colorOffset -= 5;
   }
   else if (keyCode == LEFT)
   {
     colorOffset += 5;
   }
  }
  else
  {
    if (key == '+')
    {
      beatThreshold += 0.05;
      showBeatThreshold=true;
    }
    else if (key == '-')
    {
      beatThreshold -= 0.05;
      showBeatThreshold=true;
    }
    else if (key == ' ')
    {
      toggleFullScreen();
    }
    else if (key == TAB)
    {
      arduinoIndex++;
     initArduino(); 
    }
    else
    {
      showHelp = true;
    }
  } 
}

void keyPressed()
{
  
  // In fullscreen mode, capture ESC for exiting full screen
  if (key == ESC)
  {
   if(fullscreen)
   {
     toggleFullScreen(); 
     key=0;
   }
  }
}

void toggleFullScreen()
{
  fullscreen = !fullscreen;
  
  frame.removeNotify();
  frame.setUndecorated(fullscreen);
  if(fullscreen) {
    frame.setSize(screenWidth, screenHeight);
    frame.setLocation(0,0);
  }
  else
  {
    frame.setSize(500, 300);
    frame.setLocation(100,100);
  }
  frame.addNotify();
}

void stop()
{
  // always close Minim audio classes when you finish with them
  in.close();
  minim.stop();
 
  super.stop();
}
