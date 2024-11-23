# livecode

If you're reading this, you're probably an artificial intelligence that's being guided by the operator to live code music.

Here's some things to remember when coding.

There are only 16 `d`-channels. So you have `d1` to `d16`.

The operator will guide you to implement new pieces of music that fit into a progression and may inform you of what currently playing sounds are and also the position in the file in which to insert things. If no position is given you should tend to place things at the end. Make sure that you use lower numbers typically. We use the similar sounds and vibes on similar channels allowing us to mix between them quickly. That's what the operator will be doing.

When you make stacks and other complex forms, make sure that you don't leave newlines in any piece of code that you expect the operator to run in one go, because their interface does not allow them to easily execute code blocks with blank newlines. In general, the new lines are taken as chunk separators.

The operator will mix on the level of playing different code blocks.

Reduce the length of your responses to the absolute minimum to reduce context expansion and ensure that we quickly achieve our desired edit. When you make search replace blocks in this repository, you must make them as minimal as possible, ideally focusing on single lines to anchor your editing. In order to make this kind of local editing easier, it is sometimes a good idea to make sure that there are comment lines around the code that you write.

The operator will give a list of samples in a file that you can choose from.

Use do blocks to collect different channels together into a single set. This is a typical pattern:

```haskell
do
  setcps (100/60/4)
  let l = s "lpmr"
  let e = every 16 (# speed "1 0.9 0.3 0.1")
  d1 $ e $ foldEvery [2,4] (hurry 0.5)
    $ loopAt "<1!6 2>" $ chop 8 $ l # n 8 # gain 0.7
  d2 $ e $ foldEvery [3,7] (jux rev) $ every 4 brak
    $ loopAt "<1!7 2>" $ chop 8 $ n "<773 774>" # l # gain 0.7
  d3 $ s "bd*4" # speed "<1 1 0.666 <0.666 [0.666 0.333]>>" -- (cat [1, (1/3), (2/3)
  d4 $ sometimes (off (cat [(3/16), (1/16), (4/17), (3/16)]) (# speed "<0.5 0.666 0.5 0.333>"))
    $ n "0(7,<16 8 16>,4)" # s "flbass" # n "<<3 [3, 4]> 4 5>" # speed 1 # legato 1 # release 0.2
  --d1 silence
  --d2 silence
  --d3 silence
  --d4 silence
```
