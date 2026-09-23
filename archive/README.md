# Performance archive — mined pi session transcripts

`*.evals.tidal` / `*.evals.jsonl` are extracted from the pi session logs in
`~/.pi/agent/sessions/--home-erik-livecode--/` by
`~/pi-tidal/tools/extract_session_evals.py`.

Each file is the complete, in-order trace of every `tidal_eval` sent in one
session — i.e. the edit history of a performance, with timestamps. The big one
(`01a0c051-*.evals.tidal`, 274 chunks) is the 36-minute "Nocturne Soul ->
machine noise -> lo-fi" take: `recordings/jam-20260923-1403.*`.

Regenerate:

    ~/pi-tidal/tools/extract_session_evals.py --all --include-marks \
        --project /home/erik/livecode
