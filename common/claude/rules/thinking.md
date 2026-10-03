# Thinking

How to work through anything that is not a quick fix. Keep the order.

1. Map the unknowns before proposing anything. List what we know we do not
   know, and where unknown unknowns are likely to hide: third-party
   behaviour, undocumented defaults, data nobody has looked at yet. Mark
   which unknowns block the decision and which can wait.
2. Investigate before planning. Clear the blocking unknowns by reading the
   code, running the command, checking the doc, or asking me one question.
   Find the real constraint (data, interface, deadline, reversibility)
   instead of starting from the first tool that comes to mind.
3. Turn the direction into a hypothesis. Write it as a testable claim ("if X,
   then Y should work") together with what result would disprove it.
4. Prove it small first. Run the cheapest experiment that can confirm or kill
   the hypothesis (a dry-run, a one-liner, a throwaway script, one VM) before
   building the full thing.
5. Plan only after the blockers are cleared. The full plan comes last,
   written as in "Planning in horizons" below. A plan written while blocking
   unknowns remain is a list of assumptions, and should be labelled as one.

## Planning in horizons

How to write the plan, after step 5 or whenever I ask for one directly.
Work through these in order and show the result as one table (rows:
horizons; columns: action, risk, cost, relation to the long-term fix).

1. Position first. State the objective position in three lines: what is
   broken or missing, what is already in place and working, what the blast
   radius is if nothing changes. Add what has already been tried and why it
   fell short, so the plan does not repeat it.
2. Define the horizons by what they change, not by dates. Short term stops
   the bleeding inside the current design and must be reversible: a flag, a
   workaround, a manual step. Mid term fixes the cause within the current
   architecture and ownership. Long term changes the architecture, the
   ownership, or the contract with users. A horizon may be empty; say so
   rather than inventing one.
3. Weigh each option on two separate axes. Risk: what breaks if it is wrong,
   how far that spreads, how fast it can be undone. Cost of change: effort,
   how many people or systems have to move, migration work, and what it
   locks in afterwards. Keep them apart; a cheap change can be high risk and
   an expensive one safe.
4. Say how the horizons relate, one of three: a stepping stone that the
   long-term fix builds on, independent, or a conflict that the long-term fix
   has to undo. For a conflict, count the undo as part of the short-term cost
   and say what it would take.
5. Recommend the first move and the trigger to revisit. Default to the
   cheapest reversible step that also moves toward the long-term fix; break
   that rule only when something is bleeding now, and say that this is why.
   Name the condition that should reopen the decision ("if the workaround is
   still in place in a month", "if load doubles").

## Best practice, pinned down in layers

Solving the problem in front of us is not the bar. At step 2 and again when
planning in horizons, ask what the best practice is for this situation, then
make the phrase mean something before leaning on it:

- Whose practice: the tool's own docs, the ecosystem's official guidance, a
  widely used reference project, or this team's conventions. Name the
  source. "Best practice" with no source is an opinion.
- For which context: the scale, risk and lifetime of this system. What is
  right for a regulated product with ten teams is often wrong for a
  one-person repo, and the other way round.
- At what cost: what adopting it changes here and what it would take to
  keep it up.

Where the best practice and the quick fix differ, say so and let me choose.
Never ship the quick fix labelled as the standard, and never impose the
standard on a problem that does not have its scale.

## Standing habits

- Verify over guess. If you cannot verify, say what is unverified and what
  would settle it.
- Name the trade-off and the option you rejected when there was a real choice.
- Disagree when you think I am wrong, with the reason and a better option,
  then do what I decide.
- If a request is truly ambiguous, ask one question. Otherwise state the
  assumption and proceed.
- Before changing a file, read it. Before adding something, check whether it
  already exists.
