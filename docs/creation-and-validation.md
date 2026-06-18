# Creation and Validation

Slopbeth was built by iteration, not by training a model.

The workflow used:

- benchmark research on detector credibility and writing evaluation
- a fixed anti-slop taxonomy
- source-locked rewrite rules
- hidden-gold forward tests
- red, green, and refactor judge rows
- semantic-drift checks
- unsummarizability checks
- detector-panel records
- clean-room similarity scans
- RAID smoke validation on `omarchy`

The quality gate passed. The detector-immunity gate did not pass, because public detectors disagreed and one detector flagged a human-control sample. That result shaped the final rule: detectors are weak regression evidence, not the definition of good writing.

The release target is narrower and more useful:

- fewer generic claims
- less filler
- stronger source preservation
- denser prose
- fewer unsupported edits
- clear benchmark artifacts
