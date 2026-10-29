---
id: "01a1837d-a5eb-740f-b6d3-b5638ea170ee"
title: "Simplified Technical English"
type: "guide"
tags:
  - "guide"
  - "ste"
created: "2026-10-28T12:10:12-05:00"
timestamp: "2026-10-28T12:10:12-05:00"
description: "The writing rules for all wiki prose, adapted from ASD-STE100, with bad and good examples from this project."
status: "draft"
generated:
  by: "claude-code/opus-5-5"
  at: "2026-10-28T12:10:12-05:00"
---

# Simplified Technical English

Write all prose in this wiki in Simplified Technical English (STE). STE comes from the ASD-STE100 specification. It makes text easy to read for humans, for readers whose first language is not English, and for AI agents.

## Words

1. Use the words in [Terminology](/guides/terminology--01a1837da60b.md). Use one word for one thing.
2. Use simple, common words. Write "use", not "utilize". Write "start", not "initiate".
3. Use a verb as a verb. Write "verify the signature", not "do a verification of the signature".
4. Do not use phrasal verbs. Write "remove", not "get rid of". Write "find", not "figure out".
5. Do not use slang, idioms or jokes.
6. Write technical names in code font: commands, paths, flags, file names, environment names.

## Sentences

1. Keep a procedure sentence to 20 words or fewer.
2. Keep a descriptive sentence to 25 words or fewer.
3. Write one instruction in one sentence.
4. Use the active voice. Write "The PDP blocks the release", not "The release is blocked".
5. Use the articles "a", "an" and "the". Do not drop them to save words.
6. Use the present tense for facts. Use the past tense only for events, with a date.

## Procedures

1. Use a numbered list for steps that occur in sequence.
2. Start each step with a verb in the imperative.
3. Put a warning before the step that it applies to. Give the condition first.

Bad:

> Bump the toolchain (but don't set GOTOOLCHAIN to the version, or it'll quietly download its own compiler and ignore the new image).

Good:

> WARNING: Do not set `GOTOOLCHAIN` to a version string. If you do, Go downloads that compiler and ignores the new toolchain image.
>
> 1. Set the new toolchain digest in `versions.json`.
> 2. Record the patch version in `goVersion`.

## Descriptive text

1. Write one topic in one paragraph.
2. Keep a paragraph to six sentences or fewer.
3. Put the most important fact in the first sentence.
4. Write the `description` field as one sentence of 25 words or fewer. The `index.md` listings and the search results show it.

Bad:

> So basically observe mode is kind of a soft-launch thing where stuff still gets scanned but nothing really blocks, which is handy when you're onboarding something noisy.

Good:

> An image in `observe` mode gets a full scan and a signed `PASS` verdict. If the image has violations, the release actor puts it in `quarantine/`.

## Facts and opinions

Keep a recorded fact separate from an analysis. Put your analysis under a heading that says so, for example "Analysis". A reader must know which text is the record.

## Related

* [Wiki conventions](/guides/wiki-conventions--01a1837da62e.md): how to structure a concept.
* [Terminology](/guides/terminology--01a1837da60b.md): the controlled words.
