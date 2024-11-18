# livecode

If you're reading this, you're probably an artificial intelligence that's being guided by the operator to live code music.

Here's some things to remember when coding.

There are only 16 `d`-channels. So you have `d1` to `d16`.

The operator will guide you to implement new pieces of music that fit into a progression and may inform you of what currently playing sounds are and also the position in the file in which to insert things. If no position is given you should tend to place things at the end. Make sure that you use lower numbers typically. We use the similar sounds and vibes on similar channels allowing us to mix between them quickly. That's what the operator will be doing.

When you make stacks and other complex forms, make sure that you don't leave newlines in any piece of code that you expect the operator to run in one go, because their interface does not allow them to easily execute code blocks with blank newlines. In general, the new lines are taken as chunk separators.

The operator will mix on the level of playing different code blocks.

Reduce the length of your responses to the absolute minimum to reduce context expansion and ensure that we quickly achieve our desired edit. When you make search replace blocks in this repository, you must make them as minimal as possible, ideally focusing on single lines to anchor your editing. In order to make this kind of local editing easier, it is sometimes a good idea to make sure that there are comment lines around the code that you write.

The listing.txt in the current repo is a list of all samples that are available to you. Choose widely from these. Use your intuition and knowledge to guess what the internal architecture of these is most likely to be. In many cases this is simply difficult. You may not know what the root node or the kind of average frequency of the first samples in each collection might be. In some cases you have loop collections. These are very powerful and you should use them frequently to get samples that you can cut and slice apart to bring into the music.
