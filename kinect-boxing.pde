// Kinect photo booth + boxing game

import org.openkinect.*;
import org.openkinect.processing.*;
import interfascia.*;
import unlekker.util.*;
import unlekker.geom.*;
import unlekker.data.*;

// UI
GUIController c;
IFTextField email;
IFLabel question;
IFLabel response;

boolean do_update = true;

// Kinect Library object
Kinect kinect;
// depth data buffer
int[]  depth; 
// Size of kinect image
int w = 640;
int h = 480;
// rotation variable
float a = 0;


// We'll use a lookup table so that we don't have to repeat the math over and over
float[] depthLookUp = new float[2048];

// Game data
PVector old_center = null;
PVector disturbance = new PVector(0,0,0);
float disturbance_threshold = 0.01;
float relaxation = 0.95;

// scores
float high_today = 0;
float high_this_session = 0;

void setup() {
  size(800,600,P3D);
  colorMode(HSB,100);

  // Kinect setup:
  kinect = new Kinect(this);
  kinect.start();
  kinect.enableDepth(true);
  //  kinect.enableRGB(true);
  
  // We don't need the grayscale image in this example
  // so this makes it more efficient
  kinect.processDepthImage(false);

  // GUI features
  c = new GUIController(this);
  email = new IFTextField("Email Field", 25, 50, 150);
  question = new IFLabel("", 25, 20);
  response = new IFLabel("", 25, 80);
  
  c.add(email);
  c.add(question);
  c.add(response);

  email.addActionListener(this);
    // ui color
  IFLookAndFeel white = new IFLookAndFeel(this, IFLookAndFeel.DEFAULT);
  white.textColor = color(100,0,100);
  question.setLookAndFeel(white);
  response.setLookAndFeel(white);

  // Speedup: Lookup table for all possible depth values (0 - 2047)
  for (int i = 0; i < depthLookUp.length; i++) {
    depthLookUp[i] = rawDepthToMeters(i);
  }
  
  // game data
  String[] state_data = loadStrings("sketch_state.txt");
  if (state_data != null) {
    high_today = Float.parseFloat(state_data[0]);
  }
}

void draw() {
  if (do_update) {
    pushMatrix();
    background(100,0,10);
    fill(255);
    textMode(SCREEN);
    text("Kinect FR: " + (int)kinect.getDepthFPS() + "\nProcessing FR: " + (int)frameRate,10,16);
  
    // Get the raw depth as array of integers
    depth = kinect.getRawDepth();
  //  PImage rgb = new PImage(640,480);
  //  rgb.copy(kinect.getVideoImage(),0,0,640,480,0,0,640,480);
  
    // We're just going to calculate and draw every 4th pixel (equivalent of 160x120)
    int skip = 4;
  
    // Translate and rotate
    translate(width/2,height/2,-50);
    rotateY(sin(a));
  //  rotateZ(a);
    float minz = 100;
    int npixels = 0;
    int[] buckets = new int[10];
    for (int i=0; i < depth.length; i++) {
      if (depthLookUp[depth[i]] > 0) {
        npixels++;
        minz = min(depthLookUp[depth[i]],minz);
      }
    }
    for (int i=0; i < depth.length; i++) {
      float z = depthLookUp[depth[i]];
      if (z > 0 && z < minz + 0.8) {
        int bi = floor((z-minz)/0.8*10);
        buckets[bi] = buckets[bi] + 1;
      }
    }
    float collect_z = 0.0;
    if (buckets[0] < 0.1 * npixels) {
      collect_z = minz + 0.1*0.8;
    }
  //  println("minz: " + minz);
    PVector center = new PVector(0,0,0);
    float summed = 0;
    //println("Color max H: " + (100.0/2+min(disturbance.mag()*500,50)));
  
    for(int x=0; x<w; x+=skip) {
      for(int y=0; y<h; y+=skip) {
        int offset = x+y*w;
  
        // Convert kinect data to world xyz coordinate
        int rawDepth = depth[offset];
        PVector v = depthToWorld(x,y,rawDepth);
        if (v.z<minz+0.8 && 0<v.z) {
          if (v.z < collect_z) {
            center.add(v);
            summed++;
          }
          stroke(255);
          pushMatrix();
          // Scale up by 200
          float factor = 600;
          PVector sinevec = new PVector(random(1)*disturbance.x,random(1)*disturbance.y,random(1)*disturbance.z);
  //        sinevec.mult(0.1);
          sinevec.mult(sin(10*a*a));
          v.add(sinevec);
          translate(v.x*factor,v.y*factor,factor-v.z*factor);
          // Draw a point
          color c = color(100-((v.z-minz)/0.8*100)/2+min(disturbance.mag()*500,50),100,100);
          stroke(c);
          fill(c);
          beginShape();
          vertex(0,-1);
          vertex(1,0);
          vertex(0,1);
          vertex(-1,0);
          endShape();
          popMatrix();
        }
      }
    }
    if (summed > 10) {
      center.div(summed); // center of mass
      PVector diff = new PVector(center.x,center.y,center.z);
      if (old_center != null) {
        diff.sub(old_center);
        diff.set(diff.x,diff.y,2*diff.z);
        if (diff.mag() > disturbance.mag() && diff.mag() > disturbance_threshold) {
          disturbance.add(diff);
          high_this_session = max(high_this_session,disturbance.mag());
          response.setLabel("");
        }
        disturbance.mult(relaxation);
      }
      old_center = center;
    }
    // Rotate
    a += 0.015f;
    popMatrix();
    // draw score graphs
    stroke(0,0,100);
    fill(0,0,100);
    float score_scale = 200;
    // current score
    rect(750,580-disturbance.mag()*score_scale,10,disturbance.mag()*score_scale);
    rect(750,580-high_this_session*score_scale,10,5);
    if (high_today > high_this_session) {
      rect(750,580-high_today*score_scale,10,5);
    }
  }
}

void keyPressed() {
  if (key == ' ') {
    if (do_update) {
      response.setLabel("");
      question.setLabel("Giv os din email, for at gemme et billede");
      email.setValue("");
      c.requestFocus(email);
      do_update = false;
    } else {
      do_update = true;
      question.setLabel("");
    }
  }
}


void actionPerformed(GUIEvent e) {
  if (e.getSource() == email) {
    if (e.getMessage().equals("Completed")) {
      String filename = savePointcloud();
      // save hi-score + STL cloud
      String[] content = new String[4];
      content[0] = "email=" + email.getValue();
      content[1] = "stlfile=" + filename + ".stl";
      content[2] = "score=" + high_this_session;
      content[3] = "ranking=" + performance_stats();
      saveStrings(filename + ".txt",content);
      // save the data
      response.setLabel("Tak! Vi sender dig en email");
      question.setLabel("");
      email.setValue("");
      do_update = true;
      high_this_session = 0;
      a = 0.0;
    }
  }
}

String performance_stats() {
  if (high_this_session>high_today) {
    high_today = high_this_session;
    String[] state_data = new String[1];
    state_data[0] = "" + high_today;
    saveStrings("sketch_state.txt",state_data);
    return "Bedste score idag!";
  } else {
    return "" + high_this_session/high_today*100 + " af dagens bedste score";
  }
}

String savePointcloud() {
  String filename = "samdata.ansigt_" + year() + "_" + month() + "_" + day() + "_" + hour() + "_" + minute() + "_" + second() + "_" + millis();
  beginRaw("unlekker.data.STL", filename + ".stl");
  pushMatrix();
  // We're just going to calculate and draw every 4th pixel (equivalent of 160x120)
  int skip = 4;

  // Translate and rotate
  translate(width/2,height/2,-50);
  rotateY(0);
  float minz = 100;
  for (int i=0; i < depth.length; i++) {
    if (depthLookUp[depth[i]] > 0) {
      minz = min(depthLookUp[depth[i]],minz);
    }
  }
  for(int x=0; x<w; x+=skip) {
    for(int y=0; y<h; y+=skip) {
      int offset = x+y*w;

      // Convert kinect data to world xyz coordinate
      int rawDepth = depth[offset];
      PVector v = depthToWorld(x,y,rawDepth);
      if (v.z<minz+0.8 && 0<v.z) {
        pushMatrix();
        // Scale up by 200
        float factor = 600;
        translate(v.x*factor,v.y*factor,factor-v.z*factor);
        // Draw a point
        color c = color(100-((v.z-minz)/0.8*100)/2+min(disturbance.mag()*500,50),100,100);
        stroke(c);
        fill(c);
        beginShape();
        vertex(0,-1);
        vertex(1,0);
        vertex(0,1);
        vertex(-1,0);
        endShape();
        popMatrix();
      }
    }
  }
  popMatrix();
  endRaw();
  return filename;
}

// These functions come from: http://graphics.stanford.edu/~mdfisher/Kinect.html
float rawDepthToMeters(int depthValue) {
  if (depthValue < 2047) {
    return (float)(1.0 / ((double)(depthValue) * -0.0030711016 + 3.3309495161));
  }
  return 0.0f;
}

PVector depthToWorld(int x, int y, int depthValue) {

  final double fx_d = 1.0 / 5.9421434211923247e+02;
  final double fy_d = 1.0 / 5.9104053696870778e+02;
  final double cx_d = 3.3930780975300314e+02;
  final double cy_d = 2.4273913761751615e+02;

  PVector result = new PVector();
  double depth =  depthLookUp[depthValue];//rawDepthToMeters(depthValue);
  result.x = (float)((x - cx_d) * depth * fx_d);
  result.y = (float)((y - cy_d) * depth * fy_d);
  result.z = (float)(depth);
  return result;
}

void stop() {
  kinect.quit();
  super.stop();
}


