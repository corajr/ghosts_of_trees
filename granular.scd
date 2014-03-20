(
SynthDef("granular", { |out = 0, buf = 0, newGrain = 200, grainSize = 0.05, rate = 1, pos = 0.5, amp = 0.0, pan = 0, gate = 1|
    var mix, env;

    // env = Env.cutoff(4,1);
    env = Env.adsr(0.001, 0.2, 1, 4, 1);
    mix = GrainBuf.ar(2, Impulse.kr(newGrain), grainSize, buf, rate, pos, 2, pan);

    Out.ar(out, mix*amp*EnvGen.kr(env, gate, doneAction: 2));
}).add; //replace .add; with .writeDefFile; if NRT is desired
)


// Non-realtime audio rendering (fix paths as needed)
(
TempoClock.default.tempo = 12;
Score.writeFromFile("/Users/chrisjr/Documents/Processing/fractal_sc/score.txt", "/Users/chrisjr/test.osc", TempoClock.default);
unixCmd("/Applications/SuperCollider/SuperCollider.app/Contents/Resources/scsynth -N ~/test.osc _ ~/test.aiff 44100 AIFF int16 -m 32768 -o 2")
)
