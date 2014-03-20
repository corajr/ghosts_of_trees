import supercollider.*;
import oscP5.*;

import java.util.*;
/** 
 * Ghosts of Trees
 * by Chris J-R. 
 * 
 * A video of this piece is up at https://vimeo.com/38447960
 * see "granular.scd" for SuperCollider synthdef
 */

int N = 3;
int totalGenerations = 8;
int scoreIndex = 0;
StochasticLSystem trees[];
ArrayList<Segment> oldSegs[];
int absoluteID = 1000;

float totalFrames = 720.0;
PImage bg;
PFont myFont;
int bgColor = 255;
int treeColor = 0;

int defaultType = 1;

ArrayList<String> scoreBundles;
PrintWriter score;
String defaultAxioms[] = {
  "X", "X", "X"
};
float defaultLengths[] = {
  70.0, 80.0, 70.0
};


// insert the paths of your own sound files here!
String files[] = {
//  "/Users/chrisjr/Desktop/Save Me.aif", 
//  "/Users/chrisjr/Music/88422__cognito-perceptu__construction-equipment-tracked.wav",
//  "/Users/chrisjr/Music/91995__blaukreuz__0200-sayda-090927-1056.aiff"
};

float samps[];
Deque<Float> ampLevels = new ArrayDeque<Float>();
float time = 0.0, timeStep = 0.005, vol = 0.3;
float duration = 4.0;

boolean record = false, audio = false, synthsInitialized = false;
boolean scRecord = false;

void setup() {
  size(1280, 720);

  if (scRecord) {
    scoreBundles = new ArrayList<String>();
    score = createWriter("score.txt");
    score.println("[");
    for (int i = 0; i < files.length; i++) {
      score.println("[0, [\\b_allocReadChannel, " + str(i) + ", \"" + files[i] + "\", 0, -1, 0]],");
    }
    //    scoreIndex++;
  } else if (audio) {
    for (int i = 0; i < files.length; i++) {
      OscMessage msg = new OscMessage("/b_allocReadChannel");
      msg.add(i);
      msg.add(files[i]);
      msg.add(0);
      msg.add(-1);
      msg.add(0);
      Server.osc.send(msg, Server.local.addr);
    }
  }

  trees = new StochasticLSystem[N];
  oldSegs = new ArrayList[N];
  for (int i = 0; i < N; i++) {
    regenerate(i);
    trees[i].buf = i;
    trees[i].playbackRate = 1;
    oldSegs[i] = trees[i].renderToSegments();
  }
  myFont = createFont("FFScala", 12);
  textFont(myFont);
  frameRate(15);
}

void draw() {
  treeColor = constrain(int(255 * ((frameCount+20) / (totalFrames))), 0, 255);
  bgColor = constrain(int(255 * (1-(frameCount / (totalFrames)))), 0, 255);
  background(bgColor);
  //  fill(treeColor);
  //  text("FPS: " + nf(frameRate, 1, 3), 20, 20);
  //    text("Frame: " + str(frameCount), 20, 32);

  //  image(bg, 0, 0);
  smooth();


  for (int i = 0; i < N; i++) {
    trees[i].stillRising = false;

    if (trees[i].eventsInitialized && audio) {
      if (trees[i].eventsCalled[trees[i].currentY] != N) {
        Iterator evtItr = trees[i].events[trees[i].currentY].iterator();
        while (evtItr.hasNext ()) {
          MusicalEvent m = (MusicalEvent) evtItr.next();
          m.send();
          trees[i].eventsCalled[trees[i].currentY]++;
        }
      }
    }

    ListIterator itr = oldSegs[i].listIterator();
    while (itr.hasNext ()) {
      Segment seg = (Segment) itr.next();
      if (seg.start.y >= trees[i].currentY) {
        stroke(treeColor, constrain(64 - (seg.start.y - trees[i].currentY), 0, 64));
      }
      if (seg.start.y < trees[i].currentY) {
        trees[i].stillRising = true;
        stroke(treeColor, 128);
      }
      if (trees[i].segs.size() > itr.previousIndex()) {
        Segment newSeg;
        newSeg = trees[i].segs.get(itr.previousIndex());
//        newSeg = lerpSegments(seg, newSeg, time/duration);
        strokeWeight(seg.strokeWidth);
        line(newSeg.start.x, newSeg.start.y, newSeg.end.x, newSeg.end.y);
      }
    }

    if (!trees[i].stillRising && trees[i].wasStillRising) {
      //      println("done");
      trees[i].wasStillRising = false;
      if (audio) {
        for (int j = 0; j < N; j++) {
          if (trees[j].mySynthsInitialized) {
            for (int k = 0; k < trees[j].synths.length; k++) {
              trees[j].synths[k].free();
            }
            trees[j].mySynthsInitialized = false;
          }
        }
      }
    }

    //    drawBounds(trees[i]);
  }

  time += timeStep;
  for (int i = 0; i < N; i++) {
    trees[i].currentY = int(constrain(height - (height * (frameCount/totalFrames)), 0, height));// constrain(trees[i].currentY - 1, 0, height);
  }
  if (scRecord && frameCount > 1) scoreBundleConsolidate();
  scoreIndex = frameCount;

  if (record) saveFrame("/Users/chrisjr/Desktop/treenew/####.png");
  if (frameCount == int(totalFrames)) exit();
}

void regenerate(int i) {
  float thisAngle = radians(25.0+random(-5, 5));
  trees[i] = new StochasticLSystem(); // thisAxiom, thisAngle, (width/(N+1))*(i+1))
  trees[i].setTreeType(i);
  trees[i].theta = thisAngle;
  trees[i].xoff = (width/(N+1))*(i+1);
  if (i == 2 || i == 0) trees[i].simulate(totalGenerations - 1);
  else trees[i].simulate(totalGenerations);
  time = 0.0;
  trees[i].wasStillRising = true;
}

void keyPressed() {
  if (key == ' ') {
    for (int i = 0; i < 1; i++) {
      replaceTree(i);
    }
  }

  if (key == '1') {
    defaultType = 0;
    for (int i = 0; i < N; i++) {
      //      trees[i].setTreeType(0);
      replaceTree(i);
    }
  }
  if (key == '2') {
    defaultType = 1;
    for (int i = 0; i < N; i++) {
      //      trees[i].setTreeType(1);
      replaceTree(i);
    }
  }

  if (key == '=') {
    trees[0].playbackRate *= pow(2, (1/12.0));
    for (int i = 0; i < height; i++) {
      Iterator evtItr = trees[0].events[i].iterator();
      while (evtItr.hasNext ()) {
        MusicalEvent m = (MusicalEvent) evtItr.next();
        m.rate = trees[0].playbackRate;
      }
    }
  }
  if (key == '-') {
    trees[0].playbackRate /= pow(2, (1/12.0));
    for (int i = 0; i < height; i++) {
      Iterator evtItr = trees[0].events[i].iterator();
      while (evtItr.hasNext ()) {
        MusicalEvent m = (MusicalEvent) evtItr.next();
        m.rate = trees[0].playbackRate;
      }
    }
  }
  if (key == 'p') {
    for (StochasticLSystem l : trees) {
      for (int i = 0; i < l.synths.length; i++) {
        l.synths[i].get("amp", this, "show");
      }
    }
  }
}

void show (int nodeID, String arg, float value)
{
  print(str(nodeID) + " ");
  println(value);
}


void exit()
{
  if (audio) {
    for (StochasticLSystem l : trees) {
      if (l.mySynthsInitialized)
        for (int i = 0; i < l.synths.length; i++) {
        l.synths[i].free();
      }
    }
  }
  if (scRecord) {
    scoreBundleConsolidate();
    score.println("[" + str(scoreIndex+1) + ", [\\c_set, 0, 0]]");
    score.println("]");
    score.flush();
    score.close();
  }
  super.exit();
}

public static String repeat(String str, int num) {
  int len = num * str.length();
  StringBuilder sb = new StringBuilder(len);
  for (int i = 0; i < num; i++) {
    sb.append(str);
  }
  return sb.toString();
}

public static ArrayList<PVector> cloneList(ArrayList<PVector> list) {
  ArrayList<PVector> clone = new ArrayList<PVector>(list.size());
  for (int i = 0; i < list.size(); i++) clone.add(new PVector(list.get(i).x, list.get(i).y));
  return clone;
}

void drawBounds(StochasticLSystem l) {
  line(l.minX, l.minY, l.minX, l.maxY);
  line(l.minX, l.maxY, l.maxX, l.maxY);
  line(l.maxX, l.maxY, l.maxX, l.minY);
  line(l.maxX, l.minY, l.minX, l.minY);
}

Segment lerpSegments(Segment A, Segment B, float v) {
  Segment thisSegment = new Segment(A.start, A.end, A.strokeWidth);
  thisSegment.start.x = lerp(A.start.x, B.start.x, v);
  thisSegment.start.y = lerp(A.start.y, B.start.y, v);
  thisSegment.end.x = lerp(A.end.x, B.end.x, v);
  thisSegment.end.y = lerp(A.end.y, B.end.y, v);
  return thisSegment;
}

class SynthWrapper {
  Synth scSynth;
  int id;
  String name;
  boolean active;

  SynthWrapper(String _name, int i) {
    name = _name;
    id = i;
    scSynth = new Synth(name);
    active = false;
  }
  void create() {
    if (scRecord) {
      scoreBundles.add("[\\s_new, \\" + name + ", " + str(id) + ", 0, 0]");
    }
    else scSynth.create();
    active = true;
  }
  void set(String property, float val) {
    if (!active) return;
//    print(property + " ");
//    println(val);
    if (scRecord) {
      scoreBundles.add("[\\n_set, " + str(id)+", \\" + property + ", "+str(val) + "]");
    }
    else scSynth.set(property, val);
  }
  void get(String property, PApplet applet, String func) {
    if (!scRecord) scSynth.get(property, applet, func);
  }
  void free() {
    set("gate", 0.0);
    //    scSynth.free();
    active = false;
  }
}


void scoreBundleConsolidate() {
  String bundle[] = new String[scoreBundles.size()];
  for (int i = 0; i < bundle.length; i++) {
    bundle[i] = (String) scoreBundles.get(i);
  }
  if (bundle.length > 0 && bundle.length <= 20) {
    score.println("[" + str(scoreIndex) + ", " + join(bundle, ", ") + "],");
  }
  else if (bundle.length > 20) {
    int b = bundle.length;
    while (b > 20) {
      score.println("[" + str(scoreIndex) + ", " + join(subset(bundle, b-20, 20), ", ") + "],");
      b -= 20;
    }
    score.println("[" + str(scoreIndex) + ", " + join(subset(bundle, 0, b), ", ") + "],");
  }
  //  scoreIndex++;
  scoreBundles.clear();
}

void replaceTree(int i) {
  if (trees[i].mySynthsInitialized) {
    for (int j = 0; j < trees[i].synths.length; j++) {
      trees[i].synths[j].free();
    }
  }
  trees[i].mySynthsInitialized = false;
  regenerate(i);
  trees[i].renderToSegments();
}

