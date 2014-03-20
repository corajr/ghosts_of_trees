/*
 * This code was based on Patrick Dwyer's L-System class,
 * with additions for SuperCollider integration.
 */

class StochasticLSystem {

  int steps = 0;

  String axiom;
  String production;

  float startLength;
  float drawLength;
  float theta;
  float playbackRate = 1.0;
  float angleJitter = 0.4;

  int treeType;  // -1 is custom
  int xoff = 0;
  int generations;
  Rule rules[];

  Deque<Position> posStack = new ArrayDeque<Position>();
  ArrayList<PVector> parts = new ArrayList<PVector>();
  ArrayList<Segment> segs = new ArrayList<Segment>();
  ArrayList<MusicalEvent> events[];

  int eventsCalled[];
  int currentY;

  float maxGrainSize = 0.2;
  float minGrainSize = 0.01;
  boolean logGrains = true;

  SynthWrapper synths[];
  int maxSynthWrappersNeeded;

  int buf = 0;
  boolean mySynthsInitialized = false;
  boolean eventsInitialized = false, segmentsInitialized = false;
  boolean stillRising = true, wasStillRising = true;


  float minX, maxX, minY, maxY;

  StochasticLSystem(String _axiom, float _theta, int _xoff, int _treeType) {

    treeType = _treeType;

    if (treeType == -1) {
      axiom = _axiom;
      startLength = 60.0;
    }
    else {
      setTreeType(treeType);
    }

    theta = _theta;
    xoff = _xoff;
    minX = xoff;
    maxX = xoff;
    minY = height;
    maxY = height;
    events = new ArrayList[height];
    eventsCalled = new int[height];
    for (int i = 0; i < height; i++) {
      eventsCalled[i] = 0;
    }
    currentY = height - 1;
    reset();
  }

  StochasticLSystem() {
    this("F", radians(25.0), width/2, 0);
  }

  void reset() {
    production = axiom;
    drawLength = startLength;
    generations = 0;
  }

  int getAge() {
    return generations;
  }

  void simulate(int gen) {
    while (getAge () < gen) {
      production = iterate(production);
    }
  }

  void render() {
    translate(xoff, height);
    steps = production.length();

    for (int i = 0; i < steps; i++) {
      char step = production.charAt(i);
      if (step == 'F') {
        noFill();
        stroke(0);
        line(0, 0, 0, -drawLength);
        translate(0, -drawLength);
      } 
      else if (step == '+') {
        rotate(theta);
      } 
      else if (step == '-') {
        rotate(-theta);
      } 
      else if (step == '[') {
        pushMatrix();
      } 
      else if (step == ']') {
        popMatrix();
      }
    }
  }

  ArrayList<Segment> renderToSegments() {
    PVector pos = new PVector(xoff, height - 1);
    segs.clear();
    float currentAngle = 0.0;

    steps = production.length();

    int i = 0;
    while (i < steps) {
      char step = production.charAt(i);
      if (step == 'F') {
        //         PVector toPoint = new PVector(drawLength*sin(currentAngle), -drawLength*cos(currentAngle));
        PVector toPoint = new PVector(drawLength*sin(currentAngle + (random(-1, 1)*angleJitter)), -drawLength*cos(currentAngle + (random(-1, 1)*angleJitter)));

        // if you want longer segments, comment the above and uncomment beow
        //        PVector toPoint = new PVector(0, 0);

        int j = i;
        while (j + 1 < steps && production.charAt (j+1) == 'F') {
          j++;
        }
        //        float newAngle = random(-1,1)*angleJitter*currentAngle;
        //        toPoint.x = toPoint.x * cos(newAngle) - toPoint.y * sin(newAngle);
        //        toPoint.y = toPoint.x * sin(newAngle) + toPoint.y * cos(newAngle);

        float branchSize = constrain((j - i)/7.0 + 0.25, 0.5, 10);
        PVector newPoint = PVector.add(pos, toPoint);
        segs.add(new Segment(pos, newPoint, branchSize));
        if (newPoint.x < minX) minX = newPoint.x;
        if (newPoint.y < minY) minY = newPoint.y;
        if (newPoint.x > maxX) maxX = newPoint.x;
        if (newPoint.y > maxY) maxY = newPoint.y;
        pos = newPoint;
        //        continue;
      } 
      else if (step == '+') {
        currentAngle += theta;
      } 
      else if (step == '-') {
        currentAngle -= theta;
      } 
      else if (step == '[') {
        posStack.addFirst(new Position(new PVector(pos.x, pos.y), currentAngle));
      } 
      else if (step == ']') {
        Position p = posStack.removeFirst();
        pos = p.vec;
        currentAngle = p.angle;
      }
      i++;
    }

    if (audio) generateEvents();
    segmentsInitialized = true;
    return segs;
  }

  void generateEvents() {
    for (int i = 0; i < height; i++) {
      events[i] = new ArrayList<MusicalEvent>();
    }
    ListIterator itr = segs.listIterator();
    while (itr.hasNext ()) {
      Segment seg = (Segment) itr.next();
      MusicalEvent m = new MusicalEvent();
      if (int(seg.start.y) >= height || int(seg.start.y) < 0) continue;
      m.yValue = int(seg.start.y);
      m.pos = (seg.start.x - minX) / (maxX - minX);
      m.pan = constrain(4 * (seg.start.x - xoff) / width, -1, 1);
      m.buf = buf;
      m.rate = playbackRate; // exp(log(2)*round(map(((maxY-minY) - seg.start.y) / (maxY-minY), 0, 1, -1, 1)));
      if (!logGrains) {
        m.grainSize = ((m.yValue - minY) * (maxGrainSize-minGrainSize)/maxY) + minGrainSize;
      }
      else {
        //        float myLog = log(maxY/(maxGrainSize/minGrainSize));
        float logarithm = log((maxY + (m.yValue - minY))/maxY);
        float base = log(2) / (maxGrainSize - minGrainSize);
        logarithm /= base;
        logarithm += minGrainSize;
        m.grainSize = logarithm;
      }
      // x == 0: f(x) = 0.01
      // x == 480: f(x) = 0.1
      events[int(seg.start.y)].add(m);
      for (int i = int(seg.start.y) - 1; i > int(seg.end.y); i--) {
        if (i > 0 && i < height) {
          float x = lerp(seg.start.x, seg.end.x, (seg.start.y - i) / (seg.start.y - seg.end.y) );
          MusicalEvent n = new MusicalEvent();
          n.buf = buf;
          n.pan = constrain(4 * (x - xoff) / width, -1, 1);
          n.yValue = i;
          n.pos = constrain((x - minX) / (maxX - minX), 0, 1);
          if (!logGrains) {
            n.grainSize = ((n.yValue - minY) * (maxGrainSize-minGrainSize)/maxY) + minGrainSize;
          }
          else {
            //        float myLog = log(maxY/(maxGrainSize/minGrainSize));
            float logarithm = log((maxY + (n.yValue - minY))/maxY);
            float base = log(2) / (maxGrainSize - minGrainSize);
            logarithm /= base;
            logarithm += minGrainSize;
            n.grainSize = logarithm;
          }

          events[i].add(n);
          //          print(i);
          //          println(" "+str(x) + str(n.pos));
          if (events[i].size() > maxSynthWrappersNeeded) maxSynthWrappersNeeded = events[i].size();
        }
      }
      //      if (events[int(seg.start.y)].size() > maxSynthWrappersNeeded) maxSynthWrappersNeeded = events[int(seg.start.y)].size();
    }

    genSynthWrappers(maxSynthWrappersNeeded);

    for (int i = 0; i < height; i++) {
      ListIterator evtItr = events[i].listIterator();
      while (evtItr.hasNext ()) {
        MusicalEvent m = (MusicalEvent) evtItr.next();
        //        if (synths.length > evtItr.previousIndex())
        m.mySynthWrapper = synths[evtItr.previousIndex() % synths.length];
        //        m.rate = exp(log(2)*int(random(-2, 2)));
        //      }
      }
    }
    eventsInitialized = true;
  }

  void genSynthWrappers(int numOfSynthWrappers) {
    println(numOfSynthWrappers);
    if (mySynthsInitialized) {
      for (int i = 0; i < synths.length; i++) {
        synths[i].free();
      }
    }
    mySynthsInitialized = false;
    synths = new SynthWrapper[numOfSynthWrappers];
    for (int i = 0; i < numOfSynthWrappers; i++) {
      synths[i] = new SynthWrapper("granular", absoluteID);
      synths[i].create();
      absoluteID++;
    }
    mySynthsInitialized = true;
  }

  void setTreeType(int type) {
    axiom = defaultAxioms[type];
    rules = getRuleSet(type);
    startLength = defaultLengths[type];
    reset();
  }
  String iterate(String prod_) {
    drawLength = drawLength * 0.6;
    generations++;
    String newProduction = prod_;
    float rnd = random(1);
    for (int i = 0; i < rules.length; i++) {
      if (rules[i].weight == 1) {
        newProduction = rules[i].execute(newProduction);
        continue;
      }
      rnd -= rules[i].weight;
      if (rnd < 0) {
        newProduction = rules[i].execute(newProduction);
        break;
      }
    }

    return newProduction;
  }
}

class Rule {
  String input;
  String output;
  float weight;

  Rule(String _input, String _output, float _weight) {
    input = _input;
    output = _output;
    weight = _weight;
  }
  Rule(String _input, String _output) {
    this(_input, _output, 1);
  }

  String execute(String production) {
    return production.replaceAll(input, output);
  }
}

class Position {
  PVector vec;
  float angle;

  Position(PVector _vec, float _angle) {
    vec = _vec;
    angle = _angle;
  }
}

class Segment {
  PVector start;
  PVector end;
  float strokeWidth = 0.5;
  Segment(PVector _start, PVector _end, float _strokeWidth) {
    start = _start;
    end = _end;
    strokeWidth = _strokeWidth;
  }
}

class MusicalEvent {
  float pos, amp, rate, pan, grainSize, newGrainRate;
  int yValue, buf;
  SynthWrapper mySynthWrapper;
  boolean mute;

  MusicalEvent(SynthWrapper _thisSynthWrapper, int _yValue, int _buf, float _pos, float _amp, float _pan, float _rate, float _grainSize, float _newGrainRate) {
    yValue = _yValue;
    pos = _pos;
    amp = _amp;
    pan = _pan;
    rate = _rate;
    grainSize = _grainSize;
    newGrainRate = _newGrainRate;
    buf = _buf;
    mute = false;
    mySynthWrapper = _thisSynthWrapper;
  }
  MusicalEvent() {
    //    this(null, height, 0.5, 0.05, 0.0, 1, 0.05, 20);
    //    this(null, height, 0.5, 0.05, 0.0, 1, 0.2, 10);
    this(null, height, 0, 0.5, 0.1, 0.0, 1, 0.1, -1.0);
  }

  void send() {
    if (mute) mySynthWrapper.set("amp", 0.0);
    else {
      mySynthWrapper.set("pos", pos);
      mySynthWrapper.set("amp", amp);
      mySynthWrapper.set("rate", rate);
      if (newGrainRate == -1.0) newGrainRate = (1.0/grainSize)*2.0;
      mySynthWrapper.set("newGrain", newGrainRate);
      mySynthWrapper.set("grainSize", grainSize);
      mySynthWrapper.set("pan", pan);
      mySynthWrapper.set("buf", buf);
    }
  }
  void printMe() {
    print(yValue);
    print(" ");
    println(pos);
  }
}

Rule[] getRuleSet(int index) {
  Rule[] rules;

  switch (index) {
  case 0: 
    rules = new Rule[3];
//    rules[0] = new Rule("F", "FF-[-F+F+F]+[+F-F-F]");
    rules[0] = new Rule("F", "FF");
    rules[1] = new Rule("X", "F-[[X]+X]+F[+FX]-X", 2.0/3.0);
    rules[2] = new Rule("X", "F+[[X]-X]-F[-FX]+X", 1.0/3.0);

//    rules[1] = new Rule("X", "F[+X]F[-X]+X", 1.0/2.0);
//    rules[2] = new Rule("X", "F[-X]F[+X]-X", 1.0/2.0);

    //    rules[0] = new Rule("F", "FF");
    //    rules[1] = new Rule("X", "F-[[X]+X]+F[+FX]-X", 1.0/3.0);
    //    rules[2] = new Rule("X", "F-[[-X]+X]+F[+FX]-X", 1.0/3.0);
    //    rules[3] = new Rule("X", "F-[[--X]-X]+F[+FX]-X", 1.0/3.0);
    break;
  case 2:
    rules = new Rule[3];
    rules[0] = new Rule("F", "FF");
    rules[1] = new Rule("X", "F-[[X]+X]+F[+FX]-X", 1.0/3.0);
    rules[2] = new Rule("X", "F+[[X]-X]-F[-FX]+X", 2.0/3.0);

    //    rules[2] = new Rule("X", "F-[[-X]+X]+F[+FX]-X", 1.0/3.0);
    //    rules[3] = new Rule("X", "F-[[--X]-X]+F[+FX]-X", 1.0/3.0);
    break;
  case 1:
  default:
    rules = new Rule[2];
    rules[0] = new Rule("F", "FF");
    rules[1] = new Rule("X", "F[+X][-X]FX");

//    rules[0] = new Rule("F", "F[+F]F[-F]", 1.0/3.0);
//    rules[1] = new Rule("F", "F[+F]F[+F]", 1.0/3.0);
//    rules[2] = new Rule("F", "F[-F]F[-F]", 1.0/3.0);

    break;
  }
  return rules;
}

