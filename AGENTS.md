<!-- BEGIN KATA (managed by `kata init --with-agents`) -->
This workspace tracks its work in kata. Use kata for the changes the user asks
you to make here, not for questions, explanations, or reviews that change
nothing.

Before starting a change, look for an existing issue:

    kata search "<one or two distinctive words>" --agent

Search returns issues that contain every word, so add words only to narrow the
results. If an open issue covers the work, use it. Otherwise create one:

    kata create "<title>" --body "<what and why>" --idempotency-key <key> --agent

If create reports a look-alike, use that issue unless the work truly differs
(--force-new). Link related but different work with --related <ref>, or
--parent <ref> when the new issue is part of a larger one.

Claim the issue before you work on it: kata claim <ref>. When the user only
asks you to record something, create the issue and stop there.

Comment when you learn something a later reader needs:

    kata comment <ref> -m "<finding>" --agent

Close the issue as soon as the work is verified. The message needs 40 or more
characters and the close needs evidence:

    kata close <ref> --done --message "<what changed and how you verified it>" --test "<command>" --agent

Use --commit <sha> or --pr <url> instead of --test when that is the evidence.
If you stop before the work is done, leave the issue open and say what remains:

    kata label add <ref> needs-review --comment "<what remains>"

Never run kata delete or kata purge unless the user asks for that exact action.

For subagents, inboxes, attention signals, scheduling, and relationship rules,
run kata quickstart.
<!-- END KATA -->

## Issue workflow labels

kata has only open and closed, so the workflow is tracked with labels. An issue
carries one workflow label at a time; swap them with `kata label rm` and
`kata label add`.

1. `ready-for-agent`: specified and unblocked. Remove it when work starts.
2. `in-progress`: add it when you claim the issue and start the work.
3. `in-ai-review`: the implementation is done and green (`bundle exec rake`);
   run an AI code review of the change (the `code-review` skill) and fix what it finds.
4. `in-review`: the AI review is finished; the change waits for the user's review.
   Also add `ai-reviewed` once every finding is fixed or dismissed with a reason
   (recorded in a kata comment) and `bundle exec rake` is green again.

Close the issue only after the user has reviewed and pushed the change, with the
pushed commit as evidence (`--commit <sha>`).
