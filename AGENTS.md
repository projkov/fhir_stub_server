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
