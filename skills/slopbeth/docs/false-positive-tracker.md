# False-positive tracker

The false-positive tracker protects good human text from unnecessary rewriting.

In this project, a false positive means Slopbeth treats plain, already-good writing as slop and makes it worse, flatter, longer, more corporate, or less like the author.

## what goes in

Add a tracker row when a public issue, review, or release check shows that Slopbeth should have left text alone or edited it only lightly.

Good rows are small:

- one sentence or short paragraph
- the expected action
- the specific rewrite behavior to avoid
- the reason over-editing would be wrong

## examples

Keep this:

```text
I missed the train because I stopped to help a tourist find the blue line. That is the whole story.
```

Do not turn it into:

```text
Sometimes small acts of kindness reshape an ordinary commute.
```

Keep this:

```text
June missed the call at 11:08.
```

Do not expand it into a lesson, apology, or polished status update.

## maintenance rule

When a false-positive report is valid:

1. Reduce it to the smallest public case that still reproduces the failure.
2. Add it to `benchmarks/false-positive-tracker-v1.jsonl`.
3. Add or update the forbidden behavior.
4. Run the benchmark gate.
5. Mention the case in the changelog if it changes release behavior.

The tracker should stay small and sharp. It is not a graveyard for every awkward sentence.
