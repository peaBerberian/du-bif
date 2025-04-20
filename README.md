# du-bif

**NOTE: This is a not-functional Work-In-Progress for now**

This is a simple tool written to allow the packaging of BIF files: archives
containing video thumbnails.

## What is this "BIF" thing?

Media streaming platforms often provide "thumbnail previews" when for example
scrubbing over a slider below the video, to roughly preview the video frame
if you seeked at that position.

This may be implemented in multiple ways, but one of the most frequent ones is
by relying on a "BIF" file, which is an archive format grouping all thumbnails
in a common file.

Then media players usually load that file when the content is loaded, unpack the
archive themselves ([a very simple
operation](https://github.com/peaBerberian/rx-player/blob/82796cfebbe2e2fe51603b312824d6481ac699fb/src/parsers/images/bif.ts#L49-L143))
and then display the right one depending on where the end user moves their mouse
on the screen.

## How to use this tool?

This tool only creates the BIF archive format, it doesn't generate ones from
your video.

For now it thus rely on you having already generated individual thumbnails and
putting them in a common directory.
Like most things in life, this is just a single `ffmpeg` call away:

```sh
# Create directory where thumbnails will be outputed.
mkdir thumbnails

# Generate thumbnails with resolution 320x180 for every two seconds of content
# (-r 0.5 = An image every two seconds)
ffmpeg -i input.mp4 -r 0.5 -vf "scale=320:180" thumbnails/thumb_%d.jpg
```

Each thumbnail's file name has to end with an integer (like in this example)
which increments to follow chronological order. There can be leading zeroes or
not in that integer, both are supported.

Then you can generate the resulting BIF file containing all those thumbnails by
calling the following command:

```sh
# call du-bif to construct the BIF archive. The "interval" option indicates
# here that thumbnails were generated for every 2 seconds (2000 milliseconds).
dubif --input thumbnails/ --output output.bif --interval 2000
```
