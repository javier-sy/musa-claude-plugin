# MusaDSL Condensed Reference

MusaDSL is a Ruby framework for algorithmic music composition. This reference covers all subsystems with accurate API signatures.

## Architecture

```
Transport (clock → sequencer) → Series (lazy generators) → Neumas (notation)
    ↓                              ↓                          ↓
Sequencer DSL                  Generative tools           Datasets (GDV/PDV)
(at, every, play, move)       (Markov, Rules, etc.)        ↓
    ↓                                                   Transcription → MIDI/MusicXML
MIDIVoices (output)
```

**Include pattern**: `include Musa::All` gives access to all modules. Individual: `include Musa::Series`, `include Musa::Scales`, etc.

## Setup Pattern (main.rb)

```ruby
require 'musa-dsl'
require 'midi-communications'
include Musa::All
using Musa::Extension::Neumas  # FILE-SCOPED — must declare in EACH file

output = MIDICommunications::Output.gets
clock_input = MIDICommunications::Input.gets  # for MIDI sync

# Clock options:
clock = InputMidiClock.new(clock_input)                    # DAW sync
# clock = TimerClock.new(bpm: 120, ticks_per_beat: 24)    # standalone
# clock = DummyClock.new(100)                               # testing

transport = Transport.new(clock, 4, 24)  # beats_per_bar, ticks_per_beat
scale = Scales.et12[440.0].major[60]     # A=440, C major, middle C
voices = MIDIVoices.new(sequencer: transport.sequencer, output: output, channels: [0, 1])

# Transcriptor for ornament expansion (required for tr, mor, st, turn)
transcriptor = Musa::Transcription::Transcriptor.new(
  Musa::Transcriptors::FromGDV::ToMIDI.transcription_set(duration_factor: 1/4r),
  base_duration: 1/4r, tick_duration: 1/96r)
decoder = Musa::Neumas::Decoders::NeumaDecoder.new(scale, base_duration: 1/4r, transcriptor: transcriptor)

transport.sequencer.with(scale: scale, voices: voices, decoder: decoder) do |scale:, voices:, decoder:|
  # ... schedule events here ...
end
transport.start
```

## Series — Lazy Sequence Generators

**CRITICAL**: Series are LAZY. They do NOT have `.each`. Use `.next_value` for manual iteration, or `play` in sequencer. Must call `.i` to instantiate before iterating.

### Constructors

| Constructor | Signature | Description |
|-------------|-----------|-------------|
| `S(...)` | `S(*values)` | Array serie from values |
| `E(&block)` | `E { next_value }` | Serie from evaluation block |
| `H(k: s, ...)` | `H(key1: serie1, key2: serie2)` | Hash serie (stops at shortest) |
| `HC(k: s, ...)` | `HC(key1: serie1, key2: serie2)` | Hash combined (cycles all) |
| `A(s1, s2)` | `A(serie1, serie2)` | Array of series (stops at shortest) |
| `AC(s1, s2)` | `AC(serie1, serie2)` | Array combined (cycles all) |
| `FOR(...)` | `FOR(from:, to:, step:)` | Numeric range generator |
| `MERGE(...)` | `MERGE(s1, s2, s3)` | Concatenate series sequentially |
| `RND(...)` | `RND(*values)` | Random values (infinite) |
| `SIN(...)` | `SIN(steps:, amplitude:, center:)` | Sinusoidal waveform |
| `FIBO()` | `FIBO()` | Fibonacci sequence |
| `HARMO(...)` | `HARMO(error:)` | Harmonic series (overtones) |
| `TIMED_UNION(...)` | `TIMED_UNION(s1, s2)` or `TIMED_UNION(k: s)` | Merge timed series |

### Operations

```ruby
serie.map { |v| transform(v) }      # Transform values
serie.select { |v| condition(v) }    # Filter (keep matching)
serie.remove { |v| condition(v) }    # Filter (remove matching)
serie.with(k: other_serie) { |v, k:| ... }  # Combine series
serie.repeat(n)                      # Repeat n times
serie.autorestart                    # Restart when exhausted
serie.reverse                        # Reverse order
serie.randomize                      # Randomize order
serie.max_size(n)                    # Limit to n values
serie.skip(n)                        # Skip first n values
serie.shift(n)                       # Circular rotation
serie.cut(n)                         # Split into chunks of size n
serie.merge / serie.flatten          # Flatten nested series
serie.after(other)                   # Concatenate
serie.buffered                       # Enable multiple readers
serie.quantize(step:)                # Quantize values
```

### Usage Pattern
```ruby
melody = S(0, 2, 4, 5, 7)
inst = melody.i           # Instantiate
inst.next_value            # => 0
inst.next_value            # => 2
inst.to_a                  # => [4, 5, 7] (remaining values)

# In sequencer: use play (handles lazy iteration)
play melody, decoder: decoder, mode: :neumalang do |gdv|
  # ...
end
```

## Neumas — Text Notation

**Format**: `(grade duration velocity ornament)` — each element in parentheses.

```ruby
using Musa::Extension::Neumas  # Required in EACH file
'(0 1 mf)'.to_neumas           # Grade 0, 1x base_duration, mezzo-forte
'(+2 2) (-1 1/2)'.to_neumas    # Relative grades; half note; eighth (if base=1/4r)
'(silence 2)'.to_neumas        # Rest, 2x base_duration
```

**Durations are MULTIPLES of base_duration** (not fractions like /4):
- If `base_duration = 1/4r`: `1` = quarter, `2` = half, `4` = whole, `1/2` = eighth

**Velocities**: `ppp pp p mp mf f ff fff` | Relative: `+f +ff -p -pp`

**Ornaments** (require Transcriptor): `tr` (trill), `mor` (mordent), `st` (staccato), `turn` (grupetto)

**Parallel voices**: Use `|` operator — `'(0 1 mf)' | '(4 1 f)'`

## Sequencer DSL

```ruby
transport.sequencer.with do
  at 1 do ... end                    # At bar 1 (absolute position)
  wait 2 do ... end                  # 2 bars from now (relative)
  now do ... end                     # Immediately

  # Play a serie with timing from dataset durations
  control = play serie, decoder: decoder, mode: :neumalang do |gdv|
    pdv = gdv.to_pdv(scale)
    voice.note pitch: pdv[:pitch], velocity: pdv[:velocity], duration: pdv[:duration]
  end
  control.after { launch :next_section }  # Chain when done

  # Recurring events
  every 1, duration: 8 do ... end    # Every bar for 8 bars

  # Animated values
  move from: 0, to: 127, duration: 4, every: 1/4r do |v| ... end
  move from: {p: 60, v: 80}, to: {p: 72, v: 120}, duration: 2, every: 1/4r do |vals| ... end

  # Events for section chaining
  on :section_a do ... end
  launch :section_a                  # Trigger event
end
```

**position** — current bar position (available inside sequencer blocks).

## Scales & Music

```ruby
scale = Scales.et12[440.0].major[60]          # C major at middle C
scale = Scales.et12[440.0].minor_harmonic[69]  # A harmonic minor

# Access notes
scale[0].pitch        # => 60 (tonic)
scale[4].pitch        # => 67 (dominant)
scale.tonic           # NoteInScale
scale.dominant        # NoteInScale
scale[:V]             # Roman numeral access

# Note operations
note.sharp / note.flat / note.sharp(n)  # Chromatic alteration
note.at_octave(1)                       # Octave transposition
note.frequency                          # Hz value

# Chords
chord = scale.tonic.chord               # Triad from scale degree
chord = scale.tonic.chord(:seventh)     # Seventh chord
chord.pitches                           # => [60, 64, 67]
chord.quality                           # => :major
chord.with_quality(:minor)              # Change quality
chord.with_size(:ninth)                 # Change extension
chord.with_move(root: -1, fifth: 1)    # Voicing
chord.with_duplicate(root: -2)          # Double note in octave
```

**Available scales**: `major minor minor_harmonic major_harmonic chromatic dorian phrygian lydian mixolydian locrian pentatonic_major pentatonic_minor blues blues_major whole_tone diminished_hw diminished_wh minor_melodic dorian_b2 lydian_augmented lydian_dominant mixolydian_b6 locrian_sharp2 altered double_harmonic hungarian_minor phrygian_dominant neapolitan_minor neapolitan_major bebop_dominant bebop_major bebop_minor`

## Generative Tools

### Markov Chains
```ruby
markov = Musa::Markov::Markov.new(
  start: 0, finish: :end,
  transitions: {
    0 => { 2 => 0.5, 4 => 0.3, 7 => 0.2 },
    2 => { 0 => 0.3, 4 => 0.5, :end => 0.2 },
    # ... probabilities must sum to 1.0 per state
  }
).i  # Returns a serie — call .i then .next_value or .to_a
```

### Variatio (Cartesian product)
```ruby
variatio = Musa::Variatio::Variatio.new :name do
  field :param1, [val1, val2]
  field :param2, range_or_array
  constructor do |param1:, param2:| { ... } end
end
variatio.run           # All combinations
variatio.on(param1: [val1])  # Override at runtime
```

### Rules (L-system / tree search)
```ruby
rules = Musa::Rules::Rules.new do
  N.times do
    grow 'step' do |object, **params|
      branch new_object   # Create possibility
    end
  end
  cut 'reason' do |object|
    prune if invalid?(object)
  end
  ended_when do |object|
    object.size == target  # Check OBJECT size, NOT history
  end
end
tree = rules.apply(seed, **params)
results = tree.combinations.map(&:last)
```

**Key**: With single seed, `history` is always `[]`. Use cumulative state in the object.

### Generative Grammar
```ruby
include Musa::GenerativeGrammar
a = N('a', size: 1)          # Terminal node
b = N('b', size: 1)
grammar = (a | b).repeat(3)  # Choice + repetition
grammar.options(content: :join)  # All combinations as strings
```

**Operators**: `|` (choice), `+` (sequence), `.repeat(exactly:)`, `.repeat(min:, max:)`, `.limit { |o| condition }`

### Darwin (fitness selection)
```ruby
darwin = Musa::Darwin::Darwin.new do
  measures do |obj|
    die if unfit?(obj)
    feature :name if has_feature?(obj)
    dimension :metric, numeric_value
  end
  weight metric: 2.0, name: 1.5
end
ranked = darwin.select(population)  # Best first
```

## Datasets

| Type | Keys | Purpose |
|------|------|---------|
| GDV | grade, duration, velocity, octave, sharps, silence | Score notation |
| PDV | pitch, duration, velocity | MIDI values |
| GDVd | delta_grade, delta_duration, delta_velocity | Delta encoding |
| AbsD | duration, note_duration, forward_duration | Duration container |

```ruby
gdv = { grade: 0, duration: 1r, velocity: 0 }.extend(GDV)
pdv = gdv.to_pdv(scale)     # => { pitch: 60, duration: 1r, velocity: 64 }
pdv.to_gdv(scale)           # Reverse conversion
```

**Score container**: `score = Score.new` → `score.at(pos, add: dataset)` → `score.between(a, b)` → `score.to_mxml(...)`

## Transcription

Required for ornaments. Without transcriptor, ornaments are silently ignored.

```ruby
# MIDI transcriptor (expands ornaments to note sequences)
transcriptor = Musa::Transcription::Transcriptor.new(
  Musa::Transcriptors::FromGDV::ToMIDI.transcription_set(duration_factor: 1/4r),
  base_duration: 1/4r, tick_duration: 1/96r)

# MusicXML transcriptor (preserves ornaments as symbols)
transcriptor = Musa::Transcription::Transcriptor.new(
  Musa::Transcriptors::FromGDV::ToMusicXML.transcription_set,
  base_duration: 1/4r, tick_duration: 1/96r)
```

## MIDI

```ruby
# Device selection (interactive prompt)
output = MIDICommunications::Output.gets
input = MIDICommunications::Input.gets

# Voice management
voices = MIDIVoices.new(sequencer: sequencer, output: output, channels: [0, 1, 2])
voice = voices.voices[0]
voice.note pitch: 60, velocity: 100, duration: 1/4r      # Single note
voice.note pitch: [60, 64, 67], velocity: 90, duration: 1r  # Chord

# Recording
recorder = MIDIRecorder.new(sequencer)
input.on_message { |bytes| recorder.record(bytes) }
notes = recorder.transcription  # => [{position:, pitch:, velocity:, duration:}, ...]
```

## Transport & Clocks

| Clock | Use case | Activation |
|-------|----------|------------|
| `TimerClock.new(bpm:, ticks_per_beat:)` | Standalone | External (`clock.start`) |
| `InputMidiClock.new(midi_input)` | DAW sync | MIDI Start message |
| `ExternalTickClock.new` | Testing/integration | Manual `clock.tick()` |
| `DummyClock.new(ticks)` | Unit tests | Automatic |

```ruby
transport = Transport.new(clock, beats_per_bar, ticks_per_beat)
transport.sequencer    # Access sequencer
transport.start        # Blocks until stopped
transport.stop         # From within scheduled event

# Lifecycle callbacks
transport.before_begin { ... }   # Once before first start
transport.on_start { ... }       # Each start
transport.after_stop { ... }     # Each stop
```

## Matrix

```ruby
using Musa::Extension::Matrix
gesture = Matrix[[0, 60], [1, 62], [2, 64]]  # [time, pitch]
p_seq = gesture.to_p(time_dimension: 0)       # => [[[60], 1, [62], 1, [64]]]
```

## MusicXML Builder

```ruby
score = Musa::MusicXML::Builder::ScorePartwise.new do
  work_title "Title"
  part :p1, name: "Piano" do
    measure do
      attributes do
        divisions 4; key 1, fifths: 0; time 1, beats: 4, beat_type: 4
        clef 1, sign: 'G', line: 2
      end
      pitch 'C', octave: 4, duration: 4, type: 'quarter'
    end
  end
end
File.write("score.musicxml", score.to_xml.string)
```

## Common Pitfalls

1. **Series have NO `.each`** — use `.next_value` or `play` in sequencer
2. **Must call `.i`** on a serie before iterating (instantiation)
3. **`H()` expects keyword args** — `H(pitch: serie1, dur: serie2)`, NOT `H(serie1, serie2)`
4. **Ornaments need Transcriptor** — without one, `tr`, `mor`, `st`, `turn` are silently ignored
5. **`using` is file-scoped** — `using Musa::Extension::Neumas` must be in EACH `.rb` file
6. **Durations are multiples** — in neumas, `1` = 1x base_duration, NOT a whole note
7. **Use Rational for timing** — `1/4r` not `0.25` to avoid float precision issues
8. **Rules `history` is `[]` with single seed** — track state in the object, not history
9. **TimerClock needs external start** — call `clock.start` from another thread after `transport.start`
10. **Velocity in GDV is relative** — 0 = default (mf), positive = louder, negative = softer

## Demo Index

| Demo | Topic | Key concepts |
|------|-------|-------------|
| demo-00 | Template | Basic setup pattern |
| demo-01 | Hello Musa | First composition |
| demo-02 | Series Explorer | S, FOR, FIBO, operations |
| demo-03 | Canon | BufferSerie, polyphony |
| demo-04 | Neumas | Notation, decoder, ornaments |
| demo-05 | Markov | Probabilistic sequences |
| demo-06 | Variatio | Cartesian variations |
| demo-07 | Scale Navigator | Scales, modes, chords |
| demo-08 | Voice Leading | Chord progressions |
| demo-09 | Darwin | Fitness selection |
| demo-10 | Grammar | GenerativeGrammar |
| demo-11 | Matrix | Geometric gestures |
| demo-12 | DAW Sync | InputMidiClock, Transport |
| demo-13 | Live Coding | REPL, MusaLCE |
| demo-14 | Clock Modes | Timer, External, Dummy |
| demo-15 | OSC SuperCollider | OSC integration |
| demo-16 | OSC Max/MSP | OSC integration |
| demo-17 | Event Architecture | on/launch, sections |
| demo-18 | Parameter Automation | move, interpolation |
| demo-19 | Advanced Series | Timed, quantized, buffered |
| demo-20 | Neuma Files | .neuma file loading |
| demo-21 | Fibonacci Episodes | FIBO, structural form |
| demo-22 | Multiphase | Rules with multiple seeds |
